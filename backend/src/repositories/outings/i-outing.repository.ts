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

export interface IOutingRepository {
  findById(id: string): Promise<Outing | null>;
  findMany(): Promise<Outing[]>;
  findByGroupId(groupId: string): Promise<Outing[]>;
  findByUserId(userId: string): Promise<Outing[]>;
  create(data: CreateOutingInput): Promise<Outing>;
  update(id: string, data: UpdateOutingInput): Promise<Outing>;
  delete(id: string): Promise<Outing>;

  listAttendance(outingId: string): Promise<OutingAttendance[]>;
  upsertAttendance(data: UpsertAttendanceInput): Promise<OutingAttendance>;

  listGuests(outingId: string): Promise<OutingGuest[]>;
  addGuest(data: AddGuestInput): Promise<OutingGuest>;
  removeGuest(outingId: string, userId: string): Promise<OutingGuest>;

  listVoteOptions(outingId: string): Promise<OutingVoteOption[]>;
  createVoteOption(data: CreateVoteOptionInput): Promise<OutingVoteOption>;
  deleteVoteOption(id: string): Promise<OutingVoteOption>;
  listVotes(outingId: string): Promise<OutingVote[]>;
  castVote(data: CastVoteInput): Promise<OutingVote>;
  removeVote(
    outingId: string,
    userId: string,
    optionId: string,
  ): Promise<OutingVote>;

  findDraftById(id: string): Promise<OutingDraft | null>;
  listDraftsByUser(userId: string): Promise<OutingDraft[]>;
  createDraft(data: CreateOutingDraftInput): Promise<OutingDraft>;
  updateDraft(id: string, data: UpdateOutingDraftInput): Promise<OutingDraft>;
  deleteDraft(id: string): Promise<OutingDraft>;

  listSavedByUser(userId: string): Promise<SavedOuting[]>;
  saveOuting(userId: string, outingId: string): Promise<SavedOuting>;
  unsaveOuting(userId: string, outingId: string): Promise<SavedOuting>;
}
