/** How long a pending invitation can be claimed. */
export const GROUP_INVITATION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export function invitationExpiresAt(now = new Date()): Date {
  return new Date(now.getTime() + GROUP_INVITATION_TTL_MS);
}
