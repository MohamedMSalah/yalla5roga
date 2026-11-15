import type { weekday } from "@prisma/client";
import type { Tags } from "./taxonomy.js";
const DAYS: weekday[] = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
const TOKENS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
/** Only the subset representable by the existing unique place/day schema. */
export function parseHours(expression: string | null): { rows: any[]; supported: boolean } {
  if (!expression) return { rows: [], supported: true };
  const rows = new Map<string, any>();
  for (const clause of expression.split(";")) {
    const match = /^\s*((?:Mo|Tu|We|Th|Fr|Sa|Su)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?(?:,(?:Mo|Tu|We|Th|Fr|Sa|Su))*)\s+(off|closed|\d{2}:\d{2}-\d{2}:\d{2})\s*$/.exec(clause);
    if (!match) return { rows: [], supported: false };
    let opens: Date | null = null, closes: Date | null = null;
    if (match[2] !== "off" && match[2] !== "closed") {
      const [start, end] = match[2]!.split("-") as [string, string];
      if (![start, end].every((v) => /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(v)) || start >= end) return { rows: [], supported: false };
      opens = new Date(`1970-01-01T${start}:00.000Z`); closes = new Date(`1970-01-01T${end}:00.000Z`);
    }
    for (const group of match[1]!.split(",")) {
      const [a, b] = group.split("-"); const first = TOKENS.indexOf(a!); const last = TOKENS.indexOf(b ?? a!);
      for (let i = first; ; i = (i + 1) % 7) {
        if (rows.has(DAYS[i]!)) return { rows: [], supported: false };
        rows.set(DAYS[i]!, { day: DAYS[i], opens_at: opens, closes_at: closes, is_closed: opens === null });
        if (i === last) break;
      }
    }
  }
  return { rows: [...rows.values()], supported: true };
}
export function sourcePrices(tags: Tags): { label: string; amount: string; currency: string; evidence: any }[] {
  if (tags.fee === "no") return [{ label: "Admission", amount: "0", currency: "EGP", evidence: { fee: "no" } }];
  const match = /^(\d{1,8}(?:\.\d{1,2})?)\s*EGP$/i.exec(tags.charge ?? "");
  return match ? [{ label: "Admission", amount: match[1]!, currency: "EGP", evidence: { charge: tags.charge } }] : [];
}
export async function commonsImage(tags: Tags): Promise<any | null> {
  const title = tags.wikimedia_commons;
  if (!title?.startsWith("File:")) return null;
  const url = new URL("https://commons.wikimedia.org/w/api.php");
  url.search = new URLSearchParams({ action: "query", format: "json", titles: title, prop: "imageinfo", iiprop: "url|extmetadata" }).toString();
  const response = await fetch(url, { signal: AbortSignal.timeout(15000), headers: { "User-Agent": "Yalla5roga-Places/1.0" } });
  if (!response.ok) throw new Error(`Commons image lookup failed: ${response.status}`);
  const body: any = await response.json();
  const info: any = Object.values(body.query?.pages ?? {}).map((p: any) => p.imageinfo?.[0]).find(Boolean);
  const meta = info?.extmetadata;
  const license = meta?.LicenseShortName?.value;
  if (!info?.url?.startsWith("https://upload.wikimedia.org/") || !/^(CC0|Public domain|CC BY(?:-SA)? \d\.\d)$/.test(license ?? "")) return null;
  const strip = (v: unknown) => typeof v === "string" ? v.replace(/<[^>]*>/g, "").slice(0, 900) : "";
  const attribution = [strip(meta.Artist?.value), strip(meta.Credit?.value), license].filter(Boolean).join("; ");
  if (!attribution) return null;
  return { image_url: info.url, source_url: info.descriptionurl, license, attribution, caption: title.slice(5, 205) };
}
