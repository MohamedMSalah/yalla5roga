import type { Prisma, transportation_mode } from "@prisma/client";
import type { MeetupSession } from "../../types/meetups/meetup-session.js";
import { NotFoundError } from "../../utils/errors.js";

export type ManualParticipantInput = {
  latitude: number;
  longitude: number;
  display_name?: string | null;
  approximate_area?: string | null;
  transportation_mode?: transportation_mode | null;
};

export class StandaloneMeetupAuthorizationPolicy {
  requireOwner(session: MeetupSession, uid: string) {
    if (session.session_type !== "STANDALONE" || session.group_id !== null ||
        session.outing_id !== null || session.created_by_user_id !== uid) {
      throw new NotFoundError("Quick Meetup");
    }
  }
}

const participantFields = {
  id: true, display_name: true, approximate_area: true,
  latitude: true, longitude: true, transportation_mode: true,
} as const;

export class StandaloneMeetupRepository {
  list(tx: Prisma.TransactionClient, sessionId: string) {
    return tx.meetup_manual_participants.findMany({
      where: { meetup_session_id: sessionId },
      orderBy: [{ created_at: "asc" }, { id: "asc" }],
      select: participantFields,
    });
  }

  count(tx: Prisma.TransactionClient, sessionId: string) {
    return tx.meetup_manual_participants.count({ where: { meetup_session_id: sessionId } });
  }

  async add(tx: Prisma.TransactionClient, sessionId: string, input: ManualParticipantInput) {
    await tx.meetup_manual_participants.create({ data: { ...input, meetup_session_id: sessionId } });
  }

  async update(tx: Prisma.TransactionClient, sessionId: string, id: string, input: Partial<ManualParticipantInput>) {
    const { count } = await tx.meetup_manual_participants.updateMany({
      where: { id, meetup_session_id: sessionId }, data: input,
    });
    if (!count) throw new NotFoundError("Manual participant");
  }

  async remove(tx: Prisma.TransactionClient, sessionId: string, id: string) {
    const { count } = await tx.meetup_manual_participants.deleteMany({ where: { id, meetup_session_id: sessionId } });
    if (!count) throw new NotFoundError("Manual participant");
  }

  async clear(tx: Prisma.TransactionClient, sessionId: string) {
    await tx.meetup_manual_participants.deleteMany({ where: { meetup_session_id: sessionId } });
  }
}
