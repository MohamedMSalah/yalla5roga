import { getMessaging } from "firebase-admin/messaging";
import { prisma } from "../../../config/database.js";
import { initFirebase } from "../../../config/firebase.js";
import { controlTypes, resolvePush } from "../resolve-push.js";
import type {
  ChannelSendInput,
  ChannelSendResult,
  NotificationChannelSender,
} from "./notification-channel.js";

export class PushChannel implements NotificationChannelSender {
  readonly channel = "push" as const;
  constructor(
    private readonly messaging = () => {
      initFirebase();
      return getMessaging();
    },
  ) {}

  async send(input: ChannelSendInput): Promise<ChannelSendResult> {
    const uid = input.recipientUserId;
    if (!uid)
      return {
        provider: "fcm",
        status: "failed",
        retryable: false,
        error: "Missing push recipient",
      };
    const skip = (reason: string): ChannelSendResult => ({
      provider: "fcm",
      status: "sent",
      response: { skipped: true, reason },
    });
    const registered = await prisma.user_fcm_tokens.findMany({
      where: { user_id: uid },
    });
    if (!registered.length) return skip("no_device_tokens");
    const payload = await resolvePush(
      uid,
      input.payload as Record<string, unknown>,
      input.inboxEventKey,
    );
    if (!payload) return skip("no_longer_relevant_or_disabled");
    const data: Record<string, string> = {
      eventId: input.eventId,
      pushId: input.eventId,
      recipientUserId: uid,
    };
    for (const [key, value] of Object.entries(payload))
      if (typeof value === "string") data[key] = value;
    data.eventId = input.eventId;
    const type = data.type ?? "system",
      control = controlTypes.has(type);
    const expiry = type === "meetup_location_requested" && data.expiresAt
      ? Date.parse(data.expiresAt) : null;
    if (expiry !== null && expiry <= Date.now()) return skip("location_request_expired");
    data.notificationType = type;
    data.actionType = control ? "update" : "open";
    data.createdAt ??= new Date().toISOString();
    const logs = await prisma.notification_delivery_logs.findMany({
      where: { event_id: input.eventId, channel: "push" },
      select: { response: true },
    });
    const delivered = new Set(
      logs.flatMap((log) => {
        const response = log.response as {
          deliveredTokenIds?: string[];
        } | null;
        return response?.deliveredTokenIds ?? [];
      }),
    );
    const tokens = registered.filter((t) => !delivered.has(t.id));
    if (!tokens.length) return skip("no_pending_device_tokens");
    let messaging;
    try {
      messaging = this.messaging();
    } catch {
      return {
        provider: "fcm",
        status: "failed",
        error: "Firebase Admin unavailable",
      };
    }

    const deliveredTokenIds: string[] = [],
      invalidTokenIds: string[] = [];
    let failures = 0;
    // FCM has a maximum of 500 tokens per multicast. Retry only failed devices.
    const legacyAndroid = tokens.filter(
      (t) => t.platform === "android" && t.notification_version < 2,
    );
    const modern = tokens.filter((t) => !legacyAndroid.includes(t));
    for (const group of [modern, legacyAndroid])
      for (let start = 0; start < group.length; start += 500) {
      const chunk = group.slice(start, start + 500);
        const legacyVisible = group === legacyAndroid && !control;
        try {
          const result = await messaging.sendEachForMulticast({
      tokens: chunk.map((t) => t.token),
            data,
      ...(legacyVisible
              ? {
                  notification: {
                    title:
                      data.lockScreenPreview === "true"
                        ? (data.title ?? "Yalla 5roga")
                        : "Yalla 5roga",
                    body:
                      data.lockScreenPreview === "true"
                        ? (data.body ?? "New notification")
                        : "You have a new notification",
                  },
                }
              : {}),
            // Android owns rendering in all app states, including RemoteInput actions.
            // No top-level notification: otherwise Android bypasses the Dart handler.
            android: {
              priority: "high",
              ttl: expiry !== null ? Math.max(0, expiry - Date.now()) : control ? 3_600_000 : 86_400_000,
            },
            apns: control
              ? {
                  headers: {
                    "apns-push-type": "background",
                    "apns-priority": "5",
                  },
                  payload: { aps: { contentAvailable: true } },
                }
              : {
                  ...(expiry !== null && { headers: { "apns-expiration": String(Math.floor(expiry / 1000)) } }),
                  payload: { aps: {
                      alert: {
                        title: data.title ?? "Yalla 5roga",
                        body: data.body ?? "New notification",
                      },
                      sound: "default",
                      ...(type === "chat_message"
                        ? { category: "outing_chat" } : {}),
                    },
                  },
                },
    });
          for (let index = 0; index < result.responses.length; index++) {
            const token = chunk[index]!,
              response = result.responses[index]!;
            if (response.success) {
              deliveredTokenIds.push(token.id);
              continue;
            }
            const code = response.error?.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
            ) {
              invalidTokenIds.push(token.id);
              await prisma.user_fcm_tokens.deleteMany({
        where: { id: token.id, user_id: uid, token: token.token },
      });
    } else failures++;
          }
        } catch {
          failures += chunk.length;
        }
      }
    return {
        provider: "fcm",
        providerMessageId: `fcm-${input.eventId}`,
        status: failures ? "failed" : "sent",
      error: failures ? "FCM transient or configuration failure" : undefined,
        response: { deliveredTokenIds, invalidTokenIds, retryCount: failures },
    };
  }
}
