/** Private import evidence, leases, manual flags and diagnostics never cross public APIs. */
export function publicPlace<T extends Record<string, any>>(row: T) {
  const { source_tags, manually_managed, missing_sync_count, source_records, status_changes, ...safe } = row;
  if (!safe.cover_image_url && Array.isArray(safe.place_images) && safe.place_images[0]?.image_url)
    return { ...safe, cover_image_url: safe.place_images[0].image_url };
  return safe;
}
