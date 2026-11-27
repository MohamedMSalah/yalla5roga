import { z } from "zod";
import { routePreviewSchema } from "../types/routing/route-preview.js";

type Spec = { paths: Record<string, unknown>; components: { schemas: Record<string, unknown> } };

export function extendRoutePreviewOpenApi(spec: Spec) {
  const { $schema: _schema, ...preview } = z.toJSONSchema(routePreviewSchema, { target: "openapi-3.0" });
  spec.components.schemas.RoutePreview = {
    ...preview,
    description: "Caller-only route preview. All GeoJSON positions are [longitude, latitude]. Expiry bounds reuse of the response.",
  };
  const parameter = (name: string, location = "path", schema: object = { type: "string", format: "uuid" }) =>
    ({ name, in: location, required: true, schema });
  for (const [path, operationId, parameters] of [
    ["/api/outings/{outingId}/my-route", "getMyOutingRoute", [parameter("outingId")]],
    ["/api/smart-meetups/{sessionId}/recommendations/{placeId}/my-route", "getMyMeetupRoute",
      [parameter("sessionId"), parameter("placeId"), parameter("calculation_id", "query"),
        parameter("input_version", "query", { type: "integer", minimum: 1, maximum: Number.MAX_SAFE_INTEGER })]],
  ] as const) {
    spec.paths[path] = { get: {
      operationId, parameters, tags: ["Routing"], security: [{ bearerAuth: [] }],
      summary: "Read your personal route preview",
      description: "Uses your authorized effective starting location and the server-resolved destination. Until routing is configured, routing.status is ROUTING_UNAVAILABLE.",
      responses: {
        200: {
          description: "Private, non-cacheable preview",
          headers: { "Cache-Control": { schema: { type: "string", example: "private, no-store" } } },
          content: { "application/json": { schema: { type: "object", required: ["success", "data"],
            properties: { success: { type: "boolean" }, data: { $ref: "#/components/schemas/RoutePreview" } } } } },
        },
        400: { description: "Invalid parameters or unexpected inputs" },
        401: { description: "Authentication required" },
        403: { description: "Caller does not have access to the context" },
        404: { description: "Context or recommendation not found" },
        409: { description: "Expired context, stale meetup calculation, or unavailable destination" },
      },
    } };
  }
}
