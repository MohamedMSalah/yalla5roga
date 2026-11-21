import { isolatedDatabase } from "../tests/support/isolated-database.js";
import { randomBytes, randomInt, randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { performance } from "node:perf_hooks";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth, type DecodedIdToken } from "firebase-admin/auth";
import { withApi } from "../tests/support/http-fixture.js";

if (!isolatedDatabase) throw new Error("Set YALLA_TEST_DATABASE_URL to the migrated disposable database");
if (process.env.LOAD_SCENARIO === "authentication") {
  throw new Error("The authentication scenario needs dedicated Firebase test credentials. Use the fixture-auth load scenarios here.");
}

const monitoringToken = randomBytes(32).toString("hex");
process.env.MONITORING_TOKEN = monitoringToken;
process.env.OBS_ISOLATED_LOAD_TEST = "1";
process.env.OBSERVABILITY_ENABLED = "1";
const { default: app } = await import("../src/app.js");
const { prisma } = await import("../src/config/database.js");
const { CreateOutingUseCase } = await import("../src/usecases/outings/create-outing.usecase.js");
const { metricsText, startMetrics, stopMetrics } = await import("../src/monitoring/metrics.js");
const firebase = initializeApp({ projectId: "demo-yalla-local-load" });
const auth = getAuth(firebase);
const identities = new Map(Array.from({ length: 10 }, () => [randomUUID(), randomUUID()]));
const ids = [...identities.values()];
auth.verifyIdToken = async token => {
  const uid = identities.get(token);
  if (!uid) throw Object.assign(new Error("Invalid fixture session"), { code: "auth/invalid-id-token" });
  return { uid, firebase: { sign_in_provider: "custom" } } as DecodedIdToken;
};

let groupId: string | undefined;
let outingId: string | undefined;
const places: string[] = [];
try {
  await prisma.users.createMany({ data: ids.map((id, index) => ({
    id, name: "Synthetic load account", phone: `+2010${index}${randomInt(1000000, 9999999)}`,
  })) });
  const group = await prisma.groups.create({
    data: { name: "Synthetic load group", created_by: ids[0]!,
      group_members: { create: ids.map((id, index) => ({ user_id: id, role: index === 0 ? "owner" : "member" })) } },
  });
  groupId = group.id;
  const outing = await new CreateOutingUseCase().execute({
    title: "Load fixture", group_id: groupId, created_by: ids[0]!,
    scheduled_at: new Date(Date.now() + 14400000), vote_deadline_hours: 2,
    initial_vote_options: [{ label: "Fixture A" }, { label: "Fixture B" }],
  });
  outingId = outing.id;
  const catalog = await prisma.places.createManyAndReturn({
    data: Array.from({ length: 24 }, (_, index) => ({
      name: "Fixture Coffee", latitude: 30.025 + index / 1000, longitude: 31.23, status: "active",
    })), select: { id: true },
  });
  places.push(...catalog.map(row => row.id));
  const collectCount = () => metricsText().split("\n").find(line => line.startsWith("yalla_db_engine_query_seconds_count{"))
    ?.split(" ").at(-1) ?? "0";

  await withApi(app, async base => {
    startMetrics();
    const sqlBefore = Number(collectCount());
    const memoryBefore = process.memoryUsage().rss;
    const cpuBefore = process.cpuUsage();
    const started = performance.now();
    const workload = spawn(process.env.K6_EXECUTABLE ?? "k6", ["run", "monitoring/load/workflows.js"], {
      stdio: "inherit", shell: false,
      env: { ...process.env, API_BASE_URL: base, MONITORING_TOKEN: monitoringToken,
        FIXTURE_TOKENS: [...identities.keys()].join(","), FIXTURE_GROUP: groupId, FIXTURE_OUTING: outingId,
        ALLOW_DISPOSABLE_LOAD: "1" },
    });
    try {
      const [code] = await once(workload, "exit");
      if (code !== 0) process.exitCode = Number(code) || 1;
      const cpu = process.cpuUsage(cpuBefore);
      const wallMs = performance.now() - started;
      console.log(JSON.stringify({
        wallMs: Math.round(wallMs),
        backendCpuMs: (cpu.user + cpu.system) / 1000,
        backendCpuPercentOfOneCore: ((cpu.user + cpu.system) / 10 / wallMs),
        backendRssBeforeMiB: memoryBefore / 1048576,
        backendRssAfterMiB: process.memoryUsage().rss / 1048576,
        sqlStatements: Number(collectCount()) - sqlBefore,
      }, null, 2));
    } finally { stopMetrics(); }
  });
} finally {
  if (outingId) await prisma.outings.deleteMany({ where: { id: outingId } });
  if (groupId) await prisma.groups.deleteMany({ where: { id: groupId } });
  await prisma.places.deleteMany({ where: { id: { in: places } } });
  await prisma.users.deleteMany({ where: { id: { in: ids } } });
  await prisma.$disconnect();
  await deleteApp(firebase);
}
