import "dotenv/config";

const BASE = process.env.API_BASE ?? "http://localhost:3000";
const email = "mm.6800771@gmail.com";
const password = "M0h@med74#";

const results = [];

async function call(name, method, path, { token, body, expect } = {}) {
  const headers = { Accept: "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  let parsed;
  const text = await res.text();
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = { raw: text.slice(0, 300) };
  }

  const ok =
    expect === undefined
      ? res.status >= 200 && res.status < 300
      : Array.isArray(expect)
        ? expect.includes(res.status)
        : res.status === expect;

  results.push({
    name,
    method,
    path,
    status: res.status,
    ok,
    message: parsed?.message ?? null,
    dataPreview: JSON.stringify(parsed?.data ?? parsed).slice(0, 180),
  });

  console.log(`${ok ? "PASS" : "FAIL"} [${res.status}] ${method} ${name}`);
  if (!ok) console.log("  ", JSON.stringify(parsed).slice(0, 400));
  return { status: res.status, body: parsed, ok };
}

const login = await call("auth/login", "POST", "/api/auth/login", {
  body: { email, password },
  expect: 200,
});
const token = login.body?.data?.idToken;
if (!token) {
  console.error("No token; aborting");
  process.exit(1);
}

console.log("user from login:", login.body?.data?.user ? "present" : "null");
console.log("uid:", login.body?.data?.uid);

await call("system/root", "GET", "/", { expect: 200 });
await call("system/health", "GET", "/health", { expect: 200 });

await call("users/cuser", "GET", "/api/users/cuser", { token, expect: 200 });
await call("users/list", "GET", "/api/users", { token, expect: 200 });
await call("users/getById", "GET", `/api/users/${login.body.data.uid}`, {
  token,
  expect: 200,
});
await call("users/update", "PATCH", "/api/users/cuser", {
  token,
  body: { name: "MESO" },
  expect: 200,
});

const group = await call("groups/create", "POST", "/api/groups", {
  token,
  body: { name: "API Sweep Group", bio: "test group" },
  expect: 201,
});
const groupId = group.body?.data?.id;

await call("groups/cuser", "GET", "/api/groups/cuser", { token, expect: 200 });
await call("groups/list", "GET", "/api/groups", { token, expect: 200 });
await call("groups/get", "GET", `/api/groups/${groupId}`, { token, expect: 200 });
await call("groups/members", "GET", `/api/groups/${groupId}/members`, {
  token,
  expect: 200,
});
await call("groups/update", "PATCH", `/api/groups/${groupId}`, {
  token,
  body: { bio: "updated bio" },
  expect: 200,
});
await call("groups/invite", "POST", `/api/groups/${groupId}/invitations`, {
  token,
  body: { phoneNumber: "+201100000099" },
  expect: [201, 200, 409, 400],
});

const place = await call("places/create", "POST", "/api/places", {
  token,
  body: {
    name: "Sweep Cafe",
    area: "Downtown",
    vibe: "food",
    description: "API sweep place",
    price_level: "budget",
    latitude: 30.0444,
    longitude: 31.2357,
  },
  expect: 201,
});
const placeId = place.body?.data?.id;

await call("places/list", "GET", "/api/places", { expect: 200 });
await call(
  "places/nearby",
  "GET",
  "/api/places/nearby?lat=30.0444&lng=31.2357&radiusKm=5",
  { expect: 200 },
);
await call("places/get", "GET", `/api/places/${placeId}`, { expect: 200 });
await call("places/update", "PATCH", `/api/places/${placeId}`, {
  token,
  body: { description: "updated place" },
  expect: 200,
});

const hourClosed = await call(
  "places/setHour-closed",
  "PUT",
  `/api/places/${placeId}/hours`,
  {
    token,
    body: { day: "sunday", is_closed: true },
    expect: [200, 201],
  },
);
const hour = await call("places/setHour", "PUT", `/api/places/${placeId}/hours`, {
  token,
  body: { day: "monday", opens_at: "09:00", closes_at: "23:00" },
  expect: [200, 201],
});
await call("places/setHour-invalid", "PUT", `/api/places/${placeId}/hours`, {
  token,
  body: { day: "tuesday", is_closed: false },
  expect: 400,
});
await call("places/getHours", "GET", `/api/places/${placeId}/hours`, {
  expect: 200,
});

const image = await call("places/addImage", "POST", `/api/places/${placeId}/images`, {
  token,
  body: { image_url: "https://example.com/cafe.jpg", caption: "front" },
  expect: 201,
});
await call("places/getImages", "GET", `/api/places/${placeId}/images`, {
  expect: 200,
});

const price = await call("places/addPrice", "POST", `/api/places/${placeId}/prices`, {
  token,
  body: { label: "Coffee", amount: 50, currency: "EGP" },
  expect: 201,
});
await call("places/getPrices", "GET", `/api/places/${placeId}/prices`, {
  expect: 200,
});

const badOuting = await call("outings/create-invalid", "POST", "/api/outings", {
  token,
  body: { title: "No Group" },
  expect: 400,
});

const scheduled = new Date(Date.now() + 2 * 24 * 3600 * 1000).toISOString();
const outing = await call("outings/create", "POST", "/api/outings", {
  token,
  body: {
    title: "Sweep Outing",
    group_id: groupId,
    scheduled_at: scheduled,
    location_place_id: placeId,
    location_name: "Sweep Cafe",
  },
  expect: 201,
});
const outingId = outing.body?.data?.id;

const special = await call("outings/create-special", "POST", "/api/outings", {
  token,
  body: {
    title: "Bday Party",
    occasion: "birthday",
    scheduled_at: scheduled,
  },
  expect: 201,
});

await call("outings/cuser", "GET", "/api/outings/cuser", { token, expect: 200 });
await call("outings/list", "GET", "/api/outings", { token, expect: 200 });
await call("outings/get", "GET", `/api/outings/${outingId}`, { token, expect: 200 });
await call("outings/update", "PATCH", `/api/outings/${outingId}`, {
  token,
  body: { location_area: "Cairo" },
  expect: 200,
});

await call("outings/attendance/get", "GET", `/api/outings/${outingId}/attendance`, {
  token,
  expect: 200,
});
await call("outings/attendance/set", "PUT", `/api/outings/${outingId}/attendance`, {
  token,
  body: { status: "going" },
  expect: [200, 201],
});

await call("outings/guests/list", "GET", `/api/outings/${outingId}/guests`, {
  token,
  expect: 200,
});

const voteOpt = await call(
  "outings/vote-options/add",
  "POST",
  `/api/outings/${outingId}/vote-options`,
  {
    token,
    body: {
      place_id: placeId,
      label: "Sweep Cafe",
      area: "Downtown",
      vibe: "food",
    },
    expect: 201,
  },
);
const optionId = voteOpt.body?.data?.id;
await call("outings/vote-options/list", "GET", `/api/outings/${outingId}/vote-options`, {
  token,
  expect: 200,
});
await call("outings/votes/cast", "POST", `/api/outings/${outingId}/votes`, {
  token,
  body: { option_id: optionId },
  expect: [200, 201],
});
await call("outings/votes/list", "GET", `/api/outings/${outingId}/votes`, {
  token,
  expect: 200,
});

await call("outings/save", "POST", `/api/outings/${outingId}/save`, {
  token,
  expect: 201,
});
await call("outings/saved", "GET", "/api/outings/saved", { token, expect: 200 });
await call("outings/unsave", "DELETE", `/api/outings/${outingId}/save`, {
  token,
  expect: 200,
});

const draft = await call("outings/drafts/create", "POST", "/api/outings/drafts", {
  token,
  body: { title: "Draft Two", vibe: "movie" },
  expect: 201,
});
const draftId = draft.body?.data?.id;
await call("outings/drafts/list", "GET", "/api/outings/drafts", {
  token,
  expect: 200,
});
await call("outings/drafts/update", "PATCH", `/api/outings/drafts/${draftId}`, {
  token,
  body: { title: "Draft Ed" },
  expect: 200,
});

await call("notifications/list", "GET", "/api/notifications", {
  token,
  expect: 200,
});

await call("chat/list", "GET", `/api/chat/outings/${outingId}/messages`, {
  token,
  expect: 200,
});
await call("chat/send", "POST", `/api/chat/outings/${outingId}/messages`, {
  token,
  body: { text: "Hello from API sweep" },
  expect: 201,
});

// cleanup non-destructive order
await call("outings/votes/unvote", "DELETE", `/api/outings/${outingId}/votes/${optionId}`, {
  token,
  expect: [200, 204],
});
await call(
  "outings/vote-options/delete",
  "DELETE",
  `/api/outings/${outingId}/vote-options/${optionId}`,
  { token, expect: 200 },
);
await call("outings/drafts/delete", "DELETE", `/api/outings/drafts/${draftId}`, {
  token,
  expect: 200,
});
if (image.body?.data?.id) {
  await call(
    "places/removeImage",
    "DELETE",
    `/api/places/${placeId}/images/${image.body.data.id}`,
    { token, expect: 200 },
  );
}
if (price.body?.data?.id) {
  await call(
    "places/removePrice",
    "DELETE",
    `/api/places/${placeId}/prices/${price.body.data.id}`,
    { token, expect: 200 },
  );
}
if (hour.body?.data?.id) {
  await call(
    "places/removeHour",
    "DELETE",
    `/api/places/${placeId}/hours/${hour.body.data.id}`,
    { token, expect: 200 },
  );
}
if (hourClosed.body?.data?.id) {
  await call(
    "places/removeHour-closed",
    "DELETE",
    `/api/places/${placeId}/hours/${hourClosed.body.data.id}`,
    { token, expect: 200 },
  );
}

await call("outings/delete", "DELETE", `/api/outings/${outingId}`, {
  token,
  expect: 200,
});
if (special.body?.data?.id) {
  await call("outings/delete-special", "DELETE", `/api/outings/${special.body.data.id}`, {
    token,
    expect: 200,
  });
}
await call("places/delete", "DELETE", `/api/places/${placeId}`, {
  token,
  expect: 200,
});
await call("groups/delete", "DELETE", `/api/groups/${groupId}`, {
  token,
  expect: 200,
});

const failed = results.filter((r) => !r.ok);
console.log("\n==== SUMMARY ====");
console.log(`total=${results.length} pass=${results.length - failed.length} fail=${failed.length}`);
if (failed.length) {
  for (const f of failed) {
    console.log(`FAIL ${f.method} ${f.name} => ${f.status} ${f.message ?? ""}`);
  }
  process.exitCode = 1;
}
