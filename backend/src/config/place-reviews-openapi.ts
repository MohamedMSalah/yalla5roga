type Schema = Record<string, unknown>;
type Spec = {
  paths: Record<string, Record<string, Schema>>;
  components: { schemas: Record<string, { properties?: Record<string, Schema> } & Schema> };
};

export function extendPlaceReviewsOpenApi(spec: Spec) {
  const uuid = { type: "string", format: "uuid" };
  const date = { type: "string", format: "date-time" };
  const count = { type: "integer", minimum: 0 };
  const rating = { ...count, minimum: 1, maximum: 5 };
  const text = { type: "string", nullable: true, maxLength: 1000 };
  const visibility = { type: "string", enum: ["visible", "hidden"] };
  const reason = { type: "string", enum: ["spam", "harassment", "inappropriate", "off_topic", "other"] };
  const reportStatus = { type: "string", enum: ["open", "dismissed", "actioned"] };
  const object = (properties: Record<string, Schema>, required = Object.keys(properties)) =>
    ({ type: "object", properties, required, additionalProperties: false });
  const ref = (name: string) => ({ $ref: "#/components/schemas/" + name });
  const statistics = ref("PlaceRatingStatistics");
  const review = ref("PlaceReview");
  const fields = {
    id: uuid, placeId: uuid, rating, reviewText: text, createdAt: date, updatedAt: date,
    isMine: { type: "boolean" }, reviewer: object({ name: { type: "string" } }),
  };
  const nullableReview = { ...object(fields), nullable: true,
    properties: { ...fields, moderationStatus: visibility } };
  const cursor = { type: "string", nullable: true, maxLength: 160 };
  const page = (items: Schema) => object({ items: { type: "array", items }, nextCursor: cursor });
  const ratingBody = object({ rating, reviewText: text }, ["rating"]);
  const mutation = object({ review: nullableReview, statistics });
  const report = object({ id: uuid, status: reportStatus });

  Object.assign(spec.components.schemas, {
    PlaceRatingStatistics: object({
      averageRating: { type: "number", nullable: true, minimum: 1, maximum: 5 },
      ratingCount: count, writtenReviewCount: count, updatedAt: { ...date, nullable: true },
      distribution: object({ 1: count, 2: count, 3: count, 4: count, 5: count }),
    }),
    PlaceReview: { ...nullableReview, nullable: false },
  });
  for (const name of ["Place", "NearbyPlace", "PlaceRecommendation", "VoteOption", "OutingVoteOption"]) {
    const properties = spec.components.schemas[name]?.properties;
    if (properties) properties.rating_statistics = statistics;
  }

  function operation(operationId: string, summary: string, params: string[], data: Schema, options: {
    body?: Schema; public?: boolean; paginated?: boolean; moderation?: boolean;
  } = {}) {
    const parameters: Schema[] = params.map((name) => ({ name, in: "path", required: true, schema: uuid }));
    if (options.paginated) parameters.push(
      { name: "cursor", in: "query", schema: { type: "string", maxLength: cursor.maxLength } },
      { name: "limit", in: "query", schema: { ...count, minimum: 1, maximum: 50, default: 15 } },
    );
    const responses: Record<string, Schema> = { 200: {
      description: "Success", content: { "application/json": {
        schema: object({ success: { type: "boolean" }, data }),
      } },
    } };
    for (const [code, name] of Object.entries({ 400: "BadRequest", 401: "Unauthorized",
      403: "Forbidden", 404: "NotFound", 409: "Conflict", 429: "TooManyRequests",
      500: "InternalServerError" })) {
      responses[code] = { $ref: "#/components/responses/" + name };
    }
    return { operationId, summary, tags: ["Place Reviews"], parameters, responses,
      security: options.public ? [] : [{ bearerAuth: [] }],
      ...(options.moderation && { description: "Requires a UID explicitly authorized for review moderation." }),
      ...(options.body && { requestBody: { required: true, content: { "application/json": { schema: options.body } } } }),
    };
  }

  const base = "/api/places";
  const branch = base + "/{placeId}";
  const item = branch + "/reviews/{reviewId}";
  const place = ["placeId"];
  const target = ["placeId", "reviewId"];
  Object.assign(spec.paths, {
    [branch + "/ratings"]: {
      get: operation("getPlaceRatingStatistics", "Get branch rating statistics", place, statistics, { public: true }),
    },
    [branch + "/reviews"]: {
      get: operation("getPlaceReviews", "Get visible written branch reviews", place, page(review), { paginated: true }),
    },
    [branch + "/my-rating"]: {
      get: operation("getMyPlaceRating", "Get your branch rating", place, nullableReview),
      put: operation("submitPlaceRating", "Create or replace your branch rating", place, mutation, { body: ratingBody }),
      patch: operation("updatePlaceRating", "Update your existing branch rating", place, mutation, { body: ratingBody }),
      delete: operation("deletePlaceRating", "Delete your branch rating", place, mutation),
    },
    [item + "/report"]: {
      post: operation("reportPlaceReview", "Report a written review", target, report, { body: object({ reason }) }),
    },
    [item + "/block"]: {
      put: operation("blockPlaceReviewAuthor", "Hide this author's reviews for your account", target, object({ id: uuid })),
    },
    [base + "/review-blocks"]: {
      get: operation("listPlaceReviewBlocks", "List authors you blocked", [], page(object({ id: uuid, name: { type: "string" } })), { paginated: true }),
    },
    [base + "/review-blocks/{id}"]: {
      delete: operation("removePlaceReviewBlock", "Unblock a review author", ["id"], object({ removed: { type: "boolean" } })),
    },
    [base + "/review-reports"]: {
      get: operation("listPlaceReviewReports", "List open reports for moderation", [], page(object({
        id: uuid, reason, status: reportStatus, createdAt: date, review,
      })), { moderation: true, paginated: true }),
    },
    [base + "/review-reports/{id}/dismiss"]: {
      patch: operation("dismissPlaceReviewReport", "Dismiss an open report", ["id"], report, { moderation: true }),
    },
    [item + "/moderation"]: {
      patch: operation("moderatePlaceReview", "Hide or restore a review and its rating", target, mutation,
        { moderation: true, body: object({ moderationStatus: visibility }) }),
    },
  });
}
