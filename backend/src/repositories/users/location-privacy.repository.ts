import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";

const coordinates = { latitude: true, longitude: true } as const;
const catalogPoint = { ...coordinates, district: true, is_active: true, status: true } as const;

export class LocationPrivacyRepository {
  constructor(private readonly db = prisma) {}

  transaction<T>(run: (tx: Prisma.TransactionClient) => Promise<T>) {
    return this.db.$transaction(run);
  }

  lockUsers(tx: Prisma.TransactionClient, ids: string[], edit = false) {
    return tx.$queryRaw<Array<{ id: string; created_at: Date }>>`
      SELECT id, created_at FROM users WHERE id IN (${Prisma.join(ids)})
      ORDER BY id ${edit ? Prisma.sql`FOR NO KEY UPDATE` : Prisma.sql`FOR SHARE`}
    `;
  }

  lockGroup(tx: Prisma.TransactionClient, groupId: string) {
    return tx.$queryRaw`SELECT id FROM groups WHERE id = ${groupId}::uuid FOR KEY SHARE`;
  }

  lockMemberships(tx: Prisma.TransactionClient, groupId: string, ids: string[]) {
    return tx.$queryRaw<Array<{ user_id: string; joined: string }>>`
      SELECT user_id, EXTRACT(EPOCH FROM joined_at)::text AS joined FROM group_members
      WHERE group_id = ${groupId}::uuid AND user_id IN (${Prisma.join(ids)})
      ORDER BY user_id FOR SHARE
    `;
  }

  get(tx: Prisma.TransactionClient, userId: string) {
    return tx.user_location_privacy.findUnique({ where: { user_id: userId } });
  }

  set(
    tx: Prisma.TransactionClient,
    userId: string,
    data: Omit<Prisma.user_location_privacyUncheckedCreateInput, "user_id">,
  ) {
    return tx.user_location_privacy.upsert({
      where: { user_id: userId }, create: { user_id: userId, ...data }, update: data,
    });
  }

  listExclusions(userId: string) {
    return this.db.user_location_group_exclusions.findMany({
      where: { user_id: userId, group: { group_members: { some: { user_id: userId } } } },
      select: { group_id: true, created_at: true },
      orderBy: [{ created_at: "asc" }, { group_id: "asc" }],
    });
  }

  getExclusion(tx: Prisma.TransactionClient, userId: string, groupId: string) {
    return tx.user_location_group_exclusions.findUnique({
      where: { user_id_group_id: { user_id: userId, group_id: groupId } },
      select: { group_id: true },
    });
  }

  async changeExclusion(tx: Prisma.TransactionClient, userId: string, groupId: string, excluded: boolean) {
    if (excluded) {
      await tx.user_location_group_exclusions.create({ data: { user_id: userId, group_id: groupId } });
    } else {
      await tx.user_location_group_exclusions.deleteMany({ where: { user_id: userId, group_id: groupId } });
    }
  }

  getStartingPoint(tx: Prisma.TransactionClient, userId: string) {
    return tx.default_starting_locations.findUnique({
      where: { user_id: userId },
      select: {
        saved_location: { select: coordinates },
        saved_place: { select: { places: { select: coordinates } } },
      },
    });
  }

  // Select only the public catalog district. Personal labels and addresses are never read here.
  async getDistrict(tx: Prisma.TransactionClient, userId: string) {
    const selection = await tx.default_starting_locations.findUnique({
      where: { user_id: userId },
      select: {
        saved_location: { select: { ...coordinates, place: { select: catalogPoint } } },
        saved_place: { select: { places: { select: catalogPoint } } },
      },
    });
    const personal = selection?.saved_location;
    const place = personal ? personal.place : selection?.saved_place?.places;
    if (!place?.is_active || place.status !== "active" || place.latitude == null || place.longitude == null) {
      return null;
    }
    // A client-supplied catalog link alone does not establish a private point's district.
    if (personal && (personal.latitude !== place.latitude || personal.longitude !== place.longitude)) {
      return null;
    }
    return place.district;
  }
}
