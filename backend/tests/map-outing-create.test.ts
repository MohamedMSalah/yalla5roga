import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import test from "node:test";
import { PrismaClient } from "@prisma/client";
import { CreateOutingUseCase } from "../src/usecases/outings/create-outing.usecase.js";
import { createOutingBodySchema } from "../src/validators/outings/outing.validator.js";

test("initial candidates publish atomically and a concurrent replay returns the same outing", async () => {
  const prisma = new PrismaClient();
  const owner = `map-${randomUUID()}`;
  const useCase = new CreateOutingUseCase();
  await prisma.users.create({
    data: { id: owner, name: "Map Test", phone: `+2015${randomInt(10000000, 99999999)}` },
  });
  try {
    const group = await prisma.groups.create({
      data: { name: "Map Test", created_by: owner },
    });
    const catalog = await prisma.places.create({ data: { name: "Catalog Test" } });
    try {
      const body = createOutingBodySchema.parse({
        title: "Map Test",
        group_id: group.id,
        create_request_key: randomUUID(),
        vote_deadline_hours: 3,
        initial_vote_options: [
          { place_id: catalog.id, label: catalog.name, latitude: null, longitude: null, sort_order: 20 },
          { label: "Lobby", latitude: 0, longitude: 0 },
          { label: "Rooftop", latitude: 0, longitude: 0 },
        ],
      });
      const input = { ...body, created_by: owner };
      const [first, replay] = await Promise.all([useCase.execute(input), useCase.execute(input)]);
      assert.equal(first.id, replay.id);
      assert.equal(first.status, "voting");
      const options = await prisma.outing_vote_options.findMany({
        where: { outing_id: first.id },
        orderBy: { sort_order: "asc" },
      });
      assert.deepEqual(options.map((row) => row.label), ["Catalog Test", "Lobby", "Rooftop"]);
      assert.deepEqual(options.map((row) => row.sort_order), [0, 1, 2]);
      assert.equal(options[0]?.place_id, catalog.id);
      assert.equal(options[0]?.latitude, null);
      assert.equal(options[1]?.latitude, 0);
      assert.equal(await prisma.outing_attendance.count({ where: { outing_id: first.id } }), 1);

      await assert.rejects(useCase.execute({
        ...input,
        initial_vote_options: [{ label: " Lobby ", latitude: 0, longitude: 0 },
          { label: "lobby", latitude: 0, longitude: 0 }],
      }), /Duplicate initial option/);

      const brokenKey = randomUUID();
      await assert.rejects(useCase.execute({
        ...input,
        create_request_key: brokenKey,
        initial_vote_options: [{ label: "Valid" }, { label: "Missing", place_id: randomUUID() }],
      }));
      assert.equal(await prisma.outings.count({
        where: { created_by: owner, create_request_key: brokenKey },
      }), 0);
    } finally {
      await prisma.outings.deleteMany({ where: { created_by: owner } });
      await prisma.places.delete({ where: { id: catalog.id } });
      await prisma.groups.delete({ where: { id: group.id } });
    }
  } finally {
    await prisma.users.delete({ where: { id: owner } });
    await prisma.$disconnect();
  }
});
