import type { chat_messages, chat_reads } from "@prisma/client";

export type ChatMessage = chat_messages & { sender?: string; avatar?: string | null };
export type ChatHistoryPage = { limit: number; before?: string };
export type ChatRead = chat_reads;

export type CreateChatMessageInput = {
  outing_id: string;
  sender_id: string;
  text: string;
  /** Client-generated UUID that makes a retried send idempotent. */
  client_message_id?: string | null;
};

export type UpsertChatReadInput = {
  outing_id: string;
  user_id: string;
  last_read_at?: Date;
};
