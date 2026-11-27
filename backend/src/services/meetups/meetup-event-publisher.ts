import type { Prisma } from "@prisma/client";
import { getChatIo } from "../../realtime/chat-emitter.js";
import type { NotificationChannelSender, ChannelSendInput, ChannelSendResult } from "../notifications/channels/notification-channel.js";
import { meetupChange, SmartMeetupRealtimeService } from "./smart-meetup-realtime.service.js";

export class MeetupEventPublisher implements NotificationChannelSender {
  readonly channel = "realtime";
  constructor(private readonly realtime = new SmartMeetupRealtimeService()) {}

  async enqueuePreferencesChanged(tx: Prisma.TransactionClient, sessionId: string, inputVersion: number) {
    await tx.$executeRaw`SELECT enqueue_meetup_change(${sessionId}::uuid, ${inputVersion}::integer, 'PREFERENCES_CHANGED')`;
  }

  async send({ payload }: ChannelSendInput): Promise<ChannelSendResult> {
    const provider = "socket.io";
    const parsed = meetupChange.safeParse(payload);
    if (!parsed.success) return { provider, status: "failed", error: "Invalid Meetup event metadata", retryable: false };
    const io = getChatIo();
    if (!io) return { provider, status: "failed", error: "Shared socket is unavailable" };
    await this.realtime.deliver(io, parsed.data);
    return { provider, status: "sent" };
  }
}
