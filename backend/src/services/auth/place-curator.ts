/**
 * Place catalog curation is server configuration, not a product role.
 *
 * The application authorization model has no global admin/curator role — only
 * group roles and outing owners — so the catalog allowlist lives in the
 * server-only `PLACES_CURATOR_UIDS` environment variable (comma-separated
 * Firebase UIDs). It fails closed when unset or empty, and no client field,
 * profile column, or token claim can grant curator status.
 *
 * Shared by the route middleware (`place-curator.middleware.ts`) and the media
 * upload policy so catalog writes and catalog media intents use one rule.
 */
export function placeCuratorUids(
  raw: string | undefined = process.env.PLACES_CURATOR_UIDS,
): string[] {
  return (raw ?? "")
    .split(",")
    .map((uid) => uid.trim())
    .filter((uid) => uid.length > 0);
}

export function isPlaceCurator(
  uid: string | undefined,
  raw: string | undefined = process.env.PLACES_CURATOR_UIDS,
): boolean {
  if (!uid) return false;
  return placeCuratorUids(raw).includes(uid);
}
