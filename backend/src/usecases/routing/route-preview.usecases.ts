import type { Prisma } from "@prisma/client";
import { StartingLocationOverrideRepository } from "../../repositories/users/starting-location-override.repository.js";
import { resolveRoutePreview, UnavailableRoutePreviewService, type RoutePreviewService } from "../../services/routing/route-preview.service.js";
import { isRoutePoint, type RoutePoint } from "../../types/routing/route-preview.js";
import type { StartingLocationContext } from "../../types/users/starting-location-override.js";
import { ConflictError, NotFoundError } from "../../utils/errors.js";
import { GetMeetupResultsUseCase } from "../meetups/meetup-result.usecases.js";
import { MeetupSessionWorkflow } from "../meetups/meetup-session.usecases.js";
import { GetEffectiveStartingLocationUseCase } from "../users/starting-location-override.usecases.js";

export class RoutePreviewAuthorizationPolicy {
  constructor(private readonly startingLocation = new GetEffectiveStartingLocationUseCase()) {}

  readOwnStartingLocation(tx: Prisma.TransactionClient, authenticatedUid: string, context: StartingLocationContext) {
    return this.startingLocation.read(tx, authenticatedUid, context);
  }
}

type AuthorizedInputs = Awaited<ReturnType<RoutePreviewAuthorizationPolicy["readOwnStartingLocation"]>>;

function destinationPoint(value: unknown): RoutePoint {
  if (!isRoutePoint(value)) throw new ConflictError("Destination coordinates are unavailable", "route_destination_unavailable");
  return value;
}

async function preview(service: RoutePreviewService, context: StartingLocationContext,
    { effective, expiresAt }: AuthorizedInputs, destination: RoutePoint) {
  if (expiresAt <= new Date()) throw new ConflictError("Route preview context has expired");
  const { location, status, input_version, transportation, override } = effective;
  const origin = location && isRoutePoint(location)
    ? { latitude: location.latitude, longitude: location.longitude, name: location.name, name_ar: location.name_ar }
    : null;
  const mode = transportation.mode;
  const expires = override && override.expires_at < expiresAt ? override.expires_at : expiresAt;
  const routing = await resolveRoutePreview(service, { context, input_version, origin, destination, mode });
  if (expires <= new Date()) throw new ConflictError("Route preview inputs have expired");
  return {
    input_version, expires_at: expires.toISOString(), starting_location_status: status,
    origin, destination, mode, routing,
  };
}

export class GetMyMeetupRouteUseCase {
  constructor(
    private readonly policy = new RoutePreviewAuthorizationPolicy(),
    private readonly results = new GetMeetupResultsUseCase(new MeetupSessionWorkflow()),
    private readonly service: RoutePreviewService = new UnavailableRoutePreviewService(),
  ) {}

  async execute(uid: string, sessionId: string, placeId: string, calculationId: string, inputVersion: number) {
    const context: StartingLocationContext = { kind: "meetup", id: sessionId };
    const prepared = await this.results.flow.withSession(uid, sessionId, async (tx, session) => {
      // Acquire the existing owner and membership locks before resolving the calculation.
      const own = await this.policy.readOwnStartingLocation(tx, uid, context);
      const result = await this.results.read(tx, session, uid, {});
      const calculation = result.calculation;
      if (result.inputVersion !== inputVersion || own.effective.input_version !== inputVersion ||
          calculation?.id !== calculationId || calculation.inputVersion !== inputVersion || !calculation.expiresAt ||
          (result.status !== "READY" && result.status !== "PARTIAL")) return null;
      const place = result.recommendations.find(row => row.placeId === placeId)?.place;
      if (!place) throw new NotFoundError("Meetup recommendation");
      const expiresAt = calculation.expiresAt < own.expiresAt ? calculation.expiresAt : own.expiresAt;
      return { own: { ...own, expiresAt }, destination: destinationPoint({
        latitude: place.latitude, longitude: place.longitude, name: place.name_en ?? place.name, name_ar: place.name_ar,
      }) };
    }, { activeOnly: true });
    // Commit any invalidation performed by the existing result reader before returning the conflict.
    if (!prepared) throw new ConflictError("Refresh the Smart Meetup recommendations", "stale_meetup_result");
    return preview(this.service, context, prepared.own, prepared.destination);
  }
}

export class GetMyOutingRouteUseCase {
  constructor(
    private readonly policy = new RoutePreviewAuthorizationPolicy(),
    private readonly repository = new StartingLocationOverrideRepository(),
    private readonly service: RoutePreviewService = new UnavailableRoutePreviewService(),
  ) {}

  async execute(uid: string, outingId: string) {
    const context: StartingLocationContext = { kind: "outing", id: outingId };
    const { own, destination } = await this.repository.transaction(async tx => {
      const own = await this.policy.readOwnStartingLocation(tx, uid, context);
      const outing = await tx.outings.findUniqueOrThrow({ where: { id: outingId }, select: {
        status: true, location_latitude: true, location_longitude: true, location_name: true,
      } });
      if (outing.status !== "confirmed") {
        throw new ConflictError("The outing venue is not confirmed", "route_destination_unavailable");
      }
      return { own, destination: destinationPoint({
        latitude: outing.location_latitude, longitude: outing.location_longitude, name: outing.location_name, name_ar: null,
      }) };
    });
    return preview(this.service, context, own, destination);
  }
}
