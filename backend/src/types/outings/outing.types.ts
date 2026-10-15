import type {
  attendance_status,
  outing_drafts,
  outing_guests,
  outing_occasion,
  outing_status,
  outing_vibe,
  outing_vote_options,
  outing_votes,
  outings,
  Prisma,
  saved_outings,
} from "@prisma/client";

export type Outing = outings;
export type OutingStatus = outing_status;
export type OutingOccasion = outing_occasion;
export type OutingVibe = outing_vibe;
export type AttendanceStatus = attendance_status;
export type OutingAttendance = {
  outing_id: string;
  user_id: string;
  status: AttendanceStatus;
  updated_at: Date;
};
export type OutingGuest = outing_guests;
export type OutingVoteOption = outing_vote_options;
export type OutingVote = outing_votes;
export type OutingDraft = outing_drafts;
export type SavedOuting = saved_outings;

export type CreateOutingInput = {
  title: string;
  image_url?: string;
  group_id?: string | null;
  created_by: string;
  status?: OutingStatus;
  occasion?: OutingOccasion;
  scheduled_at?: Date | null;
  location_place_id?: string | null;
  location_name?: string | null;
  location_area?: string | null;
  location_latitude?: number | null;
  location_longitude?: number | null;
  vote_deadline_hours?: number | null;
  vote_ends_at?: Date | null;
  suggested_by_user_id?: string | null;
};

export type UpdateOutingInput = Partial<
  Omit<CreateOutingInput, "created_by">
> & {
  vote_finalized?: boolean;
};

export type UpsertAttendanceInput = {
  outing_id: string;
  user_id: string;
  status: AttendanceStatus;
};

export type AddGuestInput = {
  outing_id: string;
  user_id: string;
};

export type CreateVoteOptionInput = {
  outing_id: string;
  place_id?: string | null;
  label: string;
  area?: string;
  image_url?: string;
  vibe?: OutingVibe;
  latitude?: number | null;
  longitude?: number | null;
  sort_order?: number;
};

export type CastVoteInput = {
  outing_id: string;
  user_id: string;
  option_id: string;
};

export type CreateOutingDraftInput = {
  user_id: string;
  title?: string;
  image_url?: string;
  group_id?: string | null;
  occasion?: OutingOccasion;
  special_event?: boolean;
  vibe?: OutingVibe;
  scheduled_date?: Date | null;
  scheduled_hour?: number | null;
  scheduled_minute?: number | null;
  location_name?: string | null;
  location_area?: string | null;
  location_latitude?: number | null;
  location_longitude?: number | null;
  let_vote?: boolean;
  vote_deadline_hours?: number | null;
  guest_ids?: Prisma.InputJsonValue;
  selected_places?: Prisma.InputJsonValue;
};

export type UpdateOutingDraftInput = Partial<
  Omit<CreateOutingDraftInput, "user_id">
>;
