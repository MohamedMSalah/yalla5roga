import { getMessaging } from "firebase-admin/messaging";
import { prisma } from "../../../config/database.js";
import { initFirebase } from "../../../config/firebase.js";
import type {
  ChannelSendInput,
  ChannelSendResult,
  NotificationChannelSender,
} from "./notification-channel.js";

/**
 * FCM push channel. Requires Firebase Admin credentials in the environment.
 * Invalid / unregistered tokens are deleted from user_fcm_tokens.
 */
export class PushChannel implements NotificationChannelSender {
  readonly channel = "push" as const;

  async send(input: ChannelSendInput): Promise<ChannelSendResult> {
    if (!input.recipientUserId) {
      return {
        provider: "fcm",
        status: "failed",
        error: "Missing recipient_user_id for push delivery",
      };
    }

    const tokens = await prisma.user_fcm_tokens.findMany({
      where: { user_id: input.recipientUserId },
      select: { token: true },
    });

    if (tokens.length === 0) {
      // No device registered — treat as sent so outbox does not infinite-retry.
      return {
        provider: "fcm",
        providerMessageId: `no-token-${input.eventId}`,
        status: "sent",
        response: { skipped: true, reason: "no_device_tokens" },
      };
    }

    try {
      initFirebase();
    } catch (error) {
      return {
        provider: "fcm",
        status: "failed",
        error:
          error instanceof Error
            ? error.message
            : "Firebase Admin not configured for FCM",
      };
    }

    const payload = input.payload as Record<string, unknown>;
    const title =
      typeof payload.title === "string" && payload.title.trim()
        ? payload.title
        : "Yalla 5roga";
    const body =
      typeof payload.body === "string"
        ? payload.body
        : "You have a new notification";

    const data: Record<string, string> = {};
    for (const [key, value] of Object.entries(payload)) {
      if (value == null) continue;
      data[key] = typeof value === "string" ? value : String(value);
    }

    const messaging = getMessaging();
    const response = await messaging.sendEachForMulticast({
      tokens: tokens.map((row) => row.token),
      notification: { title, body },
      data,
    });

    const invalidTokens: string[] = [];
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error?.code ?? "";
      if (
        code.includes("registration-token-not-registered") ||
        code.includes("invalid-registration-token") ||
        code.includes("invalid-argument")
      ) {
        const token = tokens[index]?.token;
        if (token) invalidTokens.push(token);
      }
    });

    if (invalidTokens.length > 0) {
      await prisma.user_fcm_tokens.deleteMany({
        where: { token: { in: invalidTokens } },
      });
    }

    const anySuccess = response.successCount > 0;
    const onlyInvalid =
      !anySuccess && invalidTokens.length === tokens.length;

    if (anySuccess || onlyInvalid) {
      return {
        provider: "fcm",
        providerMessageId: `fcm-${input.eventId}`,
        status: "sent",
        response: {
          successCount: response.successCount,
          failureCount: response.failureCount,
          invalidTokens,
        },
        invalidTokens,
      };
    }

    return {
      provider: "fcm",
      status: "failed",
      error: `FCM send failed (${response.failureCount} failures)`,
      response: {
        successCount: response.successCount,
        failureCount: response.failureCount,
      },
      invalidTokens,
    };
  }
}
