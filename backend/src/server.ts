import http from "node:http";
import os from "node:os";
import { once } from "node:events";
import { performance } from "node:perf_hooks";
import app, { swaggerCoverage } from "./app.js";
import { prisma } from "./config/database.js";
import { getMediaConfig } from "./config/media.js";
import { validateProductionConfig } from "./config/deployment.js";
import { hasAutomaticWhatsApp } from "./config/notifications.js";
import { initFirebase } from "./config/firebase.js";
import { configuredGeocodingProvider } from "./services/places/geocoding.js";
import { R2StorageAdapter } from "./services/media/r2-storage.adapter.js";
import { startOutingCompletionJob } from "./jobs/complete-outings.job.js";
import { startVotingDeadlineJob } from "./jobs/close-voting-deadline.job.js";
import { startNotificationWorker } from "./jobs/notification-worker.job.js";
import { startMediaCleanupJob } from "./jobs/media-cleanup.job.js";
import { loadDeletedAccounts, startAccountDeletionJob } from "./jobs/account-deletion.job.js";
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

function publicOrigin(raw = process.env.API_BASE_URL): string | undefined {
  const url = URL.parse(raw?.trim() ?? "");
  if (url && ["http:", "https:"].includes(url.protocol) && !url.username && !url.password) return url.origin;
}

async function startStorageChecks() {
  const { provider, r2 } = getMediaConfig();
  if (provider !== "r2" || !r2.accountId || !r2.accessKeyId || !r2.secretAccessKey || !r2.bucket) {
    setDependency("r2_private", "disabled");
    setDependency("r2_catalog", "disabled");
    return;
  }
  const buckets = [["r2_private", r2.bucket], ["r2_catalog", r2.publicBucket]] as const;
  const checks = buckets.flatMap(([name, bucket]) => {
    if (!bucket) {
      setDependency(name, "disabled");
      return [];
    }
    const adapter = new R2StorageAdapter({
      accountId: r2.accountId!, accessKeyId: r2.accessKeyId!, secretAccessKey: r2.secretAccessKey!,
      endpoint: r2.endpoint, bucket, privateReads: name === "r2_private",
    });
    setDependency(name, "pending");
    return [async () => {
      try {
        await adapter.probe();
        setDependency(name, "ready");
      } catch (error) {
        setDependency(name, "failed");
        logger.warn({ service: name, errorCode: errorCode(error) }, "R2 bucket probe failed");
      }
    }];
  });
  const probe = () => Promise.allSettled(checks.map(check => check()));
  await probe();
  let running: ReturnType<typeof probe> | undefined;
  const timer = setInterval(() => {
    running ??= probe().finally(() => { running = undefined; });
  }, 60_000);
  timer.unref();
  stops.push(async () => { clearInterval(timer); await running; });
}

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
  if (environment === "production") validateProductionConfig();

  phase = "database";
  const dbStarted = performance.now();
  await prisma.$connect();
  const connectionMs = performance.now() - dbStarted;
  const probe = await databaseHealth(true);
  if (!probe.available) throw new Error("Database probe failed");
  await loadDeletedAccounts();

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
  if (environment === "production" && !firebaseReady) throw new Error("FIREBASE_PRIVATE_KEY");
  setDependency("fcm", firebaseReady ? "pending" : "disabled");
  await startStorageChecks();

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
  const sharedDevelopment = environment !== "production" && process.env.SHARED_PRODUCTION_SERVICES === "true";
  const components = Object.entries({
    ...(sharedDevelopment ? {} : {
    outing_completion: () => startOutingCompletionJob(),
    voting_deadlines: () => startVotingDeadlineJob(),
    notification_worker: () => startNotificationWorker(),
    media_cleanup: () => startMediaCleanupJob(),
    account_deletion: () => startAccountDeletionJob(),
    }),
    catalog_listener: () => startCatalogListener(),
  });
  if (sharedDevelopment) logger.warn("Shared production services: automatic mutation and cleanup jobs are disabled");
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
  const { provider, publicBaseUrlConfigured } = getMediaConfig();
  const status = firebaseReady && firebaseClientConfigured && jobs === components.length &&
    (environment !== "production" || dependencyState("r2_private") === "ready") ? "SERVER READY" : "SERVER DEGRADED";
  const storageStatus = (name: string) => ({ ready: "connected", failed: "connection failed" })[
    dependencyState(name) as "ready" | "failed"] ?? "not configured";
  const r2Private = provider === "r2" ? storageStatus("r2_private") : "development mock";
  const whatsApp = hasAutomaticWhatsApp() ? "deep links enabled; Meta configured" : "deep links enabled; Meta disabled";
  const geocoding = configuredGeocodingProvider() ? "Pelias configured" : "local catalog only";
  const report = {
    environment: process.env.YALLA_ENVIRONMENT ?? environment, bind: `${host}:${address.port}`, localUrl, lan,
    configuration: `.env.${process.env.YALLA_ENVIRONMENT ?? (environment === "production" ? "production" : "device")}`,
    publicOrigin: publicOrigin(),
    swagger: environment === "production" ? "disabled" : `${localUrl}/api-docs/`, database: dbKind, orm: "Prisma",
    environmentValidated: true, databaseConnected: probe.available, firebaseReady, firebaseClientConfigured,
    socketReady: Boolean(realtime), backgroundComponentsStarted: jobs,
    catalogListener: dependencyState("catalog_listener"), r2Private,
    r2PublicCatalog: storageStatus("r2_catalog"),
    catalogCdn: publicBaseUrlConfigured ? "configured" : "not configured",
    whatsApp, maps: "client configured at build; not verified", geocoding,
    firebaseAuth: firebaseClientConfigured ? "configured" : "not configured",
    fcm: firebaseReady ? "not verified" : "not configured",
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
      `Environment        ${report.environment}`,
      `Configuration      ${report.configuration}`,
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
      `FCM                ${report.fcm}`,
      `R2 private         ${report.r2Private}`,
      `R2 public catalog  ${report.r2PublicCatalog}; CDN ${report.catalogCdn}`,
      `WhatsApp           ${whatsApp}`,
      `Maps and geocoding ${geocoding}; ${report.maps}`,
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
  const settings = ["DATABASE_URL", "DIRECT_URL", "PORT", "DEPLOYMENT_ENV", "API_BASE_URL", "TRUST_PROXY",
    "WHATSAPP_PROVIDER", "FIREBASE_PRIVATE_KEY", "FIREBASE_API_KEY", "CORS_ORIGINS", "FIREBASE_PROJECT_ID",
    "FIREBASE_CLIENT_EMAIL", "R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET_NAME",
    "R2_PUBLIC_BUCKET_NAME", "R2_PUBLIC_BASE_URL", "R2_ENDPOINT", "EXPECTED_R2_ACCOUNT_ID", "EXPECTED_R2_PRIVATE_BUCKET"];
  const reported = error instanceof Error ? error.message.split(" ", 1)[0] : undefined;
  const setting = reported && settings.includes(reported) ? reported : undefined;
  logger.fatal({ phase, setting, errorCode: errorCode(error) }, "API startup failed");
  void shutdown("startup_failure");
});
