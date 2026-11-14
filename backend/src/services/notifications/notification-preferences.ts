import { z } from "zod";

export const notificationPreferencesSchema = z.object({
  pushEnabled: z.boolean(),
  chatMessages: z.boolean(),
  mentions: z.boolean(),
  mentionPriority: z.boolean(),
  groupEvents: z.boolean(),
  outings: z.boolean(),
  voting: z.boolean(),
  reminders: z.boolean(),
  attendance: z.boolean(),
  lockScreenPreview: z.boolean(),
});
export const defaultNotificationPreferences = {
  pushEnabled: true,
  chatMessages: true,
  mentions: true,
  mentionPriority: true,
  groupEvents: true,
  outings: true,
  voting: true,
  reminders: true,
  attendance: true,
  lockScreenPreview: false,
};
export function notificationPreferences(raw: unknown) {
  return notificationPreferencesSchema.parse({
    ...defaultNotificationPreferences,
    ...(raw && typeof raw === "object" ? raw : {}),
  });
}
