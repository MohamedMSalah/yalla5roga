import type { place_hours, weekday } from "@prisma/client";
import { parseHours } from "../places/import-ancillary.js";

type Hours = Pick<place_hours, "day" | "opens_at" | "closes_at" | "is_closed">;
export type CatalogOpeningHours = { opening_hours: string | null; place_hours: (Hours & { source: string })[] };

const cairoClock = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Africa/Cairo", weekday: "long", hour: "2-digit", minute: "2-digit",
  second: "2-digit", hourCycle: "h23",
});
const weekdays: weekday[] = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

function wallSeconds(time: Date) {
  return time.getUTCDate() === 2 && time.getUTCFullYear() === 1970 && time.getUTCMonth() === 0
    ? 86400 : time.getUTCHours() * 3600 + time.getUTCMinutes() * 60 + time.getUTCSeconds() + time.getUTCMilliseconds() / 1000;
}

export function isOpenAt(place: CatalogOpeningHours, instant: Date): boolean {
  const curated = place.place_hours.filter(row => row.source === "manual");
  const expression = place.opening_hours?.trim() ?? null;
  if (!curated.length && expression === "24/7") return true;

  // Unsupported raw clauses can include holiday exceptions. Do not use partial imports for them.
  const raw = parseHours(expression, true);
  const rows = curated.length ? curated : raw.rows.length ? raw.rows : raw.supported ? place.place_hours : [];
  const parts = cairoClock.formatToParts(instant);
  const get = (type: string) => parts.find(part => part.type === type)?.value;
  const day = weekdays.indexOf(get("weekday")?.toLowerCase() as weekday);
  const previous = weekdays[(day + 6) % 7];
  const now = Number(get("hour")) * 3600 + Number(get("minute")) * 60 + Number(get("second"));
  return rows.some(row => {
    if (row.is_closed || !row.opens_at || !row.closes_at) return false;
    const open = wallSeconds(row.opens_at);
    const close = wallSeconds(row.closes_at);
    if (open === close) return false;
    if (row.day === weekdays[day]) {
      return now >= open && (close < open || now < close);
    }
    return row.day === previous && close < open && now < close;
  });
}
