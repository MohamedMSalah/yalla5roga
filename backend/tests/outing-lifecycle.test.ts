import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import test from "node:test";
import { PrismaClient } from "@prisma/client";
import { CreateOutingUseCase } from "../src/usecases/outings/create-outing.usecase.js";
import { UpsertAttendanceUseCase } from "../src/usecases/outings/attendance.usecase.js";
import { UpdateOutingUseCase } from "../src/usecases/outings/update-outing.usecase.js";
import {
  CastVoteUseCase,
  ReplaceBallotUseCase,
  CreateVoteOptionUseCase,
  TieBreakUseCase,
} from "../src/usecases/outings/voting.usecase.js";
import { closeVotingByDeadline } from "../src/services/outings/vote-resolution.js";
import { ForbiddenError } from "../src/utils/errors.js";

const prisma = new PrismaClient();

async function seedUser(suffix: string) {
  const id = `test_${suffix}_${randomUUID().slice(0, 8)}`;
  await prisma.users.create({
    data: {
      id,
      name: suffix.slice(0, 30),
      phone: `+2010${randomInt(10000000, 99999999)}`,
    },
  });
  return id;
}

async function cleanup(userIds: string[], outingIds: string[], groupIds: string[]) {
  for (const outingId of outingIds) {
    await prisma.outings.deleteMany({ where: { id: outingId } });
  }
  for (const groupId of groupIds) {
    await prisma.groups.deleteMany({ where: { id: groupId } });
  }
  for (const userId of userIds) {
    await prisma.users.deleteMany({ where: { id: userId } });
  }
}

test("outing lifecycle: create, vote upsert, unique winner, attendance independent", async () => {
  const owner = await seedUser("owner");
  const member = await seedUser("member");
  const outingIds: string[] = [];
  const groupIds: string[] = [];
  const userIds = [owner, member];

  try {
    const group = await prisma.groups.create({
      data: {
        name: "Test Group",
        created_by: owner,
        group_members: {
          create: [
            { user_id: owner, role: "owner" },
            { user_id: member, role: "member" },
          ],
        },
      },
    });
    groupIds.push(group.id);

    const create = new CreateOutingUseCase();
    const outing = await create.execute({
      title: "Friday Hang",
      created_by: owner,
      group_id: group.id,
      vote_deadline_hours: 2,
    });
    outingIds.push(outing.id);

    assert.equal(outing.status, "draft");
    assert.equal(outing.type, "group");

    const attendance = await prisma.outing_attendance.findUnique({
      where: {
        outing_id_user_id: { outing_id: outing.id, user_id: owner },
      },
    });
    assert.equal(attendance?.status, "going");

    const options = new CreateVoteOptionUseCase();
    const a = await options.execute(owner, {
      outing_id: outing.id,
      label: "Cafe A",
      sort_order: 0,
    });
    const b = await options.execute(owner, {
      outing_id: outing.id,
      label: "Cafe B",
      sort_order: 1,
    });

    await assert.rejects(
      () =>
        options.execute(member, {
          outing_id: outing.id,
          label: "Hacker Cafe",
        }),
      ForbiddenError,
    );

    const cast = new CastVoteUseCase();
    await cast.execute(outing.id, owner, a.id);

    await assert.rejects(
      () => new UpdateOutingUseCase().execute(outing.id, owner, { status: "confirmed" }),
      /venue confirmation endpoint/,
    );

    // Change vote before every eligible voter has participated (keeps poll open).
    await new ReplaceBallotUseCase().execute(outing.id, owner, [b.id]);
    const ownerVote = await prisma.outing_votes.findUnique({
      where: {
        outing_id_user_id_option_id: { outing_id: outing.id, user_id: owner, option_id: b.id },
      },
    });
    assert.equal(ownerVote?.option_id, b.id);
    assert.equal(
      await prisma.outing_votes.count({ where: { outing_id: outing.id } }),
      1,
    );

    await cast.execute(outing.id, member, a.id);
    const votes = await prisma.outing_votes.findMany({
      where: { outing_id: outing.id },
    });
    assert.equal(votes.length, 2);

    // Attendance maybe does not create votes.
    const upsertAttendance = new UpsertAttendanceUseCase();
    await upsertAttendance.execute(outing.id, member, "maybe");
    const voteCount = await prisma.outing_votes.count({
      where: { outing_id: outing.id },
    });
    assert.equal(voteCount, 2);

    // Owner + member voted → early close; currently tied so stay voting locked.
    // Cast owner to B as well for unique winner path in a fresh outing below.
  } finally {
    await cleanup(userIds, outingIds, groupIds);
  }
});

test("unique winner confirms; tie-break selects server winner; member rejected", async () => {
  const owner = await seedUser("own2");
  const m1 = await seedUser("m1");
  const m2 = await seedUser("m2");
  const outingIds: string[] = [];
  const groupIds: string[] = [];
  const userIds = [owner, m1, m2];

  try {
    const group = await prisma.groups.create({
      data: {
        name: "Vote Group",
        created_by: owner,
        group_members: {
          create: [
            { user_id: owner, role: "owner" },
            { user_id: m1, role: "member" },
            { user_id: m2, role: "member" },
          ],
        },
      },
    });
    groupIds.push(group.id);

    const create = new CreateOutingUseCase();
    const outing = await create.execute({
      title: "Unique Win",
      created_by: owner,
      group_id: group.id,
      vote_deadline_hours: 2,
    });
    outingIds.push(outing.id);

    const options = new CreateVoteOptionUseCase();
    const a = await options.execute(owner, {
      outing_id: outing.id,
      label: "Place A",
    });
    const b = await options.execute(owner, {
      outing_id: outing.id,
      label: "Place B",
    });

    const cast = new CastVoteUseCase();
    await cast.execute(outing.id, owner, a.id);
    await cast.execute(outing.id, m1, a.id);
    const result = await cast.execute(outing.id, m2, a.id);

    assert.equal(result.resolution?.outcome, "confirmed");
    const confirmed = await prisma.outings.findUnique({ where: { id: outing.id } });
    assert.equal(confirmed?.status, "confirmed");
    assert.equal(confirmed?.winning_option_id, a.id);

    // Tie outing
    const tied = await create.execute({
      title: "Tie Event",
      created_by: owner,
      group_id: group.id,
      vote_deadline_hours: 2,
    });
    outingIds.push(tied.id);
    const t1 = await options.execute(owner, {
      outing_id: tied.id,
      label: "X",
    });
    const t2 = await options.execute(owner, {
      outing_id: tied.id,
      label: "Y",
    });
    await cast.execute(tied.id, owner, t1.id);
    await cast.execute(tied.id, m1, t2.id);
    // Force close by deadline path after setting vote_ends_at in past
    await prisma.outings.update({
      where: { id: tied.id },
      data: { vote_ends_at: new Date(Date.now() - 1000), status: "voting" },
    });
    const closed = await closeVotingByDeadline(tied.id);
    assert.equal(closed?.outcome, "tie");

    await assert.rejects(
      () => new TieBreakUseCase().execute(tied.id, m1),
      ForbiddenError,
    );

    const broken = await new TieBreakUseCase().execute(tied.id, owner);
    assert.equal(broken.outcome, "confirmed");
    assert.ok(broken.winningOptionId === t1.id || broken.winningOptionId === t2.id);

    const again = await new TieBreakUseCase().execute(tied.id, owner);
    assert.equal(again.winningOptionId, broken.winningOptionId);

    // Zero votes cancel
    const empty = await create.execute({
      title: "No Votes",
      created_by: owner,
      group_id: group.id,
      vote_deadline_hours: 2,
    });
    outingIds.push(empty.id);
    await options.execute(owner, { outing_id: empty.id, label: "Z" });
    await prisma.outings.update({
      where: { id: empty.id },
      data: { vote_ends_at: new Date(Date.now() - 1000), status: "voting" },
    });
    const cancelled = await closeVotingByDeadline(empty.id);
    assert.equal(cancelled?.outcome, "cancelled");
    const row = await prisma.outings.findUnique({ where: { id: empty.id } });
    assert.equal(row?.status, "cancelled");
  } finally {
    await cleanup(userIds, outingIds, groupIds);
  }
});

test("special event create and chat statuses remain open in draft", async () => {
  const owner = await seedUser("spec");
  try {
    const outing = await new CreateOutingUseCase().execute({
      title: "Birthday",
      created_by: owner,
      occasion: "birthday",
      vote_deadline_hours: 24,
    });
    assert.equal(outing.type, "special_event");
    assert.equal(outing.status, "draft");

    const message = await prisma.chat_messages.create({
      data: {
        outing_id: outing.id,
        sender_id: owner,
        text: "hello draft chat",
      },
    });
    assert.ok(message.id);

    await prisma.outings.delete({ where: { id: outing.id } });
  } finally {
    await prisma.users.deleteMany({ where: { id: owner } });
    await prisma.$disconnect();
  }
});
