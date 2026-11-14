/** Only HTTP operations selected from served OpenAPI; disposable database schema. */
import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { Client } from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";

const schema = `push_api_${randomUUID().replaceAll("-", "")}`;
const url = new URL(process.env.DATABASE_URL!);
url.searchParams.delete("channel_binding");
url.searchParams.delete("pgbouncer");
url.searchParams.set(
  "sslmode",
  process.env.PHASE3_SECURE_TUNNEL === "1" ? "disable" : "verify-full",
);
url.hostname = url.hostname.replace("-pooler.", ".");
const admin = new Client({
  connectionString: url.toString(),
  ssl:
    process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1"
      ? false
      : { rejectUnauthorized: true },
  connectionTimeoutMillis: 15000,
});
url.searchParams.set("schema", schema);
url.searchParams.set("connection_limit", "1");
process.env.DATABASE_URL = url.toString();
process.env.NODE_ENV = "test";
let db: import("@prisma/client").PrismaClient | undefined,
  server: import("node:http").Server | undefined,
  made = false;
const rows: any[] = [];
let stopWorker: (() => Promise<void>) | undefined;
let stopVotingJob: (() => void) | undefined;
const providerCalls: any[] = [];
const oldError = console.error;
console.error = (m, ...args) => {
  if (
    typeof m === "string" &&
    (m.startsWith("[Firebase Auth]") || m.startsWith("[Firebase Admin]"))
  )
    return;
  oldError(m, ...args);
};
try {
  await admin.connect();
  assert.match(schema, /^push_api_[a-f0-9]{32}$/);
  await admin.query(`CREATE SCHEMA "${schema}"`);
  made = true;
  await admin.query(`SET search_path TO "${schema}"`);
  for (const m of readdirSync("prisma/migrations")
    .filter((n) => /^\d/.test(n))
    .sort())
    await admin.query(
      readFileSync(`prisma/migrations/${m}/migration.sql`, "utf8").replace(
        'CREATE SCHEMA IF NOT EXISTS "public";',
        "",
      ),
    );
  const owner = "push-owner",
    member = "push-member",
    invitee = "push-invitee",
    outsider = "push-outsider";
  const phones = new Map([
    [owner, "+201000091001"],
    [member, "+201000091002"],
    [invitee, "+201000091003"],
    [outsider, "+201000091004"],
  ]);
  for (const [uid, phone] of phones)
    await admin.query(`INSERT INTO users(id,name,phone) VALUES ($1,$2,$3)`, [
      uid,
      uid.replace("push-", ""),
      phone,
    ]);
  db = (await import("../src/config/database.js")).prisma;
  await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
  assert.equal(
    (
      (await db.$queryRawUnsafe("SELECT current_schema() AS schema")) as any[]
    )[0].schema,
    schema,
  );
  // Only Firebase's network boundary is controlled. Application routes/use cases/SQL are real.
  const { getFirebaseAuth } = await import("../src/config/firebase.js");
  const auth = getFirebaseAuth();
  auth.verifyIdToken = (async (token: string) => {
    if (!phones.has(token))
      throw Object.assign(new Error("Invalid fixture token"), {
        code: "auth/invalid-id-token",
      });
    return {
      uid: token,
      phone_number: phones.get(token),
      firebase: { sign_in_provider: "custom" },
    };
  }) as any;
  auth.getUser = (async (uid: string) => ({
    uid,
    phoneNumber: phones.get(uid),
    disabled: false,
  })) as any;
  auth.getUserByPhoneNumber = (async (phone: string) => {
    const found = [...phones].find(([, p]) => p === phone);
    if (!found)
      throw Object.assign(new Error("Not registered"), {
        code: "auth/user-not-found",
      });
    return { uid: found[0], phoneNumber: phone, disabled: false };
  }) as any;
  const { swaggerSpec } = await import("../src/config/swagger.js"),
    spec = swaggerSpec as any;
  const operations = new Map<string, any>();
  for (const [path, item] of Object.entries(spec.paths) as any)
    for (const [method, op] of Object.entries(item) as any)
      if (op.operationId)
        operations.set(op.operationId, { path, method, ...op });
  const { errorMiddleware } =
    await import("../src/middleware/error.middleware.js");
  const app = express();
  app.use(express.json());
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(spec));
  for (const feature of [
    "groups",
    "outings",
    "invitations",
    "notifications",
    "users",
  ])
    app.use((await import(`../src/routes/${feature}/index.js`)).default);
  app.use(errorMiddleware);
  server = app.listen(0, "127.0.0.1");
  await new Promise<void>((done) => server!.once("listening", done));
  const base = `http://127.0.0.1:${(server.address() as import("node:net").AddressInfo).port}`;
  const resolve = (ref: string): any =>
    ref
      .slice(2)
      .split("/")
      .reduce((v: any, k: string) => v[k], spec);
  function validate(s: any, v: any): void {
    if (!s) return;
    if (s.$ref) return validate(resolve(s.$ref), v);
    if (v === null && s.nullable) return;
    for (const a of s.allOf ?? []) validate(a, v);
    if (s.enum) assert.ok(s.enum.includes(v), `Unexpected enum ${v}`);
    if (s.type === "object") {
      assert.ok(v && typeof v === "object");
      for (const k of s.required ?? []) assert.ok(k in v, `Missing ${k}`);
      for (const [k, c] of Object.entries(s.properties ?? {}))
        if (k in v) validate(c, v[k]);
    } else if (s.type === "array") {
      assert.ok(Array.isArray(v));
      for (const c of v) validate(s.items, c);
    } else if (s.type === "integer") assert.ok(Number.isInteger(v));
    else if (s.type) assert.equal(typeof v, s.type);
  }
  const ids: Record<string, string> = {
    id: randomUUID(),
    outingId: randomUUID(),
    invitationId: randomUUID(),
    messageId: randomUUID(),
    userId: member,
  };
  async function call(
    id: string,
    status = 200,
    token: string | null = owner,
    body?: unknown,
    query = "",
  ) {
    const op = operations.get(id);
    assert.ok(op, `Undocumented ${id}`);
    const path = op.path.replace(
      /\{(\w+)\}/g,
      (_: string, key: string) => ids[key] ?? ids.id!,
    );
    const response = await fetch(base + path + query, {
      method: op.method.toUpperCase(),
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(30000),
    });
    const json = (await response.json()) as any;
    assert.equal(response.status, status, `${id}: ${JSON.stringify(json)}`);
    const r = op.responses[String(status)];
    assert.ok(r, `${id}: undocumented ${status}`);
    validate(
      (r.$ref ? resolve(r.$ref) : r).content?.["application/json"]?.schema,
      json,
    );
    rows.push({ scenario: id, status, result: "PASS" });
    if (rows.length % 20 === 0)
      console.log(JSON.stringify({ checks: rows.length, last: id }));
    return json;
  }
  async function feed(uid = member) {
    return (await call("listNotifications", 200, uid, undefined, "?limit=100"))
      .data as any[];
  }
  async function waitFor(predicate: () => Promise<boolean>, label: string) {
    for (let n = 0; n < 240; n++) {
      if (await predicate()) {
        rows.push({ scenario: label, result: "PASS" });
        return;
      }
      await new Promise((r) => setTimeout(r, 250));
    }
    throw new Error(`Timed out: ${label}`);
  }
  assert.equal((await fetch(base + "/api-docs/")).status, 200);
  const init = await (
    await fetch(base + "/api-docs/swagger-ui-init.js")
  ).text();
  assert.deepEqual(
    JSON.parse(init.split("var options = ")[1]!.split(/;\r?\n/)[0]!).swaggerDoc,
    spec,
  );
  rows.push({
    scenario: "Served Swagger matches generated OpenAPI",
    result: "PASS",
  });
  for (const id of [
    "listNotifications",
    "getNotificationPreferences",
    "updateNotificationPreferences",
    "getNotificationSystemPayload",
    "sendOutingMessage",
    "markOutingChatRead",
    "acceptGroupInvitation",
    "declineGroupInvitation",
    "registerFcmToken",
  ])
    for (const token of [null, "invalid"])
      await call(
        id,
        401,
        token,
        [
          "updateNotificationPreferences",
          "sendOutingMessage",
          "registerFcmToken",
        ].includes(id)
          ? {}
          : undefined,
      );
  await call("updateNotificationPreferences", 400, member, {
    anotherUser: owner,
  });
  await call("updateNotificationPreferences", 400, member, {
    pushEnabled: "yes",
  });
  assert.equal(
    (await call("getNotificationPreferences", 200, member)).data
      .lockScreenPreview,
    false,
  );
  const group = (
    await call("createGroup", 201, owner, { name: "Push Friends" })
  ).data.id;
  ids.id = group;
  await admin.query(
    `INSERT INTO group_members(group_id,user_id) VALUES ($1,$2)`,
    [group, member],
  );
  assert.ok(
    (await feed(owner)).some((n) => n.notificationType === "group_created"),
  );
  const invitation = (
    await call("inviteToGroup", 201, owner, {
      phoneNumber: phones.get(invitee),
    })
  ).data.invitation_id;
  ids.invitationId = invitation;
  assert.equal(
    (await call("listUserInvitations", 200, invitee)).data.find(
      (i: any) => i.invitation_id === invitation,
    ).status,
    "pending",
  );
  await call("getGroup", 403, invitee);
  const invitationNotification = (await feed(invitee)).find(
    (n) => n.invitationId === invitation,
  );
  assert.ok(invitationNotification);
  ids.id = invitationNotification.id;
  const invitationPayload = (
    await call("getNotificationSystemPayload", 200, invitee)
  ).data.payload;
  for (const key of [
    "notificationId",
    "eventId",
    "notificationType",
    "groupId",
    "invitationId",
    "actionType",
    "createdAt",
  ])
    assert.ok(invitationPayload[key]);
  await call("getNotificationSystemPayload", 403, outsider);
  await call("acceptGroupInvitation", 403, outsider);
  await call("declineGroupInvitation", 403, outsider);
  await call("acceptGroupInvitation", 200, invitee);
  await call("acceptGroupInvitation", 200, invitee);
  assert.equal(
    (await call("declineGroupInvitation", 200, invitee)).data.status,
    "accepted",
  );
  ids.id = group;
  await call("getGroup", 200, invitee);
  assert.equal(
    (await feed(invitee)).filter(
      (n) => n.notificationType === "membership_activated",
    ).length,
    1,
  );
  assert.equal(
    (await feed(member)).filter((n) => n.notificationType === "member_joined")
      .length,
    1,
  );
  const declineInvitation = (
    await call("inviteToGroup", 201, owner, {
      phoneNumber: phones.get(outsider),
    })
  ).data.invitation_id;
  ids.invitationId = declineInvitation;
  await call("declineGroupInvitation", 200, outsider);
  await call("declineGroupInvitation", 200, outsider);
  assert.equal(
    (await call("acceptGroupInvitation", 200, outsider)).data.status,
    "declined",
  );
  ids.id = group;
  await call("getGroup", 403, outsider);
  assert.ok(
    !(await call("listGroupMembers")).pending_members.some(
      (p: any) => p.invitation_id === declineInvitation,
    ),
  );
  assert.equal(
    (await call("listUserInvitations", 200, outsider)).data.find(
      (i: any) => i.invitation_id === declineInvitation,
    ).status,
    "declined",
  );
  const unlinked = randomUUID();
  await admin.query(
    `INSERT INTO group_invitations(id,group_id,invited_by_user_id,invited_phone,expires_at) VALUES ($1,$2,$3,$4,now()+interval '1 day')`,
    [unlinked, group, owner, phones.get(outsider)],
  );
  await call("syncUser", 200, outsider, {});
  ids.id = group;
  await call("getGroup", 403, outsider);
  assert.equal(
    (await call("listUserInvitations", 200, outsider)).data.find(
      (i: any) => i.invitation_id === unlinked,
    ).status,
    "pending",
  );
  assert.ok((await feed(outsider)).some((n) => n.invitationId === unlinked));
  const outingBody = {
    title: "Friday Push",
    group_id: group,
    scheduled_at: new Date(Date.now() + 86_400_000).toISOString(),
    vote_deadline_hours: 3,
    create_request_key: randomUUID(),
    initial_vote_options: [
      { label: "Bowling", latitude: 30, longitude: 31 },
      { label: "Cafe", latitude: 30.01, longitude: 31.01 },
    ],
  };
  const outing = (await call("createOuting", 201, owner, outingBody)).data.id;
  assert.equal(
    (await call("createOuting", 201, owner, outingBody)).data.id,
    outing,
  );
  ids.id = outing;
  ids.outingId = outing;
  const baseline = await feed(member);
  for (const type of ["outing_created", "voting_started", "rsvp_opened"])
    assert.equal(
      baseline.filter(
        (n) => n.outingId === outing && n.notificationType === type,
      ).length,
      1,
    );
  const key = randomUUID();
  const message = (
    await call("sendOutingMessage", 201, owner, {
      text: `<@${member}|Fake> Are we meeting at 8?`,
      clientMessageId: key,
    })
  ).data;
  ids.messageId = message.id;
  assert.equal(
    (
      await call("sendOutingMessage", 201, owner, {
        text: "Retry text",
        clientMessageId: key,
      })
    ).data.id,
    message.id,
  );
  let chatNotice = (await feed(member)).find((n) => n.messageId === message.id);
  assert.ok(chatNotice);
  assert.equal(
    (await feed(member)).filter((n) => n.messageId === message.id).length,
    1,
  );
  ids.id = chatNotice.id;
  let resolved = (await call("getNotificationSystemPayload", 200, member)).data
    .payload;
  assert.ok(
    resolved.title.includes("owner") && resolved.title.includes("Friday Push"),
  );
  assert.ok(resolved.body.includes("8?"));
  assert.equal(resolved.mention, "true");
  await call("getNotificationSystemPayload", 403, outsider);
  await call("markNotificationRead", 403, outsider);
  await call("markOutingChatRead", 403, outsider);
  await call("sendOutingMessage", 403, outsider, {
    text: "No access",
    clientMessageId: randomUUID(),
  });
  await call("editOutingMessage", 403, member, { text: "Not mine" });
  await call("editOutingMessage", 200, owner, { text: "Changed meeting to 9" });
  assert.equal(
    (await call("getNotificationSystemPayload", 200, member)).data.payload.body,
    "Changed meeting to 9",
  );
  const replyKey = randomUUID();
  const reply = (
    await call("sendOutingMessage", 201, member, {
      text: "See you at 9",
      clientMessageId: replyKey,
    })
  ).data;
  assert.equal(
    (
      await call("sendOutingMessage", 201, member, {
        text: "See you at 9",
        clientMessageId: replyKey,
      })
    ).data.id,
    reply.id,
  );
  await call("deleteOutingMessage", 200, owner);
  assert.equal(
    (await call("getNotificationSystemPayload", 200, member)).data.available,
    false,
  );
  assert.equal(
    (await feed(member)).find((n) => n.messageId === message.id).body,
    "Message deleted",
  );
  const second = (
    await call("createOuting", 201, owner, {
      ...outingBody,
      title: "Other Conversation",
      create_request_key: randomUUID(),
    })
  ).data.id;
  ids.outingId = second;
  const otherMessage = (
    await call("sendOutingMessage", 201, owner, {
      text: "Another thread",
      clientMessageId: randomUUID(),
    })
  ).data;
  ids.outingId = outing;
  const unreadMessage = (
    await call("sendOutingMessage", 201, owner, {
      text: "Unread here",
      clientMessageId: randomUUID(),
    })
  ).data;
  await call("markOutingChatRead", 200, member);
  let notices = await feed(member);
  assert.equal(
    notices.find((n) => n.messageId === unreadMessage.id).is_read,
    true,
  );
  assert.equal(
    notices.find((n) => n.messageId === otherMessage.id).is_read,
    false,
  );
  assert.equal(
    (await call("listNotifications", 200, member, undefined, "?limit=1"))
      .unreadCount,
    notices.filter((n) => !n.is_read).length,
  );
  await call("updateNotificationPreferences", 200, member, {
    mentionPriority: false,
    chatMessages: false,
  });
  ids.id = notices.find((n) => n.messageId === otherMessage.id).id;
  assert.equal(
    (await call("getNotificationSystemPayload", 200, member)).data.available,
    false,
  );
  await call("updateNotificationPreferences", 200, member, {
    chatMessages: true,
  });
  ids.id = outing;
  const options = (await call("listVoteOptions")).data;
  const beforeVotes = (await feed(member)).length;
  await call("replaceOutingBallot", 200, owner, {
    option_ids: [options[0].id, options[1].id],
  });
  await call("replaceOutingBallot", 200, owner, {
    option_ids: [options[0].id, options[1].id],
  });
  assert.equal((await feed(member)).length, beforeVotes);
  await call("replaceOutingBallot", 200, member, {
    option_ids: [options[0].id],
  });
  await call("replaceOutingBallot", 200, invitee, {
    option_ids: [options[0].id],
  });
  assert.equal((await call("getOuting")).data.status, "confirmed");
  notices = await feed(member);
  for (const type of ["voting_closed", "winner_selected", "outing_confirmed"])
    assert.equal(
      notices.filter(
        (n) => n.outingId === outing && n.notificationType === type,
      ).length,
      1,
    );
  await call("confirmOutingVenue", 200, owner, { option_id: options[0].id });
  assert.equal(
    (await feed(member)).filter(
      (n) => n.outingId === outing && n.notificationType === "winner_selected",
    ).length,
    1,
  );
  await call("updateOuting", 200, owner, { title: "Friday Updated" });
  assert.ok(
    (await feed(member)).some(
      (n) => n.outingId === outing && n.notificationType === "outing_updated",
    ),
  );
  await call("setOutingAttendance", 200, member, { status: "going" });
  await call("setOutingAttendance", 200, member, { status: "going" });
  assert.equal(
    (await feed(owner)).filter(
      (n) =>
        n.outingId === outing && n.notificationType === "attendance_changed",
    ).length,
    1,
  );
  const proof = () => ({
    latitude: 30,
    longitude: 31,
    accuracy: 5,
    captured_at: new Date().toISOString(),
  });
  assert.equal(
    (await call("recordOutingArrival", 200, member, proof())).data.arrived,
    false,
  );
  await call("recordOutingArrival", 403, outsider, proof());
  // Time shifts are fixture setup only; real background jobs produce observable inbox rows.
  await admin.query(
    `UPDATE outings SET scheduled_at=now()+interval '30 minutes' WHERE id=$1`,
    [outing],
  );
  await admin.query(
    `UPDATE outings SET vote_ends_at=now()+interval '30 minutes' WHERE id=$1`,
    [second],
  );
  // Start the transport fixture with an empty pre-existing delivery backlog.
  // Earlier HTTP scenarios assert inbox persistence independently of delivery.
  await admin.query(
    `UPDATE notification_events SET status='sent' WHERE channel='push'`,
  );
  ids.outingId = second;
  await call("sendOutingMessage", 201, owner, {
    text: "Transport retry fixture",
    clientMessageId: randomUUID(),
  });
  ids.outingId = outing;
  for (const token of [
    "valid-device-001",
    "transient-device-001",
    "invalid-device-001",
  ])
    await call("registerFcmToken", 201, member, {
      token,
      platform: "android",
      notificationVersion: 2,
    });
  await call("registerFcmToken", 201, member, {
    token: "valid-device-001",
    platform: "android",
    notificationVersion: 2,
  });
  await call("registerFcmToken", 201, member, {
    token: "legacy-device-001",
    platform: "android",
  });
  await call("registerFcmToken", 400, member, {
    token: "unsupported-device-001",
    platform: "android",
    notificationVersion: 3,
  });
  const { PushChannel } =
    await import("../src/services/notifications/channels/push.channel.js");
  const { NotificationDispatcher } =
    await import("../src/services/notifications/dispatch-notification.js");
  const { getNotificationConfig } =
    await import("../src/config/notifications.js");
  const { startNotificationWorker } =
    await import("../src/jobs/notification-worker.job.js");
  const transient = new Set<string>();
  const fakeMessaging = {
    sendEachForMulticast: async (input: any) => {
      providerCalls.push(input);
      if (
        input.tokens.includes("legacy-device-001") &&
        input.data.actionType !== "update"
      ) {
        assert.equal(input.notification?.body, "You have a new notification");
      } else assert.ok(!input.notification);
      assert.equal(input.android.priority, "high");
      for (const key of [
        "eventId",
        "notificationType",
        "createdAt",
        "actionType",
        "recipientUserId",
      ])
        assert.ok(input.data[key]);
      const responses = input.tokens.map((token: string) => {
        if (token.startsWith("invalid-"))
          return {
            success: false,
            error: { code: "messaging/registration-token-not-registered" },
          };
        const key = input.data.eventId + token;
        if (token.startsWith("transient-") && !transient.has(key)) {
          transient.add(key);
          return {
            success: false,
            error: { code: "messaging/server-unavailable" },
          };
        }
        return { success: true, messageId: "fixture-confirmed-delivery" };
      });
      return {
        responses,
        successCount: responses.filter((r: any) => r.success).length,
        failureCount: responses.filter((r: any) => !r.success).length,
      };
    },
  };
  const config = getNotificationConfig();
  config.worker.intervalMs = 500;
  config.worker.batchSize = 5;
  stopWorker = startNotificationWorker(
    new NotificationDispatcher(
      undefined,
      [new PushChannel(() => fakeMessaging as any)],
      config,
    ),
    config,
  );
  await waitFor(
    async () =>
      (await feed(member)).some(
        (n) =>
          n.outingId === second &&
          n.notificationType === "voting_deadline_approaching",
      ),
    "Voting deadline reminder via OpenAPI inbox",
  );
  await waitFor(
    async () =>
      (await feed(member)).some(
        (n) => n.outingId === outing && n.notificationType === "venue_reminder",
      ),
    "Confirmed venue and outing reminder via OpenAPI inbox",
  );
  await waitFor(
    async () => providerCalls.length > 0,
    "Controlled FCM adapter received durable events",
  );
  await waitFor(
    async () =>
      providerCalls.some(
        (input, index) =>
          input.tokens.includes("transient-device-001") &&
          providerCalls
            .slice(0, index)
            .some(
              (old) =>
                old.data.eventId === input.data.eventId &&
                old.tokens.includes("transient-device-001"),
            ),
      ),
    "Worker retries partially failed multicast after backoff",
  );
  assert.equal(
    (
      await call("unregisterFcmToken", 200, member, {
        token: "invalid-device-001",
      })
    ).data.deleted,
    0,
  );
  const byEvent = new Map<string, any[]>();
  for (const input of providerCalls.filter((p) =>
    p.tokens.includes("transient-device-001"),
  )) {
    const a = byEvent.get(input.data.eventId) ?? [];
    a.push(input);
    byEvent.set(input.data.eventId, a);
  }
  const retried = [...byEvent.values()].filter((a) => a.length > 1);
  assert.ok(retried.length);
  for (const calls of retried)
    for (const retry of calls.slice(1))
      assert.ok(!retry.tokens.includes("valid-device-001"));
  assert.ok(
    providerCalls.some(
      (input) =>
        input.tokens.includes("legacy-device-001") && input.notification,
    ),
  );
  rows.push({
    scenario:
      "Legacy Android tokens retain redacted OS-visible delivery; v2 tokens use native action data delivery",
    result: "PASS",
  });
  rows.push({
    scenario:
      "Partial multicast retry excludes successful devices; invalid token cleanup; Android data-only structured envelope",
    result: "PASS",
  });
  await admin.query(
    `UPDATE outings SET scheduled_at=now()-interval '1 minute' WHERE id=$1`,
    [outing],
  );
  await waitFor(
    async () =>
      (await feed(member)).some(
        (n) =>
          n.outingId === outing && n.notificationType === "arrival_reminder",
      ),
    "Arrival reminder inside confirmed attendance window",
  );
  ids.id = outing;
  await call("recordOutingArrival", 200, member, proof());
  assert.ok(
    (await feed(owner)).some(
      (n) => n.outingId === outing && n.notificationType === "arrival_changed",
    ),
  );
  ids.id = second;
  await call("cancelOuting");
  await call("cancelOuting");
  notices = await feed(member);
  assert.equal(
    notices.filter(
      (n) => n.outingId === second && n.notificationType === "outing_cancelled",
    ).length,
    1,
  );
  ids.id = notices.find(
    (n) =>
      n.outingId === second &&
      n.notificationType === "voting_deadline_approaching",
  ).id;
  assert.equal(
    (await call("getNotificationSystemPayload", 200, member)).data.available,
    false,
  );
  ids.id = group;
  ids.userId = invitee;
  await call("removeGroupMember", 200, owner);
  assert.ok(
    (await feed(member)).some(
      (n) => n.groupId === group && n.notificationType === "member_left",
    ),
  );
  ids.id = outing;
  await call("getOuting", 403, invitee);
  ids.id = (await feed(invitee)).find(
    (n) => n.outingId === outing && n.notificationType === "outing_created",
  ).id;
  assert.equal(
    (await call("getNotificationSystemPayload", 200, invitee)).data.available,
    false,
  );
  await call("registerFcmToken", 201, outsider, {
    token: "valid-device-001",
    platform: "android",
  });
  assert.equal(
    (
      await call("unregisterFcmToken", 200, member, {
        token: "valid-device-001",
      })
    ).data.deleted,
    0,
  );
  assert.equal(
    (
      await call("unregisterFcmToken", 200, outsider, {
        token: "valid-device-001",
      })
    ).data.deleted,
    1,
  );
  await stopWorker();
  stopWorker = undefined;
  const expired = (
    await call("createOuting", 201, owner, {
      ...outingBody,
      title: "Deadline fixture",
      scheduled_at: new Date(Date.now() + 72 * 3_600_000).toISOString(),
      vote_deadline_hours: 48,
      create_request_key: randomUUID(),
    })
  ).data.id;
  await admin.query(
    `UPDATE outings SET vote_ends_at=now()-interval '1 minute' WHERE id=$1`,
    [expired],
  );
  const { startVotingDeadlineJob } =
    await import("../src/jobs/close-voting-deadline.job.js");
  stopVotingJob = startVotingDeadlineJob();
  ids.id = expired;
  await waitFor(
    async () =>
      (await call("getOuting", 200, member)).data.status === "cancelled",
    "Scheduled deadline closes voting and cancels zero-vote outing",
  );
  const expiredInbox = (await feed(member)).filter(
    (n) => n.outingId === expired,
  );
  assert.equal(
    expiredInbox.filter((n) => n.notificationType === "voting_closed").length,
    1,
  );
  assert.equal(
    expiredInbox.filter((n) => n.notificationType === "outing_cancelled")
      .length,
    1,
  );
  assert.equal(
    expiredInbox.filter(
      (n) => n.notificationType === "voting_deadline_approaching",
    ).length,
    0,
  );
  rows.push({
    scenario:
      "48-hour deadline metadata, server-time closure, no reminder after deadline, idempotent closed/cancelled events",
    result: "PASS",
  });
  rows.push({
    scenario:
      "Android RemoteInput, permissions, channels, badge, lock screen, cold start, OEM process handling",
    result: "MANUAL_DEVICE_REQUIRED",
  });
} catch (error) {
  rows.push({
    scenario: "HTTP/OpenAPI verification",
    result: "FAILED_OR_BLOCKED",
    reason:
      error instanceof Error
        ? error.message.replace(/postgres(?:ql)?:\/\/\S+/g, "[redacted]")
        : "Unknown",
  });
  throw error;
} finally {
  await stopWorker?.();
  stopVotingJob?.();
  if (server) await new Promise<void>((done) => server!.close(() => done()));
  await new Promise((r) => setTimeout(r, 1000));
  await db?.$disconnect();
  if (made) {
    await admin.query("ROLLBACK");
    assert.match(schema, /^push_api_[a-f0-9]{32}$/);
    await admin.query(`DROP SCHEMA "${schema}" CASCADE`);
  }
  await admin.end();
  console.error = oldError;
  writeFileSync(
    "../docs/audit/ANDROID_PUSH_OPENAPI_RESULTS.json",
    JSON.stringify(
      {
        checkedAt: new Date().toISOString(),
        mode: "Served Swagger/OpenAPI HTTP; real PostgreSQL disposable schema; controlled Firebase identity and FCM boundary; no app/device/UI tests; no application-schema deployment",
        cleanup: made ? "Disposable schema removed" : "No test schema created",
        rows,
      },
      null,
      2,
    ) + "\n",
  );
  console.log(JSON.stringify({ checks: rows.length, cleanup: "complete" }));
}
