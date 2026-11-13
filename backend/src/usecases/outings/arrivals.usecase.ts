import type { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { arrivalMaxAccuracyMeters, arrivalRadiusMeters, arrivalWindowEnd, arrivalWindowOpen, verifiedDistance, type ArrivalProof } from "../../services/outings/arrival-policy.js";
import { listEligibleVoterIds } from "../../services/outings/outing-participants.js";
import { emitOutingArrivalChanged } from "../../realtime/chat-emitter.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

function venueCoordinates(outing: {
  location_latitude: number | null;
  location_longitude: number | null;
  places: { latitude: number | null; longitude: number | null } | null;
}): { latitude: number; longitude: number } | null {
  const coordinatePairs = [
    [outing.location_latitude, outing.location_longitude],
    [outing.places?.latitude, outing.places?.longitude],
  ];
  for (const [latitude, longitude] of coordinatePairs) {
    if (latitude != null && longitude != null &&
        Number.isFinite(latitude) && Number.isFinite(longitude) &&
        Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180) {
      return { latitude, longitude };
    }
  }
  return null;
}

export class OutingArrivalsUseCase {
  private async getForParticipant(db: Prisma.TransactionClient, id: string, userId: string) {
    const outing = await db.outings.findUnique({
      where: { id },
      include: { places: { select: { latitude: true, longitude: true } } },
    });
    if (!outing) throw new NotFoundError("Outing");
    const participantIds = outing.group_id
      ? (await db.group_members.findMany({
          where: { group_id: outing.group_id },
          select: { user_id: true },
        })).map(({ user_id }) => user_id)
      : await listEligibleVoterIds(outing, db);
    if (!participantIds.includes(userId)) {
      throw new ForbiddenError("Only outing participants can view or record arrivals");
    }
    return { outing, participantIds };
  }

  async list(id: string, userId: string) {
    const { outing, participantIds } = await this.getForParticipant(prisma, id, userId);
    const [arrivals, participants] = await Promise.all([
      prisma.outing_arrivals.findMany({
        where: { outing_id: id, user_id: { in: participantIds }, verification_method: { not: "organizer" } },
        orderBy: [{ arrived_at: "asc" }, { user_id: "asc" }],
        select: { user_id: true, arrived_at: true, verification_method: true, users: { select: { name: true } } },
      }),
      prisma.users.findMany({
        where: { id: { in: participantIds } },
        orderBy: [{ name: "asc" }, { id: "asc" }],
        select: { id: true, name: true },
      }),
    ]);
    const confirmed = new Set(arrivals.map((row) => row.user_id));
    const venue = venueCoordinates(outing);
    const open = venue != null && arrivalWindowOpen(outing, new Date());
    return {
      arrivals: arrivals.map(({ users, ...arrival }) => ({ ...arrival, name: users.name })),
      unconfirmed: participants.filter((person) => !confirmed.has(person.id)),
      total_confirmed: arrivals.length,
      open,
      closes_at: arrivalWindowEnd(outing),
      radius_meters: arrivalRadiusMeters(),
      opens_at: outing.scheduled_at,
      max_accuracy_meters: arrivalMaxAccuracyMeters(),
      venue: outing.status === "confirmed" ? venue : null,
      automatic_eligible: true,
      can_confirm_arrivals: false,
    };
  }

  async record(id: string, userId: string, proof: ArrivalProof) {
    const result = await prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM outings WHERE id = ${id}::uuid FOR UPDATE`;
      const { outing, participantIds } = await this.getForParticipant(tx, id, userId);
      if (outing.group_id) {
        const membership = await tx.$queryRaw<{ user_id: string }[]>`
          SELECT user_id FROM group_members
          WHERE group_id = ${outing.group_id}::uuid AND user_id = ${userId}
          FOR KEY SHARE
        `;
        if (!membership.length) throw new ForbiddenError("Only current group members can verify arrival");
      }
      const key = { outing_id: id, user_id: userId };
      const where = { outing_id_user_id: key };
      const previous = await tx.outing_arrivals.findUnique({ where });
      if (previous && previous.verification_method !== "organizer") {
        return { arrived: true, recipients: [] };
      }

      const now = new Date();
      const venue = venueCoordinates(outing);
      // A reported mock fix is a negative signal only. False/omitted is never
      // evidence of genuine GPS; access, venue, time and distance are checked here.
      if (proof.is_mocked === true || !venue || !arrivalWindowOpen(outing, now)) {
        return { arrived: false, recipients: [] };
      }
      const capturedAt = Date.parse(proof.captured_at);
      if (!Number.isFinite(capturedAt) || capturedAt < now.getTime() - 30_000 ||
          capturedAt > now.getTime() + 5_000 ||
          !arrivalWindowOpen(outing, new Date(capturedAt))) {
        return { arrived: false, recipients: [] };
      }
      const distance = verifiedDistance(proof, venue.latitude, venue.longitude);
      if (distance == null) return { arrived: false, recipients: [] };
      const data = {
        arrived_at: now,
        verification_method: "gps",
        verification_distance: distance,
        location_accuracy: proof.accuracy,
      };
      await tx.outing_arrivals.upsert({ where, create: { ...key, ...data }, update: data });
      return { arrived: true, recipients: participantIds };
    });
    if (result.arrived) emitOutingArrivalChanged(id, result.recipients);
    return { arrived: result.arrived };
  }
}
