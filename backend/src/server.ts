import "dotenv/config";
import http from "node:http";
import os from "node:os";
import { once } from "node:events";
import { performance } from "node:perf_hooks";
import app, { swaggerCoverage } from "./app.js";
import { prisma } from "./config/database.js";
import { getMediaConfig } from "./config/media.js";
import { hasAutomaticWhatsApp } from "./config/notifications.js";
import { initFirebase } from "./config/firebase.js";
import { startOutingCompletionJob } from "./jobs/complete-outings.job.js";
import { startVotingDeadlineJob } from "./jobs/close-voting-deadline.job.js";
import { startNotificationWorker } from "./jobs/notification-worker.job.js";
import { startMediaCleanupJob } from "./jobs/media-cleanup.job.js";
import { attachRealtime } from "./realtime/index.js";
import { bindChatEmitter } from "./realtime/chat-emitter.js";
import { startCatalogListener } from "./services/places/catalog-notifications.js";
import { enabled, environment } from "./monitoring/config.js";
import { databaseHealth, dependencyState, privateMonitoringAvailable, setDependency } from "./monitoring/health.js";
import { errorCode, logger } from "./monitoring/logger.js";
import { startMetrics, stopMetrics } from "./monitoring/metrics.js";

const started = performance.now();
const PORT = Number(process.env.PORT?.trim() || 3000);
const HOST = process.env.HOST || "0.0.0.0";
const httpServer = http.createServer(app);
const stops: (() => void | Promise<void>)[] = [];
let realtime: ReturnType<typeof attachRealtime> | undefined;
let stopping = false;
let phase = "environment";

function configuredDatabase() {
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL");
  let url: URL;
  try { url = new URL(process.env.DATABASE_URL); } catch { throw new Error("DATABASE_URL"); }
  if (!["postgres:", "postgresql:"].includes(url.protocol)) throw new Error("DATABASE_URL");
  return url.hostname.endsWith(".neon.tech") ? "Neon PostgreSQL" : "PostgreSQL";
}

async function shutdown(reason: string) {
  if (stopping) return;
  stopping = true;
  setDependency("server", "stopping");
  const deadline = setTimeout(() => {
    logger.error({ reason }, "Graceful shutdown timed out");
    process.exit(1);
  }, 25000);
  deadline.unref();
  let socketCleanup = false;
  const close = new Promise<void>((resolve, reject) => {
    if (realtime) {
      void realtime.close(error => {
        if (error && (error as NodeJS.ErrnoException).code !== "ERR_SERVER_NOT_RUNNING") return reject(error);
        socketCleanup = true;
        resolve();
      });
    } else httpServer.close(() => resolve());
  });
  httpServer.closeIdleConnections();
  const results = await Promise.allSettled([close, ...stops.map(stop => Promise.resolve().then(stop))]);
  bindChatEmitter(null);
  stopMetrics();
  let databaseDisconnected = false;
  try {
    await prisma.$disconnect();
    databaseDisconnected = true;
  } catch (error) {
    logger.error({ errorCode: errorCode(error) }, "Database disconnect failed");
  }
  clearTimeout(deadline);
  const clean = databaseDisconnected && results.every(result => result.status === "fulfilled");
  if (!clean) process.exitCode = 1;
  logger[clean ? "info" : "warn"]({ reason, databaseDisconnected, socketCleanup,
    failedCleanupTasks: results.filter(result => result.status === "rejected").length }, "API server stopped");
}

async function start() {
  const dbKind = configuredDatabase();
  if (!Number.isInteger(PORT) || PORT < 0 || PORT > 65535) throw new Error("PORT");
  if (environment === "production" && process.env.WHATSAPP_PROVIDER === "stub") throw new Error("WHATSAPP_PROVIDER");
  if (environment === "production" && !process.env.CORS_ORIGINS?.trim()) throw new Error("CORS_ORIGINS");

  phase = "database";
  const dbStarted = performance.now();
  await prisma.$connect();
  const connectionMs = performance.now() - dbStarted;
  const probe = await databaseHealth(true);
  if (!probe.available) throw new Error("Database probe failed");

  phase = "firebase";
  const missingFirebase = ["FIREBASE_PROJECT_ID", "FIREBASE_CLIENT_EMAIL", "FIREBASE_PRIVATE_KEY"].filter(key => !process.env[key]);
  let firebaseReady = false;
  try {
    initFirebase();
    firebaseReady = true;
  } catch (error) {
    logger.error({ missing: missingFirebase, errorCode: errorCode(error) }, "Firebase initialization failed");
  }
  setDependency("firebase", firebaseReady ? "ready" : "failed");
  const firebaseClientConfigured = Boolean(process.env.FIREBASE_API_KEY?.trim());
  setDependency("firebase_client", firebaseClientConfigured ? "ready" : "failed");
  if (!firebaseClientConfigured) logger.error({ setting: "FIREBASE_API_KEY" }, "Firebase client session configuration missing");

  phase = "socket";
  realtime = attachRealtime(httpServer);
  setDependency("socket", "ready");
  startMetrics();
  setDependency("monitoring", enabled ? "ready" : "disabled");
  setDependency("health_routes", "ready");

  phase = "listen";
  const listening = once(httpServer, "listening");
  httpServer.listen(PORT, HOST);
  await listening;
  const address = httpServer.address();
  if (!address || typeof address === "string") throw new Error("TCP listener unavailable");

  phase = "jobs";
  let jobs = 0;
  const components = Object.entries({
    outing_completion: () => startOutingCompletionJob(),
    voting_deadlines: () => startVotingDeadlineJob(),
    notification_worker: () => startNotificationWorker(),
    media_cleanup: () => startMediaCleanupJob(),
    catalog_listener: () => startCatalogListener(),
  });
  for (const [name, begin] of components) {
    try {
      stops.push(begin());
      jobs++;
    } catch (error) {
      setDependency(name, "failed");
      logger.error({ job: name, errorCode: errorCode(error) }, "Startup component failed");
    }
  }
  setDependency("jobs", jobs === components.length ? "ready" : "degraded");
  setDependency("server", "ready");

  const wildcard = address.address === "0.0.0.0" || address.address === "::";
  const ipv4 = Object.values(os.networkInterfaces()).flatMap(entries => entries ?? [])
    .filter(entry => entry.family === "IPv4" && !entry.internal).map(entry => entry.address);
  const host = address.family === "IPv6" ? `[${address.address}]` : address.address;
  const localUrl = `http://${wildcard || address.address === "127.0.0.1" || address.address === "::1" ? "localhost" : host}:${address.port}`;
  const lan = ipv4.filter(ip => wildcard || ip === address.address).map(ip => `http://${ip}:${address.port}`);
  const status = firebaseReady && firebaseClientConfigured && jobs === components.length ? "SERVER READY" : "SERVER DEGRADED";
  const media = getMediaConfig().provider === "r2" ? "r2_configured" : environment === "production" ? "disabled" : "development_mock";
  const whatsApp = hasAutomaticWhatsApp() ? "configured" : "disabled";
  const report = {
    environment, bind: `${host}:${address.port}`, localUrl, lan,
    swagger: `${localUrl}/api-docs/`, database: dbKind, orm: "Prisma",
    environmentValidated: true, databaseConnected: probe.available, firebaseReady, firebaseClientConfigured,
    socketReady: Boolean(realtime), backgroundComponentsStarted: jobs,
    catalogListener: dependencyState("catalog_listener"), media, whatsApp,
    monitoring: enabled ? "active" : "disabled",
    privateMonitoring: privateMonitoringAvailable ? "protected" : "disabled",
    ...swaggerCoverage, databaseConnectionMs: Number(connectionMs.toFixed(2)),
    databaseProbeMs: Number(probe.latencyMs?.toFixed(2)),
    startupMs: Number((performance.now() - started).toFixed(2)),
    rssMiB: Number((process.memoryUsage().rss / 1048576).toFixed(1)),
  };
  if (environment !== "production") {
    process.stdout.write([
      "================================================",
      "              YALLA 5ROGA API SERVER",
      "================================================",
      `Environment        ${environment}`,
      `Server             ${report.bind}`,
      `Local              ${localUrl}`,
      `LAN                ${lan.join(", ") || "(unavailable on this bind)"}`,
      `Swagger            ${report.swagger}`,
      `Database           ${dbKind} via Prisma`,
      `Environment        validated`,
      `Database           connected (${report.databaseProbeMs} ms probe, ${report.databaseConnectionMs} ms connect)`,
      `Firebase           Admin ${firebaseReady ? "initialized" : "failed"}, client session ${firebaseClientConfigured ? "configured" : "missing key"}`,
      `Socket.IO          attached at /socket.io`,
      `Registered APIs    ${report.apiRoutes} (Swagger ${report.documentedApiRoutes}, ${report.optionalUndocumented.length} dev helpers, ${report.undocumented.length + report.unregistered.length} mismatches)`,
      `Background jobs    ${jobs} components started (catalog listener ${report.catalogListener})`,
      `Optional services  media ${media}, WhatsApp ${whatsApp}`,
      `Monitoring         ${report.monitoring}, private endpoints ${report.privateMonitoring}`,
      `Health checks      /health/live and /health/ready`,
      `Startup            ${report.startupMs} ms, RSS ${report.rssMiB} MiB`,
      status, "================================================",
    ].join("\n") + "\n");
  } else {
    logger.info(report, status);
  }
  if (report.undocumented.length || report.unregistered.length || report.duplicated) {
    logger.warn({ undocumented: report.undocumented, unregistered: report.unregistered, duplicated: report.duplicated }, "Swagger route mismatch");
  }
  process.once("SIGINT", () => void shutdown("SIGINT"));
  process.once("SIGTERM", () => void shutdown("SIGTERM"));
}

void start().catch(error => {
  process.exitCode = 1;
  const settings = ["DATABASE_URL", "PORT", "WHATSAPP_PROVIDER", "CORS_ORIGINS"];
  const setting = error instanceof Error && settings.includes(error.message) ? error.message : undefined;
  logger.fatal({ phase, setting, errorCode: errorCode(error) }, "API startup failed");
  void shutdown("startup_failure");
});
