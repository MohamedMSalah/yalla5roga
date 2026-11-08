import { swaggerSpec } from "../src/config/swagger.js";
import app from "../src/app.js";

type Op = {
  method: string;
  path: string;
  tags: string[];
  summary: string;
  description?: string;
  operationId: string;
};

const spec = swaggerSpec as {
  tags?: Array<{ name: string }>;
  paths?: Record<string, Record<string, Record<string, unknown>>>;
};

const expectedTags = [
  "System",
  "Authentication",
  "Users",
  "Groups",
  "Outings",
  "Saved Outings",
  "Places",
  "Notifications",
  "Chat",
];

const tags = (spec.tags || []).map((t) => t.name);
console.log("=== TAG ORDER ===");
console.log("actual:  ", tags.join(" | "));
console.log("expected:", expectedTags.join(" | "));
console.log("tagsOk:", JSON.stringify(tags) === JSON.stringify(expectedTags));

const paths = spec.paths || {};
const ops: Op[] = [];
for (const [p, methods] of Object.entries(paths)) {
  for (const [m, op] of Object.entries(methods)) {
    if (!["get", "post", "put", "patch", "delete"].includes(m)) continue;
    ops.push({
      method: m.toUpperCase(),
      path: p,
      tags: (op.tags as string[]) || [],
      summary: (op.summary as string) || "",
      description: op.description as string | undefined,
      operationId: (op.operationId as string) || "",
    });
  }
}

console.log("\n=== ENDPOINT COUNT ===");
console.log("total operations:", ops.length);

const byTag: Record<string, number> = {};
for (const op of ops) {
  for (const t of op.tags) byTag[t] = (byTag[t] || 0) + 1;
}
console.log("by tag:", byTag);

const unknownTags = ops.filter((o) =>
  o.tags.some((t) => !expectedTags.includes(t)),
);
console.log(
  "unknown tags:",
  unknownTags.length
    ? unknownTags.map((o) => `${o.method} ${o.path} -> ${o.tags}`)
    : "none",
);

const missingSummary = ops.filter((o) => !o.summary);
const missingDescription = ops.filter((o) => !o.description);
console.log("missing summary:", missingSummary.length);
console.log("missing description:", missingDescription.length);
if (missingDescription.length) {
  for (const o of missingDescription) {
    console.log(`  ${o.method} ${o.path}`);
  }
}

const opIds = ops.map((o) => o.operationId);
const dupIds = [...new Set(opIds.filter((id, i) => id && opIds.indexOf(id) !== i))];
console.log("duplicate operationIds:", dupIds.length ? dupIds : "none");

console.log("\n=== OPS BY TAG ===");
for (const tag of expectedTags) {
  console.log(`\n[${tag}]`);
  for (const op of ops.filter((o) => o.tags.includes(tag))) {
    console.log(`  ${op.method.padEnd(7)}${op.path} — ${op.summary}`);
  }
}

type RouteInfo = { methods: string[]; path: string };

function collectRoutes(stack: unknown[], prefix = ""): RouteInfo[] {
  const out: RouteInfo[] = [];
  for (const layerUnknown of stack) {
    const layer = layerUnknown as {
      route?: { path: string; methods: Record<string, boolean> };
      name?: string;
      handle?: { stack?: unknown[] };
      keys?: Array<{ name: string }>;
      regexp?: { source: string };
      path?: string;
    };

    if (layer.route) {
      out.push({
        methods: Object.keys(layer.route.methods)
          .filter(Boolean)
          .map((m) => m.toUpperCase()),
        path: prefix + layer.route.path,
      });
      continue;
    }

    if (layer.name === "router" && layer.handle?.stack) {
      const mount = typeof layer.path === "string" ? layer.path : "";
      out.push(...collectRoutes(layer.handle.stack, prefix + mount));
    }
  }
  return out;
}

const appAny = app as unknown as {
  _router?: { stack?: unknown[] };
  router?: { stack?: unknown[] };
};
const stack = appAny._router?.stack || appAny.router?.stack || [];
const routes = collectRoutes(stack);

console.log("\n=== REGISTERED ROUTES (sample critical) ===");
const critical = [
  "/api/users/cuser",
  "/api/users/:id",
  "/api/users/sync",
  "/api/users/cuser/fcm-token",
  "/api/groups/cuser",
  "/api/groups/:id",
  "/api/groups/invitations/:invitationId/decline",
  "/api/outings/cuser",
  "/api/outings/drafts",
  "/api/outings/saved",
  "/api/outings/:id",
  "/api/outings/:outingId/messages",
  "/api/outings/:outingId/read",
  "/api/places/nearby",
  "/api/places/saved",
  "/api/places/:id",
];

for (const needle of critical) {
  const matches = routes.filter((r) => r.path === needle || r.path.endsWith(needle));
  console.log(
    needle,
    matches.length
      ? matches.map((m) => `${m.methods.join(",")} ${m.path}`).join(" | ")
      : "NOT FOUND in flattened list",
  );
}

console.log("\n=== ROUTE ORDER CHECKS (relative) ===");
function firstIndex(substr: string): number {
  return routes.findIndex((r) => r.path.includes(substr));
}

const checks: Array<[string, string, string]> = [
  ["users cuser before :id", "/api/users/cuser", "/api/users/:id"],
  ["users sync before :id", "/api/users/sync", "/api/users/:id"],
  ["groups cuser before :id", "/api/groups/cuser", "/api/groups/:id"],
  [
    "groups invitations decline before :id",
    "/api/groups/invitations/:invitationId/decline",
    "/api/groups/:id",
  ],
  ["outings cuser before :id", "/api/outings/cuser", "/api/outings/:id"],
  ["outings drafts before :id", "/api/outings/drafts", "/api/outings/:id"],
  ["outings saved before :id", "/api/outings/saved", "/api/outings/:id"],
  [
    "outings messages before bare :id",
    "/api/outings/:outingId/messages",
    "/api/outings/:id",
  ],
  ["places nearby before :id", "/api/places/nearby", "/api/places/:id"],
  ["places saved before :id", "/api/places/saved", "/api/places/:id"],
  [
    "users fcm before :id",
    "/api/users/cuser/fcm-token",
    "/api/users/:id",
  ],
];

for (const [label, a, b] of checks) {
  const ia = firstIndex(a);
  const ib = firstIndex(b);
  console.log(
    `${label}: ${ia >= 0 && ib >= 0 && ia < ib ? "OK" : "FAIL"} (a=${ia}, b=${ib})`,
  );
}

console.log("\n=== ALL FLATTENED ROUTES ===");
for (const r of routes) {
  console.log(`  ${r.methods.join(",").padEnd(18)}${r.path}`);
}
