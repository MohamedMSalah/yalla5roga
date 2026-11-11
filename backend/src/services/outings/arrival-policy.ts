import type { Outing } from "../../types/outings/outing.types.js";

function positiveSetting(name: string, fallback: number): number {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

export function arrivalRadiusMeters(): number {
  return positiveSetting("OUTING_ARRIVAL_RADIUS_METERS", 100);
}

export function arrivalWindowEnd(outing: Pick<Outing, "scheduled_at" | "ends_at">): Date | null {
  if (!outing.scheduled_at) return null;
  const maximum = outing.scheduled_at.getTime() +
    positiveSetting("OUTING_ARRIVAL_WINDOW_MINUTES", 360) * 60_000;
  return new Date(Math.min(maximum, outing.ends_at?.getTime() ?? maximum));
}

export function arrivalWindowOpen(outing: Pick<Outing, "status" | "scheduled_at" | "ends_at">, now: Date): boolean {
  const end = arrivalWindowEnd(outing);
  return outing.status === "confirmed" && end != null &&
    now >= outing.scheduled_at! && now < end;
}

export function arrivalMaxAccuracyMeters(): number {
  return positiveSetting("OUTING_ARRIVAL_MAX_ACCURACY_METERS", 50);
}

export type ArrivalPosition = { latitude: number; longitude: number; accuracy: number };
export type ArrivalProof = ArrivalPosition & {
  captured_at: string;
  is_mocked?: boolean;
};

export function verifiedDistance(position: ArrivalPosition, latitude: number, longitude: number): number | null {
  if (!Number.isFinite(position.latitude) || Math.abs(position.latitude) > 90 ||
      !Number.isFinite(position.longitude) || Math.abs(position.longitude) > 180 ||
      !Number.isFinite(position.accuracy) || position.accuracy <= 0 ||
      position.accuracy > arrivalMaxAccuracyMeters()) {
    return null;
  }
  const radians = Math.PI / 180;
  const dLat = (latitude - position.latitude) * radians;
  const dLng = (longitude - position.longitude) * radians;
  const haversine = Math.sin(dLat / 2) ** 2 +
    Math.cos(position.latitude * radians) * Math.cos(latitude * radians) *
    Math.sin(dLng / 2) ** 2;
  const distance = 2 * 6_371_000 * Math.asin(Math.sqrt(Math.min(1, haversine)));
  return distance <= arrivalRadiusMeters() ? distance : null;
}

export function isAtVenue(position: ArrivalPosition, latitude: number, longitude: number): boolean {
  return verifiedDistance(position, latitude, longitude) != null;
}
