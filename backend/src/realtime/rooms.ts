/** Canonical Socket.IO room for an outing chat. */
export function outingChatRoom(outingId: string): string {
  return `outing:${outingId}`;
}
