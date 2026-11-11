/** Legacy expiry metadata retained for group association records. */
export const GROUP_INVITATION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export function invitationExpiresAt(now = new Date()): Date {
  return new Date(now.getTime() + GROUP_INVITATION_TTL_MS);
}
