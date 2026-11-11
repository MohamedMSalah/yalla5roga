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
 * Uses the configured Meta WhatsApp Cloud API and requires recipient opt-in.
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
      if (input.payload.whatsappOptIn !== true) {
        return { provider: "meta", status: "failed", retryable: false, error: "WhatsApp recipient opt-in is required" };
      }
      return this.sendViaMeta(input);
    }

    return {
      provider: this.config.whatsapp.provider,
      status: "failed",
      retryable: false,
      error: "WhatsApp Business delivery is not configured",
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
        retryable: false,
        error:
          "WHATSAPP_ACCESS_TOKEN and WHATSAPP_PHONE_NUMBER_ID are required for meta provider",
      };
    }

    const to = input.recipientPhone!.replace(/^\+/, "");
    const url = `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`;

    const event = (input.payload as Record<string, unknown>).specialEvent as {
      title: string;
      dateTime: string;
      location: string;
      calendarUrl: string;
      appUrl: string;
    } | undefined;
    const template = event
      ? this.config.whatsapp.specialEventTemplateName ?? "special_event_invite"
      : templateName;
    const values = event
      ? [event.title, event.dateTime, event.location, event.calendarUrl, event.appUrl]
      : [input.payload.inviterName || "A friend", input.payload.groupName || "a group", input.payload.deepLink];
    const body = {
      messaging_product: "whatsapp",
      to,
      type: "template",
      template: {
        name: template,
        language: { code: templateLanguage },
        components: [
          {
            type: "body",
            parameters: values.map((value) => ({
              type: "text",
              text: String(value).replace(/\s+/g, " ").trim(),
            })),
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
        signal: AbortSignal.timeout(15_000),
      });

      const json = (await response.json()) as MetaMessageResponse;
      if (!response.ok) {
        return {
          provider: "meta",
          status: "failed",
          response: json,
          retryable: response.status === 429 || response.status >= 500,
          error:
            json.error?.message ??
            `WhatsApp Cloud API HTTP ${response.status}`,
        };
      }

      const messageId = json.messages?.[0]?.id;
      if (!messageId) {
        return { provider: "meta", status: "failed", retryable: false,
          error: "WhatsApp did not confirm message acceptance" };
      }
      return {
        provider: "meta",
        providerMessageId: messageId,
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
