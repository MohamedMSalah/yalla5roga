import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { readEnvironment, rootPath } from "./environment.mjs";

try {
  const { MONITORING_TOKEN: token, GRAFANA_ADMIN_PASSWORD: password } = readEnvironment("device");
  if (!token || token.length < 24 || /\r|\n/.test(token) || !password) {
    throw new Error("Set MONITORING_TOKEN (24+ characters) and GRAFANA_ADMIN_PASSWORD in .env.device.");
  }
  const directory = rootPath("backend/monitoring/");
  writeFileSync(rootPath("backend/monitoring/monitoring-token.local"), token, { mode: 0o600 });
  const result = spawnSync("docker", ["compose", "-f", "compose.yml", "--profile", "monitoring", "up", "-d"], {
    cwd: directory, env: { ...process.env, GRAFANA_ADMIN_PASSWORD: password }, stdio: "inherit",
  });
  if (result.error) throw new Error("Install or start Docker with Compose before starting monitoring.");
  process.exitCode = result.status ?? 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
