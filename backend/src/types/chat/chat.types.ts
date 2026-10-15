import type {
  chat_messages,
  chat_reads,
  message_delivery_status,
} from "@prisma/client";

export type ChatMessage = chat_messages;
export type ChatRead = chat_reads;
export type MessageDeliveryStatus = message_delivery_status;

export type CreateChatMessageInput = {
  outing_id: string;
  sender_id: string;
  text: string;
  delivery_status?: MessageDeliveryStatus;
};

export type UpsertChatReadInput = {
  outing_id: string;
  user_id: string;
  last_read_at?: Date;
};
