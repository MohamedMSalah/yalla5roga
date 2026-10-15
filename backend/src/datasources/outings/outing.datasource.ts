import { prisma } from "../../config/database.js";
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

export class OutingDatasource {
  findById(id: string): Promise<Outing | null> {
    return prisma.outings.findUnique({ where: { id } });
  }

  findMany(): Promise<Outing[]> {
    return prisma.outings.findMany({ orderBy: { created_at: "desc" } });
  }

  findByGroupId(groupId: string): Promise<Outing[]> {
    return prisma.outings.findMany({
      where: { group_id: groupId },
      orderBy: { scheduled_at: "desc" },
    });
  }

  findByUserId(userId: string): Promise<Outing[]> {
    return prisma.outings.findMany({
      where: {
        OR: [
          { created_by: userId },
          { outing_guests: { some: { user_id: userId } } },
          { groups: { group_members: { some: { user_id: userId } } } },
        ],
      },
      orderBy: { created_at: "desc" },
    });
  }

  create(data: CreateOutingInput): Promise<Outing> {
    return prisma.outings.create({ data });
  }

  update(id: string, data: UpdateOutingInput): Promise<Outing> {
    return prisma.outings.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  delete(id: string): Promise<Outing> {
    return prisma.outings.delete({ where: { id } });
  }

  // Attendance
  listAttendance(outingId: string): Promise<OutingAttendance[]> {
    return prisma.outing_attendance.findMany({ where: { outing_id: outingId } });
  }

  upsertAttendance(data: UpsertAttendanceInput): Promise<OutingAttendance> {
    return prisma.outing_attendance.upsert({
      where: {
        outing_id_user_id: {
          outing_id: data.outing_id,
          user_id: data.user_id,
        },
      },
      create: data,
      update: { status: data.status, updated_at: new Date() },
    });
  }

  // Guests
  listGuests(outingId: string): Promise<OutingGuest[]> {
    return prisma.outing_guests.findMany({ where: { outing_id: outingId } });
  }

  addGuest(data: AddGuestInput): Promise<OutingGuest> {
    return prisma.outing_guests.create({ data });
  }

  removeGuest(outingId: string, userId: string): Promise<OutingGuest> {
    return prisma.outing_guests.delete({
      where: {
        outing_id_user_id: { outing_id: outingId, user_id: userId },
      },
    });
  }

  // Voting
  listVoteOptions(outingId: string): Promise<OutingVoteOption[]> {
    return prisma.outing_vote_options.findMany({
      where: { outing_id: outingId },
      orderBy: { sort_order: "asc" },
    });
  }

  createVoteOption(data: CreateVoteOptionInput): Promise<OutingVoteOption> {
    return prisma.outing_vote_options.create({ data });
  }

  deleteVoteOption(id: string): Promise<OutingVoteOption> {
    return prisma.outing_vote_options.delete({ where: { id } });
  }

  listVotes(outingId: string): Promise<OutingVote[]> {
    return prisma.outing_votes.findMany({ where: { outing_id: outingId } });
  }

  castVote(data: CastVoteInput): Promise<OutingVote> {
    return prisma.outing_votes.create({ data });
  }

  removeVote(
    outingId: string,
    userId: string,
    optionId: string,
  ): Promise<OutingVote> {
    return prisma.outing_votes.delete({
      where: {
        outing_id_user_id_option_id: {
          outing_id: outingId,
          user_id: userId,
          option_id: optionId,
        },
      },
    });
  }

  // Drafts
  findDraftById(id: string): Promise<OutingDraft | null> {
    return prisma.outing_drafts.findUnique({ where: { id } });
  }

  listDraftsByUser(userId: string): Promise<OutingDraft[]> {
    return prisma.outing_drafts.findMany({
      where: { user_id: userId },
      orderBy: { updated_at: "desc" },
    });
  }

  createDraft(data: CreateOutingDraftInput): Promise<OutingDraft> {
    return prisma.outing_drafts.create({ data });
  }

  updateDraft(id: string, data: UpdateOutingDraftInput): Promise<OutingDraft> {
    return prisma.outing_drafts.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  deleteDraft(id: string): Promise<OutingDraft> {
    return prisma.outing_drafts.delete({ where: { id } });
  }

  // Saved outings
  listSavedByUser(userId: string): Promise<SavedOuting[]> {
    return prisma.saved_outings.findMany({
      where: { user_id: userId },
      orderBy: { saved_at: "desc" },
    });
  }

  saveOuting(userId: string, outingId: string): Promise<SavedOuting> {
    return prisma.saved_outings.create({
      data: { user_id: userId, outing_id: outingId },
    });
  }

  unsaveOuting(userId: string, outingId: string): Promise<SavedOuting> {
    return prisma.saved_outings.delete({
      where: {
        user_id_outing_id: { user_id: userId, outing_id: outingId },
      },
    });
  }
}
