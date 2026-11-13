import { prisma } from "../../config/database.js";
import type { NextFunction, Request, Response } from "express";
import { AcceptGroupInvitationUseCase } from "../../usecases/groups/accept-group-invitation.usecase.js";
import { DeclineGroupInvitationUseCase } from "../../usecases/groups/decline-group-invitation.usecase.js";
import { FirebasePhoneIdentity } from "../../services/phone/phone-identity.js";
import { UnauthorizedError } from "../../utils/errors.js";
import { emitDataChange } from "../../realtime/data-changes.js";

interface InvitationWithRelations {
  id: string;
  group_id: string;
  invited_by_user_id: string;
  invited_phone: string;
  user_id: string | null;
  status: string;
  created_at: Date;
  updated_at: Date;
  groups: { name: string; image_url: string } | null;
  inviter: { name: string } | null;
}

function toUserInvitation(raw: InvitationWithRelations) {
  return {
    invitation_id: raw.id,
    group_id: raw.group_id,
    group_name: raw.groups?.name ?? "",
    group_image: raw.groups?.image_url ?? "",
    invited_phone: raw.invited_phone,
    status: raw.status,
    created_at: raw.created_at.toISOString(),
    inviter_name: raw.inviter?.name ?? "",
  };
}

export class UserInvitationsController {
  constructor(
    private readonly acceptInvitation = new AcceptGroupInvitationUseCase(),
    private readonly declineInvitation = new DeclineGroupInvitationUseCase(),
  ) {}

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user?.uid;
      if (!userId) throw new UnauthorizedError();

      const phone = await new FirebasePhoneIdentity().verifiedPhone(userId);

      const rows = await prisma.group_invitations.findMany({
        where: {
          OR: [
            { user_id: userId },
            ...(phone
              ? [{ user_id: null, status: "pending" as const, invited_phone: phone }]
              : []),
          ],
        },
        orderBy: [{ created_at: "desc" }, { id: "desc" }],
        include: {
          groups: { select: { name: true, image_url: true } },
          inviter: { select: { name: true } },
        },
      });

      res.json({
        success: true,
        data: rows.map(toUserInvitation),
      });
    } catch (error) {
      next(error);
    }
  };

  accept = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user?.uid;
      if (!userId) throw new UnauthorizedError();

      const invitationId = req.params.invitationId as string;

      // Get the user's phone for phone-match authorization
      const phone = await new FirebasePhoneIdentity().verifiedPhone(userId);

      const result = await this.acceptInvitation.execute({
        invitationId,
        userId,
        userPhone: phone,
      });

      // Emit inbox invalidation so the notification disappears
      emitDataChange({ kind: "inbox" }, [userId]);

      res.json({
        success: true,
        data: {
          invitation_id: result.invitationId,
          group_id: result.groupId,
          status: result.status,
        },
      });
    } catch (error) {
      next(error);
    }
  };

  decline = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user?.uid;
      if (!userId) throw new UnauthorizedError();

      const invitationId = req.params.invitationId as string;

      // Get the user's phone for phone-match authorization
      const phone = await new FirebasePhoneIdentity().verifiedPhone(userId);

      const result = await this.declineInvitation.execute({
        invitationId,
        userId,
        userPhone: phone,
      });

      // Emit inbox invalidation
      emitDataChange({ kind: "inbox" }, [userId]);

      res.json({
        success: true,
        data: {
          invitation_id: result.invitationId,
          group_id: result.groupId,
          status: result.status,
        },
      });
    } catch (error) {
      next(error);
    }
  };
}
