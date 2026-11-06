import { getNotificationConfig } from "../../../config/notifications.js";
import type {
  ChannelSendInput,
  ChannelSendResult,
  NotificationChannelSender,
} from "./notification-channel.js";

type MetaMessageResponse = {
  messages?: Array<{ id?: string }>;
  error?: { message?: string; code?: number };
};

/**
 * Primary notification channel for non-user group invites.
 * Uses Meta WhatsApp Cloud API when configured; otherwise a stub so the
 * outbox worker can still complete the pipeline in local/dev.
 */
export class WhatsAppChannel implements NotificationChannelSender {
  readonly channel = "whatsapp" as const;

  constructor(
    private readonly config = getNotificationConfig(),
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async send(input: ChannelSendInput): Promise<ChannelSendResult> {
    if (!input.recipientPhone) {
      return {
        provider: this.config.whatsapp.provider,
        status: "failed",
        error: "Missing recipient phone for WhatsApp delivery",
      };
    }

    if (this.config.whatsapp.provider === "meta") {
      return this.sendViaMeta(input);
    }

    const payload = input.payload as {
      body?: string;
      deepLink?: string;
    };
    return {
      provider: "stub",
      providerMessageId: `stub-${input.eventId}`,
      status: "sent",
      response: {
        mode: "stub",
        to: input.recipientPhone,
        body: payload.body,
        deepLink: payload.deepLink,
      },
    };
  }

  private async sendViaMeta(
    input: ChannelSendInput,
  ): Promise<ChannelSendResult> {
    const { accessToken, phoneNumberId, apiVersion, templateName, templateLanguage } =
      this.config.whatsapp;

    if (!accessToken || !phoneNumberId) {
      return {
        provider: "meta",
        status: "failed",
        error:
          "WHATSAPP_ACCESS_TOKEN and WHATSAPP_PHONE_NUMBER_ID are required for meta provider",
      };
    }

    const to = input.recipientPhone!.replace(/^\+/, "");
    const url = `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`;

    const body = {
      messaging_product: "whatsapp",
      to,
      type: "template",
      template: {
        name: templateName,
        language: { code: templateLanguage },
        components: [
          {
            type: "body",
            parameters: [
              { type: "text", text: input.payload.inviterName || "A friend" },
              { type: "text", text: input.payload.groupName || "a group" },
              { type: "text", text: input.payload.deepLink },
            ],
          },
        ],
      },
    };

    try {
      const response = await this.fetchImpl(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });

      const json = (await response.json()) as MetaMessageResponse;
      if (!response.ok) {
        return {
          provider: "meta",
          status: "failed",
          response: json,
          error:
            json.error?.message ??
            `WhatsApp Cloud API HTTP ${response.status}`,
        };
      }

      return {
        provider: "meta",
        providerMessageId: json.messages?.[0]?.id,
        status: "sent",
        response: json,
      };
    } catch (error) {
      return {
        provider: "meta",
        status: "failed",
        error: error instanceof Error ? error.message : "WhatsApp send failed",
      };
    }
  }
}
