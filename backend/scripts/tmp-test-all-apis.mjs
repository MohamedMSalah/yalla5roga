import "dotenv/config";

const BASE = "http://localhost:3000";
const email = "mm.6800771@gmail.com";
const password = "M0h@med74#";

const results = [];

async function req(method, path, { token, body, expectOk = true } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  let json = null;
  const text = await res.text();
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text.slice(0, 200) };
  }

  const entry = {
    method,
    path,
    status: res.status,
    ok: res.ok,
    success: json?.success,
    message: json?.message ?? null,
  };
  results.push(entry);

  const label = `${method} ${path} -> ${res.status}`;
  if (expectOk && !res.ok) {
    console.log(`FAIL ${label}`, json?.message ?? "");
  } else if (!expectOk && res.ok) {
    console.log(`UNEXPECTED_OK ${label}`);
  } else {
    console.log(`OK   ${label}`);
  }

  return { res, json };
}

function dataOf(json) {
  return json?.data;
}

const login = await req("POST", "/api/auth/login", {
  body: { email, password },
});
if (!login.res.ok || !login.json?.data?.idToken) {
  console.error("Login failed; aborting.");
  console.log(JSON.stringify(login.json, null, 2));
  process.exit(1);
}

const token = login.json.data.idToken;
const uid = login.json.data.uid;
console.log(`Authenticated uid=${uid}`);

// System
await req("GET", "/");
await req("GET", "/health");

// Users
const cuser = await req("GET", "/api/users/cuser", { token });
await req("POST", "/api/users/sync", { token, body: {} });
await req("PATCH", "/api/users/cuser", {
  token,
  body: { name: "MESO" },
});
await req("GET", "/api/users", { token });
await req("GET", `/api/users/${uid}`, { token });

// Groups
const groupCreate = await req("POST", "/api/groups", {
  token,
  body: { name: "API Test Group", bio: "smoke test" },
});
const groupId = dataOf(groupCreate.json)?.id;
await req("GET", "/api/groups/cuser", { token });
await req("GET", "/api/groups", { token });
if (groupId) {
  await req("GET", `/api/groups/${groupId}`, { token });
  await req("PATCH", `/api/groups/${groupId}`, {
    token,
    body: { bio: "updated bio" },
  });
  await req("GET", `/api/groups/${groupId}/members`, { token });
  await req("POST", `/api/groups/${groupId}/invitations`, {
    token,
    body: { phoneNumber: "+201000000099" },
  });
}

// Places
await req("GET", "/api/places", { token });
await req("GET", "/api/places/nearby?lat=30.0444&lng=31.2357&radiusKm=5", {
  token,
});
const placeCreate = await req("POST", "/api/places", {
  token,
  body: {
    name: "API Test Cafe",
    area: "Downtown",
    vibe: "food",
    latitude: 30.0444,
    longitude: 31.2357,
  },
});
const placeId = dataOf(placeCreate.json)?.id;
let hourId = null;
let imageId = null;
let priceId = null;
if (placeId) {
  await req("GET", `/api/places/${placeId}`, { token });
  await req("PATCH", `/api/places/${placeId}`, {
    token,
    body: { description: "smoke place" },
  });
  await req("GET", `/api/places/${placeId}/hours`, { token });
  const hour = await req("PUT", `/api/places/${placeId}/hours`, {
    token,
    body: { day: "monday", opens_at: "09:00", closes_at: "22:00" },
  });
  hourId = dataOf(hour.json)?.id;
  await req("GET", `/api/places/${placeId}/images`, { token });
  const image = await req("POST", `/api/places/${placeId}/images`, {
    token,
    body: { image_url: "https://example.com/place.jpg" },
  });
  imageId = dataOf(image.json)?.id;
  await req("GET", `/api/places/${placeId}/prices`, { token });
  const price = await req("POST", `/api/places/${placeId}/prices`, {
    token,
    body: { label: "Coffee", amount: 50, currency: "EGP" },
  });
  priceId = dataOf(price.json)?.id;
}

// Outings + drafts
await req("GET", "/api/outings/cuser", { token });
await req("GET", "/api/outings", { token });
await req("GET", "/api/outings/drafts", { token });
const draftCreate = await req("POST", "/api/outings/drafts", {
  token,
  body: { title: "Draft Test", group_id: groupId ?? null },
});
const draftId = dataOf(draftCreate.json)?.id;
if (draftId) {
  await req("PATCH", `/api/outings/drafts/${draftId}`, {
    token,
    body: { title: "Draft Edit" },
  });
}

const outingCreate = await req("POST", "/api/outings", {
  token,
  body: groupId
    ? {
        title: "API Outing",
        group_id: groupId,
        occasion: "none",
        location_name: "Cairo",
      }
    : {
        title: "API Outing",
        occasion: "birthday",
        location_name: "Cairo",
      },
});
const outingId = dataOf(outingCreate.json)?.id;
let optionId = null;
if (outingId) {
  await req("GET", `/api/outings/${outingId}`, { token });
  await req("PATCH", `/api/outings/${outingId}`, {
    token,
    body: { title: "API Outing 2" },
  });

  await req("GET", `/api/outings/${outingId}/attendance`, { token });
  await req("PUT", `/api/outings/${outingId}/attendance`, {
    token,
    body: { status: "going" },
  });

  await req("GET", `/api/outings/${outingId}/guests`, { token });
  // Self as guest may fail; still exercise endpoint contract.
  await req("POST", `/api/outings/${outingId}/guests`, {
    token,
    body: { user_id: uid },
    expectOk: false,
  });

  await req("GET", `/api/outings/${outingId}/vote-options`, { token });
  const option = await req("POST", `/api/outings/${outingId}/vote-options`, {
    token,
    body: {
      label: "Option A",
      area: "Nasr City",
      vibe: "food",
      place_id: placeId ?? null,
    },
  });
  optionId = dataOf(option.json)?.id;

  await req("GET", `/api/outings/${outingId}/votes`, { token });
  if (optionId) {
    await req("POST", `/api/outings/${outingId}/votes`, {
      token,
      body: { option_id: optionId },
    });
    await req("DELETE", `/api/outings/${outingId}/votes/${optionId}`, {
      token,
    });
    await req("DELETE", `/api/outings/${outingId}/vote-options/${optionId}`, {
      token,
    });
  }

  // Saved
  await req("POST", `/api/outings/${outingId}/save`, { token });
  await req("GET", "/api/outings/saved", { token });
  await req("DELETE", `/api/outings/${outingId}/save`, { token });

  // Chat
  await req("GET", `/api/chat/outings/${outingId}/messages`, { token });
  await req("POST", `/api/chat/outings/${outingId}/messages`, {
    token,
    body: { text: "hello from api smoke test" },
  });
}

// Notifications
const notifs = await req("GET", "/api/notifications", { token });
const firstNotif = Array.isArray(dataOf(notifs.json))
  ? dataOf(notifs.json)[0]
  : null;
if (firstNotif?.id) {
  await req("PATCH", `/api/notifications/${firstNotif.id}/read`, { token });
} else {
  results.push({
    method: "PATCH",
    path: "/api/notifications/:id/read",
    status: "skipped",
    ok: true,
    success: true,
    message: "no notifications to mark read",
  });
  console.log("SKIP PATCH /api/notifications/:id/read (none)");
}

// Decline invitation with a fake UUID (expect 404)
await req(
  "POST",
  "/api/groups/invitations/11111111-1111-4111-8111-111111111111/decline",
  { token, expectOk: false },
);

// Cleanup created resources (keep user)
if (draftId) {
  await req("DELETE", `/api/outings/drafts/${draftId}`, { token });
}
if (outingId) {
  await req("DELETE", `/api/outings/${outingId}`, { token });
}
if (imageId && placeId) {
  await req("DELETE", `/api/places/${placeId}/images/${imageId}`, { token });
}
if (priceId && placeId) {
  await req("DELETE", `/api/places/${placeId}/prices/${priceId}`, { token });
}
if (hourId && placeId) {
  await req("DELETE", `/api/places/${placeId}/hours/${hourId}`, { token });
}
if (placeId) {
  await req("DELETE", `/api/places/${placeId}`, { token });
}
if (groupId) {
  await req("DELETE", `/api/groups/${groupId}`, { token });
}

const failed = results.filter(
  (r) =>
    r.status !== "skipped" &&
    r.expectOk !== false &&
    typeof r.status === "number" &&
    r.status >= 400 &&
    // expected non-ok calls we marked via console only; recompute:
    !["POST /api/outings/:id/guests", "POST /api/groups/invitations/:id/decline"].some(
      () => false,
    ),
);

// Recount failures more carefully from logged expectOk
const summary = {
  total: results.length,
  http2xx: results.filter((r) => typeof r.status === "number" && r.status < 300)
    .length,
  http4xx: results.filter(
    (r) => typeof r.status === "number" && r.status >= 400 && r.status < 500,
  ).length,
  http5xx: results.filter((r) => typeof r.status === "number" && r.status >= 500)
    .length,
  skipped: results.filter((r) => r.status === "skipped").length,
};

console.log("\n=== SUMMARY ===");
console.log(JSON.stringify(summary, null, 2));

const unexpected = results.filter((r) => {
  if (r.status === "skipped") return false;
  if (r.method === "POST" && r.path.includes("/guests") && r.status >= 400)
    return false;
  if (r.path.includes("/invitations/") && r.path.includes("/decline") && r.status >= 400)
    return false;
  return typeof r.status === "number" && r.status >= 400;
});

if (unexpected.length) {
  console.log("\n=== UNEXPECTED FAILURES ===");
  console.log(JSON.stringify(unexpected, null, 2));
  process.exitCode = 1;
} else {
  console.log("\nAll exercised endpoints behaved as expected.");
}
