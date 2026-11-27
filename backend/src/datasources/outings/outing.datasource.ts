import type { Prisma } from "@prisma/client";
import { ConflictError, ForbiddenError, NotFoundError } from "../../utils/errors.js";
import { getNotificationConfig, hasAutomaticWhatsApp,
} from "../../config/notifications.js";
import { specialEventInvitation } from "../../services/whatsapp/special-event-invitation.js";
import { prisma } from "../../config/database.js";
import { assertSelectablePlaces } from "../../services/places/place-selection.js";
import { ValidateMeetupSelectionService } from "../../services/meetups/validate-meetup-selection.service.js";
import { persistOutingTransition } from "../../services/notifications/outing-events.js";
import { notifyOutingParticipants } from "../../services/notifications/outing-notifier.js";
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
  SavedPlace,
  UpdateOutingDraftInput,
  UpdateOutingInput,
  UpsertAttendanceInput,
} from "../../types/outings/outing.types.js";

function catalogAddressSnapshot(address: string | null) {
  return address && Array.from(address).slice(0, 500).join("");
}

export class OutingDatasource {
  constructor(private readonly meetupSelection = new ValidateMeetupSelectionService()) {}

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
          { outing_guests: { some: { user_id: userId, status: { in: ["pending", "accepted"] },
              },
            },
          },
          { groups: { group_members: { some: { user_id: userId } } } },
        ],
      },
      orderBy: { created_at: "desc" },
    });
  }

  /**
   * Creates the outing and marks the owner Going in one transaction.
   */
  async create(data: CreateOutingInput): Promise<Outing> {
    const selection = data.smart_meetup_selection;
    if (selection) this.meetupSelection.requireMatchingSelection(data, selection);
    const create = async (tx: Prisma.TransactionClient) => {
      if (data.create_request_key) {
        const requestKey = `${data.created_by}:${data.create_request_key}`;
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${requestKey}, 0))`;
        const existing = await tx.outings.findUnique({
          where: { created_by_create_request_key: {
            created_by: data.created_by,
            create_request_key: data.create_request_key,
          },
          },
        });
        if (existing) return existing;
      }
      const voteEndsAt =
        data.vote_ends_at ??
        (data.vote_deadline_hours != null
          ? new Date(Date.now() + data.vote_deadline_hours * 60 * 60 * 1000)
          : null);

      const status =
        data.status ??
        (data.location_place_id || data.location_name ? "confirmed" : "draft");

      const {
        guest_phones: phones,
        guest_phones_whatsapp_opt_in: _optIn,
        smart_meetup_selection: _selection,
        initial_vote_options: initialOptions,
        ...fields
      } = data;
      let options = initialOptions;
      if (selection) {
        const places = await this.meetupSelection.execute(tx, data, selection);
        if (options) {
          options = options.map(({ place_id }) => {
            const venue = places.get(place_id!.toLowerCase())!;
            return {
              place_id: venue.id, label: venue.name, area: venue.area,
              category_id: venue.category_id ?? undefined, address: catalogAddressSnapshot(venue.address) ?? undefined,
              latitude: venue.latitude, longitude: venue.longitude, vibe: venue.vibe,
              image_url: venue.cover_image_url,
            };
          });
          // Voting locations only come from the initial options.
          Object.assign(fields, {
            location_place_id: null, location_name: null, location_area: null,
            location_category_id: null, location_address: null,
            location_latitude: null, location_longitude: null,
          });
        } else {
          const venue = places.get(data.location_place_id!.toLowerCase())!;
          Object.assign(fields, {
            location_place_id: venue.id, location_name: venue.name, location_area: venue.area,
            location_category_id: venue.category_id, location_address: catalogAddressSnapshot(venue.address),
            location_latitude: venue.latitude, location_longitude: venue.longitude,
          });
        }
      } else {
        await assertSelectablePlaces(tx, [
          data.location_place_id,
          ...(options ?? []).map((o) => o.place_id),
        ]);
      }
      const outing = await tx.outings.create({
        data: {
          ...fields,
          status,
          vote_ends_at: voteEndsAt,
          image_url: data.image_url ?? "",
        },
      });

      if (options?.length) {
        await tx.outing_vote_options.createMany({
          data: options.map((option, index) => ({
            ...option,
            outing_id: outing.id,
            sort_order: index,
          })),
        });
      }

      await tx.outing_attendance.create({
        data: {
          outing_id: outing.id,
          user_id: data.created_by,
          status: "going",
        },
      });

      if (phones?.length && outing.scheduled_at && hasAutomaticWhatsApp()) {
        const payload = specialEventInvitation({ ...outing, scheduled_at: outing.scheduled_at,
        });
        await tx.notification_events.createMany({
          data: phones.map((phone) => ({
            type: "outing_invite",
            channel: "whatsapp",
            recipient_phone: phone,
            outing_id: outing.id,
            event_key: `special_event_invite:${outing.id}:${phone}`,
            max_attempts: getNotificationConfig().worker.maxAttempts,
            payload,
          })),
        });
      }

      await persistOutingTransition(tx, null, outing);
      return outing;
    };
    return selection ? this.meetupSelection.transaction(create) : prisma.$transaction(create);
  }

  update(id: string, data: UpdateOutingInput): Promise<Outing> {
    return prisma.$transaction(async (tx) => {
      const [before] = await tx.$queryRaw<
        Outing[]
      >`SELECT * FROM outings WHERE id = ${id}::uuid FOR UPDATE`;
      if (!before) throw new NotFoundError("Outing");
      const changesDeadline = data.vote_ends_at !== undefined || data.vote_deadline_hours !== undefined;
      if (changesDeadline && (before.vote_closed_at || before.current_voting_round > 1)) {
        throw new ConflictError("The voting round deadline is locked");
      }
      if ((before.status === "confirmed" || before.winning_option_id) && (
        data.location_place_id !== undefined || data.location_name !== undefined ||
        data.location_category_id !== undefined || data.location_address !== undefined ||
        data.location_area !== undefined || data.location_latitude !== undefined || data.location_longitude !== undefined
      )) {
        throw new ConflictError("Confirmed winning place cannot be changed");
      }
      if (
        data.location_place_id &&
        data.location_place_id !== before.location_place_id
      )
        await assertSelectablePlaces(tx, [data.location_place_id]);
      const updated = await tx.outings.update({
        where: { id },
        data: { ...data, updated_at: new Date(Math.max(Date.now(), before.updated_at.getTime() + 1)) },
      });
      if (data.vote_ends_at !== undefined) await tx.outing_voting_rounds.update({ where: { outing_id_round_number: { outing_id: id, round_number: updated.current_voting_round } }, data: { ends_at: updated.vote_ends_at } });
      if (updated.status === "cancelled" || updated.status === "past") await tx.outing_voting_rounds.updateMany({ where: { outing_id: id, status: { in: ["active", "tie_pending"] } }, data: { status: updated.status === "cancelled" ? "cancelled" : "closed" } });
      await persistOutingTransition(tx, before, updated);
      return updated;
    });
  }

  delete(id: string): Promise<Outing> {
    return prisma.outings.delete({ where: { id } });
  }

  listAttendance(outingId: string): Promise<OutingAttendance[]> {
    return prisma.outing_attendance.findMany({ where: { outing_id: outingId },
    });
  }

  upsertAttendance(data: UpsertAttendanceInput): Promise<OutingAttendance> {
    return prisma.$transaction(async (tx) => {
      const [outing] = await tx.$queryRaw<
        Outing[]
      >`SELECT * FROM outings WHERE id = ${data.outing_id}::uuid FOR UPDATE`;
      if (!outing || ["cancelled", "past"].includes(outing.status))
        throw new ConflictError("Attendance is closed for this outing");
      const before = await tx.outing_attendance.findUnique({
        where: {
          outing_id_user_id: {
            outing_id: data.outing_id,
            user_id: data.user_id,
          },
        },
      });
      const [row] = await tx.$queryRaw<OutingAttendance[]>`
      INSERT INTO outing_attendance (outing_id, user_id, status)
      VALUES (${data.outing_id}::uuid, ${data.user_id}, ${data.status}::attendance_status)
      ON CONFLICT (outing_id, user_id) DO UPDATE
      SET status = EXCLUDED.status,
          updated_at = CASE WHEN outing_attendance.status <> EXCLUDED.status
            THEN clock_timestamp() ELSE outing_attendance.updated_at END
      RETURNING *
    `;
      if (
        data.user_id !== outing.created_by &&
        before?.status !== row!.status
      ) {
        await notifyOutingParticipants(
          {
            outing,
            type: "outing",
            eventType: "attendance_changed",
            body: "A participant updated their attendance.",
            userIds: [outing.created_by],
            eventKey: `attendance:${outing.id}:${data.user_id}:${row!.status}:${row!.updated_at.toISOString()}`,
          },
          tx,
        );
      }
      return row!;
    });
  }

  listGuests(outingId: string): Promise<OutingGuest[]> {
    return prisma.outing_guests.findMany({ where: { outing_id: outingId }, include: { users: { select: { name: true, image_url: true } } },
    });
  }

  async addGuest(data: AddGuestInput): Promise<OutingGuest> {
    const key = { outing_id: data.outing_id, user_id: data.user_id };
    const status = data.status ?? "pending";
    return prisma.$transaction(async (tx) => {
      await tx.outing_guests.createMany({
        data: { ...key, status },
        skipDuplicates: true,
      });
      await tx.outing_guests.updateMany({
        where: { ...key, status: { notIn: ["pending", "accepted"] } },
        data: { status, invited_at: new Date() },
      });
      const guest = await tx.outing_guests.findUniqueOrThrow({ where: { outing_id_user_id: key },
      });
      if (guest.status === "pending") {
        const outing = await tx.outings.findUniqueOrThrow({
          where: { id: data.outing_id },
        });
        await notifyOutingParticipants(
          {
            outing,
            type: "invitation",
            eventType: "outing_invite",
            body: `You were invited to "${outing.title}".`,
            eventKey: `outing_invite:${outing.id}:${guest.user_id}:${guest.invited_at.toISOString()}`,
            userIds: [guest.user_id],
            actionRequired: true,
          },
          tx,
        );
      }
      return guest;
    });
  }

  removeGuest(outingId: string, userId: string): Promise<OutingGuest> {
    return prisma.outing_guests.delete({
      where: {
        outing_id_user_id: { outing_id: outingId, user_id: userId },
      },
    });
  }

  async listVoteOptions(outingId: string): Promise<OutingVoteOption[]> {
    const outing = await prisma.outings.findUniqueOrThrow({ where: { id: outingId } });
    return prisma.outing_vote_options.findMany({
      where: { outing_id: outingId, round_options: { some: { round_number: outing.current_voting_round } } },
      orderBy: { sort_order: "asc" },
    });
  }

  createVoteOption(data: CreateVoteOptionInput): Promise<OutingVoteOption> {
    return prisma.outing_vote_options.create({ data });
  }

  findVoteOptionById(id: string): Promise<OutingVoteOption | null> {
    return prisma.outing_vote_options.findUnique({ where: { id } });
  }

  deleteVoteOption(id: string): Promise<OutingVoteOption> {
    return prisma.outing_vote_options.delete({ where: { id } });
  }

  async listVotes(outingId: string): Promise<OutingVote[]> {
    const outing = await prisma.outings.findUniqueOrThrow({ where: { id: outingId } });
    return prisma.outing_votes.findMany({ where: { outing_id: outingId, round_number: outing.current_voting_round } });
  }

  /** Idempotently add one selection without removing the rest of the ballot. */
  castVote(data: CastVoteInput): Promise<OutingVote> {
    return prisma.$transaction(async (tx) => {
      const [outing] = await tx.$queryRaw<Array<{status:string;vote_closed_at:Date|null;vote_ends_at:Date|null;current_voting_round:number;updated_at:Date;
        }>>`SELECT status, vote_closed_at, vote_ends_at, current_voting_round, updated_at FROM outings WHERE id = ${data.outing_id}::uuid FOR UPDATE`;
      if (!outing || outing.status !== "voting" || outing.vote_closed_at || !outing.vote_ends_at || outing.vote_ends_at <= new Date()) throw new ConflictError("Voting is closed");
      if ((data.round_number ?? 1) !== outing.current_voting_round) throw new ConflictError("Voting round changed");
      const eligible = await tx.outing_voting_round_options.findUnique({ where: { outing_id_round_number_option_id: { outing_id: data.outing_id, round_number: outing.current_voting_round, option_id: data.option_id } } });
      if (!eligible) throw new ConflictError("Location is not eligible in this round");
      await tx.outings.update({ where: { id: data.outing_id }, data: { updated_at: new Date(Math.max(Date.now(), outing.updated_at.getTime()+1)) } });
      return tx.outing_votes.upsert({
      where: { outing_id_user_id_option_id_round_number: {
        outing_id: data.outing_id, user_id: data.user_id, option_id: data.option_id, round_number: outing.current_voting_round,
      },
        }, create: { ...data, round_number: outing.current_voting_round }, update: {},
      });
    });
  }

  async removeVote(outingId: string, userId: string, optionId?: string, expectedRound?: number,
  ): Promise<OutingVote> {
    return prisma.$transaction(async (tx) => {
      const [outing] = await tx.$queryRaw<Array<{status:string;vote_closed_at:Date|null;vote_ends_at:Date|null;current_voting_round:number;updated_at:Date;
        }>>`SELECT status, vote_closed_at, vote_ends_at, current_voting_round, updated_at FROM outings WHERE id = ${outingId}::uuid FOR UPDATE`;
      if (!outing || outing.status !== "voting" || outing.vote_closed_at || !outing.vote_ends_at || outing.vote_ends_at <= new Date()) throw new ConflictError("Voting is closed");
      if ((expectedRound ?? 1) !== outing.current_voting_round) throw new ConflictError("Voting round changed");
      const where = { outing_id: outingId, round_number: outing.current_voting_round, user_id: userId, ...(optionId ? { option_id: optionId } : {}),
      };
      const vote = await tx.outing_votes.findFirstOrThrow({ where });
      await tx.outing_votes.deleteMany({ where });
      await tx.outings.update({ where: { id: outingId }, data: { updated_at: new Date(Math.max(Date.now(), outing.updated_at.getTime()+1)) } });
      return vote;
    });
  }

  async clearVotes(outingId: string): Promise<number> {
    return prisma.$transaction(async tx => {
      const [outing] = await tx.$queryRaw<Outing[]>`SELECT * FROM outings WHERE id = ${outingId}::uuid FOR UPDATE`;
      if (!outing || outing.current_voting_round > 1 || outing.vote_closed_at || outing.status !== "voting") throw new ConflictError("Cannot clear closed or historical ballots");
      return (await tx.outing_votes.deleteMany({ where: { outing_id: outingId, round_number: outing.current_voting_round } })).count;
    });
  }

  findDraftById(id: string): Promise<OutingDraft | null> {
    return prisma.outing_drafts.findUnique({ where: { id } });
  }

  listDraftsByUser(userId: string): Promise<OutingDraft[]> {
    return prisma.outing_drafts.findMany({
      where: { user_id: userId },
      orderBy: { updated_at: "desc" },
    });
  }

  async createDraft(data: CreateOutingDraftInput): Promise<OutingDraft> {
    if (!data.id) return prisma.outing_drafts.create({ data });
    // The caller's stable UUID makes response-loss retries safe.
    await prisma.outing_drafts.createMany({ data: [data], skipDuplicates: true,
    });
    const draft = await prisma.outing_drafts.findUniqueOrThrow({ where: { id: data.id },
    });
    if (draft.user_id !== data.user_id) throw new ForbiddenError();
    return draft;
  }

  async updateDraft(id: string, data: UpdateOutingDraftInput, expected?: Date,
  ): Promise<OutingDraft> {
    return prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM outing_drafts WHERE id = ${id}::uuid FOR UPDATE`;
      const current = await tx.outing_drafts.findUniqueOrThrow({ where: { id },
      });
      if (expected && current.updated_at.getTime() !== expected.getTime()) throw new ConflictError("Draft changed; reload before saving");
      return tx.outing_drafts.update({ where: { id }, data: {
        ...data, updated_at: new Date(Math.max(Date.now(), current.updated_at.getTime() + 1),
          ),
      },
      });
    });
  }

  async deleteDraft(id: string, expected?: Date): Promise<OutingDraft> {
    return prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM outing_drafts WHERE id = ${id}::uuid FOR UPDATE`;
      const draft = await tx.outing_drafts.findUniqueOrThrow({ where: { id } });
      if (expected && draft.updated_at.getTime() !== expected.getTime()) throw new ConflictError("Draft changed; reload before deleting");
      return tx.outing_drafts.delete({ where: { id } });
    });
  }

  listSavedByUser(userId: string): Promise<SavedOuting[]> {
    return prisma.saved_outings.findMany({
      where: { user_id: userId },
      orderBy: { saved_at: "desc" },
    });
  }

  saveOuting(userId: string, outingId: string): Promise<SavedOuting> {
    return prisma.saved_outings.upsert({
      where: { user_id_outing_id: { user_id: userId, outing_id: outingId } },
      create: { user_id: userId, outing_id: outingId },
      update: { outing_id: outingId },
    });
  }

  unsaveOuting(userId: string, outingId: string): Promise<SavedOuting> {
    return prisma.saved_outings.delete({
      where: {
        user_id_outing_id: { user_id: userId, outing_id: outingId },
      },
    });
  }

  listSavedPlacesByUser(userId: string): Promise<SavedPlace[]> {
    return prisma.saved_places.findMany({
      include:{places:{omit:{source_tags:true,manually_managed:true,missing_sync_count:true},include:{place_vibes:true,category:true,brand:{include:{_count:{select:{branches:{where:{is_active:true,status:"active"}}}}}}}}},
      where: { user_id: userId },
      orderBy: { saved_at: "desc" },
    });
  }

  savePlace(userId: string, placeId: string): Promise<SavedPlace> {
    return prisma.saved_places.upsert({
      where: { user_id_place_id: { user_id: userId, place_id: placeId } },
      create: { user_id: userId, place_id: placeId },
      update: { place_id: placeId },
    });
  }

  unsavePlace(userId: string, placeId: string): Promise<SavedPlace> {
    return prisma.saved_places.delete({
      where: {
        user_id_place_id: { user_id: userId, place_id: placeId },
      },
    });
  }
}
