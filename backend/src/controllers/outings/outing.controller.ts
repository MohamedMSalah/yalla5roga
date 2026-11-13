import { z } from "zod";
import { emitDataChange, outingRealtimeUsers, publishOutingChange } from "../../realtime/data-changes.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import { assertGroupMember } from "../../services/groups/group-access.js";
import { confirmProposedVenue } from "../../services/outings/vote-resolution.js";
import { assertOutingAccess } from "../../services/outings/outing-access.js";
import { hasAutomaticWhatsApp } from "../../config/notifications.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import { buildWhatsAppClickToChatUrl } from "../../services/whatsapp/invitation-message.js";
import { specialEventMessage } from "../../services/whatsapp/special-event-invitation.js";
import { OutingArrivalsUseCase } from "../../usecases/outings/arrivals.usecase.js";
import type { NextFunction, Request, Response } from "express";
import {
  ListAttendanceUseCase,
  UpsertAttendanceUseCase,
} from "../../usecases/outings/attendance.usecase.js";
import { CreateOutingUseCase } from "../../usecases/outings/create-outing.usecase.js";
import { DeleteOutingUseCase } from "../../usecases/outings/delete-outing.usecase.js";
import {
  CreateDraftUseCase,
  DeleteDraftUseCase,
  ListDraftsUseCase,
  UpdateDraftUseCase,
} from "../../usecases/outings/drafts.usecase.js";
import { GetOutingUseCase } from "../../usecases/outings/get-outing.usecase.js";
import {
  AcceptOutingInvitationUseCase,
  AddGuestUseCase,
  DeclineOutingInvitationUseCase,
  ListGuestsUseCase,
  RemoveGuestUseCase,
} from "../../usecases/outings/guests.usecase.js";
import { ListOutingsUseCase } from "../../usecases/outings/list-outings.usecase.js";
import {
  ListSavedOutingsUseCase,
  SaveOutingUseCase,
  UnsaveOutingUseCase,
} from "../../usecases/outings/saved.usecase.js";
import { UpdateOutingUseCase } from "../../usecases/outings/update-outing.usecase.js";
import {
  CancelOutingUseCase,
  CastVoteUseCase,
  CreateVoteOptionUseCase,
  DeleteVoteOptionUseCase,
  GetVotingStateUseCase,
  ListVoteOptionsUseCase,
  ListVotesUseCase,
  RemoveVoteUseCase,
  ReplaceVoteOptionsUseCase,
  TieBreakUseCase,
} from "../../usecases/outings/voting.usecase.js";
import {
  ListSavedPlacesUseCase,
  SavePlaceUseCase,
  UnsavePlaceUseCase,
} from "../../usecases/outings/saved-places.usecase.js";
import { ForbiddenError, UnauthorizedError } from "../../utils/errors.js";

export class OutingController {
  constructor(
    private readonly createOuting = new CreateOutingUseCase(),
    private readonly getOuting = new GetOutingUseCase(),
    private readonly listOutings = new ListOutingsUseCase(),
    private readonly updateOuting = new UpdateOutingUseCase(),
    private readonly deleteOuting = new DeleteOutingUseCase(),
    private readonly listAttendance = new ListAttendanceUseCase(),
    private readonly upsertAttendance = new UpsertAttendanceUseCase(),
    private readonly listGuests = new ListGuestsUseCase(),
    private readonly addGuest = new AddGuestUseCase(),
    private readonly removeGuest = new RemoveGuestUseCase(),
    private readonly acceptInvitation = new AcceptOutingInvitationUseCase(),
    private readonly declineInvitation = new DeclineOutingInvitationUseCase(),
    private readonly listVoteOptions = new ListVoteOptionsUseCase(),
    private readonly createVoteOption = new CreateVoteOptionUseCase(),
    private readonly deleteVoteOption = new DeleteVoteOptionUseCase(),
    private readonly replaceVoteOptions = new ReplaceVoteOptionsUseCase(),
    private readonly listVotes = new ListVotesUseCase(),
    private readonly castVote = new CastVoteUseCase(),
    private readonly removeVote = new RemoveVoteUseCase(),
    private readonly tieBreak = new TieBreakUseCase(),
    private readonly votingState = new GetVotingStateUseCase(),
    private readonly cancelOuting = new CancelOutingUseCase(),
    private readonly listDrafts = new ListDraftsUseCase(),
    private readonly createDraft = new CreateDraftUseCase(),
    private readonly updateDraft = new UpdateDraftUseCase(),
    private readonly deleteDraft = new DeleteDraftUseCase(),
    private readonly listSaved = new ListSavedOutingsUseCase(),
    private readonly saveOuting = new SaveOutingUseCase(),
    private readonly unsaveOuting = new UnsaveOutingUseCase(),
    private readonly listSavedPlaces = new ListSavedPlacesUseCase(),
    private readonly savePlace = new SavePlaceUseCase(),
    private readonly unsavePlace = new UnsavePlaceUseCase(),
    private readonly arrivals = new OutingArrivalsUseCase(),
  ) {}

  listArrivals = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      res.json({ success: true, data: await this.arrivals.list(req.params.id as string, req.user.uid) });
    } catch (error) {
      next(error);
    }
  };

  recordArrival = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      res.json({ success: true, data: await this.arrivals.record(req.params.id as string, req.user.uid, req.body) });
    } catch (error) {
      next(error);
    }
  };

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const groupId = req.query.groupId as string | undefined;
      const userId = req.user?.uid;
      if (!userId) throw new UnauthorizedError();
      if (req.query.userId !== undefined && req.query.userId !== userId) {
        throw new ForbiddenError("You can only list your own outings");
      }
      if (groupId) await assertGroupMember(new GroupRepository(), groupId, userId);
      const outings = await this.listOutings.execute({ groupId, userId });
      res.json({ success: true, data: outings });
    } catch (error) {
      next(error);
    }
  };

  listForCuser = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const outings = await this.listOutings.execute({
        userId: req.user.uid,
      });
      res.json({ success: true, data: outings });
    } catch (error) {
      next(error);
    }
  };

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const id = req.params.id as string;
      await assertOutingAccess(id, req.user.uid);
      const outing = await this.getOuting.execute(id);
      res.json({ success: true, data: outing });
    } catch (error) {
      next(error);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      if (req.body.group_id) {
        await assertGroupMember(new GroupRepository(), req.body.group_id, req.user.uid);
      }
      const outing = await this.createOuting.execute({
        ...req.body,
        created_by: req.user.uid,
      });
      const phones: string[] = req.body.guest_phones ?? [];
      const manualUrls = !hasAutomaticWhatsApp() && phones.length && outing.scheduled_at
        ? [...new Set(phones.map(normalizePhoneNumber))].map((phone) =>
            buildWhatsAppClickToChatUrl(
              phone,
              specialEventMessage({ ...outing, scheduled_at: outing.scheduled_at! }),
            ),
          )
        : [];
      await publishOutingChange(outing.id, "outings");
      res.status(201).json({
        success: true,
        data: { ...outing, ...(manualUrls.length ? { manual_whatsapp_urls: manualUrls } : {}) },
      });
    } catch (error) {
      next(error);
    }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      if (req.body.group_id) {
        await assertGroupMember(new GroupRepository(), req.body.group_id, req.user.uid);
      }
      const audience = req.body.group_id !== undefined
        ? await outingRealtimeUsers(req.params.id as string) : [];
      const outing = await this.updateOuting.execute(
        req.params.id as string,
        req.user.uid,
        req.body,
      );
      await publishOutingChange(outing.id, "outings", audience);
      res.json({ success: true, data: outing });
    } catch (error) {
      next(error);
    }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const audience = await outingRealtimeUsers(req.params.id as string);
      const outing = await this.deleteOuting.execute(
        req.params.id as string,
        req.user.uid,
      );
      emitDataChange({ kind: "outings", id: outing.id }, audience);
      res.json({ success: true, data: outing });
    } catch (error) {
      next(error);
    }
  };

  // Attendance
  getAttendance = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const id = req.params.id as string;
      const data = await this.listAttendance.execute(id, req.user.uid);
      res.json({ success: true, data, ...attendanceSummary(data, req.user.uid) });
    } catch (error) {
      next(error);
    }
  };

  setAttendance = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.upsertAttendance.execute(
        req.params.id as string,
        req.user.uid,
        req.body.status,
      );
      emitDataChange({ kind: "attendance", id: data.outing_id, payload: {
        user_id: data.user_id, status: data.status, updated_at: data.updated_at.toISOString(),
      } }, await outingRealtimeUsers(data.outing_id, false));
      const items = await this.listAttendance.execute(data.outing_id, req.user.uid);
      res.json({ success: true, data, items, ...attendanceSummary(items, req.user.uid) });
    } catch (error) {
      next(error);
    }
  };

  // Guests
  getGuests = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const id = req.params.id as string;
      await assertOutingAccess(id, req.user.uid);
      const data = await this.listGuests.execute(id);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  inviteGuest = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.addGuest.execute(
        req.params.id as string,
        req.user.uid,
        req.body.user_id,
      );
      await publishOutingChange(req.params.id as string, "outings");
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  uninviteGuest = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.removeGuest.execute(
        req.params.id as string,
        req.user.uid,
        req.params.userId as string,
      );
      await publishOutingChange(req.params.id as string, "outings", [req.params.userId as string]);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  // Voting
  getVoteOptions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const id = req.params.id as string;
      await assertOutingAccess(id, req.user.uid);
      const data = await this.listVoteOptions.execute(id);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  addVoteOption = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.createVoteOption.execute(req.user.uid, {
        ...req.body,
        outing_id: req.params.id as string,
      });
      await publishOutingChange(req.params.id as string);
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  replaceOptions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.replaceVoteOptions.execute(
        req.params.id as string,
        req.user.uid,
        req.body.options,
      );
      await publishOutingChange(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  acceptInvite = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.acceptInvitation.execute(
        req.params.id as string,
        req.user.uid,
      );
      await publishOutingChange(req.params.id as string, "outings");
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  declineInvite = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.declineInvitation.execute(
        req.params.id as string,
        req.user.uid,
      );
      await publishOutingChange(req.params.id as string, "outings", [req.user.uid]);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  removeVoteOption = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.deleteVoteOption.execute(
        req.params.optionId as string,
        req.user.uid,
        req.params.id as string,
      );
      await publishOutingChange(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  getVotes = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const id = req.params.id as string;
      await assertOutingAccess(id, req.user.uid);
      const data = await this.listVotes.execute(id);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  vote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.castVote.execute(
        req.params.id as string,
        req.user.uid,
        req.body.option_id,
      );
      // Resolution already published the committed lifecycle change.
      if (!data.resolution) await publishOutingChange(req.params.id as string);
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  unvote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.removeVote.execute(
        req.params.id as string,
        req.user.uid,
        req.params.optionId as string | undefined,
      );
      await publishOutingChange(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  breakTie = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.tieBreak.execute(
        req.params.id as string,
        req.user.uid,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  confirmVenue = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await confirmProposedVenue(req.params.id as string, req.user.uid, req.body.option_id);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  getVotingState = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const id = req.params.id as string;
      await assertOutingAccess(id, req.user.uid);
      const state = await this.votingState.execute(id);
      const counts = new Map<string, number>();
      for (const vote of state.votes) counts.set(vote.option_id, (counts.get(vote.option_id) ?? 0) + 1);
      res.json({ success: true, data: {
        ...state,
        options: state.options.map((option) => ({ ...option, vote_count: counts.get(option.id) ?? 0 })),
        my_option_id: state.votes.find((vote) => vote.user_id === req.user?.uid)?.option_id ?? null,
      } });
    } catch (error) {
      next(error);
    }
  };

  cancel = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.cancelOuting.execute(
        req.params.id as string,
        req.user.uid,
      );
      await publishOutingChange(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  getSavedPlaces = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.listSavedPlaces.execute(req.user.uid);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  savePlaceBookmark = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.savePlace.execute(
        req.user.uid,
        req.params.id as string,
      );
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  unsavePlaceBookmark = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.unsavePlace.execute(
        req.user.uid,
        req.params.id as string,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  // Drafts
  getDrafts = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.listDrafts.execute(req.user.uid);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  addDraft = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.createDraft.execute({
        ...req.body,
        user_id: req.user.uid,
        id: req.get("Idempotency-Key") ? z.uuid().parse(req.get("Idempotency-Key")) : undefined,
      });
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  editDraft = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.updateDraft.execute(
        req.params.id as string,
        req.user.uid,
        req.body,
        req.get("If-Match") ? z.coerce.date().parse(req.get("If-Match")) : undefined,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  removeDraft = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.deleteDraft.execute(
        req.params.id as string,
        req.user.uid,
        req.get("If-Match") ? z.coerce.date().parse(req.get("If-Match")) : undefined,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  // Saved
  getSaved = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.listSaved.execute(req.user.uid);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  save = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.saveOuting.execute(
        req.user.uid,
        req.params.id as string,
      );
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  unsave = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await this.unsaveOuting.execute(
        req.user.uid,
        req.params.id as string,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };
}

function attendanceSummary(rows: { user_id: string; status: "going" | "maybe" | "not_going" }[], userId: string) {
  const summary = { going: 0, maybe: 0, not_going: 0 };
  for (const row of rows) summary[row.status]++;
  return { summary, my_response: rows.find((row) => row.user_id === userId)?.status ?? null };
}
