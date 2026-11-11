export type WhatsAppProvider = "meta" | "stub";

export type NotificationConfig = {
  deepLinkBaseUrl: string;
  appScheme: string;
  whatsapp: {
    provider: WhatsAppProvider;
    accessToken: string;
    phoneNumberId: string;
    apiVersion: string;
    /** Approved Meta template name for outbound invites. */
    templateName: string;
    templateLanguage: string;
    specialEventTemplateName?: string;
  };
  worker: {
    intervalMs: number;
    batchSize: number;
    maxAttempts: number;
  };
};

function env(name: string, fallback = ""): string {
  return process.env[name]?.trim() || fallback;
}

function envInt(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = Number(raw);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

/**
 * Notification pipeline settings. Meta Cloud API credentials are optional in
 * local/dev. With no provider, WhatsApp delivery is disabled.
 */
export function getNotificationConfig(): NotificationConfig {
  const providerRaw = env("WHATSAPP_PROVIDER", "stub").toLowerCase();
  const provider: WhatsAppProvider =
    providerRaw === "meta" ? "meta" : "stub";

  return {
    deepLinkBaseUrl: env(
      "INVITE_DEEP_LINK_BASE",
      env("APP_DOWNLOAD_URL", "https://yalla5roga.com"),
    ).replace(/\/$/, ""),
    appScheme: env("FLUTTER_APP_SCHEME", "yalla5roga"),
    whatsapp: {
      provider,
      accessToken: env("WHATSAPP_ACCESS_TOKEN"),
      phoneNumberId: env("WHATSAPP_PHONE_NUMBER_ID"),
      apiVersion: env("WHATSAPP_API_VERSION", "v21.0"),
      templateName: env("WHATSAPP_INVITE_TEMPLATE", "group_invite"),
      templateLanguage: env("WHATSAPP_INVITE_TEMPLATE_LANG", "en"),
      specialEventTemplateName: env("WHATSAPP_SPECIAL_EVENT_TEMPLATE", "special_event_invite"),
    },
    worker: {
      intervalMs: envInt("NOTIFICATION_WORKER_INTERVAL_MS", 5_000),
      batchSize: envInt("NOTIFICATION_WORKER_BATCH_SIZE", 20),
      maxAttempts: envInt("NOTIFICATION_MAX_ATTEMPTS", 5),
    },
  };
}

export function hasAutomaticWhatsApp(config = getNotificationConfig()): boolean {
  const { provider, accessToken, phoneNumberId } = config.whatsapp;
  return provider === "meta" && Boolean(accessToken && phoneNumberId);
}
