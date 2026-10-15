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
  AddGuestUseCase,
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
  CastVoteUseCase,
  CreateVoteOptionUseCase,
  DeleteVoteOptionUseCase,
  ListVoteOptionsUseCase,
  ListVotesUseCase,
  RemoveVoteUseCase,
} from "../../usecases/outings/voting.usecase.js";
import { UnauthorizedError } from "../../utils/errors.js";

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
    private readonly listVoteOptions = new ListVoteOptionsUseCase(),
    private readonly createVoteOption = new CreateVoteOptionUseCase(),
    private readonly deleteVoteOption = new DeleteVoteOptionUseCase(),
    private readonly listVotes = new ListVotesUseCase(),
    private readonly castVote = new CastVoteUseCase(),
    private readonly removeVote = new RemoveVoteUseCase(),
    private readonly listDrafts = new ListDraftsUseCase(),
    private readonly createDraft = new CreateDraftUseCase(),
    private readonly updateDraft = new UpdateDraftUseCase(),
    private readonly deleteDraft = new DeleteDraftUseCase(),
    private readonly listSaved = new ListSavedOutingsUseCase(),
    private readonly saveOuting = new SaveOutingUseCase(),
    private readonly unsaveOuting = new UnsaveOutingUseCase(),
  ) {}

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const groupId = req.query.groupId as string | undefined;
      const userId =
        (req.query.userId as string | undefined) ?? req.user?.uid;
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
      const outing = await this.getOuting.execute(req.params.id as string);
      res.json({ success: true, data: outing });
    } catch (error) {
      next(error);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const outing = await this.createOuting.execute({
        ...req.body,
        created_by: req.user.uid,
      });
      res.status(201).json({ success: true, data: outing });
    } catch (error) {
      next(error);
    }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const outing = await this.updateOuting.execute(
        req.params.id as string,
        req.body,
      );
      res.json({ success: true, data: outing });
    } catch (error) {
      next(error);
    }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const outing = await this.deleteOuting.execute(req.params.id as string);
      res.json({ success: true, data: outing });
    } catch (error) {
      next(error);
    }
  };

  // Attendance
  getAttendance = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.listAttendance.execute(req.params.id as string);
      res.json({ success: true, data });
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
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  // Guests
  getGuests = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.listGuests.execute(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  inviteGuest = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.addGuest.execute(
        req.params.id as string,
        req.body.user_id,
      );
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  uninviteGuest = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.removeGuest.execute(
        req.params.id as string,
        req.params.userId as string,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  // Voting
  getVoteOptions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.listVoteOptions.execute(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  addVoteOption = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.createVoteOption.execute({
        ...req.body,
        outing_id: req.params.id as string,
      });
      res.status(201).json({ success: true, data });
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
      const data = await this.deleteVoteOption.execute(
        req.params.optionId as string,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  getVotes = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.listVotes.execute(req.params.id as string);
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
        req.params.optionId as string,
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
