import { prisma } from "../../config/database.js";
import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import { persistNotificationControl } from "../../services/notifications/persist-notification.js";
import { notifyOutingParticipants } from "../../services/notifications/outing-notifier.js";
import { assertIsOutingCreator } from "../../services/outings/outing-access.js";
import type { OutingGuest } from "../../types/outings/outing.types.js";
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from "../../utils/errors.js";

export class ListGuestsUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string): Promise<OutingGuest[]> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.listGuests(outingId);
  }
}

/** Owner invites a registered user — creates pending invitation (not yet a Member). */
export class AddGuestUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(
    outingId: string,
    callerUid: string,
    userId: string,
  ): Promise<OutingGuest> {
    if (!userId) throw new ValidationError("user_id is required");
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    assertIsOutingCreator(outing, callerUid);

    if (userId === outing.created_by) {
      throw new ValidationError("Owner is already a member of this outing");
    }

    const guest = await this.outings.addGuest({
      outing_id: outingId,
      user_id: userId,
      status: "pending",
    });

    return guest;
  }
}

export class AcceptOutingInvitationUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string, userId: string): Promise<OutingGuest> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");

    const accepted = await resolveOutingInvitation(outingId, userId, "accepted",
    );

    return accepted;
  }
}

export class DeclineOutingInvitationUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string, userId: string): Promise<OutingGuest> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");

    return resolveOutingInvitation(outingId, userId, "declined");
  }
}

async function resolveOutingInvitation(
  outingId: string,
  userId: string,
  status: "accepted" | "declined",
): Promise<OutingGuest> {
  const key = { outing_id: outingId, user_id: userId };
  return prisma.$transaction(async (tx) => {
    const [updated] = await tx.outing_guests.updateManyAndReturn({
    where: { ...key, status: "pending" },
    data: { status },
  });
  if (updated) {
      const outing = await tx.outings.findUniqueOrThrow({
        where: { id: outingId },
      });
      if (status === "accepted")
        await notifyOutingParticipants(
          {
            outing,
            type: "invitation",
            eventType: "outing_invite",
            body: `A member accepted the invitation to "${outing.title}".`,
            eventKey: `outing_invite_accepted:${outingId}:${userId}`,
            userIds: [outing.created_by],
          },
          tx,
        );
      await tx.notifications.updateMany({
        where: {
          user_id: userId,
          outing_id: outingId,
          type: "invitation",
          action_required: true,
        },
        data: { is_read: true, action_required: false },
      });
      await persistNotificationControl(tx, {
        recipients: [userId],
        outingId,
        type: "invitation_resolved",
        eventKey: `outing_invitation_resolved:${outingId}:${userId}:${updated.invited_at.toISOString()}`,
      });
      return updated;
    }
    const existing = await tx.outing_guests.findUnique({
    where: { outing_id_user_id: key },
  });
  if (!existing) throw new NotFoundError("Invitation");
  if (existing.status === status) return existing;
  throw new ConflictError("Invitation is no longer available");
  });
}

export class RemoveGuestUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(
    outingId: string,
    callerUid: string,
    userId: string,
  ): Promise<OutingGuest> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");

    if (callerUid === userId && outing.created_by !== callerUid) {
      throw new ForbiddenError("Members cannot leave an outing");
    }

    assertIsOutingCreator(outing, callerUid);
    return this.outings.removeGuest(outingId, userId);
  }
}
