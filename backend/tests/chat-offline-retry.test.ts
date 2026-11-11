import assert from "node:assert/strict";
import test from "node:test";
import { prisma } from "../src/config/database.js";
import type { IChatRepository } from "../src/repositories/chat/i-chat.repository.js";
import { SendMessageUseCase } from "../src/usecases/chat/send-message.usecase.js";
import { ConflictError, ForbiddenError } from "../src/utils/errors.js";

const input = {
  outing_id: "outing", sender_id: "alice", text: "hello", client_message_id: "uuid",
};
const committed = { ...input, id: "canonical", sent_at: new Date() };

test("lost acknowledgment after closure returns the committed message without a new write", async (t) => {
  const findOuting = prisma.outings.findUnique;
  const query = prisma.$queryRaw;
  prisma.outings.findUnique = (async () => ({
    id: input.outing_id, title: "Test", created_by: "alice", group_id: null,
  })) as unknown as typeof findOuting;
  prisma.$queryRaw = (async () => [{ user_id: "alice" }]) as typeof query;
  t.after(() => { prisma.outings.findUnique = findOuting; prisma.$queryRaw = query; });
  let lookups = 0;
  const repository = {
    async findMessageByClientId(outing: string, sender: string, key: string) {
      assert.deepEqual([outing, sender, key], ["outing", "alice", "uuid"]);
      lookups++;
      return committed;
    },
    async createMessage() { assert.fail("must not create another message"); },
  } as unknown as IChatRepository;
  const send = new SendMessageUseCase(repository, async () => { throw new ConflictError("CHAT_CLOSED"); });
  assert.equal(await send.execute(input), committed);
  assert.equal(lookups, 1);
});

test("an uncommitted closed-chat send remains a permanent conflict", async () => {
  const repository = {
    async findMessageByClientId() { return null; },
    async createMessage() { assert.fail("must not reopen chat"); },
  } as unknown as IChatRepository;
  const send = new SendMessageUseCase(repository, async () => { throw new ConflictError("CHAT_CLOSED"); });
  await assert.rejects(send.execute(input), ConflictError);
});

test("revoked membership cannot use deduplication to bypass authorization", async () => {
  const repository = {
    async findMessageByClientId() { assert.fail("must authorize before reading a committed message"); },
  } as unknown as IChatRepository;
  const send = new SendMessageUseCase(repository, async () => { throw new ForbiddenError("NOT_A_PARTICIPANT"); });
  await assert.rejects(send.execute(input), ForbiddenError);
});
