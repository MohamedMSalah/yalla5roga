import { prisma } from "../../config/database.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { ValidationError } from "../../utils/errors.js";

// Inline tokens survive REST, Socket.IO, pagination and the existing offline queue.
// Both components are URI encoded; display names are canonicalized from Neon.
const tokenPattern = /<@([^|<>]+)\|([^<>]*)>/g;

/** Chat also permits pending outing guests; voting eligibility is separate. */
export async function chatParticipantIds(outing: Outing): Promise<string[]> {
  const rows = await prisma.$queryRaw<{ user_id: string }[]>`
    SELECT ${outing.created_by}::varchar AS user_id
    UNION SELECT user_id FROM outing_guests
      WHERE outing_id = ${outing.id}::uuid AND status IN ('pending', 'accepted')
    UNION SELECT user_id FROM group_members WHERE group_id = ${outing.group_id}::uuid
  `;
  return rows.map(row => row.user_id);
}

export function mentionedUserIds(text: string): string[] {
  try {
    return [...new Set([...text.matchAll(tokenPattern)].map(m => decodeURIComponent(m[1]!)))];
  } catch {
    throw new ValidationError("Invalid mention encoding");
  }
}

export async function canonicalizeMentions(text: string, outing: Outing): Promise<string> {
  const ids = mentionedUserIds(text);
  if (!ids.length) return text;
  if (ids.length > 50) throw new ValidationError("Too many mentions");
  const participants = new Set(await chatParticipantIds(outing));
  if (ids.some(id => !participants.has(id))) {
    throw new ValidationError("Mentions must reference current outing members");
  }
  const users = await prisma.users.findMany({
    where: { id: { in: ids } }, select: { id: true, name: true },
  });
  const names = new Map(users.map(u => [u.id, u.name]));
  if (names.size !== ids.length) throw new ValidationError("Mentioned user not found");
  const result = text.replace(tokenPattern, (_, id: string) =>
    `<@${encodeURIComponent(decodeURIComponent(id))}|${encodeURIComponent(names.get(decodeURIComponent(id))!)}>`);
  if (result.length > 2000) throw new ValidationError("Message with mentions exceeds 2000 characters");
  return result;
}
