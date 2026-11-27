import { savedLocationTypes, startingLocationSources } from "../types/users/saved-location.types.js";

import { routingCapabilities, routingUnavailableReason, transportationModes } from "../types/users/transportation.types.js";

type Schema = Record<string, unknown>;
type Operation = Record<string, unknown>;

export function extendSavedLocationsOpenApi(spec: {
  paths: Record<string, Record<string, Operation>>;
  components: { schemas: Record<string, Schema> };
}) {
  const root = "/api/users/me";
  const uuid = { type: "string", format: "uuid" };
  const text = (maxLength: number) => ({ type: "string", minLength: 1, maxLength });
  const nullable = (schema: Schema) => ({ ...schema, nullable: true });
  const date = { type: "string", format: "date-time" };
  const coordinates = {
    latitude: { type: "number", minimum: -90, maximum: 90 },
    longitude: { type: "number", minimum: -180, maximum: 180 },
  };
  const area = nullable(text(100));
  const mode = { type: "string", enum: transportationModes };
  const storedMode = { ...mode, nullable: true, enum: [...transportationModes, null] };
  const input = {
    name: text(100),
    location_type: { type: "string", enum: savedLocationTypes },
    ...coordinates,
    approximate_area: area,
    address: nullable(text(1000)),
    place_id: nullable(uuid),
    preferred_transportation_mode: storedMode,
  };
  const object = (properties: Record<string, Schema>, required = Object.keys(properties)) => ({
    type: "object", required, properties, additionalProperties: false,
  });
  const patch = {
    type: "object", minProperties: 1, properties: input, additionalProperties: false,
    description: "Coordinates must be supplied as a pair. Use null to clear an optional field.",
  };
  const source = { type: "string", enum: startingLocationSources };
  const exampleId = "37dd17a6-9a69-4c4e-9201-57aad85da9fb";
  const point = { name: "Home", latitude: 30.0444, longitude: 31.2357, approximate_area: "Cairo" };
  const createExample = { ...point, location_type: "home", address: null, place_id: null, preferred_transportation_mode: null };
  const location = {
    ...createExample, id: exampleId, is_default: false,
    created_at: "2026-11-26T10:00:00Z", updated_at: "2026-11-26T10:00:00Z",
  };
  const effective = {
    ...point, source: "saved_location", reference_id: exampleId,
    location_type: "home", place_id: null, preferred_transportation_mode: null, is_default: true,
  };
  const ref = (schema: string) => ({ $ref: `#/components/schemas/${schema}` });
  const error = (name: string) => ({ $ref: `#/components/responses/${name}` });
  const json = (schema: Schema, example: unknown) => ({
    content: { "application/json": { schema, example } },
  });
  const body = (schema: Schema, example: unknown) => ({ required: true, ...json(schema, example) });
  const response = (data: Schema, example: unknown, description = "Success") => ({
    description, ...json(object({ success: { type: "boolean" }, data }), { success: true, data: example }),
  });
  const invalid = { 400: error("BadRequest") };
  const missing = { 404: error("NotFound") };
  const conflict = { 409: error("Conflict") };
  const params = [{ $ref: "#/components/parameters/UuidId" }];
  const operation = (
    summary: string, operationId: string, responses: Operation, extra: Operation = {},
  ): Operation => ({
    tags: ["Users"], summary, operationId, security: [{ bearerAuth: [] }], ...extra,
    responses: { ...responses, 401: error("Unauthorized"), 500: error("InternalServerError") },
  });
  const empty = {
    type: "object", nullable: true, enum: [null],
  };
  const effectiveSchema = object({
    source, reference_id: uuid, name: text(100), ...coordinates, approximate_area: area,
    location_type: input.location_type, place_id: input.place_id, preferred_transportation_mode: storedMode,
    is_default: { type: "boolean", enum: [true] },
  });
  const account = object({ default_transportation_mode: storedMode });
  const bookmark = object({ preferred_transportation_mode: storedMode });
  const flag = { type: "boolean" };
  Object.assign(spec.components.schemas, {
    TransportationPreferences: account,
    SavedTransportationPreference: bookmark,
    RoutingCapabilities: object({
      mode,
      can_store_preference: flag,
      supports_routes: flag,
      supports_matrices: flag,
      supports_distance: flag,
      supports_duration: flag,
      supports_alternatives: flag,
      supports_isochrones: flag,
      supports_departure_time: flag,
      unavailability_reason_code: {
        type: "string", nullable: true, example: routingUnavailableReason,
        description: "Stable reason code for clients to localize. Null when no unavailability reason applies.",
      },
    }),
    SavedLocation: object({ ...input, id: uuid, is_default: { type: "boolean" }, created_at: date, updated_at: date }),
    CreateSavedLocation: object(input, ["name", "location_type", "latitude", "longitude"]),
    UpdateSavedLocation: patch,
    StartingLocationSelection: object({ source, referenceId: uuid }),
    EffectiveStartingLocation: effectiveSchema,
  });

  const accountExample = { default_transportation_mode: "CAR" };
  const accountResponse = response(ref("TransportationPreferences"), accountExample);
  spec.paths[root + "/transportation-preferences"] = {
    get: operation("Read your default transportation preference", "getTransportationPreferences", {
      200: accountResponse, ...missing,
    }),
    patch: operation("Set or clear your default transportation preference", "updateTransportationPreferences", {
      200: accountResponse, ...invalid, ...missing,
    }, { requestBody: body(ref("TransportationPreferences"), accountExample) }),
  };
  const bookmarkExample = { preferred_transportation_mode: "METRO" };
  spec.paths["/api/places/{id}/save"].patch = operation(
    "Set or clear your bookmark transportation preference", "updateSavedPlaceTransportationPreference", {
      200: response(ref("SavedTransportationPreference"), bookmarkExample), ...invalid, ...missing,
    }, { tags: ["Places"], parameters: params, requestBody: body(ref("SavedTransportationPreference"), bookmarkExample) },
  );
  spec.paths["/api/routing/capabilities"] = {
    get: {
      tags: ["System"],
      summary: "List transportation preference and routing support by mode",
      operationId: "getRoutingCapabilities",
      security: [],
      responses: {
        200: response({ type: "array", items: ref("RoutingCapabilities") }, routingCapabilities),
      },
    },
  };

  const saved = response(ref("SavedLocation"), location);
  const cleared = response(empty, null);
  spec.paths[`${root}/saved-locations`] = {
    get: operation("List your saved locations", "listSavedLocations", {
      200: response({ type: "array", items: ref("SavedLocation") }, [location]),
    }),
    post: operation("Create a saved location", "createSavedLocation", {
      201: { ...saved, description: "Created" }, ...invalid, ...missing, ...conflict,
    }, { requestBody: body(ref("CreateSavedLocation"), createExample) }),
  };
  spec.paths[`${root}/saved-locations/{id}`] = {
    get: operation("Get your saved location", "getSavedLocation", { 200: saved, ...invalid, ...missing }, { parameters: params }),
    patch: operation("Update your saved location", "updateSavedLocation", {
      200: saved, ...invalid, ...missing, ...conflict,
    }, { parameters: params, requestBody: body(ref("UpdateSavedLocation"), { name: "New name" }) }),
    delete: operation("Delete your saved location", "deleteSavedLocation", {
      200: cleared, ...invalid, ...missing,
    }, { parameters: params }),
  };
  spec.paths[`${root}/default-starting-location`] = {
    get: operation("Get your effective default starting location", "getDefaultStartingLocation", {
      200: response(nullable(effectiveSchema), effective, "The selected location, or null when setup is required"),
    }),
    put: operation("Set your default starting location", "setDefaultStartingLocation", {
      200: response(ref("EffectiveStartingLocation"), {
        ...effective, source: "saved_place", location_type: "custom",
        name: "Bookmarked library", place_id: exampleId,
      }), ...invalid, ...missing, ...conflict,
    }, {
      description: "For saved_place, referenceId is the catalog place UUID on the caller's existing bookmark.",
      requestBody: body(ref("StartingLocationSelection"), { source: "saved_place", referenceId: exampleId }),
    }),
    delete: operation("Clear your default starting location", "clearDefaultStartingLocation", {
      200: cleared,
    }),
  };
}
