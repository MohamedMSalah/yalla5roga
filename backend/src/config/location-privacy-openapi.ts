import {
  locationSetupStatuses,
  locationUsagePolicyVersion,
  locationVisibilityValues,
} from "../types/users/location-privacy.types.js";

type Schema = Record<string, unknown>;

export function extendLocationPrivacyOpenApi(spec: {
  paths: Record<string, Record<string, Schema>>;
  components: { schemas: Record<string, Schema> };
}) {
  const privacy = "/api/users/me/location-privacy";
  const consent = "/api/users/me/location-consent";
  const exclusions = consent + "/excluded-groups";
  const shared = "/api/groups/{groupId}/members/{userId}/starting-location-area";
  const uuid = { type: "string", format: "uuid" };
  const date = { type: "string", format: "date-time" };
  const visibility = { type: "string", enum: locationVisibilityValues, default: "APPROXIMATE" };
  const version = { type: "string", minLength: 1, maxLength: 64, example: locationUsagePolicyVersion };
  const flag = { type: "boolean" };
  const group = { name: "groupId", in: "path", required: true, schema: uuid };
  const object = (properties: Record<string, Schema>) => ({
    type: "object", properties, required: Object.keys(properties), additionalProperties: false,
  });
  const ref = (name: string) => ({ $ref: `#/components/schemas/${name}` });
  const error = (name: string) => ({ $ref: `#/components/responses/${name}` });
  const body = (schema: Schema) => ({ required: true, content: { "application/json": { schema } } });
  const success = (data: Schema) => ({
    description: "Success. Private response with Cache-Control: private, no-store.",
    content: { "application/json": { schema: object({ success: flag, data }) } },
  });
  const operation = (
    operationId: string, summary: string, data: Schema, errors: Schema,
    details: Schema = {},
  ) => ({
    tags: ["Users"], operationId, summary, security: [{ bearerAuth: [] }], ...details,
    responses: { 200: success(data), 401: error("Unauthorized"), 500: error("InternalServerError"), ...errors },
  });
  const ownerErrors = { 404: error("NotFound") };
  const validation = { 400: error("BadRequest") };
  const groupErrors = { ...ownerErrors, ...validation, 403: error("Forbidden") };
  Object.assign(spec.components.schemas, {
    LocationPrivacySettings: object({
      location_visibility: visibility,
      automatic_meetup_location_usage_enabled: { ...flag, default: false, description: "True only for valid current consent." },
      location_usage_consent_at: { ...date, nullable: true },
      consent_policy_version: { ...version, nullable: true },
      required_consent_policy_version: version,
      updated_at: date,
      setup_status: { type: "string", enum: locationSetupStatuses },
    }),
    GroupLocationExclusion: object({ group_id: uuid, created_at: date }),
    SharedStartingLocationArea: {
      oneOf: [
        object({ status: { type: "string", enum: ["APPROXIMATE"] }, district: { type: "string" } }),
        object({ status: { type: "string", enum: ["HIDDEN", "UNAVAILABLE"] }, district: { type: "string", nullable: true, enum: [null] } }),
      ],
    },
  });
  const settings = ref("LocationPrivacySettings");
  const exclusionChange = object({ group_id: uuid, excluded: flag });
  spec.paths[privacy] = {
    get: operation("getLocationPrivacy", "Read your location privacy and setup state", settings, ownerErrors),
    patch: operation("updateLocationVisibility", "Update how current group members see your starting area", settings,
      { ...ownerErrors, ...validation }, {
        requestBody: body(object({ location_visibility: visibility })),
        description: "Visibility and automatic calculation permission are independent.",
      }),
  };
  spec.paths[consent] = {
    put: operation("grantLocationUsageConsent", "Explicitly grant current Smart Meetup location consent", settings,
      { ...ownerErrors, ...validation, 409: error("Conflict") }, {
        requestBody: body(object({ consent_policy_version: version })),
        description: "Call only after the signed-in owner confirms the current policy for internal calculations.",
      }),
    delete: operation("withdrawLocationUsageConsent", "Withdraw Smart Meetup location consent", settings, ownerErrors),
  };
  spec.paths[exclusions] = {
    get: operation("listGroupLocationExclusions", "List your exclusions for groups you still belong to",
      { type: "array", items: ref("GroupLocationExclusion") }, {}),
  };
  spec.paths[exclusions + "/{groupId}"] = {
    put: operation("excludeGroupFromLocationUsage", "Exclude one of your current groups from automatic calculation",
      exclusionChange, groupErrors, { parameters: [group] }),
    delete: operation("removeGroupLocationExclusion", "Remove your exclusion for a current group",
      exclusionChange, groupErrors, { parameters: [group] }),
  };
  spec.paths[shared] = {
    get: operation("getSharedStartingLocationArea", "Read a current group member's shared starting area",
      ref("SharedStartingLocationArea"), groupErrors, {
        tags: ["Group Members"],
        parameters: [group, { name: "userId", in: "path", required: true, schema: { type: "string", maxLength: 128 } }],
        description: "Both accounts must be current group members. The response contains only a status and an optional verified district.",
      }),
  };
}
