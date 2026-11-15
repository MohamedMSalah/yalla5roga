/** Additive catalog contracts augment the existing Places operations and schemas. */
export function extendPlacesOpenApi(spec: any) {
  const ref = (s: string) => ({ $ref: `#/components/schemas/${s}` });
  const response = (schema: any) => ({
    description: "Success",
    content: {
      "application/json": {
        schema: {
          type: "object",
          required: ["success", "data"],
          properties: { success: { type: "boolean" }, data: schema },
        },
      },
    },
  });
  const status = {
    type: "string",
    enum: ["active", "temporarily_closed", "permanently_closed", "unverified"],
  };
  const fields: any = {
    category_id: { type: "string", nullable: true },
    name_ar: { type: "string", nullable: true },
    name_en: { type: "string", nullable: true },
    status,
    source: { type: "string", enum: ["manual", "osm", "overture"] },
    source_type: { type: "string", nullable: true },
    source_id: { type: "string", nullable: true },
    vibes: { type: "array", items: { type: "string" } },
    image_url: { type: "string" },
    opening_hours: { type: "string", nullable: true },
    phone: { type: "string", nullable: true },
    website: { type: "string", nullable: true },
    address: { type: "string", nullable: true },
    city: { type: "string", nullable: true },
    district: { type: "string", nullable: true },
    last_synced_at: { type: "string", format: "date-time", nullable: true },
    last_seen_at: { type: "string", format: "date-time", nullable: true },
  };
  Object.assign(spec.components.schemas.Place.properties, fields);
  spec.components.schemas.Place.properties.price_level.nullable = true;
  spec.components.schemas.NearbyPlace.properties.price_level.nullable = true;
  spec.components.schemas.SavedPlace.properties.places=ref('Place');
  spec.components.schemas.PlaceListResponse.allOf.push({
    type: "object",
    properties: {
      pagination: {
        type: "object",
        required: ["limit", "offset", "has_more", "next_offset"],
        properties: {
          limit: { type: "integer" },
          offset: { type: "integer" },
          has_more: { type: "boolean" },
          next_offset: { type: "integer", nullable: true },
          next_cursor: { type: "string", nullable: true },
        },
      },
      attribution: { type: "string" },
    },
  });
  for (const name of ["CreatePlaceRequest", "UpdatePlaceRequest"])
    if (spec.components.schemas[name])
      Object.assign(
        spec.components.schemas[name].properties,
        Object.fromEntries(
          Object.entries(fields).filter(
            ([k]) =>
              ![
                "source",
                "source_type",
                "source_id",
                "last_synced_at",
                "last_seen_at",
                "image_url",
              ].includes(k),
          ),
        ),
      );
  spec.components.schemas.CatalogDefinition = {
    type: "object",
    required: ["id", "name_en", "name_ar", "icon"],
    properties: {
      id: { type: "string" },
      name_en: { type: "string" },
      name_ar: { type: "string" },
      icon: { type: "string" },
      group_id: { type: "string" },
      is_active: { type: "boolean" },
    },
  };
  spec.components.schemas.PlaceSyncRun = {
    type: "object",
    required: ["id", "status", "started_at", "complete", "dry_run"],
    properties: {
      id: { type: "string", format: "uuid" },
      status: {
        type: "string",
        enum: ["running", "success", "partial", "dry_run", "failed", "interrupted"],
      },
      started_at: { type: "string", format: "date-time" },
      completed_at: { type: "string", nullable: true, format: "date-time" },
      complete: { type: "boolean" },
      dry_run: { type: "boolean" },
      ...Object.fromEntries(
        [
          "imported_count",
          "updated_count",
          "closed_count",
          "skipped_count",
          "failed_count",
          "processed_count",
        ].map((k) => [k, { type: "integer" }]),
      ),
      error_details: { type: "array", items: { type: "string" } },
      coverage: { type: "object" },
      progress: { type: "object" },
      source: { type: "string", enum: ["osm", "overture"] },
    },
  };
  const list = spec.paths["/api/places"].get;
  list.description =
    "Paged active catalog. OR within categories/vibes and AND across dimensions. Bounds use bbox or all four min/max aliases. Use next_cursor with unchanged filters for keyset pagination, or the compatible offset API. Internal source evidence and sync diagnostics are excluded. Attribution covers Overture and OSM.";
  list.parameters = [
    ...(list.parameters ?? []),
    ...Object.entries({
      search: { type: "string", maxLength: 120 },
      categories: {
        type: "string",
        description: "Comma-separated category IDs",
      },
      vibes: { type: "string", description: "Comma-separated vibe IDs" },
      vibe: { type: "string", enum: ["food", "activity", "outdoor", "movie"] },
      status: { ...status, default: "active" },
      lat: { type: "number", minimum: -90, maximum: 90 },
      lng: { type: "number", minimum: -180, maximum: 180 },
      radiusKm: { type: "number", minimum: 0, maximum: 100 },
      bbox: { type: "string", description: "west,south,east,north" },
      sort: { type: "string", enum: ["updated", "name", "distance"] },
      limit: { type: "integer", minimum: 1, maximum: 100, default: 50 },
      offset: { type: "integer", minimum: 0, default: 0 },
      cursor: { type: "string", description: "Opaque next_cursor for the same filters/sort" },
      category: { type: "string", description: "Alias for categories" },
      minLat: { type: "number", minimum: -90, maximum: 90 },
      maxLat: { type: "number", minimum: -90, maximum: 90 },
      minLng: { type: "number", minimum: -180, maximum: 180 },
      maxLng: { type: "number", minimum: -180, maximum: 180 },
    }).map(([name, schema]) => ({ in: "query", name, schema })),
  ];
  const unauthorized = { $ref: "#/components/responses/Unauthorized" },
    forbidden = { $ref: "#/components/responses/Forbidden" },
    bad = { $ref: "#/components/responses/BadRequest" };
  spec.paths["/api/places/geojson"] = { get: {
    operationId: "getPlacesGeoJson", tags: ["Places"], security: [],
    summary: "Bounded lightweight MapLibre GeoJSON points",
    description: "Requires bbox or all min/max bounds. Coordinates are [longitude,latitude]. Same category/vibe/search/cursor filters as the catalog; maximum 100 points per page.",
    parameters: list.parameters,
    responses: { "200": { description: "GeoJSON FeatureCollection", content: { "application/geo+json": { schema: {
      type: "object", required: ["type", "features", "pagination", "attribution"], properties: {
        type: { type: "string", enum: ["FeatureCollection"] }, attribution: { type: "string" }, pagination: { type: "object" },
        features: { type: "array", items: { type: "object", required: ["type", "geometry", "properties"], properties: {
          type: { type: "string", enum: ["Feature"] }, id: { type: "string", format: "uuid" },
          geometry: { type: "object", required: ["type", "coordinates"], properties: { type: { type: "string", enum: ["Point"] }, coordinates: { type: "array", minItems: 2, maxItems: 2, items: { type: "number" } } } },
          properties: { type: "object", required: ["place_id", "name", "category", "vibes", "icon"], properties: { place_id: { type: "string" }, name: { type: "string" }, category: { type: "string", nullable: true }, vibes: { type: "array", items: { type: "string" } }, icon: { type: "string" } } },
        } } },
      },
    } } } }, "400": bad, "500": { $ref: "#/components/responses/InternalServerError" } },
  } };
  Object.assign(spec.components.schemas.Place.properties, {
    place_hours: { type: "array", items: ref("PlaceHour") },
    place_images: { type: "array", items: ref("PlaceImage") },
    place_prices: { type: "array", items: ref("PlacePrice") },
  });
  const op = (
    operationId: string,
    summary: string,
    data: any,
    secure = false,
  ) => ({
    operationId,
    summary,
    tags: ["Places"],
    security: secure ? [{ bearerAuth: [] }] : [],
    responses: {
      "200": response(data),
      "400": bad,
      ...(secure ? { "401": unauthorized, "403": forbidden } : {}),
      "500": { $ref: "#/components/responses/InternalServerError" },
    },
  });
  for (const kind of ["categories", "vibes"])
    spec.paths[`/api/places/${kind}`] = {
      get: op(
        kind === "categories" ? "listPlaceCategories" : "listPlaceVibes",
        `List active bilingual ${kind}`,
        { type: "array", items: ref("CatalogDefinition") },
      ),
    };
  spec.paths["/api/places/licenses"] = { get: op("getPlacesLicenses", "Catalog source attribution, upstream notices and complete license text", { type: "object" }) };
  spec.paths["/api/places/version"] = {
    get: op(
      "getPlacesVersion",
      "Catalog revision for reconnect/resume invalidation",
      { type: "object", properties: { version: { type: "string" } } },
    ),
  };
  spec.paths["/api/places/sync/status"] = {
    get: op(
      "getPlacesSyncStatus",
      "Curator: manual import history and current run; automatic sync is disabled",
      { type: "object" },
      true,
    ),
  };
  spec.paths["/api/places/sync/history"] = {
    get: {
      ...op(
        "listPlacesSyncHistory",
        "Curator: synchronization logs",
        { type: "array", items: ref("PlaceSyncRun") },
        true,
      ),
      parameters: [
        {
          in: "query",
          name: "limit",
          schema: { type: "integer", maximum: 100, default: 20 },
        },
        {
          in: "query",
          name: "offset",
          schema: { type: "integer", default: 0 },
        },
      ],
    },
  };
  spec.paths["/api/places/sync"] = {
    post: {
      ...op(
        "syncPlaces",
        "Curator: manually synchronize Overture or Geofabrik catalog",
        ref("PlaceSyncRun"),
        true,
      ),
      requestBody: {
        required: false,
        content: {
          "application/json": {
            schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                dryRun: { type: "boolean" },
                source: { type: "string", enum: ["overture", "osm"], default: "overture" },
                city: { type: "string", enum: ["cairo", "giza"] },
                limit: {
                  type: "integer",
                  minimum: 1,
                  description:
                    "Validation only; disables completeness and missing-place accounting. Omit for production.",
                },
              },
            },
          },
        },
      },
      responses: {
        ...op("", "", ref("PlaceSyncRun"), true).responses,
        "409": { description: "Another worker holds the lease" },
      },
    },
  };
}
