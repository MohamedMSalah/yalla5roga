import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { routeInventory, swaggerCoverage } from "../src/app.js";

const lib = fileURLToPath(new URL("../../flutter/lib/", import.meta.url));
const constantsFile = path.join(lib, "core/constants/api_constants.dart");
const constantSource = readFileSync(constantsFile, "utf8");
const constants = new Map<string, string>();
function expand(expression: string) {
  return expression.replace(/\$\{Uri\.encodeComponent\([^{}]*\)\}/g, ":param").replace(/\$\{(?:ApiConstants\.)?(\w+)(?:\([^{}]*\))?\}|\$(\w+)/g,
    (_match, expressionName, bareName) => constants.get(expressionName ?? bareName) ?? ":param");
}
for (const match of constantSource.matchAll(/static\s+(?:const\s+(?:String\s+)?|String\s+)(\w+)(?:\([^)]*\))?\s*(?:=|=>)\s*'([^']+)'/g)) {
  constants.set(match[1]!, match[2]!);
}
for (const [name, expression] of constants) {
  let expanded = expression;
  // Some paths reference a constant declared later in the same file.
  for (let i = 0; i < 4; i++) expanded = expand(expanded);
  constants.set(name, expanded);
}
function* dartFiles(dir: string): Iterable<string> {
  for (const item of readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, item.name);
    if (item.isDirectory()) yield* dartFiles(file);
    else if (item.name.endsWith(".dart") && file !== constantsFile) yield file;
  }
}

const transactions: { verb: string; path: string; consumer: string }[] = [];
const references: { path: string; consumer: string }[] = [];
function candidates(expression: string, file: string) {
  const param = ":param";
  if (expression.endsWith("/$kind") && file.endsWith("discover_remote_datasource.dart")) {
    return ["categories", "vibes"].map(kind => expand(expression.replace("$kind", kind)));
  }
  return [expand(expression.replace(/\$\{Uri\.encodeComponent\([^{}]*\)\}/g, param))];
}
for (const file of dartFiles(lib)) {
  const source = readFileSync(file, "utf8");
  const consumer = path.relative(lib, file).replaceAll("\\", "/");
  if (!(consumer.includes("/data/") || /^core\/media\//.test(consumer))) continue;
  const offset = (index: number) => source.slice(0, index).split("\n").length;
  const routeExpression = /(?:'((?:\/api\/|\$\{ApiConstants\.)[^'\n]+)'|ApiConstants\.(\w+)(?:\([^\n;]*?\))?)/g;
  for (const match of source.matchAll(routeExpression)) {
    const routes = match[1] ? candidates(match[1], file) : [constants.get(match[2]!) ?? ""];
    const before = source.slice(Math.max(0, match.index - 240), match.index);
    const verb = /\.(get|post|put|patch|delete)(?:<[^\n]*>)?\(\s*$/.exec(before)?.[1]?.toUpperCase();
    for (const candidate of routes) {
      if (!candidate.startsWith("/api/")) continue;
      const consumerLocation = `${consumer}:${offset(match.index)}`;
      if (verb) transactions.push({ verb, path: candidate, consumer: consumerLocation });
      else references.push({ path: candidate, consumer: consumerLocation });
    }
  }
}
const shape = (value: string) => value.replace(/:[^/]+/g, ":param");
const manual: Record<string, string> = {
  "POST /api/auth/login": "features/auth/data/datasources/auth_remote_datasource.dart (shared _postSession)",
  "POST /api/auth/signup": "features/auth/data/datasources/auth_remote_datasource.dart (shared _postSession)",
  "POST /api/auth/recovery/start": "features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery)",
  "POST /api/auth/recovery/verify": "features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery)",
  "POST /api/auth/recovery/reset": "features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery)",
  "DELETE /api/groups/:id/members/:userId": "features/groups/data/datasources/groups_remote_datasource.dart (removeMember, leaveGroup)",
  "DELETE /api/groups/:id/pending-memberships/:invitationId": "features/groups/data/datasources/groups_remote_datasource.dart (remove pending member)",
  "POST /api/outings/:id/invitations/accept": "features/outings/data/datasources/outings_remote_datasource.dart and the interactive notification handler",
  "POST /api/outings/:id/invitations/decline": "features/outings/data/datasources/outings_remote_datasource.dart and the interactive notification handler",
  "POST /api/outings/:id/vote-options": "No Flutter write call located. Creation embeds initial options in POST /api/outings.",
  "PUT /api/outings/:id/vote-options": "No Flutter write call located. Revote writes through POST /api/outings/:id/voting/revote.",
  "POST /api/places": "No Flutter write call located. Device-local places use SQLite.",
  "POST /api/users/sync": "features/auth/data/datasources/auth_remote_datasource.dart (shared _postUser)",
  "DELETE /api/groups/:id": "features/groups/data/datasources/groups_remote_datasource.dart (delete with detail path)",
  "PATCH /api/outings/:outingId/messages/:messageId": "features/chat/data/datasources/outing_chat_remote_datasource.dart (editMessage)",
  "DELETE /api/outings/:outingId/messages/:messageId": "features/chat/data/datasources/outing_chat_remote_datasource.dart (deleteMessage)",
  "PUT /api/outings/:id/arrivals/self": "features/outings/data/datasources/outing_arrivals_remote_datasource.dart (recordSelf)",
};
const api = routeInventory.filter(route => route.path.startsWith("/api/"));
const lines = [
  "# API route and Flutter consumer inventory", "",
  `The Express router registers ${api.length} API operations in this configuration. Swagger documents ${swaggerCoverage.documentedApiRoutes}. Development mock-storage helpers are intentionally absent from Swagger.`, "",
  "Regenerate with `pnpm audit:routes` from `backend`. Direct matches show the library-relative Flutter file and line. Indirect path references require call-site review. A missing Flutter match leaves the operation available to Swagger, administrative tools, external clients and older releases.", "",
  "| Method | API route | Flutter consumer evidence |", "| --- | --- | --- |",
];
for (const { method, path } of api.sort((a, b) => a.path.localeCompare(b.path) || a.method.localeCompare(b.method))) {
  const direct = transactions.filter(row => row.verb === method && shape(row.path) === shape(path));
  const indirect = references.filter(row => shape(row.path) === shape(path));
  const consumer = direct.length ? [...new Set(direct.map(row => row.consumer))].join("<br>")
    : manual[`${method} ${path}`] ?? (indirect.length ? `Indirect path reference in ${[...new Set(indirect.map(row => row.consumer.split(":")[0]))].join(", ")}`
      : path.includes("/mock-") ? "Development storage adapter via returned URL" : "No static Flutter consumer located");
  lines.push(`| ${method} | \`${path}\` | ${consumer} |`);
}
lines.push("", "HTTP infrastructure routes", "",
  "| Surface | Consumer |", "| --- | --- |",
  "| GET `/`, `/health`, `/health/live`, `/health/ready` | Hosting probes and operator checks |",
  "| GET `/health/dependencies`, `/metrics` | Authenticated operator and Prometheus |",
  "| GET `/api-docs/openapi.json`, Swagger UI | Developer tooling and contract suite |",
  "| POST `/monitoring/mobile` | Optional Flutter MobileTelemetry batches |",
  "| `/socket.io` | Shared Flutter OutingChatSocketClient |",
);
process.stdout.write(lines.join("\n") + "\n");
