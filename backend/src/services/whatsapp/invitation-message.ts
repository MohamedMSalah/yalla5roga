/**
 * Invitation copy for WhatsApp (server-sent or click-to-chat fallback).
 * Prefer store URLs when published; otherwise use `downloadUrl` (APP_DOWNLOAD_URL).
 */
export const invitationStoreLinks = {
  googlePlay: "",
  appStore: "",
} as const;

const DOWNLOAD_LINE_BEFORE_RELEASE =
  "App download links will be available here soon.";

export type InvitationMessageInput = {
  groupName?: string;
  inviterName?: string;
  deepLink?: string;
  /** Landing / store page when Play/App Store URLs are not set yet. */
  downloadUrl?: string;
  googlePlay?: string;
  appStore?: string;
};

export function buildInvitationMessage(
  input: InvitationMessageInput = {},
): string {
  const links = {
    googlePlay: input.googlePlay ?? invitationStoreLinks.googlePlay,
    appStore: input.appStore ?? invitationStoreLinks.appStore,
  };
  const published = [links.googlePlay, links.appStore].filter(
    (link): link is string => Boolean(link),
  );
  const downloadUrl = input.downloadUrl?.trim() ?? "";
  const downloadLine =
    published.length > 0
      ? published.join("\n")
      : downloadUrl
        ? `Download the app:\n${downloadUrl}`
        : DOWNLOAD_LINE_BEFORE_RELEASE;

  const groupLine = input.groupName
    ? `You've been invited to join "${input.groupName}" on Yalla 5roga!`
    : "Hey! You've been invited to join our group on Yalla 5roga!";

  const inviterLine = input.inviterName
    ? `${input.inviterName} wants you in the group.`
    : null;

  const deepLinkLine = input.deepLink
    ? `Open your invite here:\n${input.deepLink}`
    : null;

  return [
    groupLine,
    inviterLine,
    "Yalla 5roga helps us plan outings, discover places, and decide where to go together.",
    "Download the app and create an account using the phone number you were invited with. Once your number is verified, you'll automatically find your group waiting for you!",
    deepLinkLine,
    downloadLine,
    "See you there!",
  ]
    .filter((line): line is string => Boolean(line))
    .join("\n");
}

/** Opens WhatsApp with a prefilled message. The inviter still has to send it. */
export function buildWhatsAppClickToChatUrl(
  e164: string,
  message = buildInvitationMessage(),
): string {
  const digits = e164.startsWith("+") ? e164.slice(1) : e164;
  return `https://wa.me/${digits}?text=${encodeURIComponent(message)}`;
}
