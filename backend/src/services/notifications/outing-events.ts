import type { Prisma } from "@prisma/client";
import type { Outing } from "../../types/outings/outing.types.js";
import { notifyOutingParticipants } from "./outing-notifier.js";

export async function persistOutingTransition(
  tx: Prisma.TransactionClient,
  before: Outing | null,
  outing: Outing,
) {
  const send = (
    eventType: Parameters<typeof notifyOutingParticipants>[0]["eventType"],
    body: string,
    type: "outing" | "vote" = "outing",
    revision = outing.updated_at.toISOString(),
  ) =>
    notifyOutingParticipants(
      {
        outing,
        type,
        eventType,
        body,
        eventKey: `${eventType}:${outing.id}:${revision}`,
        ...(["outing_created", "outing_updated"].includes(eventType)
          ? { excludeUserId: outing.created_by }
          : {}),
      },
      tx,
    );
  if (!before) {
    const group = outing.group_id
      ? await tx.groups.findUnique({ where: { id: outing.group_id } })
      : null;
    await send(
      "outing_created",
      `New outing: ${outing.title}${group ? ` in ${group.name}` : ""}.`,
      "outing",
      "created",
    );
    await notifyOutingParticipants(
      {
        outing,
        type: "outing",
        eventType: "rsvp_opened",
        body: `Please confirm your attendance for ${outing.title}.`,
        eventKey: `rsvp_opened:${outing.id}:opened`,
        excludeUserId: outing.created_by,
      },
      tx,
    );
  }
  if (outing.vote_closed_at && !before?.vote_closed_at)
    await send(
      "voting_closed",
      `Voting for ${outing.title} has ended.`,
      "vote",
      "closed",
    );
  if (outing.status === "cancelled" && before?.status !== "cancelled") {
    await send(
      "outing_cancelled",
      `${outing.title} has been cancelled.`,
      "outing",
      "cancelled",
    );
    return;
  }
  if (["past", "cancelled"].includes(outing.status)) return;
  if (outing.status === "voting" && before?.status !== "voting")
    await send(
      "voting_started",
      `Voting is open for ${outing.title}.`,
      "vote",
      "started",
    );
  if (
    outing.winning_option_id &&
    outing.winning_option_id !== before?.winning_option_id
  ) {
    await send(
      outing.vote_close_reason === "tie_break"
        ? "tie_break_selected"
        : "winner_selected",
      `${outing.location_name ?? "A venue"} was selected for ${outing.title}.`,
      "vote",
      outing.winning_option_id,
    );
  }
  if (outing.status === "confirmed" && before?.status !== "confirmed") {
    await send(
      "outing_confirmed",
      `${outing.title} is confirmed!`,
      "outing",
      "confirmed",
    );
  } else if (
    before &&
    outing.status === before.status &&
    [
      "title",
      "scheduled_at",
      "ends_at",
      "group_id",
      "location_name",
      "location_area",
      "image_url",
    ].some(
      (key) =>
        String(before[key as keyof Outing]) !==
        String(outing[key as keyof Outing]),
    )
  ) {
    await send("outing_updated", `${outing.title}'s details have changed.`);
  }
}
