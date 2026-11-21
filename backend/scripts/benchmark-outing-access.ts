import { isolatedDatabase } from "../tests/support/isolated-database.js";
import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { performance } from "node:perf_hooks";
import { prisma } from "../src/config/database.js";
import { requestContext, type RequestContext } from "../src/monitoring/context.js";
import { hasOutingAccess } from "../src/services/outings/outing-access.js";
import { GetOutingUseCase } from "../src/usecases/outings/get-outing.usecase.js";

if (!isolatedDatabase || process.env.OBSERVABILITY_ENABLED === "0") {
  throw new Error("Configure an isolated PostgreSQL test database and enable instrumentation");
}
const uid = randomUUID();
const owner = randomUUID();
let group: string | undefined;
let outing: string | undefined;
const reads = new GetOutingUseCase();
const samples = 200;

try {
  await prisma.users.createMany({ data: [uid, owner].map((id, i) =>
    ({ id, name: "Benchmark fixture", phone: `+201${i}${randomInt(10000000, 99999999)}` })) });
  group = (await prisma.groups.create({ data: {
    name: "Benchmark fixture", created_by: owner,
    group_members: { create: [{ role: "owner", user_id: owner }, { role: "member", user_id: uid }] },
  } })).id;
  outing = (await prisma.outings.create({ data: { title: "Benchmark fixture", group_id: group, created_by: owner } })).id;
  const id = outing;

  // Mirrors the previous HTTP handler: load the row, check membership and
  // invitation concurrently, then fetch the payload a second time.
  const before = async () => {
    const row = await prisma.outings.findUniqueOrThrow({ where: { id } });
    assert.ok(await hasOutingAccess(row, uid));
    return prisma.outings.findUniqueOrThrow({ where: { id } });
  };
  const after = () => reads.execute(id, uid);
  const measure = async (read: typeof before) => {
    const context: RequestContext = {
      requestId: randomUUID(), active: true, dbCalls: 0, dbMs: 0, dbErrors: 0, dbSlow: 0, dbOperations: new Map(),
    };
    const started = performance.now();
    const row = await requestContext.run(context, read);
    assert.equal(row.id, id);
    return { elapsedMs: performance.now() - started, dbCalls: context.dbCalls, dbMs: context.dbMs };
  };
  const [base, improved] = await Promise.all([before(), after()]);
  assert.deepEqual(improved, base);
  for (let i = 0; i < 25; i++) {
    await measure(before);
    await measure(after);
  }
  const sample = [[], []] as [Awaited<ReturnType<typeof measure>>[], Awaited<ReturnType<typeof measure>>[]];
  for (let i = 0; i < samples; i++) {
    if (i % 2 === 0) {
      sample[0].push(await measure(before));
      sample[1].push(await measure(after));
    } else {
      sample[1].push(await measure(after));
      sample[0].push(await measure(before));
    }
  }
  const rounded = (value: number) => Number(value.toFixed(3));
  console.log(JSON.stringify(sample.map((rows, i) => {
    const sorted = rows.map(row => row.elapsedMs).sort((a, b) => a - b);
    return {
      variant: i === 0 ? "previous access and refetch" : "consolidated",
      samples,
      p50: rounded(sorted[Math.ceil(samples * 0.5) - 1]!),
      p95: rounded(sorted[Math.ceil(samples * 0.95) - 1]!),
      p99: rounded(sorted[Math.ceil(samples * 0.99) - 1]!),
      prismaOperationsPerRead: rows.reduce((sum, row) => sum + row.dbCalls, 0) / samples,
      meanPrismaOperationSumMs: rounded(rows.reduce((sum, row) => sum + row.dbMs, 0) / samples),
    };
  }), null, 2));
} finally {
  if (outing) await prisma.outings.deleteMany({ where: { id: outing } });
  if (group) await prisma.groups.deleteMany({ where: { id: group } });
  await prisma.users.deleteMany({ where: { id: { in: [uid, owner] } } });
  await prisma.$disconnect();
}
