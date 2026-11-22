import { spawnSync } from "node:child_process";
import { loadEnvironment, rootPath } from "./environment.mjs";

try {
  const [mode, cli, ...args] = process.argv.slice(2);
  const tools = {
    prisma: "backend/node_modules/prisma/build/index.js",
    tsx: "backend/node_modules/tsx/dist/cli.mjs",
  };
  if (!Object.hasOwn(tools, cli)) throw new Error("Choose prisma or tsx.");
  const env = loadEnvironment(mode);
  if (mode === "device" && env.SHARED_PRODUCTION_SERVICES === "true" && cli === "prisma" &&
    !["generate", "validate", "format", "version", "--version", "-v"].includes(args[0]) &&
    !(args[0] === "migrate" && ["status", "diff"].includes(args[1]))) {
    throw new Error("Device Prisma writes are blocked against shared production services. Use the separately authorized production deployment workflow.");
  }
  if (cli === "prisma" && args[0] === "migrate") {
    // Use the same target checks as server startup, but keep migration execution separate.
    if (mode === "production" && ["status", "deploy", "diff"].includes(args[1])) {
      const { validateDatabaseTargets } = await import("../backend/dist/config/deployment.js");
      validateDatabaseTargets(env);
    }
    if (mode === "production" && !["status", "deploy", "diff"].includes(args[1])) {
      throw new Error("Use migration status, deploy or diff for production.");
    }
    const direct = URL.parse(env.DIRECT_URL || env.DATABASE_URL || "");
    if (!direct) throw new Error("Set DATABASE_URL or DIRECT_URL for the selected database.");
    direct.hostname = direct.hostname.replace(/-pooler(?=\.)/, "");
    direct.searchParams.delete("channel_binding");
    direct.searchParams.delete("pgbouncer");
    env.DATABASE_URL = direct.toString();
  }
  const result = spawnSync(process.execPath, [rootPath(tools[cli]), ...args], {
    cwd: rootPath("backend/"), env, stdio: "inherit",
  });
  if (result.error) throw new Error("Could not start the selected backend tool.");
  process.exitCode = result.status ?? 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
