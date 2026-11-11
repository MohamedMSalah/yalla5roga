import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import test from "node:test";
import { PrismaClient } from "@prisma/client";
import { CreateOutingUseCase } from "../src/usecases/outings/create-outing.usecase.js";
import {
  CastVoteUseCase,
  CreateVoteOptionUseCase,
  ReplaceVoteOptionsUseCase,
  TieBreakUseCase,
} from "../src/usecases/outings/voting.usecase.js";
import { closeVotingByDeadline } from "../src/services/outings/vote-resolution.js";

const prisma = new PrismaClient();

async function seedUser(suffix: string) {
  const id = `conc_${suffix}_${randomUUID().slice(0, 8)}`;
  await prisma.users.create({
    data: { id, name: suffix.slice(0, 30), phone: `+2011${randomInt(10000000, 99999999)}` },
  });
  return id;
}

test("concurrent votes upsert to one row per user", async () => {
  const owner = await seedUser("owner");
  const voter = await seedUser("voter");
  let outingId = "";
  let groupId = "";

  try {
    const group = await prisma.groups.create({
      data: {
        name: "Conc Group",
        created_by: owner,
        group_members: {
          create: [
            { user_id: owner, role: "owner" },
            { user_id: voter, role: "member" },
          ],
        },
      },
    });
    groupId = group.id;

    const outing = await new CreateOutingUseCase().execute({
      title: "Race Vote",
      created_by: owner,
      group_id: group.id,
      vote_deadline_hours: 6,
    });
    outingId = outing.id;

    const options = new CreateVoteOptionUseCase();
    const a = await options.execute(owner, {
      outing_id: outing.id,
      label: "A",
    });
    const b = await options.execute(owner, {
      outing_id: outing.id,
      label: "B",
    });

    const cast = new CastVoteUseCase();
    await Promise.all([
      cast.execute(outing.id, voter, a.id),
      cast.execute(outing.id, voter, b.id),
      cast.execute(outing.id, voter, a.id),
    ]);

    const votes = await prisma.outing_votes.findMany({
      where: { outing_id: outing.id, user_id: voter },
    });
    assert.equal(votes.length, 1);
  } finally {
    if (outingId) await prisma.outings.deleteMany({ where: { id: outingId } });
    if (groupId) await prisma.groups.deleteMany({ where: { id: groupId } });
    await prisma.users.deleteMany({ where: { id: { in: [owner, voter] } } });
  }
});

test("parallel deadline close and dual tie-break are idempotent", async () => {
  const owner = await seedUser("own");
  const m1 = await seedUser("m1");
  const m2 = await seedUser("m2");
  let outingId = "";
  let groupId = "";

  try {
    const group = await prisma.groups.create({
      data: {
        name: "Tie Conc",
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
    groupId = group.id;

    const outing = await new CreateOutingUseCase().execute({
      title: "Tie Race",
      created_by: owner,
      group_id: group.id,
      vote_deadline_hours: 6,
    });
    outingId = outing.id;

    const options = new CreateVoteOptionUseCase();
    const a = await options.execute(owner, {
      outing_id: outing.id,
      label: "A",
    });
    const b = await options.execute(owner, {
      outing_id: outing.id,
      label: "B",
    });

    const cast = new CastVoteUseCase();
    await cast.execute(outing.id, owner, a.id);
    await cast.execute(outing.id, m1, b.id);

    await prisma.outings.update({
      where: { id: outing.id },
      data: { vote_ends_at: new Date(Date.now() - 1000), status: "voting" },
    });

    const [c1, c2] = await Promise.all([
      closeVotingByDeadline(outing.id),
      closeVotingByDeadline(outing.id),
    ]);
    const closed = c1 ?? c2;
    assert.ok(closed);
    assert.equal(closed.outcome, "tie");

    const [t1, t2] = await Promise.all([
      new TieBreakUseCase().execute(outing.id, owner),
      new TieBreakUseCase().execute(outing.id, owner),
    ]);
    assert.equal(t1.winningOptionId, t2.winningOptionId);
    assert.equal(t1.outcome, "confirmed");
  } finally {
    if (outingId) await prisma.outings.deleteMany({ where: { id: outingId } });
    if (groupId) await prisma.groups.deleteMany({ where: { id: groupId } });
    await prisma.users.deleteMany({
      where: { id: { in: [owner, m1, m2] } },
    });
    await prisma.$disconnect();
  }
});

test("replace vote options clears prior votes atomically", async () => {
  const owner = await seedUser("rep");
  const voter = await seedUser("vot");
  let outingId = "";
  let groupId = "";

  try {
    const group = await prisma.groups.create({
      data: {
        name: "Replace",
        created_by: owner,
        group_members: {
          create: [
            { user_id: owner, role: "owner" },
            { user_id: voter, role: "member" },
          ],
        },
      },
    });
    groupId = group.id;

    const outing = await new CreateOutingUseCase().execute({
      title: "Replace Ops",
      created_by: owner,
      group_id: group.id,
      vote_deadline_hours: 12,
    });
    outingId = outing.id;
    const deadline = outing.vote_ends_at;

    const createOpt = new CreateVoteOptionUseCase();
    const old = await createOpt.execute(owner, {
      outing_id: outing.id,
      label: "Old",
    });
    await new CastVoteUseCase().execute(outing.id, voter, old.id);

    const replaced = await new ReplaceVoteOptionsUseCase().execute(
      outing.id,
      owner,
      [{ label: "New1" }, { label: "New2" }],
    );
    assert.equal(replaced.length, 2);

    const votes = await prisma.outing_votes.count({
      where: { outing_id: outing.id },
    });
    assert.equal(votes, 0);

    const refreshed = await prisma.outings.findUnique({
      where: { id: outing.id },
    });
    assert.equal(
      refreshed?.vote_ends_at?.toISOString(),
      deadline?.toISOString(),
    );
  } finally {
    if (outingId) await prisma.outings.deleteMany({ where: { id: outingId } });
    if (groupId) await prisma.groups.deleteMany({ where: { id: groupId } });
    await prisma.users.deleteMany({ where: { id: { in: [owner, voter] } } });
  }
});
