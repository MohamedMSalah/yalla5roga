import type { Prisma } from "@prisma/client";
import { StartingLocationOverrideRepository } from "../users/starting-location-override.repository.js";

export type DepartureReminderPreferencePatch = { enabled?: boolean; preparation_buffer_minutes?: number };
const defaults = { enabled: false, preparation_buffer_minutes: 10, updated_at: null };
const preferenceFields = { enabled: true, preparation_buffer_minutes: true, updated_at: true } as const;

export class DepartureReminderRepository {
  constructor(private readonly transactions = new StartingLocationOverrideRepository()) {}

  transaction<T>(fn: (tx: Prisma.TransactionClient) => Promise<T>) {
    return this.transactions.transaction(fn, "ReadCommitted");
  }

  async preferences(tx: Prisma.TransactionClient, uid: string) {
    return (await tx.departure_reminder_preferences.findUnique({
      where: { user_id: uid }, select: preferenceFields,
    })) ?? defaults;
  }

  savePreferences(tx: Prisma.TransactionClient, uid: string, patch: DepartureReminderPreferencePatch) {
    return tx.departure_reminder_preferences.upsert({
      where: { user_id: uid }, create: { user_id: uid, ...patch },
      update: patch, select: preferenceFields,
    });
  }

  current(tx: Prisma.TransactionClient, outingId: string, uid: string) {
    return tx.departure_reminders.findUnique({ where: { outing_id_user_id: { outing_id: outingId, user_id: uid } } });
  }

  save(tx: Prisma.TransactionClient, outingId: string, uid: string, values: {
    scheduled_send_at: Date; estimate_reference: string; input_fingerprint: string;
    deduplication_key: string; duration_seconds: number;
  }) {
    return tx.departure_reminders.upsert({
      where: { outing_id_user_id: { outing_id: outingId, user_id: uid } },
      create: { outing_id: outingId, user_id: uid, ...values }, update: values,
    });
  }

  clear(tx: Prisma.TransactionClient, outingId: string, uid: string) {
    return tx.departure_reminders.deleteMany({ where: { outing_id: outingId, user_id: uid, status: "pending" } });
  }
}
