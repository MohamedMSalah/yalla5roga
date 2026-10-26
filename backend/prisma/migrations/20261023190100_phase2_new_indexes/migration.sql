-- Phase 2.3 (first half) of yalla-5roga-schema-review.md: create the
-- replacement indexes only. The old indexes idx_group_invitations_phone,
-- idx_group_invitations_status and idx_chat_messages_outing_sent are kept;
-- dropping them is a separate, later migration after the new ones are in use.

-- Expiry job only looks at pending rows (partial; Prisma cannot model it).
CREATE INDEX IF NOT EXISTS idx_group_invitations_pending_expiry
  ON group_invitations (expires_at) WHERE status = 'pending';

-- Stable keyset paging for chat: id breaks ties on equal sent_at.
CREATE INDEX IF NOT EXISTS idx_chat_messages_outing_sent_id
  ON chat_messages (outing_id, sent_at DESC, id DESC);
