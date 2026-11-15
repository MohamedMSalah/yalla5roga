/** Private source evidence and curator flags never cross public APIs. */
export function publicPlace<T extends Record<string, any>>(row: T) {
  const { source_tags, manually_managed, missing_sync_count, source_records, status_changes,
    brand, ...safe } = row;
  return { ...safe, branch_id: row.id, brand_id: row.brand_id ?? null,
    brand_name: brand?.name ?? row.brand_name ?? null,
    branch_name: row.branch_name ?? null,
    branch_count: brand?._count?.branches ?? row.branch_count ?? 0,
    external_source: `${row.source}:${row.source_type ?? ""}`, external_place_id: row.source_id ?? null,
    vibes: row.vibes ?? row.place_vibes?.map((v: any) => v.vibe_id) ?? [],
    cover_image_url: safe.cover_image_url || safe.place_images?.[0]?.image_url || "" };
}
