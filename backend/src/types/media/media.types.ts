import type { media_purpose, media_status, media_visibility } from "@prisma/client";

export type MediaPurpose = media_purpose;
export type MediaStatus = media_status;
export type MediaVisibility = media_visibility;

export type MediaAsset = {
  id: string;
  object_key: string;
  bucket: string;
  mime_type: string;
  file_size: number;
  visibility: MediaVisibility;
  status: MediaStatus;
  owner_id: string;
  purpose: MediaPurpose;
  user_id: string | null;
  group_id: string | null;
  outing_id: string | null;
  place_id: string | null;
  created_at: Date;
  updated_at: Date;
  verified_at: Date | null;
  upload_expires_at: Date | null;
};

export type CreateUploadInput = {
  object_key: string;
  bucket: string;
  mime_type: string;
  file_size: number;
  visibility: MediaVisibility;
  owner_id: string;
  purpose: MediaPurpose;
  upload_expires_at: Date;
};

export type MediaDeliveryUrl = {
  media_id: string;
  object_key: string;
  /** Absolute https URL (CDN or signed). */
  url: string;
  visibility: MediaVisibility;
  expires_at: Date | null;
};
