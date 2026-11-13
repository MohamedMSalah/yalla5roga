import { emitDataChange, groupRealtimeUsers, publishGroupChange } from "../../realtime/data-changes.js";
import type { NextFunction, Request, Response } from "express";
import { AddGroupMemberUseCase } from "../../usecases/groups/add-group-member.usecase.js";
import { InviteToGroupUseCase } from "../../usecases/groups/invite-to-group.usecase.js";
import { CreateGroupUseCase } from "../../usecases/groups/create-group.usecase.js";
import { RevokePendingGroupMembershipUseCase } from "../../usecases/groups/revoke-pending-group-membership.usecase.js";
import { DeleteGroupUseCase } from "../../usecases/groups/delete-group.usecase.js";
import { GetGroupUseCase } from "../../usecases/groups/get-group.usecase.js";
import { ListGroupMembersUseCase } from "../../usecases/groups/list-group-members.usecase.js";
import { ListGroupsUseCase } from "../../usecases/groups/list-groups.usecase.js";
import { RemoveGroupMemberUseCase } from "../../usecases/groups/remove-group-member.usecase.js";
import { UpdateGroupUseCase } from "../../usecases/groups/update-group.usecase.js";
import { ForbiddenError, UnauthorizedError } from "../../utils/errors.js";
import { getChatIo } from "../../realtime/chat-emitter.js";
import { groupRealtimeRoom } from "../../realtime/rooms.js";

export class GroupController {
  constructor(
    private readonly createGroup = new CreateGroupUseCase(),
    private readonly getGroup = new GetGroupUseCase(),
    private readonly listGroups = new ListGroupsUseCase(),
    private readonly updateGroup = new UpdateGroupUseCase(),
    private readonly deleteGroup = new DeleteGroupUseCase(),
    private readonly listMembers = new ListGroupMembersUseCase(),
    private readonly addMember = new AddGroupMemberUseCase(),
    private readonly inviteToGroup = new InviteToGroupUseCase(),
    private readonly revokePending = new RevokePendingGroupMembershipUseCase(),
    private readonly removeMember = new RemoveGroupMemberUseCase(),
  ) {}

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user?.uid;
      if (!userId) throw new UnauthorizedError();
      if (req.query.userId !== undefined && req.query.userId !== userId) {
        throw new ForbiddenError("You can only list your own groups");
      }
      const groups = await this.listGroups.execute(userId);
      res.json({ success: true, data: groups });
    } catch (error) {
      next(error);
    }
  };

  listForCuser = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const groups = await this.listGroups.execute(req.user.uid);
      res.json({ success: true, data: groups });
    } catch (error) {
      next(error);
    }
  };

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const group = await this.getGroup.execute(req.params.id as string, req.user.uid);
      res.json({ success: true, data: group });
    } catch (error) {
      next(error);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const group = await this.createGroup.execute({
        ...req.body,
        created_by: req.user.uid,
      });
      emitDataChange({ kind: "group", id: group.id }, [req.user.uid]);
      res.status(201).json({ success: true, data: group });
    } catch (error) {
      next(error);
    }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const group = await this.updateGroup.execute(
        req.params.id as string,
        req.user.uid,
        req.body,
      );
      await publishGroupChange(group.id, "group");
      res.json({ success: true, data: group });
    } catch (error) {
      next(error);
    }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const audience = await groupRealtimeUsers(req.params.id as string);
      const group = await this.deleteGroup.execute(
        req.params.id as string,
        req.user.uid,
      );
      emitDataChange({ kind: "membership", id: group.id }, audience);
      getChatIo()?.in(groupRealtimeRoom(group.id)).socketsLeave(groupRealtimeRoom(group.id));
      res.json({ success: true, data: group });
    } catch (error) {
      next(error);
    }
  };

  members = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const roster = await this.listMembers.execute(req.params.id as string, req.user.uid);
      res.json({ success: true, data: roster.members, pending_members: roster.pendingMembers,
        invitation_history: roster.invitationHistory ?? [] });
    } catch (error) {
      next(error);
    }
  };

  addGroupMember = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const member = await this.addMember.execute(req.user.uid, {
        group_id: req.params.id as string,
        phoneNumber: req.body.phoneNumber,
        role: req.body.role,
      });
      await publishGroupChange(req.params.id as string, "membership");
      res.status(201).json({ success: true, data: member });
    } catch (error) {
      next(error);
    }
  };

  invite = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const result = await this.inviteToGroup.execute({
        groupId: req.params.id as string,
        phoneNumber: req.body.phoneNumber,
        whatsappOptIn: req.body.whatsappOptIn,
        invitedByUserId: req.user.uid,
      });

      if (result.outcome === "member_added") {
        await publishGroupChange(req.params.id as string, "membership");
        return res.status(201).json({
          success: true,
          data: {
            outcome: "member_added",
            invitation_id: null,
            whatsapp_url: null,
            deep_link: null,
            notification_queued: false,
            member: result.member,
          },
        });
      }

      if (result.outcome === "invited") {
        await publishGroupChange(req.params.id as string, "group");
        return res.status(201).json({
          success: true,
          data: {
            outcome: "invited",
            invitation_id: result.invitation.id,
            whatsapp_url: result.whatsappUrl,
            deep_link: result.deepLink,
            notification_queued: result.notificationQueued,
            status: result.invitation.status,
            invited_phone: result.invitation.invited_phone,
          },
        });
      }

      if (result.outcome === "already_pending") {
        return res.status(409).json({
          success: false,
          message: "A pending invitation already exists for this phone number",
          data: {
            outcome: "already_pending",
            invitation_id: result.invitation.id,
            whatsapp_url: result.whatsappUrl,
            deep_link: result.deepLink,
            notification_queued: result.notificationQueued,
            status: result.invitation.status,
          },
        });
      }

      return res.status(409).json({
        success: false,
        message: "This user is already a member of the group",
        data: {
          outcome: "already_member",
          invitation_id: null,
          whatsapp_url: null,
          deep_link: null,
          notification_queued: false,
          member: result.member,
        },
      });

    } catch (error) {
      next(error);
    }
  };

  revokePendingMembership = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const invitation = await this.revokePending.execute({
        invitationId: req.params.invitationId as string,
        userId: req.user.uid,
        groupId: req.params.id as string,
      });

      await publishGroupChange(req.params.id as string, "group");
      res.json({ success: true, data: invitation });
    } catch (error) {
      next(error);
    }
  };

  removeGroupMember = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const member = await this.removeMember.execute(
        req.params.id as string,
        req.user.uid,
        req.params.userId as string,
      );
      await publishGroupChange(req.params.id as string, "membership", [req.params.userId as string]);
      res.json({ success: true, data: member });
    } catch (error) {
      next(error);
    }
  };
}
