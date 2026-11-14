import { prisma } from "../config/database.js";
import { notifyOutingParticipants } from "../services/notifications/outing-notifier.js";
import { listEligibleVoterIds } from "../services/outings/outing-participants.js";
import {
  arrivalWindowOpen,
  arrivalWindowEnd,
} from "../services/outings/arrival-policy.js";

/** Rolling time windows plus durable event keys make multiple workers/restarts safe. */
export async function enqueueDueNotificationReminders(now = new Date()) {
  const hour = new Date(now.getTime() + 3_600_000);
  let cursor: string | undefined;
  for (;;) {
    const rows = await prisma.outings.findMany({
      where: {
        status: { in: ["voting", "confirmed"] },
        OR: [
          { vote_closed_at: null, vote_ends_at: { gt: now, lte: hour } },
          { scheduled_at: { gt: now, lte: hour } },
          {
            status: "confirmed",
            scheduled_at: {
              lte: now,
              gte: new Date(now.getTime() - 86_400_000),
            },
          },
        ],
      },
      orderBy: { id: "asc" },
      take: 100,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    for (const candidate of rows)
      await prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM outings WHERE id = ${candidate.id}::uuid FOR UPDATE`;
        const outing = await tx.outings.findUnique({
          where: { id: candidate.id },
        });
        if (!outing || ["cancelled", "past"].includes(outing.status)) return;
        if (
          outing.status === "voting" &&
          !outing.vote_closed_at &&
          outing.vote_ends_at &&
          outing.vote_ends_at > now &&
          outing.vote_ends_at <= hour
        ) {
          await notifyOutingParticipants(
            {
              outing,
              type: "vote",
              eventType: "voting_deadline_approaching",
              body: `Voting for ${outing.title} closes within 1 hour.`,
              eventKey: `voting_deadline_approaching:${outing.id}:${outing.vote_ends_at.toISOString()}`,
              data: { deadline: outing.vote_ends_at.toISOString() },
            },
            tx,
          );
        }
        const start = outing.scheduled_at;
        if (!start) return;
        const schedule = start.toISOString();
        if (start > now && start <= hour) {
          await notifyOutingParticipants(
            {
              outing,
              type: "outing",
              eventType: "outing_reminder",
              body: `${outing.title} starts within 1 hour.`,
              eventKey: `outing_reminder:${outing.id}:${schedule}`,
              data: { schedule },
            },
            tx,
          );
          if (outing.status === "confirmed" && outing.location_name)
            await notifyOutingParticipants(
              {
                outing,
                type: "outing",
                eventType: "venue_reminder",
                body: `Meet at ${outing.location_name} for ${outing.title}.`,
                eventKey: `venue_reminder:${outing.id}:${schedule}`,
                data: { schedule },
              },
              tx,
            );
        }
        if (arrivalWindowOpen(outing, now)) {
          const venue =
            (outing.location_latitude != null &&
              outing.location_longitude != null) ||
            (outing.location_place_id &&
              (await tx.places.findFirst({
                where: {
                  id: outing.location_place_id,
                  latitude: { not: null },
                  longitude: { not: null },
                },
              })));
          if (!venue) return;
          const ids = outing.group_id
            ? (
                await tx.group_members.findMany({
                  where: { group_id: outing.group_id },
                })
              ).map((m) => m.user_id)
            : await listEligibleVoterIds(outing, tx);
          const arrived = new Set(
            (
              await tx.outing_arrivals.findMany({
                where: { outing_id: outing.id },
              })
            ).map((a) => a.user_id),
          );
          await notifyOutingParticipants(
            {
              outing,
              type: "outing",
              eventType: "arrival_reminder",
              body: `${outing.title} is starting. Open the outing to check in when you arrive.`,
              userIds: ids.filter((id) => !arrived.has(id)),
              eventKey: `arrival_reminder:${outing.id}:${schedule}`,
              data: {
                schedule,
                expiresAt: arrivalWindowEnd(outing)!.toISOString(),
              },
            },
            tx,
          );
        }
      });
    if (rows.length < 100) break;
    cursor = rows[rows.length - 1]!.id;
  }
}
