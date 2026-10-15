import { z } from "zod";

const outingStatusSchema = z.enum(["upcoming", "voting", "past"]);
const outingOccasionSchema = z.enum(["none", "birthday", "wedding"]);
const outingVibeSchema = z.enum(["food", "activity", "outdoor", "movie"]);
const attendanceStatusSchema = z.enum(["going", "not_going", "not_voted"]);

export const createOutingBodySchema = z.object({
  title: z.string().trim().min(1).max(20),
  image_url: z.url().max(2048).optional(),
  group_id: z.uuid().optional().nullable(),
  status: outingStatusSchema.optional(),
  occasion: outingOccasionSchema.optional(),
  scheduled_at: z.coerce.date().optional().nullable(),
  location_place_id: z.uuid().optional().nullable(),
  location_name: z.string().trim().max(100).optional().nullable(),
  location_area: z.string().trim().max(100).optional().nullable(),
  location_latitude: z.number().optional().nullable(),
  location_longitude: z.number().optional().nullable(),
  vote_deadline_hours: z.number().int().optional().nullable(),
  vote_ends_at: z.coerce.date().optional().nullable(),
});

export const updateOutingBodySchema = createOutingBodySchema
  .partial()
  .extend({
    vote_finalized: z.boolean().optional(),
    suggested_by_user_id: z.string().min(1).optional().nullable(),
  });

export const outingIdParamsSchema = z.object({
  id: z.uuid(),
});

export const listOutingsQuerySchema = z.object({
  groupId: z.uuid().optional(),
  userId: z.string().min(1).optional(),
});

export const attendanceBodySchema = z.object({
  status: attendanceStatusSchema,
});

export const addGuestBodySchema = z.object({
  user_id: z.string().min(1),
});

export const guestParamsSchema = z.object({
  id: z.uuid(),
  userId: z.string().min(1),
});

export const createVoteOptionBodySchema = z.object({
  place_id: z.uuid().optional().nullable(),
  label: z.string().trim().min(1).max(100),
  area: z.string().trim().max(100).optional(),
  image_url: z.url().max(2048).optional(),
  vibe: outingVibeSchema.optional(),
  latitude: z.number().optional().nullable(),
  longitude: z.number().optional().nullable(),
  sort_order: z.number().int().optional(),
});

export const castVoteBodySchema = z.object({
  option_id: z.uuid(),
});

export const voteParamsSchema = z.object({
  id: z.uuid(),
  optionId: z.uuid(),
});

export const createDraftBodySchema = z.object({
  title: z.string().trim().max(20).optional(),
  image_url: z.url().max(2048).optional(),
  group_id: z.uuid().optional().nullable(),
  occasion: outingOccasionSchema.optional(),
  special_event: z.boolean().optional(),
  vibe: outingVibeSchema.optional(),
  scheduled_date: z.coerce.date().optional().nullable(),
  scheduled_hour: z.number().int().min(0).max(23).optional().nullable(),
  scheduled_minute: z.number().int().min(0).max(59).optional().nullable(),
  location_name: z.string().trim().max(100).optional().nullable(),
  location_area: z.string().trim().max(100).optional().nullable(),
  location_latitude: z.number().optional().nullable(),
  location_longitude: z.number().optional().nullable(),
  let_vote: z.boolean().optional(),
  vote_deadline_hours: z.number().int().optional().nullable(),
  guest_ids: z.unknown().optional(),
  selected_places: z.unknown().optional(),
});

export const updateDraftBodySchema = createDraftBodySchema;
export const draftIdParamsSchema = z.object({ id: z.uuid() });
export const savedOutingParamsSchema = z.object({ id: z.uuid() });
