/**
 * Click-to-chat copy for a group invitation.
 * Replace the download line when the app is published. Do not invent store URLs.
 */
export const invitationStoreLinks = {
  googlePlay: "",
  appStore: "",
} as const;

const DOWNLOAD_LINE_BEFORE_RELEASE =
  "App download links will be available here soon.";

export function buildInvitationMessage(
  links: { googlePlay?: string; appStore?: string } = invitationStoreLinks,
): string {
  const published = [links.googlePlay, links.appStore].filter(
    (link): link is string => Boolean(link),
  );
  const downloadLine =
    published.length > 0 ? published.join("\n") : DOWNLOAD_LINE_BEFORE_RELEASE;

  return [
    "Hey! 👋 You've been invited to join our group on Yalla 5roga!",
    "Yalla 5roga helps us plan outings, discover places, and decide where to go together.",
    "Download the app and create an account using the phone number you were invited with. Once your number is verified, you'll automatically find your group waiting for you!",
    downloadLine,
    "See you there! 🎉",
  ].join("\n");
}

/** Opens WhatsApp with a prefilled message. The inviter still has to send it. */
export function buildWhatsAppClickToChatUrl(
  e164: string,
  message = buildInvitationMessage(),
): string {
  const digits = e164.startsWith("+") ? e164.slice(1) : e164;
  return `https://wa.me/${digits}?text=${encodeURIComponent(message)}`;
}
