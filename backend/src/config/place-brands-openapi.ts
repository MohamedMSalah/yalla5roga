export function extendPlaceBrandsOpenApi(spec: any) {
  const uuid = { type: "string", format: "uuid" };
  const fields = {
    brand_id: { ...uuid, nullable: true }, brand_name: { type: "string", nullable: true },
    branch_id: uuid, branch_name: { type: "string", nullable: true },
    branch_count: { type: "integer", description: "Active selectable physical branches of this brand" },
    external_source: { type: "string", description: "Existing source and type namespace, e.g. osm:node" },
    external_place_id: { type: "string", nullable: true },
  };
  for (const name of ["Place", "NearbyPlace"]) Object.assign(spec.components.schemas[name].properties, fields);
  spec.components.schemas.PlaceBrand = { type: "object", required: ["id", "name", "normalized_name", "branch_count"], properties: {
    id: uuid, name: { type: "string" }, normalized_name: { type: "string" },
    description: { type: "string", nullable: true }, logo_url: { type: "string", nullable: true },
    website: { type: "string", nullable: true }, branch_count: { type: "integer" },
    aliases: { type: "array", items: { type: "object", properties: { name: { type: "string" } } } },
    created_at: { type: "string", format: "date-time" }, updated_at: { type: "string", format: "date-time" },
  } };
  for (const name of ["CreatePlaceRequest", "UpdatePlaceRequest"]) {
    const schema = spec.components.schemas[name];
    Object.assign(schema.properties, { brand_id: fields.brand_id, branch_name: fields.branch_name });
    if (name === "CreatePlaceRequest") {
      schema.required = [...new Set([...(schema.required ?? []), "latitude", "longitude"])];
      Object.assign(schema.properties, {
        latitude: { type: "number", minimum: -90, maximum: 90 }, longitude: { type: "number", minimum: -180, maximum: 180 },
        source: { type: "string", enum: ["manual"] },
        source_type: { type: "string", enum: ["place"] }, source_id: { type: "string", maxLength: 128 },
        brand: { type: "object", required: ["name"], properties: {
          name: { type: "string", minLength: 2, maxLength: 100 },
          aliases: { type: "array", maxItems: 20, items: { type: "string", minLength: 2, maxLength: 100 } },
          identity: { type: "string", pattern: "^wikidata:Q[1-9][0-9]*$" },
        } },
      });
    }
  }
  const parameter = { in: "query", name: "brand_id", schema: uuid, description: "Filter physical branches by brand UUID; never collapses map pins" };
  spec.paths["/api/places"].get.parameters.push(parameter);
  spec.paths["/api/places/nearby"].get.parameters.push(parameter);
  const id = { in: "path", name: "id", required: true, schema: uuid };
  spec.paths["/api/place-brands/{id}"] = { get: {
    operationId: "getPlaceBrand", tags: ["Places"], security: [], summary: "Get shared brand metadata",
    parameters: [id], responses: {
      "200": { description: "Brand", content: { "application/json": { schema: { type: "object", properties: {
        success: { type: "boolean" }, data: { $ref: "#/components/schemas/PlaceBrand" },
      } } } } },
      "400": { $ref: "#/components/responses/BadRequest" }, "404": { $ref: "#/components/responses/NotFound" },
      "500": { $ref: "#/components/responses/InternalServerError" },
    },
  } };
  spec.paths["/api/place-brands/{id}/branches"] = { get: {
    ...spec.paths["/api/places"].get, operationId: "listPlaceBrandBranches", summary: "List physical branches with catalog filters and sorting",
    parameters: [id, ...spec.paths["/api/places"].get.parameters.filter((p: any) => p.name !== "brand_id")],
    responses: { ...spec.paths["/api/places"].get.responses, "404": { $ref: "#/components/responses/NotFound" } },
  } };
}
