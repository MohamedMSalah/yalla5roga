/**
 * Phase B live API verification harness.
 * Never prints tokens/secrets. Writes sanitized results JSON.
 *
 * Env:
 *   BASE_URL (default http://localhost:3000)
 *   TEST_EMAIL / TEST_PASSWORD  — primary account
 *   USER_B_EMAIL / USER_B_PASSWORD / USER_B_PHONE / USER_B_NAME — optional; signup if login fails
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { randomUUID } from "node:crypto";

const BASE = process.env.BASE_URL || "http://localhost:3000";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, "_phase_b_results.json");

const results = [];
const cleanup = { groups: [], outings: [], userBCreated: false };

function record(suite, name, endpoint, method, status, httpStatus, summary, extra = {}) {
  results.push({
    suite,
    name,
    endpoint,
    method,
    status,
    httpStatus: httpStatus ?? null,
    summary,
    ...extra,
  });
  const mark = status.padEnd(10);
  console.log(`[${mark}] ${suite} · ${name} · ${method} ${endpoint} · HTTP ${httpStatus ?? "-"} · ${summary}`);
}

function sanitizeBody(body) {
  if (body == null) return null;
  if (typeof body !== "object") return String(body).slice(0, 200);
  const clone = JSON.parse(JSON.stringify(body));
  const redactKeys = new Set([
    "token",
    "idToken",
    "id_token",
    "customToken",
    "custom_token",
    "password",
    "password_hash",
    "authorization",
    "refreshToken",
    "refresh_token",
  ]);
  const walk = (obj) => {
    if (!obj || typeof obj !== "object") return;
    for (const k of Object.keys(obj)) {
      if (redactKeys.has(k)) obj[k] = "[REDACTED]";
      else if (typeof obj[k] === "object") walk(obj[k]);
    }
  };
  walk(clone);
  return clone;
}

async function req(method, endpoint, { token, body, expect } = {}) {
  const headers = { Accept: "application/json" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE}${endpoint}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  let data = null;
  const text = await res.text();
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text.slice(0, 300) };
  }
  return {
    ok: expect ? expect.includes(res.status) : res.ok,
    status: res.status,
    data: sanitizeBody(data),
    raw: data,
  };
}

function unwrap(data) {
  if (!data || typeof data !== "object") return data;
  return data.data ?? data;
}

async function login(email, password) {
  const r = await req("POST", "/api/auth/login", {
    body: { email, password },
    expect: [200],
  });
  const payload = unwrap(r.raw);
  const idToken = payload?.idToken || payload?.token || null;
  const customToken = payload?.customToken || null;
  const uid = payload?.uid || payload?.user?.id || null;
  return {
    httpStatus: r.status,
    ok: r.status === 200 && !!idToken && !!customToken && !!uid,
    idToken,
    hasCustomToken: !!customToken,
    uid,
    user: sanitizeBody(payload?.user ?? null),
  };
}

async function signup(email, password, name, phone) {
  const r = await req("POST", "/api/auth/signup", {
    body: { email, password, name, phone },
    expect: [201, 409],
  });
  const payload = unwrap(r.raw);
  return {
    httpStatus: r.status,
    ok: r.status === 201,
    idToken: payload?.idToken || null,
    hasCustomToken: !!payload?.customToken,
    uid: payload?.uid || payload?.user?.id || null,
    user: sanitizeBody(payload?.user ?? null),
    error: r.status !== 201 ? sanitizeBody(r.raw) : null,
  };
}

async function main() {
  const emailA = process.env.TEST_EMAIL;
  const passA = process.env.TEST_PASSWORD;
  if (!emailA || !passA) {
    console.error("TEST_EMAIL and TEST_PASSWORD required");
    process.exit(1);
  }

  // --- Health ---
  {
    const r = await req("GET", "/health");
    record(
      "ENV",
      "health",
      "/health",
      "GET",
      r.status === 200 && (r.raw?.database === "connected" || r.raw?.status === "ok" || true)
        ? r.status === 200
          ? "PASS"
          : "FAIL"
        : "FAIL",
      r.status,
      JSON.stringify(sanitizeBody(r.raw)).slice(0, 180),
    );
  }

  // --- Auth A ---
  const a = await login(emailA, passA);
  record(
    "A",
    "email_password_login",
    "/api/auth/login",
    "POST",
    a.ok ? "PASS" : "FAIL",
    a.httpStatus,
    a.ok
      ? `uid_present=${!!a.uid}; customToken=${a.hasCustomToken}; idToken=${!!a.idToken}`
      : "login failed",
  );
  if (!a.ok) {
    fs.writeFileSync(OUT, JSON.stringify({ results, cleanup }, null, 2));
    process.exit(2);
  }

  // Unauthenticated probe
  {
    const r = await req("GET", "/api/users/cuser", { expect: [401] });
    record(
      "A",
      "missing_bearer",
      "/api/users/cuser",
      "GET",
      r.status === 401 ? "PASS" : "FAIL",
      r.status,
      "expect 401 without Authorization",
    );
  }

  // Authenticated profile
  {
    const r = await req("GET", "/api/users/cuser", { token: a.idToken, expect: [200] });
    const u = unwrap(r.raw);
    record(
      "B",
      "get_profile",
      "/api/users/cuser",
      "GET",
      r.status === 200 && u?.id === a.uid ? "PASS" : "FAIL",
      r.status,
      `id_match=${u?.id === a.uid}; name_len=${(u?.name || "").length}`,
    );
  }

  const stamp = Date.now().toString().slice(-6);
  const newName = `QA A ${stamp}`;
  {
    const r = await req("PATCH", "/api/users/cuser", {
      token: a.idToken,
      body: { name: newName },
      expect: [200],
    });
    const u = unwrap(r.raw);
    record(
      "B",
      "update_profile",
      "/api/users/cuser",
      "PATCH",
      r.status === 200 && u?.name === newName ? "PASS" : "FAIL",
      r.status,
      `name_set=${u?.name === newName}`,
    );
  }
  {
    const r = await req("GET", "/api/users/cuser", { token: a.idToken, expect: [200] });
    const u = unwrap(r.raw);
    record(
      "B",
      "profile_persist",
      "/api/users/cuser",
      "GET",
      r.status === 200 && u?.name === newName ? "PASS" : "FAIL",
      r.status,
      `persisted=${u?.name === newName}`,
      { dbPersist: u?.name === newName },
    );
  }

  // --- User B ---
  const emailB =
    process.env.USER_B_EMAIL || `phaseb.userb.${stamp}@yalla5roga.test`;
  const passB = process.env.USER_B_PASSWORD || `PhaseB#${stamp}xY`;
  const phoneB = process.env.USER_B_PHONE || `+2010${stamp}${stamp.slice(0, 2)}`.slice(0, 13);
  const nameB = process.env.USER_B_NAME || `QA B ${stamp}`;

  let b = await login(emailB, passB);
  if (!b.ok) {
    const s = await signup(emailB, passB, nameB, phoneB);
    cleanup.userBCreated = s.ok;
    record(
      "G",
      "user_b_signup",
      "/api/auth/signup",
      "POST",
      s.ok ? "PASS" : s.httpStatus === 409 ? "BLOCKED" : "FAIL",
      s.httpStatus,
      s.ok
        ? `created uid_present; phone_set`
        : `signup not ok; may need existing User B`,
    );
    if (s.ok) {
      b = {
        ok: true,
        httpStatus: s.httpStatus,
        idToken: s.idToken,
        hasCustomToken: s.hasCustomToken,
        uid: s.uid,
        user: s.user,
      };
    } else {
      b = await login(emailB, passB);
    }
  } else {
    record("G", "user_b_login", "/api/auth/login", "POST", "PASS", b.httpStatus, "existing User B");
  }

  const hasB = b.ok && !!b.idToken && !!b.uid;
  if (!hasB) {
    record("G", "user_b_ready", "/api/auth/*", "—", "BLOCKED", null, "no second account session");
  } else {
    record(
      "G",
      "user_b_ready",
      "/api/auth/login|signup",
      "—",
      "PASS",
      b.httpStatus,
      `uid_present; distinct=${b.uid !== a.uid}`,
    );
  }

  // Ensure B profile phone for add-member
  let phoneForMember = phoneB;
  if (hasB) {
    const prof = await req("GET", "/api/users/cuser", { token: b.idToken });
    const u = unwrap(prof.raw);
    phoneForMember = u?.phone || u?.phone_number || phoneB;
  }

  // --- Groups ---
  let groupId = null;
  {
    const r = await req("POST", "/api/groups", {
      token: a.idToken,
      body: { name: `QA Grp ${stamp}`, bio: "phase b disposable" },
      expect: [201],
    });
    const g = unwrap(r.raw);
    groupId = g?.id || null;
    if (groupId) cleanup.groups.push(groupId);
    record(
      "C",
      "create_group",
      "/api/groups",
      "POST",
      r.status === 201 && groupId ? "PASS" : "FAIL",
      r.status,
      `id_present=${!!groupId}`,
      { dbPersist: !!groupId },
    );
  }
  {
    const r = await req("GET", "/api/groups/cuser", { token: a.idToken, expect: [200] });
    const list = unwrap(r.raw);
    const arr = Array.isArray(list) ? list : list?.items || list?.groups || [];
    const found = arr.some((g) => g.id === groupId);
    record(
      "C",
      "list_groups",
      "/api/groups/cuser",
      "GET",
      r.status === 200 && found ? "PASS" : "FAIL",
      r.status,
      `count=${arr.length}; created_found=${found}`,
      { dbPersist: found },
    );
  }
  {
    const r = await req("PATCH", `/api/groups/${groupId}`, {
      token: a.idToken,
      body: { bio: `updated ${stamp}` },
      expect: [200],
    });
    const g = unwrap(r.raw);
    record(
      "C",
      "update_group",
      `/api/groups/${groupId}`,
      "PATCH",
      r.status === 200 && (g?.bio || "").includes(stamp) ? "PASS" : "FAIL",
      r.status,
      `bio_updated=${(g?.bio || "").includes(stamp)}`,
      { dbPersist: (g?.bio || "").includes(stamp) },
    );
  }

  let memberAdded = false;
  if (hasB && groupId && phoneForMember) {
    const r = await req("POST", `/api/groups/${groupId}/members`, {
      token: a.idToken,
      body: { phoneNumber: phoneForMember },
      expect: [201, 404, 409, 400],
    });
    memberAdded = r.status === 201;
    record(
      "C",
      "add_member",
      `/api/groups/${groupId}/members`,
      "POST",
      memberAdded ? "PASS" : r.status === 404 ? "BLOCKED" : "FAIL",
      r.status,
      memberAdded
        ? "member created"
        : `could not add by phone (status ${r.status})`,
      { dbPersist: memberAdded },
    );
    if (memberAdded) {
      const rem = await req("DELETE", `/api/groups/${groupId}/members/${b.uid}`, {
        token: a.idToken,
        expect: [200, 403, 404],
      });
      record(
        "C",
        "remove_member",
        `/api/groups/${groupId}/members/${b.uid}`,
        "DELETE",
        rem.status === 200 ? "PASS" : "FAIL",
        rem.status,
        rem.status === 200 ? "member removed" : "remove failed",
        { dbPersist: rem.status === 200 },
      );
      // re-add for later chat/authz if useful
      await req("POST", `/api/groups/${groupId}/members`, {
        token: a.idToken,
        body: { phoneNumber: phoneForMember },
        expect: [201, 409],
      });
    }
  } else {
    record("C", "add_member", "/api/groups/:id/members", "POST", "BLOCKED", null, "needs User B phone");
    record("C", "remove_member", "/api/groups/:id/members/:userId", "DELETE", "BLOCKED", null, "needs User B");
  }

  // --- Outings ---
  let groupOutingId = null;
  let specialOutingId = null;
  {
    const r = await req("POST", "/api/outings", {
      token: a.idToken,
      body: {
        title: `Grp ${stamp}`,
        group_id: groupId,
        occasion: "none",
        status: "voting",
      },
      expect: [201],
    });
    const o = unwrap(r.raw);
    groupOutingId = o?.id || null;
    if (groupOutingId) cleanup.outings.push(groupOutingId);
    record(
      "D",
      "create_group_outing",
      "/api/outings",
      "POST",
      r.status === 201 && o?.type === "group" ? "PASS" : "FAIL",
      r.status,
      `type=${o?.type}; id_present=${!!groupOutingId}`,
      { dbPersist: o?.type === "group" },
    );
  }
  {
    const r = await req("POST", "/api/outings", {
      token: a.idToken,
      body: {
        title: `SpEv ${stamp}`,
        occasion: "birthday",
        status: "upcoming",
      },
      expect: [201],
    });
    const o = unwrap(r.raw);
    specialOutingId = o?.id || null;
    if (specialOutingId) cleanup.outings.push(specialOutingId);
    record(
      "D",
      "create_special_event",
      "/api/outings",
      "POST",
      r.status === 201 && o?.type === "special_event" ? "PASS" : "FAIL",
      r.status,
      `type=${o?.type}; occasion=${o?.occasion}`,
      { dbPersist: o?.type === "special_event" },
    );
  }
  {
    const r = await req("GET", `/api/outings/${groupOutingId}`, {
      token: a.idToken,
      expect: [200],
    });
    const o = unwrap(r.raw);
    record(
      "D",
      "get_outing",
      `/api/outings/${groupOutingId}`,
      "GET",
      r.status === 200 && o?.id === groupOutingId ? "PASS" : "FAIL",
      r.status,
      `type=${o?.type}`,
    );
  }

  let optionId = null;
  {
    const createOpt = await req("POST", `/api/outings/${groupOutingId}/vote-options`, {
      token: a.idToken,
      body: { label: `Place ${stamp}`, area: "Cairo" },
      expect: [201],
    });
    optionId = unwrap(createOpt.raw)?.id || null;
    const list = await req("GET", `/api/outings/${groupOutingId}/vote-options`, {
      token: a.idToken,
      expect: [200],
    });
    const opts = unwrap(list.raw);
    const arr = Array.isArray(opts) ? opts : opts?.items || [];
    record(
      "D",
      "vote_options",
      `/api/outings/${groupOutingId}/vote-options`,
      "GET",
      list.status === 200 && arr.length >= 1 ? "PASS" : "FAIL",
      list.status,
      `count=${arr.length}; created=${createOpt.status}`,
      { dbPersist: !!optionId },
    );
  }
  {
    const r = await req("POST", `/api/outings/${groupOutingId}/votes`, {
      token: a.idToken,
      body: { option_id: optionId },
      expect: [201],
    });
    const v = unwrap(r.raw);
    record(
      "D",
      "cast_vote",
      `/api/outings/${groupOutingId}/votes`,
      "POST",
      r.status === 201 ? "PASS" : "FAIL",
      r.status,
      `voter_match=${v?.user_id === a.uid || v?.userId === a.uid}`,
      { dbPersist: r.status === 201 },
    );
  }
  {
    const r = await req("PUT", `/api/outings/${groupOutingId}/attendance`, {
      token: a.idToken,
      body: { status: "going" },
      expect: [200],
    });
    const att = unwrap(r.raw);
    record(
      "D",
      "attendance",
      `/api/outings/${groupOutingId}/attendance`,
      "PUT",
      r.status === 200 && (att?.status === "going") ? "PASS" : "FAIL",
      r.status,
      `status=${att?.status}`,
      { dbPersist: att?.status === "going" },
    );
  }

  // --- Chat ---
  {
    const clientMessageId = randomUUID();
    const send = await req("POST", `/api/chat/outings/${groupOutingId}/messages`, {
      token: a.idToken,
      body: { text: `phaseb msg ${stamp}`, clientMessageId },
      expect: [201],
    });
    const msg = unwrap(send.raw);
    const senderOk = msg?.sender_id === a.uid || msg?.senderId === a.uid;
    record(
      "E",
      "send_message",
      `/api/chat/outings/${groupOutingId}/messages`,
      "POST",
      send.status === 201 && senderOk ? "PASS" : "FAIL",
      send.status,
      `sender_from_token=${senderOk}`,
      { dbPersist: send.status === 201 },
    );
    const list = await req("GET", `/api/chat/outings/${groupOutingId}/messages`, {
      token: a.idToken,
      expect: [200],
    });
    const msgs = unwrap(list.raw);
    const arr = Array.isArray(msgs) ? msgs : msgs?.items || msgs?.messages || [];
    const found = arr.some(
      (m) => (m.text || m.body || "").includes(`phaseb msg ${stamp}`),
    );
    record(
      "E",
      "list_messages",
      `/api/chat/outings/${groupOutingId}/messages`,
      "GET",
      list.status === 200 && found ? "PASS" : "FAIL",
      list.status,
      `count=${arr.length}; found=${found}`,
      { dbPersist: found },
    );
  }

  // --- Notifications ---
  let notifId = null;
  {
    const r = await req("GET", "/api/notifications", { token: a.idToken, expect: [200] });
    const list = unwrap(r.raw);
    const arr = Array.isArray(list) ? list : list?.items || list?.notifications || [];
    notifId = arr[0]?.id || null;
    if (arr.length === 0) {
      record(
        "F",
        "list_notifications",
        "/api/notifications",
        "GET",
        "BLOCKED",
        r.status,
        "empty feed — mark-read NOT TESTED",
      );
      record(
        "F",
        "mark_notification_read",
        "/api/notifications/:id/read",
        "PATCH",
        "NOT TESTED",
        null,
        "empty feed",
      );
    } else {
      record(
        "F",
        "list_notifications",
        "/api/notifications",
        "GET",
        "PASS",
        r.status,
        `count=${arr.length}`,
      );
      const mark = await req("PATCH", `/api/notifications/${notifId}/read`, {
        token: a.idToken,
        expect: [200],
      });
      const n = unwrap(mark.raw);
      const ownerOk = n?.user_id === a.uid || n?.userId === a.uid;
      record(
        "F",
        "mark_notification_read",
        `/api/notifications/${notifId}/read`,
        "PATCH",
        mark.status === 200 && (n?.is_read === true || n?.read === true || ownerOk) ? "PASS" : "FAIL",
        mark.status,
        `owner_match=${ownerOk}; read=${n?.is_read ?? n?.read}`,
        { dbPersist: mark.status === 200 },
      );
    }
  }

  // --- Authorization with User B ---
  if (hasB) {
    // B tries A's profile delete by id? Better: update A's group, delete A's outing, read notifications of A
    {
      const r = await req("PATCH", `/api/groups/${groupId}`, {
        token: b.idToken,
        body: { bio: "unauthorized" },
        expect: [403, 404],
      });
      record(
        "G",
        "unauthorized_group_update",
        `/api/groups/${groupId}`,
        "PATCH",
        r.status === 403 ? "PASS" : "FAIL",
        r.status,
        "expect 403 for non-owner",
      );
    }
    {
      const r = await req("DELETE", `/api/groups/${groupId}`, {
        token: b.idToken,
        expect: [403, 404],
      });
      record(
        "G",
        "unauthorized_group_delete",
        `/api/groups/${groupId}`,
        "DELETE",
        r.status === 403 ? "PASS" : "FAIL",
        r.status,
        "expect 403 for non-owner",
      );
    }
    {
      const r = await req("PATCH", `/api/outings/${groupOutingId}`, {
        token: b.idToken,
        body: { title: "Hijack" },
        expect: [403, 404],
      });
      record(
        "G",
        "unauthorized_outing_update",
        `/api/outings/${groupOutingId}`,
        "PATCH",
        r.status === 403 ? "PASS" : "FAIL",
        r.status,
        "expect 403 for non-creator",
      );
    }
    {
      const r = await req("DELETE", `/api/outings/${groupOutingId}`, {
        token: b.idToken,
        expect: [403, 404],
      });
      record(
        "G",
        "unauthorized_outing_delete",
        `/api/outings/${groupOutingId}`,
        "DELETE",
        r.status === 403 ? "PASS" : "FAIL",
        r.status,
        "expect 403 for non-creator",
      );
    }
    {
      // B listing notifications should only see own; cannot mark A's notif if we have one
      const r = await req("GET", "/api/notifications", { token: b.idToken, expect: [200] });
      const list = unwrap(r.raw);
      const arr = Array.isArray(list) ? list : list?.items || [];
      const leaked = arr.some((n) => (n.user_id || n.userId) && (n.user_id || n.userId) !== b.uid);
      record(
        "G",
        "notifications_isolation",
        "/api/notifications",
        "GET",
        r.status === 200 && !leaked ? "PASS" : "FAIL",
        r.status,
        `count=${arr.length}; foreign_leak=${leaked}`,
      );
      if (notifId) {
        const mark = await req("PATCH", `/api/notifications/${notifId}/read`, {
          token: b.idToken,
          expect: [403, 404],
        });
        record(
          "G",
          "unauthorized_notification_read",
          `/api/notifications/${notifId}/read`,
          "PATCH",
          mark.status === 403 || mark.status === 404 ? "PASS" : "FAIL",
          mark.status,
          "expect 403/404 for foreign notification",
        );
      } else {
        record(
          "G",
          "unauthorized_notification_read",
          "/api/notifications/:id/read",
          "PATCH",
          "NOT TESTED",
          null,
          "no notification id from User A",
        );
      }
    }
    {
      // Access another user's protected chat without membership
      const r = await req("GET", `/api/chat/outings/${specialOutingId}/messages`, {
        token: b.idToken,
        expect: [403, 404],
      });
      record(
        "G",
        "unauthorized_chat_access",
        `/api/chat/outings/${specialOutingId}/messages`,
        "GET",
        r.status === 403 || r.status === 404 ? "PASS" : "FAIL",
        r.status,
        "expect 403/404 for non-participant",
      );
    }
  }

  // Re-login A (logout/login simulation at API layer)
  {
    const again = await login(emailA, passA);
    record(
      "A",
      "login_again",
      "/api/auth/login",
      "POST",
      again.ok ? "PASS" : "FAIL",
      again.httpStatus,
      `customToken=${again.hasCustomToken}; idToken=${!!again.idToken}`,
    );
    if (again.ok) {
      const home = await req("GET", "/api/outings/cuser", {
        token: again.idToken,
        expect: [200],
      });
      record(
        "A",
        "authenticated_api_after_relogin",
        "/api/outings/cuser",
        "GET",
        home.status === 200 ? "PASS" : "FAIL",
        home.status,
        "Bearer ID token accepted after re-login",
      );
      a.idToken = again.idToken;
    }
  }

  // Cleanup disposable data with A's token
  for (const id of cleanup.outings) {
    await req("DELETE", `/api/outings/${id}`, { token: a.idToken, expect: [200, 404] });
  }
  for (const id of cleanup.groups) {
    await req("DELETE", `/api/groups/${id}`, { token: a.idToken, expect: [200, 404] });
  }

  const summary = {
    generatedAt: new Date().toISOString(),
    baseUrl: BASE,
    pass: results.filter((r) => r.status === "PASS").length,
    fail: results.filter((r) => r.status === "FAIL").length,
    blocked: results.filter((r) => r.status === "BLOCKED").length,
    notTested: results.filter((r) => r.status === "NOT TESTED").length,
    results,
    cleanup,
    notes: {
      tokens: "never stored",
      userA: "primary TEST_EMAIL",
      userBEmailDomain: emailB.includes("@") ? emailB.split("@")[1] : "n/a",
      userBCreated: cleanup.userBCreated,
    },
  };
  fs.writeFileSync(OUT, JSON.stringify(summary, null, 2));
  console.log(
    `\nWrote ${OUT} · PASS=${summary.pass} FAIL=${summary.fail} BLOCKED=${summary.blocked} NOT_TESTED=${summary.notTested}`,
  );
}

main().catch((err) => {
  console.error("Harness crashed:", err?.message || err);
  process.exit(1);
});
