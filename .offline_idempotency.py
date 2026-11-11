exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
edit('backend/src/datasources/chat/chat.datasource.ts',
 ('  findMessagesByOutingId(', '''  async findMessageByClientId(
    outingId: string, senderId: string, clientMessageId: string,
  ): Promise<ChatMessage | null> {
    const message = await prisma.chat_messages.findUnique({
      where: {
        outing_id_sender_id_client_message_id: {
          outing_id: outingId, sender_id: senderId, client_message_id: clientMessageId,
        },
      },
      include: senderProfile,
    });
    return message ? withSender(message) : null;
  }

  findMessagesByOutingId('''),
 ('''      const existing = await prisma.chat_messages.findFirst({
        include: senderProfile,
        where: {
          outing_id: data.outing_id,
          sender_id: data.sender_id,
          client_message_id: data.client_message_id,
        },
      });
      if (!existing) throw error;
      return withSender(existing);''','''      const existing = await this.findMessageByClientId(
        data.outing_id, data.sender_id, data.client_message_id,
      );
      if (!existing) throw error;
      return existing;'''))
edit('backend/src/repositories/chat/i-chat.repository.ts',
 ('  findMessageById', '  findMessageByClientId(outingId: string, senderId: string, clientMessageId: string): Promise<ChatMessage | null>;\n  findMessageById'))
edit('backend/src/repositories/chat/chat.repository.ts',
 ('  findMessageById', '''  findMessageByClientId(outingId: string, senderId: string, clientMessageId: string): Promise<ChatMessage | null> {
    return this.datasource.findMessageByClientId(outingId, senderId, clientMessageId);
  }

  findMessageById'''))
edit('backend/src/usecases/chat/send-message.usecase.ts',
 ('import { NotFoundError, ValidationError }', 'import { ConflictError, NotFoundError, ValidationError }'),
 ('    await this.guard(input.outing_id, input.sender_id);','''    try {
      await this.guard(input.outing_id, input.sender_id);
    } catch (error) {
      // The close check follows the participant check. A retry can acknowledge
      // a previously committed write without reopening the chat.
      if (error instanceof ConflictError && input.client_message_id) {
        const existing = await this.chat.findMessageByClientId(
          input.outing_id, input.sender_id, input.client_message_id,
        );
        if (existing) return existing;
      }
      throw error;
    }'''))
