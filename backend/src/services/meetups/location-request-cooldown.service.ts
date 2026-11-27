import type { Prisma } from "@prisma/client";

const dayMs = 86_400_000;

function positiveInteger(name: string, fallback: number, max: number) {
  const value = Number(process.env[name]);
  return Number.isSafeInteger(value) && value > 0 && value <= max ? value : fallback;
}

export class LocationRequestCooldownService {
  private readonly cooldownMs = positiveInteger("LOCATION_REQUEST_COOLDOWN_MINUTES", 360, 1440) * 60_000;
  private readonly dailyLimit = positiveInteger("LOCATION_REQUEST_DAILY_LIMIT", 5, 100);

  /** The sender and recipient user locks must be held before reading the outbox. */
  async retryAt(tx: Prisma.TransactionClient, sender: string, target: string, now: Date) {
    const [received, sent] = await Promise.all([
      tx.$queryRaw<{ created_at: Date }[]>`
        SELECT created_at FROM notification_events
        WHERE payload->>'notificationType' = 'meetup_location_requested' AND recipient_user_id = ${target}
          AND created_at > ${new Date(now.getTime() - this.cooldownMs)}
        ORDER BY created_at DESC LIMIT 1
      `,
      tx.$queryRaw<{ created_at: Date }[]>`
        SELECT created_at FROM notification_events
        WHERE payload->>'notificationType' = 'meetup_location_requested' AND payload->>'requesterId' = ${sender}
          AND created_at > ${new Date(now.getTime() - dayMs)}
        ORDER BY created_at DESC OFFSET ${this.dailyLimit - 1} LIMIT 1
      `,
    ]);
    const next = Math.max(
      received[0] ? received[0].created_at.getTime() + this.cooldownMs : 0,
      sent[0] ? sent[0].created_at.getTime() + dayMs : 0,
    );
    return next > now.getTime() ? new Date(next) : null;
  }
}
