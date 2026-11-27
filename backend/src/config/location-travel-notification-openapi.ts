type Schema = Record<string, unknown>;

export function extendLocationTravelNotificationOpenApi(spec: { paths: Record<string, Record<string, Schema>> }) {
  const dateTime = { type: "string", format: "date-time", nullable: true };
  const flag = { type: "boolean" };
  const buffer = { type: "integer", enum: [0, 5, 10, 15, 30], default: 10 };
  const string = { type: "string" };
  const object = (properties: Record<string, Schema>, required = Object.keys(properties)) =>
    ({ type: "object", properties, required, additionalProperties: false });
  const preferences = {
    enabled: { ...flag, default: false },
    preparation_buffer_minutes: buffer,
    updated_at: dateTime,
  };
  const reminder = object({
    ...preferences,
    status: { ...string, enum: [
      "OUTING_UNAVAILABLE", "RSVP_REQUIRED", "OPT_IN_REQUIRED", "NOTIFICATIONS_DISABLED",
      "STARTING_LOCATION_REQUIRED", "TRANSPORTATION_MODE_REQUIRED", "ROUTING_UNAVAILABLE",
      "ALREADY_SENT", "ESTIMATE_UNAVAILABLE", "DEPARTURE_PASSED", "AVAILABLE", "SCHEDULED",
    ] },
    starting_location: { ...object({ name: { ...string, nullable: true },
      name_ar: { ...string, nullable: true }, temporary: flag }), nullable: true },
    transportation_mode: { ...string, nullable: true },
    estimated_journey_seconds: { type: "integer", minimum: 0, nullable: true },
    suggested_departure_at: dateTime,
    scheduled_send_at: dateTime,
  });
  function operation(operationId: string, summary: string, result: Schema, pathParam?: string, body?: Schema) {
    return {
      tags: ["Notifications"], operationId, summary, security: [{ bearerAuth: [] }],
      ...(pathParam && { parameters: [{ name: pathParam, in: "path", required: true,
        schema: { type: "string", format: "uuid" } }] }),
      ...(body && { requestBody: { required: true, content: { "application/json": { schema: body } } } }),
      responses: {
        200: { description: "Success", content: { "application/json": {
          schema: object({ success: { type: "boolean", enum: [true] }, data: result }),
        } } },
        400: { description: "Invalid input" }, 401: { description: "Missing or invalid authentication" },
        403: { description: "Current access required" }, 404: { description: "Resource does not exist" },
        409: { description: "Resource context is closed or expired" },
      },
    };
  }

  spec.paths["/api/smart-meetups/{sessionId}/location-requests"] = {
    post: operation("requestMemberLocation", "Request starting location setup for one group member", object({
      status: { ...string, enum: ["REQUESTED", "COOLDOWN", "UNAVAILABLE"] },
      retry_at: dateTime,
    }), "sessionId", object({ target_user_id: { ...string, minLength: 1, maxLength: 128 } })),
  };
  spec.paths["/api/users/me/departure-reminder-preferences"] = {
    get: operation("getDepartureReminderPreferences", "Read account departure reminder preferences", object(preferences)),
    patch: operation("updateDepartureReminderPreferences", "Update account departure reminder preferences", object(preferences),
      undefined, { ...object({ enabled: flag, preparation_buffer_minutes: buffer }, []), minProperties: 1 }),
  };
  spec.paths["/api/outings/{outingId}/my-departure-reminder"] = {
    get: operation("getMyDepartureReminder", "Read your personalized departure reminder status", reminder, "outingId"),
    put: operation("scheduleMyDepartureReminder", "Request scheduling using a current backend travel estimate", reminder, "outingId"),
    delete: operation("clearMyDepartureReminder", "Clear your pending personalized departure reminder", { nullable: true, enum: [null] }, "outingId"),
  };
}
