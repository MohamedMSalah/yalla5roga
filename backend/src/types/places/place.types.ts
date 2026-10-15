import type {
  outing_vibe,
  place_hours,
  place_images,
  place_prices,
  places,
  price_level,
  weekday,
} from "@prisma/client";

export type Place = places;
export type OutingVibe = outing_vibe;
export type PriceLevel = price_level;
export type Weekday = weekday;
export type PlaceHour = place_hours;
export type PlaceImage = place_images;
export type PlacePrice = place_prices;

export type CreatePlaceInput = {
  name: string;
  area?: string;
  vibe?: OutingVibe;
  description?: string;
  cover_image_url?: string;
  price_level?: PriceLevel;
  price_min?: number | null;
  price_max?: number | null;
  currency?: string;
  latitude?: number | null;
  longitude?: number | null;
  featured?: boolean;
};

export type UpdatePlaceInput = Partial<CreatePlaceInput>;

export type UpsertPlaceHourInput = {
  place_id: string;
  day: Weekday;
  opens_at?: Date | null;
  closes_at?: Date | null;
  is_closed?: boolean;
};

export type CreatePlaceImageInput = {
  place_id: string;
  image_url: string;
  caption?: string | null;
  sort_order?: number;
};

export type CreatePlacePriceInput = {
  place_id: string;
  label: string;
  amount: number;
  currency?: string;
};
