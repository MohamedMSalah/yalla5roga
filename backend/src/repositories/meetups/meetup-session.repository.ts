import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";
import type { MeetupSession } from "../../types/meetups/meetup-session.js";

export class MeetupSessionAuthorizationPolicy {
  async requireMember(tx: Prisma.TransactionClient, groupId: string, uid: string) {
    const member = await tx.group_members.findUnique({
      where: { group_id_user_id: { group_id: groupId, user_id: uid } }, select: { user_id: true },
    });
    if (!member) throw new ForbiddenError("Current group membership required");
  }

  requireManager(session: MeetupSession, uid: string) {
    if (session.created_by_user_id !== uid) throw new ForbiddenError("Only the session creator can manage it");
  }
}

export class MeetupSessionRepository {
  invalidateInputs(tx: Prisma.TransactionClient, sessionId: string) {
    return tx.meetup_sessions.update({
      where: { id: sessionId },
      data: { input_version: { increment: 1 }, input_digest: null, calculation_status: "STALE" },
    });
  }

  async transaction<T>(
    run: (tx: Prisma.TransactionClient) => Promise<T>,
    isolationLevel: Prisma.TransactionIsolationLevel = "RepeatableRead",
  ): Promise<T> {
    for (let attempt = 0; ; attempt++) {
      try {
        return await prisma.$transaction(run, { isolationLevel });
      } catch (error) {
        // Retry a concurrent partial-unique insert or a conflicting version/lifecycle update.
        if (attempt >= 4 || !(error instanceof Prisma.PrismaClientKnownRequestError) ||
            !(["P2034", "P2002"].includes(error.code) || error.code === "P2010" &&
              ["40001", "40P01"].includes(String(error.meta?.code)))) throw error;
      }
    }
  }

  async expireDue(tx: Prisma.TransactionClient, scope: Prisma.meetup_sessionsWhereInput & {
    session_type: "GROUP" | "STANDALONE";
  }) {
    await tx.meetup_sessions.updateMany({ where: { ...scope, status: "ACTIVE", expires_at: { lte: new Date() } },
      data: { status: "EXPIRED", ...(scope.session_type === "STANDALONE" && { input_digest: null }) } });
  }

  cleanupExpired() {
    return this.transaction(async tx => {
      await this.expireDue(tx, { session_type: "GROUP" });
      await this.expireDue(tx, { session_type: "STANDALONE" });
      await tx.starting_location_overrides.deleteMany({
        where: { expires_at: { lte: new Date() } },
      });
      await tx.meetup_manual_participants.deleteMany({
        where: { meetup_session: { status: { not: "ACTIVE" } } },
      });
      await tx.$executeRaw`DELETE FROM notification_events
        WHERE event_key LIKE 'smart-meetup:%' AND channel = 'realtime'
          AND status IN ('sent', 'dead') AND created_at < now() - interval '7 days'`;
    });
  }

  async initializeStandalone(tx: Prisma.TransactionClient, uid: string) {
    const scope = { created_by_user_id: uid, session_type: "STANDALONE" as const };
    await this.expireDue(tx, scope);
    await tx.meetup_manual_participants.deleteMany({
      where: { meetup_session: { ...scope, status: { not: "ACTIVE" } } },
    });
    const existing = await tx.meetup_sessions.findFirst({ where: { ...scope, status: "ACTIVE" } });
    return existing ?? tx.meetup_sessions.create({ data: {
      ...scope, expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000),
    } });
  }

  async initialize(tx: Prisma.TransactionClient, groupId: string, outingId: string | null, uid: string) {
    if (outingId && !await tx.outings.findFirst({ where: { id: outingId, group_id: groupId }, select: { id: true } })) {
      throw new NotFoundError("Group outing");
    }
    const scope = { group_id: groupId, outing_id: outingId, session_type: "GROUP" as const };
    await this.expireDue(tx, scope);
    const existing = await tx.meetup_sessions.findFirst({ where: { ...scope, status: "ACTIVE" } });
    return existing ?? tx.meetup_sessions.create({ data: {
      ...scope, created_by_user_id: uid, expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000),
    } });
  }

  async get(tx: Prisma.TransactionClient, id: string) {
    const session = await tx.meetup_sessions.findFirst({
      where: { id },
      include: { outing: { select: { group_id: true } } },
    });
    if (!session || (session.session_type === "GROUP" &&
        (!session.group_id || (session.outing_id && session.outing?.group_id !== session.group_id)))) {
      throw new NotFoundError("Meetup");
    }
    const { outing: _outing, ...record } = session;
    return record;
  }
}
