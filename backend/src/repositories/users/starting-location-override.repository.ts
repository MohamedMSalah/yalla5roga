
import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type {
  StartingLocationContext, StartingLocationOverrideInput,
} from "../../types/users/starting-location-override.js";
import { startingLocationContextConsentVersion } from "../../types/users/starting-location-override.js";

const point = { latitude: true, longitude: true } as const;
const catalog = { ...point, name: true, name_ar: true, district: true, is_active: true, status: true, updated_at: true } as const;
const personal = { ...point, name: true, updated_at: true, preferred_transportation_mode: true,
  place: { select: catalog } } as const;
const bookmark = { preferred_transportation_mode: true, places: { select: catalog } } as const;

const contextFields = (context: StartingLocationContext) => context.kind === "meetup"
  ? { meetup_session_id: context.id } : { outing_id: context.id };

export class StartingLocationOverrideRepository {
  async transaction<T>(
    run: (tx: Prisma.TransactionClient) => Promise<T>,
    isolationLevel: Prisma.TransactionIsolationLevel = "RepeatableRead",
  ) {
    for (let attempt = 0; ; attempt++) {
      try {
        return await prisma.$transaction(run, { isolationLevel });
      } catch (error) {
        if (attempt >= 3 || !(error instanceof Prisma.PrismaClientKnownRequestError) ||
            !(["P2034", "P2002"].includes(error.code) || error.code === "P2010" &&
              ["40001", "40P01"].includes(String(error.meta?.code)))) throw error;
      }
    }
  }

  list(tx: Prisma.TransactionClient, context: StartingLocationContext, userIds: string[], now: Date) {
    if (!userIds.length) return [];
    return tx.starting_location_overrides.findMany({
      where: {
        ...contextFields(context), user_id: { in: userIds }, expires_at: { gt: now },
        OR: [
          { location_source: "DEFAULT", consent_policy_version: null },
          { consent_policy_version: startingLocationContextConsentVersion },
        ],
      },
      include: { personal_location: { select: personal }, saved_place: { select: bookmark } },
    });
  }

  defaults(tx: Prisma.TransactionClient, userIds: string[]) {
    if (!userIds.length) return [];
    return tx.default_starting_locations.findMany({
      where: { user_id: { in: userIds } },
      include: { saved_location: { select: personal }, saved_place: { select: bookmark } },
    });
  }

  personal(tx: Prisma.TransactionClient, userId: string, id: string) {
    return tx.saved_locations.findUnique({ where: { user_id_id: { user_id: userId, id } }, select: personal });
  }

  bookmark(tx: Prisma.TransactionClient, userId: string, id: string) {
    return tx.saved_places.findUnique({ where: { user_id_place_id: { user_id: userId, place_id: id } }, select: bookmark });
  }

  async set(tx: Prisma.TransactionClient, userId: string, context: StartingLocationContext,
    input: StartingLocationOverrideInput, expiresAt: Date, now: Date) {
    const fields = contextFields(context);
    const where = context.kind === "meetup"
      ? { user_id_meetup_session_id: { user_id: userId, meetup_session_id: context.id } }
      : { user_id_outing_id: { user_id: userId, outing_id: context.id } };
    const values = {
      location_source: input.location_source,
      transportation_mode: input.transportation_mode ?? null,
      personal_location_id: input.location_source === "PERSONAL_LOCATION" ? input.personal_location_id : null,
      saved_place_id: input.location_source === "SAVED_PLACE" ? input.saved_place_id : null,
      latitude: input.location_source === "MANUAL_POINT" ? input.latitude : null,
      longitude: input.location_source === "MANUAL_POINT" ? input.longitude : null,
      consent_policy_version: input.consent_policy_version ?? null,
    };
    const previous = await tx.starting_location_overrides.findUnique({ where });
    if (previous && previous.expires_at > now && previous.expires_at.getTime() === expiresAt.getTime() &&
        Object.entries(values).every(([key, value]) => previous[key as keyof typeof values] === value)) return;
    await tx.starting_location_overrides.upsert({
      where, create: { ...values, ...fields, user_id: userId, created_at: now, expires_at: expiresAt },
      update: { ...values, expires_at: expiresAt, ...(previous && previous.expires_at <= now && { created_at: now }) },
    });
  }

  clear(tx: Prisma.TransactionClient, userId: string, context: StartingLocationContext) {
    return tx.starting_location_overrides.deleteMany({ where: { user_id: userId, ...contextFields(context) } });
  }
}
