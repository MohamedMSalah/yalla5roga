import { z } from "zod";
import {
  mediaImageUrlSchema,
  optionalMediaImageUrlSchema,
} from "../media/image-url.validator.js";

const outingStatusSchema = z.enum([
  "draft",
  "voting",
  "confirmed",
  "cancelled",
  "past",
]);
const outingOccasionSchema = z.enum(["none", "birthday", "wedding"]);
const outingVibeSchema = z.enum(["food", "activity", "outdoor", "movie"]);
const attendanceStatusSchema = z.enum(["going", "not_going", "maybe"]);

/**
 * DB check pattern:
 * - group outing: group_id set and occasion = none
 * - special event: group_id null and occasion in (birthday, wedding)
 */
function assertOutingGroupOccasion(
  data: { group_id?: string | null; occasion?: "none" | "birthday" | "wedding" },
  ctx: z.RefinementCtx,
) {
  const hasGroup = data.group_id != null;
  const occasion = data.occasion ?? "none";

  if (hasGroup && occasion !== "none") {
    ctx.addIssue({
      code: "custom",
      path: ["occasion"],
      message: "group outings must use occasion 'none'",
    });
  }

  if (!hasGroup && occasion === "none") {
    ctx.addIssue({
      code: "custom",
      path: ["group_id"],
      message:
        "provide group_id for a group outing, or set occasion to 'birthday' or 'wedding' for a special event",
    });
  }
}

const optionalOutingImageUrl = optionalMediaImageUrlSchema;

export const createVoteOptionBodySchema = z.object({
  place_id: z.uuid().optional().nullable(),
  label: z.string().trim().min(1).max(100),
  area: z.string().trim().max(100).optional(),
  image_url: mediaImageUrlSchema.optional(),
  vibe: outingVibeSchema.optional(),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  sort_order: z.number().int().optional(),
});

export const createOutingBodySchema = z
  .object({
    title: z.string().trim().min(3).max(20),
    image_url: optionalOutingImageUrl,
    group_id: z.uuid().optional().nullable(),

    occasion: outingOccasionSchema.optional(),
    create_request_key: z.string().trim().min(1).max(80).optional(),
    initial_vote_options: z.array(createVoteOptionBodySchema.extend({
      latitude: z.number().min(-90).max(90).nullish(),
      longitude: z.number().min(-180).max(180).nullish(),
    })).min(2).max(5).optional(),
    guest_phones: z.array(z.string().trim().min(8).max(20)).max(50).optional(),
    guest_phones_whatsapp_opt_in: z.boolean().optional(),
    scheduled_at: z.coerce.date().optional().nullable(),
    ends_at: z.coerce.date().optional().nullable(),
    location_place_id: z.uuid().optional().nullable(),
    location_name: z.string().trim().max(100).optional().nullable(),
    location_area: z.string().trim().max(100).optional().nullable(),
    location_latitude: z.number().min(-90).max(90).optional().nullable(),
    location_longitude: z.number().min(-180).max(180).optional().nullable(),
    vote_deadline_hours: z.number().int().min(1).max(72).optional().nullable(),
    vote_ends_at: z.coerce.date().optional().nullable(),
  })
  .superRefine(assertOutingGroupOccasion)
  .superRefine((data, ctx) => {
    // Product: every outing must have a voting deadline at create time.
    if (data.vote_ends_at == null && data.vote_deadline_hours == null) {
      ctx.addIssue({
        code: "custom",
        path: ["vote_ends_at"],
        message:
          "voting deadline is required: provide vote_ends_at or vote_deadline_hours",
      });
    }
    if (data.vote_ends_at != null && data.vote_ends_at.getTime() <= Date.now()) {
      ctx.addIssue({
        code: "custom",
        path: ["vote_ends_at"],
        message: "vote_ends_at must be in the future",
      });
    }
  });

export const updateOutingBodySchema = z.object({
  title: z.string().trim().min(3).max(20).optional(),
  image_url: optionalOutingImageUrl,
  group_id: z.uuid().optional().nullable(),
  status: outingStatusSchema.optional(),
  occasion: outingOccasionSchema.optional(),
  scheduled_at: z.coerce.date().optional().nullable(),
  ends_at: z.coerce.date().optional().nullable(),
  location_place_id: z.uuid().optional().nullable(),
  location_name: z.string().trim().max(100).optional().nullable(),
  location_area: z.string().trim().max(100).optional().nullable(),
  location_latitude: z.number().min(-90).max(90).optional().nullable(),
  location_longitude: z.number().min(-180).max(180).optional().nullable(),
  vote_deadline_hours: z.number().int().min(1).max(72).optional().nullable(),
  vote_ends_at: z.coerce.date().optional().nullable(),
});

export const outingIdParamsSchema = z.object({
  id: z.uuid(),
});

export const listOutingsQuerySchema = z.object({
  groupId: z.uuid().optional(),
  userId: z.string().min(1).optional(),
});

export const arrivalBodySchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  accuracy: z.number().positive().max(10_000),
  captured_at: z.iso.datetime({ offset: true }),
  method: z.enum(["gps", "automatic_gps"]).optional(),
  is_mocked: z.boolean().optional(),
}).strict();

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

export const replaceVoteOptionsBodySchema = z.object({
  options: z
    .array(createVoteOptionBodySchema)
    .min(1)
    .max(10),
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
  image_url: optionalMediaImageUrlSchema,
  group_id: z.uuid().optional().nullable(),
  occasion: outingOccasionSchema.optional(),
  special_event: z.boolean().optional(),
  vibe: outingVibeSchema.optional(),
  scheduled_date: z.coerce.date().optional().nullable(),
  scheduled_hour: z.number().int().min(0).max(23).optional().nullable(),
  scheduled_minute: z.number().int().min(0).max(59).optional().nullable(),
  location_name: z.string().trim().max(100).optional().nullable(),
  location_area: z.string().trim().max(100).optional().nullable(),
  location_latitude: z.number().min(-90).max(90).optional().nullable(),
  location_longitude: z.number().min(-180).max(180).optional().nullable(),
  let_vote: z.boolean().optional(),
  vote_deadline_hours: z.number().int().min(1).max(72).optional().nullable(),
  guest_ids: z.unknown().optional(),
  selected_places: z.unknown().optional(),
});

export const updateDraftBodySchema = createDraftBodySchema;
export const draftIdParamsSchema = z.object({ id: z.uuid() });
export const savedOutingParamsSchema = z.object({ id: z.uuid() });
export const savedPlaceParamsSchema = z.object({ id: z.uuid() });

export const replaceBallotBodySchema = z.object({ option_ids: z.array(z.uuid()).max(5).refine(ids => new Set(ids).size === ids.length, "Duplicate options") });
