import type {
  Prisma,
  notification_event_type,
  notification_type,
} from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { listEligibleVoterIds } from "../outings/outing-participants.js";
import { emitDataChange } from "../../realtime/data-changes.js";
import { persistNotifications } from "./persist-notification.js";

type NotifyInput = {
  outing: Outing;
  type: notification_type;
  eventType: notification_event_type;
  body: string;
  eventKey: string;
  actionRequired?: boolean;
  userIds?: string[];
  excludeUserId?: string;
  data?: Record<string, string>;
};

export async function notifyOutingParticipants(
  input: NotifyInput,
  tx?: Prisma.TransactionClient,
): Promise<void> {
  const write = async (db: Prisma.TransactionClient) => {
    const recipients = [
      ...new Set(
    input.userIds ?? (await listEligibleVoterIds(input.outing, db)),
  ),
    ].filter((id) => id !== input.excludeUserId);
    await persistNotifications(db, {
      recipients,
      eventKey: input.eventKey,
      eventType: input.eventType,
    type: input.type,
          title: input.outing.title,
      body: input.body,
      actionRequired: input.actionRequired,
      outingId: input.outing.id,
      groupId: input.outing.group_id,
      data: input.data,
      });
    return recipients;
  };
  const recipients = tx ? await write(tx) : await prisma.$transaction(write);
  if (!tx) emitDataChange({ kind: "inbox" }, recipients);
}
