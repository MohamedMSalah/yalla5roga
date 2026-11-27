/** Serves real Swagger operations against an isolated PostgreSQL database. Starts no delivery workers. */
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import express from "express";
import { Client } from "pg";
import swaggerUi from "swagger-ui-express";

const port = Number(process.env.YALLA_TEST_PG_PORT);
assert(Number.isInteger(port) && port > 1024 && port < 65536, "Set YALLA_TEST_PG_PORT to a disposable loopback PostgreSQL cluster");
const name = "yalla_test_departure_" + randomUUID().replaceAll("-", "");
const origin = `postgresql://postgres@127.0.0.1:${port}`;
const url = `${origin}/${name}?sslmode=disable`;
const admin = new Client({ connectionString: `${origin}/postgres?sslmode=disable` });
const db = new Client({ connectionString: url });
Object.assign(process.env, {
  NODE_ENV: "test", DEPLOYMENT_ENV: "staging",
  DATABASE_URL: url, DIRECT_URL: url, EXPECTED_DATABASE_HOST: "127.0.0.1", EXPECTED_DATABASE_NAME: name,
  LOCATION_REQUEST_COOLDOWN_MINUTES: "60", LOCATION_REQUEST_DAILY_LIMIT: "1",
});

let server: ReturnType<typeof express.application.listen> | undefined;
let disconnect: (() => Promise<void>) | undefined;
let created = false;

try {
  await admin.connect();
  const { rows: [target] } = await admin.query("SELECT host(inet_server_addr()) AS host, current_setting('neon.project_id', true) AS neon");
  assert.deepEqual(target, { host: "127.0.0.1", neon: null });
  await admin.query(`CREATE DATABASE "${name}"`);
  created = true;
  await db.connect();
  for (const migration of readdirSync("prisma/migrations").filter(name => /^\d/.test(name)).sort()) {
    await db.query(readFileSync(`prisma/migrations/${migration}/migration.sql`, "utf8"));
  }

  const { prisma } = await import("../src/config/database.js");
  disconnect = () => prisma.$disconnect();
  const { swaggerSpec } = await import("../src/config/swagger.js");
  const { swaggerCoverage } = await import("../src/app.js");
  const { createAuthMiddleware } = await import("../src/middleware/auth.middleware.js");
  const { errorMiddleware } = await import("../src/middleware/error.middleware.js");
  const { NotificationController } = await import("../src/controllers/notifications/notification.controller.js");
  const { createLocationTravelNotificationRoutes } = await import("../src/routes/notifications/location-travel-notification.routes.js");
  const { createMeetupRoutes } = await import("../src/routes/meetups/meetup.routes.js");
  const { UnauthorizedError } = await import("../src/utils/errors.js");
  const { resolvePush } = await import("../src/services/notifications/resolve-push.js");
  const affected = /location-requests|departure-reminder/;
  assert.deepEqual(swaggerCoverage.undocumented.filter(path => affected.test(path)), []);
  assert.deepEqual(swaggerCoverage.unregistered.filter(path => affected.test(path)), []);

  const [owner, member, peer, next, outsider] = ["fixture-owner", "fixture-member", "fixture-peer", "fixture-next", "fixture-outsider"];
  const users = [owner, member, peer, next, outsider];
  for (const [i, uid] of users.entries()) {
    await db.query("INSERT INTO users(id,name,phone,default_transportation_mode) VALUES ($1,$1,$2,'CAR')", [uid, `+1555123300${i}`]);
  }
  const groupId = randomUUID(), outingId = randomUUID();
  await db.query("INSERT INTO groups(id,name,created_by) VALUES ($1,'Test group',$2)", [groupId, owner]);
  await db.query("INSERT INTO group_members(group_id,user_id,role) VALUES ($1,$2,'owner'),($1,$3,'member'),($1,$4,'member'),($1,$5,'member')",
    [groupId, owner, member, peer, next]);
  await db.query(`INSERT INTO outings(id,title,created_by,group_id,status,scheduled_at,location_name,location_latitude,location_longitude)
    VALUES ($1,'Test outing',$2,$3,'confirmed',now()+interval '1 day','Test venue',30,31)`, [outingId, owner, groupId]);

  const authorize = createAuthMiddleware(async token => {
    if (!users.includes(token)) throw new UnauthorizedError();
    return { uid: token };
  });
  const app = express();
  app.use(express.json());
  app.get("/api-docs/openapi.json", (_req, res) => res.json(swaggerSpec));
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  app.use(createLocationTravelNotificationRoutes(authorize));
  app.use(createMeetupRoutes(authorize));
  const notifications = new NotificationController();
  app.get("/api/notifications", authorize, notifications.list);
  app.use(errorMiddleware);
  server = app.listen(0, "127.0.0.1");
  await new Promise<void>((resolve, reject) => { server!.once("listening", resolve); server!.once("error", reject); });
  const address = server.address();
  assert(address && typeof address !== "string");
  const base = `http://127.0.0.1:${address.port}`;
  assert.equal((await fetch(base + "/api-docs/")).status, 200);
  const spec = await (await fetch(base + "/api-docs/openapi.json")).json() as {
    paths: Record<string, Record<string, { operationId: string; responses: Record<string, unknown> }>>;
  };
  const operations = new Map(Object.entries(spec.paths).flatMap(([path, methods]) =>
    Object.entries(methods).map(([method, operation]) => [operation.operationId, { method, path, operation }] as const)));
  async function call(operation: string, uid: string | null, params: Record<string, string> = {}, body?: unknown, status = 200) {
    const op = operations.get(operation);
    assert(op, `No served operation ${operation}`);
    assert(op.operation.responses[status], `Undocumented HTTP status ${status} for ${operation}`);
    const path = op.path.replace(/{(\w+)}/g, (_match, name: string) => encodeURIComponent(params[name]!));
    const response = await fetch(base + path, {
      method: op.method.toUpperCase(), headers: {
        ...(uid && { authorization: `Bearer ${uid}` }),
        ...(body !== undefined && { "content-type": "application/json" }),
      }, body: body === undefined ? undefined : JSON.stringify(body),
    });
    const json = await response.json() as { success: boolean; data: any };
    assert.equal(response.status, status, `${operation}: ${JSON.stringify(json)}`);
    assert.equal(json.success, status < 400);
    return json.data;
  }
  async function count(sql: string) {
    return (await db.query(sql)).rows[0].count as number;
  }
  const requests = () => count("SELECT count(*)::int FROM notification_events WHERE type = 'meetup_location_requested'");
  const jobs = () => count("SELECT count(*)::int FROM departure_reminders");

  const session = await call("initializeGroupMeetup", owner, { groupId });
  const scope = { sessionId: session.id as string };
  await call("initializeGroupMeetup", peer, { groupId });
  assert.equal(await requests(), 0);
  assert.equal(session.readiness.participants.find((row: { is_self: boolean }) => row.is_self).request_target_user_id, undefined);
  assert(session.readiness.participants.some((row: { request_target_user_id?: string }) => row.request_target_user_id === member));
  const request = (uid: string | null, target: string, status = 200, params = scope) =>
    call("requestMemberLocation", uid, params, { target_user_id: target }, status);
  await request(null, member, 401);
  await request(outsider, member, 403);
  await request(owner, outsider, 403);
  await request(owner, owner, 403);
  await request(owner, "", 400);
  const standalone = await call("createStandaloneMeetup", owner);
  await request(owner, member, 403, { sessionId: standalone.id });
  await db.query(`INSERT INTO starting_location_overrides(user_id,meetup_session_id,location_source,latitude,longitude,consent_policy_version,expires_at)
    VALUES ($1,$2,'MANUAL_POINT',30.1,31.1,'starting-location-context-v1',now()+interval '2 hours')`, [member, scope.sessionId]);
  assert.equal((await request(owner, member)).status, "UNAVAILABLE");
  await db.query("DELETE FROM starting_location_overrides WHERE user_id = $1 AND meetup_session_id = $2", [member, scope.sessionId]);
  await db.query("UPDATE users SET notification_preferences = '{\"groupEvents\":false}'::jsonb WHERE id = $1", [member]);
  assert.equal((await request(owner, member)).status, "UNAVAILABLE");
  await db.query("UPDATE users SET notification_preferences = '{}'::jsonb WHERE id = $1", [member]);
  await db.query("INSERT INTO user_location_group_exclusions(user_id,group_id) VALUES ($1,$2)", [member, groupId]);
  assert.equal((await request(owner, member)).status, "UNAVAILABLE");
  await db.query("DELETE FROM user_location_group_exclusions WHERE user_id = $1 AND group_id = $2", [member, groupId]);
  const parallel = await Promise.all([request(owner, member), request(owner, member), request(owner, next)]);
  assert.equal(parallel.filter(result => result.status === "REQUESTED").length, 1);
  assert.equal(parallel.filter(result => result.status === "COOLDOWN" && Date.parse(result.retry_at) > Date.now()).length, 2);
  assert.equal(await requests(), 1);
  const { rows: [event] } = await db.query("SELECT event_key, recipient_user_id, created_at, payload FROM notification_events WHERE type = 'meetup_location_requested'");
  assert.equal(event.payload.sessionId, scope.sessionId);
  assert.equal(event.payload.requesterId, owner);
  assert.equal(event.payload.groupId, groupId);
  assert.equal(event.created_at.toISOString(), event.payload.requestedAt);
  assert(!/latitude|longitude|coordinates/i.test(JSON.stringify(event.payload)));
  assert.equal((await request(peer, event.recipient_user_id)).status, "COOLDOWN");
  const inbox = await call("listNotifications", event.recipient_user_id);
  assert.equal(inbox[0].sessionId, scope.sessionId);
  assert.equal(inbox[0].eventType, "meetup_location_requested");
  assert(await resolvePush(event.recipient_user_id, event.payload, event.event_key.slice("outbox:".length)));
  assert.equal(await resolvePush(event.recipient_user_id, { ...event.payload, expiresAt: new Date(0).toISOString() },
    event.event_key.slice("outbox:".length)), null);
  await db.query("UPDATE users SET notification_preferences = '{\"pushEnabled\":false}'::jsonb WHERE id = $1", [event.recipient_user_id]);
  assert.equal(await resolvePush(event.recipient_user_id, event.payload, event.event_key.slice("outbox:".length)), null);
  await db.query("UPDATE users SET notification_preferences = '{}'::jsonb WHERE id = $1", [event.recipient_user_id]);
  await db.query("UPDATE meetup_sessions SET expires_at = now() - interval '1 minute' WHERE id = $1", [scope.sessionId]);
  await request(owner, member, 409);
  assert.equal(await resolvePush(event.recipient_user_id, event.payload, event.event_key.slice("outbox:".length)), null);
  console.log("PASS Swagger readiness, auth, exclusions, opt-out, concurrent cooldown, inbox, and push eligibility checks");

  const outing = { outingId };
  assert.deepEqual(await call("getDepartureReminderPreferences", member), {
    enabled: false, preparation_buffer_minutes: 10, updated_at: null,
  });
  await call("updateDepartureReminderPreferences", member, {}, { preparation_buffer_minutes: 6 }, 400);
  await call("updateDepartureReminderPreferences", member, {}, { enabled: true, user_id: owner }, 400);
  await call("getMyDepartureReminder", outsider, outing, undefined, 403);
  await call("scheduleMyDepartureReminder", member, outing, { duration_seconds: 1 }, 400);
  assert.equal((await call("getMyDepartureReminder", member, outing)).status, "RSVP_REQUIRED");
  await db.query("INSERT INTO outing_attendance(outing_id,user_id,status) VALUES ($1,$2,'going')", [outingId, member]);
  assert.equal((await call("scheduleMyDepartureReminder", member, outing)).status, "OPT_IN_REQUIRED");
  const preference = await call("updateDepartureReminderPreferences", member, {}, { enabled: true, preparation_buffer_minutes: 15 });
  assert.equal(preference.enabled, true);
  assert.equal(preference.preparation_buffer_minutes, 15);
  assert(Date.parse(preference.updated_at) <= Date.now());
  assert.equal((await call("getDepartureReminderPreferences", owner)).enabled, false);
  assert.equal((await call("scheduleMyDepartureReminder", member, outing)).status, "STARTING_LOCATION_REQUIRED");
  await db.query(`INSERT INTO starting_location_overrides(user_id,outing_id,location_source,latitude,longitude,consent_policy_version,expires_at)
    VALUES ($1,$2,'MANUAL_POINT',30.1,31.1,'starting-location-context-v1',now()+interval '2 days')`, [member, outingId]);
  const blocked = await Promise.all([call("scheduleMyDepartureReminder", member, outing), call("scheduleMyDepartureReminder", member, outing)]);
  for (const result of blocked) {
    assert.equal(result.status, "ROUTING_UNAVAILABLE");
    assert.equal(result.estimated_journey_seconds, null);
    assert.equal(result.suggested_departure_at, null);
    assert.equal(result.scheduled_send_at, null);
    assert(!/latitude|longitude/i.test(JSON.stringify(result)));
  }
  assert.equal(await jobs(), 0);
  assert.equal(await call("clearMyDepartureReminder", member, outing), null);
  console.log("PASS Swagger opt-in, invalid inputs, RSVP and consent gates, and zero scheduled jobs before routing");

  const seedJob = (user = member) => db.query(`INSERT INTO departure_reminders(outing_id,user_id,scheduled_send_at,estimate_reference,
    input_fingerprint,deduplication_key,duration_seconds) VALUES ($1,$2,now()+interval '1 hour','fixture',repeat('e',64),$3,600)`,
  [outingId, user, randomUUID().replaceAll("-", "").padEnd(64, "a")]);
  await seedJob();
  await assert.rejects(seedJob(), { code: "23505" });
  await call("clearMyDepartureReminder", member, outing);
  assert.equal(await jobs(), 0);
  const invalidate = async (sql: string, params: string[]) => {
    await seedJob();
    await db.query(sql, params);
    assert.equal(await jobs(), 0, sql);
  };
  await seedJob();
  await call("updateDepartureReminderPreferences", member, {}, { preparation_buffer_minutes: 30 });
  assert.equal(await jobs(), 0);
  await invalidate("UPDATE users SET default_transportation_mode = 'WALKING' WHERE id = $1", [member]);
  await invalidate("UPDATE users SET notification_preferences = '{\"reminders\":false}'::jsonb WHERE id = $1", [member]);
  await invalidate("UPDATE starting_location_overrides SET latitude = 30.2 WHERE user_id = $1 AND outing_id = $2", [member, outingId]);
  await invalidate("DELETE FROM starting_location_overrides WHERE user_id = $1 AND outing_id = $2", [member, outingId]);
  await invalidate("UPDATE outing_attendance SET status = 'maybe' WHERE user_id = $1 AND outing_id = $2", [member, outingId]);
  await invalidate("UPDATE outings SET scheduled_at = scheduled_at + interval '1 hour' WHERE id = $1", [outingId]);
  await invalidate("UPDATE outings SET location_longitude = 31.5 WHERE id = $1", [outingId]);
  await invalidate("DELETE FROM group_members WHERE user_id = $1 AND group_id = $2", [member, groupId]);
  await invalidate("UPDATE outings SET status = 'cancelled' WHERE id = $1", [outingId]);
  await call("updateDepartureReminderPreferences", event.recipient_user_id, {}, { enabled: true });
  await seedJob(event.recipient_user_id);
  await db.query("DELETE FROM users WHERE id = $1", [event.recipient_user_id]);
  assert.equal(await jobs(), 0);
  assert.equal(await requests(), 0);
  assert.equal(await count("SELECT count(*)::int FROM departure_reminder_preferences WHERE enabled = true"), event.recipient_user_id === member ? 0 : 1);
  assert.equal(await count("SELECT count(*)::int FROM notifications WHERE data->>'notificationType' = 'meetup_location_requested'"), 0);
  console.log("PASS unique job slot, transactional invalidations, cancellation, and account cleanup with synthetic rows");
} finally {
  if (server) await new Promise<void>(resolve => server!.close(() => resolve()));
  await disconnect?.();
  await db.end();
  if (created) await admin.query(`DROP DATABASE "${name}" WITH (FORCE)`);
  await admin.end();
}
