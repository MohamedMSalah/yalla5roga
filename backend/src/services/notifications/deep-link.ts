import { getNotificationConfig } from "../../config/notifications.js";

export type GroupInviteDeepLinkInput = {
  invitationId: string;
  groupId: string;
};

export type GroupInviteDeepLinks = {
  /** HTTPS link for WhatsApp / Universal Links / App Links. */
  web: string;
  /** Custom scheme for Flutter cold-start when app is installed. */
  app: string;
};

/** Builds the Flutter group-invite deep links included in WhatsApp messages. */
export function buildGroupInviteDeepLinks(
  input: GroupInviteDeepLinkInput,
  config = getNotificationConfig(),
): GroupInviteDeepLinks {
  const query = new URLSearchParams({
    invitationId: input.invitationId,
    groupId: input.groupId,
  });

  return {
    web: `${config.deepLinkBaseUrl}/invite/${input.invitationId}?groupId=${encodeURIComponent(input.groupId)}`,
    app: `${config.appScheme}://invite?${query.toString()}`,
  };
}

/** Prefer the HTTPS link in messages — it works for non-users before install. */
export function primaryInviteDeepLink(
  input: GroupInviteDeepLinkInput,
  config = getNotificationConfig(),
): string {
  return buildGroupInviteDeepLinks(input, config).web;
}
