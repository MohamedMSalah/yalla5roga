export const userRealtimeRoom = (userId: string) => `user:${userId}`;
export const groupRealtimeRoom = (groupId: string) => `group:${groupId}`;
export const meetupRealtimeRoom = (sessionId: string) => `meetup:${sessionId}`;

/** Canonical Socket.IO room for an outing chat. */
export function outingChatRoom(outingId: string): string {
  return `outing:${outingId}`;
}
