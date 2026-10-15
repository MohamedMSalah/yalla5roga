import { OutingDatasource } from "../../datasources/outings/outing.datasource.js";
import type {
  AddGuestInput,
  CastVoteInput,
  CreateOutingDraftInput,
  CreateOutingInput,
  CreateVoteOptionInput,
  Outing,
  OutingAttendance,
  OutingDraft,
  OutingGuest,
  OutingVote,
  OutingVoteOption,
  SavedOuting,
  UpdateOutingDraftInput,
  UpdateOutingInput,
  UpsertAttendanceInput,
} from "../../types/outings/outing.types.js";
import type { IOutingRepository } from "./i-outing.repository.js";

export class OutingRepository implements IOutingRepository {
  constructor(private readonly datasource = new OutingDatasource()) {}

  findById(id: string) {
    return this.datasource.findById(id);
  }
  findMany() {
    return this.datasource.findMany();
  }
  findByGroupId(groupId: string) {
    return this.datasource.findByGroupId(groupId);
  }
  findByUserId(userId: string) {
    return this.datasource.findByUserId(userId);
  }
  create(data: CreateOutingInput) {
    return this.datasource.create(data);
  }
  update(id: string, data: UpdateOutingInput) {
    return this.datasource.update(id, data);
  }
  delete(id: string) {
    return this.datasource.delete(id);
  }

  listAttendance(outingId: string) {
    return this.datasource.listAttendance(outingId);
  }
  upsertAttendance(data: UpsertAttendanceInput) {
    return this.datasource.upsertAttendance(data);
  }

  listGuests(outingId: string) {
    return this.datasource.listGuests(outingId);
  }
  addGuest(data: AddGuestInput) {
    return this.datasource.addGuest(data);
  }
  removeGuest(outingId: string, userId: string) {
    return this.datasource.removeGuest(outingId, userId);
  }

  listVoteOptions(outingId: string) {
    return this.datasource.listVoteOptions(outingId);
  }
  createVoteOption(data: CreateVoteOptionInput) {
    return this.datasource.createVoteOption(data);
  }
  deleteVoteOption(id: string) {
    return this.datasource.deleteVoteOption(id);
  }
  listVotes(outingId: string) {
    return this.datasource.listVotes(outingId);
  }
  castVote(data: CastVoteInput) {
    return this.datasource.castVote(data);
  }
  removeVote(outingId: string, userId: string, optionId: string) {
    return this.datasource.removeVote(outingId, userId, optionId);
  }

  findDraftById(id: string) {
    return this.datasource.findDraftById(id);
  }
  listDraftsByUser(userId: string) {
    return this.datasource.listDraftsByUser(userId);
  }
  createDraft(data: CreateOutingDraftInput) {
    return this.datasource.createDraft(data);
  }
  updateDraft(id: string, data: UpdateOutingDraftInput) {
    return this.datasource.updateDraft(id, data);
  }
  deleteDraft(id: string) {
    return this.datasource.deleteDraft(id);
  }

  listSavedByUser(userId: string) {
    return this.datasource.listSavedByUser(userId);
  }
  saveOuting(userId: string, outingId: string) {
    return this.datasource.saveOuting(userId, outingId);
  }
  unsaveOuting(userId: string, outingId: string) {
    return this.datasource.unsaveOuting(userId, outingId);
  }
}
