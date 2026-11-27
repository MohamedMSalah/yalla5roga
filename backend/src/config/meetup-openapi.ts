import { meetup_session_status, meetup_calculation_status, meetup_optimization, transportation_mode } from "@prisma/client";
import { catalogExplanationCodes, meetupRecommendationLimit } from "../types/meetups/meetup-result.js";
import {
  defaultMeetupPreferences, maximumTravelDurations, minimumRatings, OptimizationPriority,
  selectableBudgetLevels, TravelFairnessMode,
} from "../types/meetups/meetup-preferences.js";

type Schema = Record<string, unknown>;
export function extendMeetupOpenApi(spec: {
  paths: Record<string, Record<string, Schema>>;
  components: { schemas: Record<string, Schema> };
}) {
  const uuid = { type: "string", format: "uuid" };
  const flag = { type: "boolean" };
  const count = { type: "integer", minimum: 0 };
  const choices = (values: string[]) => ({ type: "string", enum: values });
  const object = (properties: Record<string, Schema>, required = Object.keys(properties)) =>
    ({ type: "object", properties, required, additionalProperties: false });
  const ref = (name: string) => ({ $ref: "#/components/schemas/" + name });
  const participant = object({ display_name: { type: "string" }, is_self: flag,
    status: choices(["READY", "SETUP_REQUIRED"]), district: { type: "string", nullable: true },
    request_target_user_id: { type: "string", maxLength: 128 },
  }, ["display_name", "is_self", "status", "district"]);
  const readiness = object({ intended: count, usable: count, requiring_setup: count,
    status: choices(["READY", "PARTIAL", "INSUFFICIENT_DATA"]), participants: { type: "array", items: participant } });
  const optimization = choices(Object.values(meetup_optimization));
  spec.components.schemas.MeetupReadiness = readiness;
  const unique = (items: Schema) => ({ type: "array", items, uniqueItems: true });
  const ratings = { type: "number", enum: minimumRatings };
  const durations = { type: "integer", enum: maximumTravelDurations };
  const budgets = choices(selectableBudgetLevels);
  const fairness = choices(Object.values(TravelFairnessMode));
  const priorities = choices(Object.values(OptimizationPriority));
  const categoryId = { type: "string", minLength: 1, maxLength: 64 };
  const preferences = ref("MeetupPreferences");
  spec.components.schemas.MeetupPreferences = {
    ...object({
      categoryIds: unique(categoryId),
      budgetLevels: unique(budgets),
      minimumRating: { ...ratings, nullable: true, enum: [...minimumRatings, null] },
      travelFairnessMode: fairness,
      maximumTravelDurationSeconds: { ...durations, nullable: true, enum: [...maximumTravelDurations, null] },
      additionalPriorities: unique(priorities),
      plannedMeetupAt: { type: "string", format: "date-time", nullable: true },
      requireOpenAtMeetupTime: flag,
    }),
    example: defaultMeetupPreferences(),
  };
  const categoryName = { type: "string" };
  spec.components.schemas.MeetupFilterOptions = object({
    categories: unique(object({ id: categoryId, name_ar: categoryName, name_en: categoryName })),
    budgetLevels: unique(budgets), minimumRatings: unique(ratings), travelFairnessModes: unique(fairness),
    maximumTravelDurationSeconds: unique(durations), additionalPriorities: unique(priorities), defaults: preferences,
  });
  const sessionFields = { id: uuid, outing_id: { ...uuid, nullable: true }, status: choices(Object.values(meetup_session_status)),
    calculation_status: choices(Object.values(meetup_calculation_status)), input_version: { type: "integer", minimum: 1 },
    expires_at: { type: "string", format: "date-time" }, optimization, preferences, can_manage: flag,
    readiness: { ...readiness, nullable: true } };
  spec.components.schemas.GroupMeetupSession = object({ ...sessionFields, session_type: choices(["GROUP"]), group_id: uuid });
  const nullableString = { type: "string", nullable: true };
  const mode = { ...choices(Object.values(transportation_mode)), nullable: true };
  const coordinate = (max: number) => ({ type: "number", minimum: -max, maximum: max });
  const manualFields = {
    display_name: { ...nullableString, minLength: 1, maxLength: 60 },
    approximate_area: { ...nullableString, minLength: 1, maxLength: 96 },
    latitude: coordinate(90), longitude: coordinate(180), transportation_mode: mode,
  };
  spec.components.schemas.StandaloneMeetupParticipant = object({
    ...manualFields, id: uuid, participant_type: choices(["OWNER", "MANUAL"]), approximate_area: nullableString,
    latitude: { ...manualFields.latitude, nullable: true }, longitude: { ...manualFields.longitude, nullable: true },
  });
  const standaloneParticipants = { type: "array", items: ref("StandaloneMeetupParticipant") };
  const absentId = { ...uuid, nullable: true, enum: [null] };
  spec.components.schemas.StandaloneMeetupSession = object({
    ...sessionFields, session_type: choices(["STANDALONE"]), group_id: absentId, outing_id: absentId,
    standalone_participants: standaloneParticipants, manual_participant_limit: { type: "integer", minimum: 1, maximum: 30 },
  });
  const groupSession = ref("GroupMeetupSession");
  const standaloneSession = ref("StandaloneMeetupSession");
  const session = { oneOf: [groupSession, standaloneSession] };
  function operation(operationId: string, summary: string, params: string[], data: Schema, body?: Schema,
    required = false, status = 200) {
    const responses: Record<string, Schema> = { [status]: { description: "Current private state", content: {
      "application/json": { schema: object({ success: flag, data }) },
    } } };
    for (const [code, name] of Object.entries({ 400: "BadRequest", 401: "Unauthorized", 403: "Forbidden",
      404: "NotFound", 409: "Conflict", 500: "InternalServerError" })) responses[code] = { $ref: "#/components/responses/" + name };
    return { operationId, summary, tags: ["Smart Meetup"], security: [{ bearerAuth: [] }],
      parameters: params.map(name => ({ in: "path", name, required: true, schema: uuid })), responses,
      ...(body && { requestBody: { required, content: { "application/json": { schema: body } } } }) };
  }
  const path = "/api/smart-meetups/{sessionId}";
  const bySession = ["sessionId"];
  const byParticipant = ["sessionId", "participantId"];
  const overrideSources = ["DEFAULT", "PERSONAL_LOCATION", "SAVED_PLACE", "MANUAL_POINT"];
  const latitude = { ...coordinate(90), nullable: true };
  const longitude = { ...coordinate(180), nullable: true };
  const dateTime = { type: "string", format: "date-time", nullable: true };
  const version = { type: "integer", minimum: 1 };
  const rank = { type: "integer", minimum: 1, maximum: meetupRecommendationLimit };
  spec.components.schemas.MeetupPlaceSummary = object({
    id: uuid, branch_id: uuid, brand_id: { ...uuid, nullable: true }, brand_name: nullableString,
    branch_name: nullableString, branch_count: count, name: { type: "string" }, name_ar: nullableString,
    name_en: nullableString, area: { type: "string" }, address: nullableString, category_id: nullableString,
    vibe: { type: "string" }, vibes: unique({ type: "string" }), status: choices(["active"]),
    latitude, longitude, price_level: nullableString, cover_image_url: { type: "string" }, source: { type: "string" },
  });
  const recommendationFields = {
    placeId: uuid, place: ref("MeetupPlaceSummary"), rank,
    averageRating: { type: "number", minimum: 1, maximum: 5, nullable: true }, ratingCount: count,
    budgetLevel: choices([...selectableBudgetLevels, "UNKNOWN"]),
    explanationCodes: unique(choices([...catalogExplanationCodes])),
  };
  spec.components.schemas.MeetupRecommendation = object({
    ...recommendationFields,
    travelStatistics: {
      ...object({ averageDurationMinutes: { type: "integer", minimum: 1 } }),
      description: "Reserved for a privacy-approved, rounded public estimate. Omitted under the current policy.",
    },
    matchScore: {
      type: "number", minimum: 0, maximum: 100,
      description: "Reserved for a calculated, privacy-approved match percentage. Omitted under the current policy.",
    },
  }, Object.keys(recommendationFields));
  spec.components.schemas.MeetupCalculation = object({
    id: uuid, inputVersion: version, attempt: version, optimizationPolicyVersion: { type: "string" },
    calculatedAt: dateTime, expiresAt: dateTime, safeFailureCode: nullableString,
  });
  spec.components.schemas.MeetupResult = {
    ...object({
      status: choices(Object.values(meetup_calculation_status)), sessionStatus: choices(Object.values(meetup_session_status)),
      inputVersion: version, isPartial: flag,
      intendedParticipantCount: count, includedParticipantCount: count, unavailableParticipantCount: count,
      preferences,
      calculation: { ...spec.components.schemas.MeetupCalculation, nullable: true },
      recommendations: { ...unique(ref("MeetupRecommendation")), maxItems: meetupRecommendationLimit },
    }),
    description: "Only current READY or PARTIAL calculations expose recommendations. Private travel metrics, route scores and participant journeys are suppressed.",
  };
  const result = ref("MeetupResult");
  spec.paths[path + "/results"] = {
    get: operation("getMeetupResults", "Read the current smart meetup result status and recommendations", bySession, result),
  };
  spec.paths[path + "/calculate"] = {
    post: operation("refreshMeetupResults", "Refresh the result for the current inputs. Routing is deferred.", bySession,
      result, object({})),
  };
  spec.paths[path + "/calculations/{calculationId}"] = {
    get: operation("getMeetupCalculation", "Revalidate a calculation scoped to this session", ["sessionId", "calculationId"], result),
  };
  const effective = object({
    status: choices(["READY", "CONSENT_REQUIRED", "GROUP_EXCLUDED", "STARTING_LOCATION_REQUIRED"]),
    location: { ...object({ latitude: coordinate(90), longitude: coordinate(180),
      name: nullableString, name_ar: nullableString, temporary: flag }), nullable: true },
    transportation: object({ mode, source: choices(["temporary_override", "saved_location", "user_default", "unspecified"]) }),
    override: { ...object({
      location_source: choices(overrideSources), personal_location_id: { ...uuid, nullable: true },
      saved_place_id: { ...uuid, nullable: true }, latitude, longitude, transportation_mode: mode,
      expires_at: { type: "string", format: "date-time" },
    }), nullable: true },
    input_version: { type: "integer", minimum: 1 },
    consent_policy_version: { type: "string" },
  });
  spec.components.schemas.ContextEffectiveStartingLocation = effective;
  const consent = { type: "string", minLength: 1, maxLength: 64 };
  const temporaryInputs = { consent_policy_version: consent, transportation_mode: mode };
  const overrideBody = { oneOf: [
    { ...object({ location_source: choices(["DEFAULT"]), transportation_mode: mode,
      consent_policy_version: consent }, ["location_source"]), anyOf: [
      { required: ["transportation_mode"], properties: { transportation_mode: choices(Object.values(transportation_mode)) } },
      { required: ["consent_policy_version"] },
    ] },
    object({ location_source: choices(["PERSONAL_LOCATION"]), personal_location_id: uuid, ...temporaryInputs },
      ["location_source", "personal_location_id", "consent_policy_version"]),
    object({ location_source: choices(["SAVED_PLACE"]), saved_place_id: uuid, ...temporaryInputs },
      ["location_source", "saved_place_id", "consent_policy_version"]),
    object({ location_source: choices(["MANUAL_POINT"]), latitude: coordinate(90), longitude: coordinate(180), ...temporaryInputs },
      ["location_source", "latitude", "longitude", "consent_policy_version"]),
  ] };
  for (const [collection, param, context] of [
    ["smart-meetups", "sessionId", "Meetup"], ["outings", "outingId", "Outing"],
  ]) {
    const data = ref("ContextEffectiveStartingLocation");
    spec.paths["/api/" + collection + "/{" + param + "}/my-starting-location"] = {
      get: operation("get" + context + "StartingLocation", "Read your effective starting location and transportation", [param], data),
      put: { ...operation("set" + context + "StartingLocation", "Set your temporary starting location or transportation", [param], data, overrideBody, true),
        description: "For a temporary point or reference, confirm context-only calculation use by sending the current consent policy version from GET. DEFAULT can change transportation without authorizing a point. For an outing, use the current contextual consent policy version to authorize the default starting point. Automatic consent covers Smart Meetup. Group exclusions remain enforced." },
      delete: operation("clear" + context + "StartingLocation", "Reset to your authorized default inputs", [param], data),
    };
  }
  spec.paths["/api/groups/{groupId}/smart-meetup"] = {
    post: operation("initializeGroupMeetup", "Open planning for all current group members", ["groupId"], groupSession,
      object({ outing_id: uuid }, [])),
  };
  spec.paths["/api/smart-meetups/standalone"] = {
    post: operation("createStandaloneMeetup", "Open or resume your private Quick Meetup", [], standaloneSession, object({})),
  };
  spec.paths[path + "/participants"] = {
    get: operation("listStandaloneParticipants", "List starting points in your active Quick Meetup", bySession, standaloneParticipants),
    post: operation("addManualParticipant", "Add a temporary guest with an approximate starting point", bySession,
      standaloneSession, object(manualFields, ["latitude", "longitude"]), true, 201),
  };
  spec.paths[path + "/participants/{participantId}"] = {
    patch: operation("updateManualParticipant", "Edit a guest in your Quick Meetup. Send both coordinates to move a point.",
      byParticipant, standaloneSession, { ...object(manualFields, []), minProperties: 1 }, true),
    delete: operation("removeManualParticipant", "Remove a guest from your Quick Meetup", byParticipant, standaloneSession),
  };
  spec.paths[path] = {
    get: operation("getMeetupSession", "Read the current session", bySession, session),
    delete: operation("cancelMeetupSession", "Cancel your own planning session", bySession, session),
  };
  spec.paths[path + "/readiness"] = { get: operation("getGroupMeetupReadiness", "Read current participant readiness", bySession, ref("MeetupReadiness")) };
  spec.paths[path + "/refresh"] = { post: operation("refreshMeetupSession", "Revalidate planning inputs", bySession, session) };
  spec.paths["/api/smart-meetups/filter-options"] = {
    get: operation("getMeetupFilterOptions", "List active catalog categories and supported preference options", [], ref("MeetupFilterOptions")),
  };
  spec.paths[path + "/preferences"] = {
    get: operation("getMeetupPreferences", "Read shared session preferences", bySession, preferences),
    put: operation("updateMeetupPreferences", "Replace preferences for an active session you manage", bySession, session, preferences, true),
    patch: { ...operation("updateLegacyMeetupOptimization", "Change the travel objective from an older client", bySession, session, object({ optimization }), true), deprecated: true },
  };
  spec.paths[path + "/preferences/reset"] = {
    post: operation("resetMeetupPreferences", "Clear preference selections and restore Balanced", bySession, session),
  };
}
