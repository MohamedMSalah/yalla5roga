import { randomUUID } from "node:crypto";
import { performance } from "node:perf_hooks";
import type { RequestHandler, Response } from "express";
import type { registeredRoutes } from "./routes.js";
import { enabled, latencyBand, requestLogSample, triggers } from "./config.js";
import { currentRequest, requestContext, type RequestContext } from "./context.js";
import { startDuplicateCheck } from "./duplicates.js";
import { logger } from "./logger.js";
import { activeRequest, increment, observe } from "./metrics.js";

const methods = new Set(["GET", "POST", "PATCH", "PUT", "DELETE", "HEAD", "OPTIONS"]);
export function safeId(value: string | undefined) {
  return value && /^(?:req_|op_)?[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(value) ? value : undefined;
}

export function requestMonitoring(routes: () => ReturnType<typeof registeredRoutes>): RequestHandler {
  return (req, res, next) => {
    if (!enabled) return next();
    const start = performance.now();
    const requestId = safeId(req.get("X-Request-ID")) ?? randomUUID();
    const correlationId = safeId(req.get("X-Correlation-ID")) ?? requestId;
    const triggerHeader = req.get("X-Request-Trigger") ?? "";
    const trigger = triggers.has(triggerHeader) ? triggerHeader : "unknown";
    const retry = trigger === "retry" ? 1 : 0;
    const client = req.get("X-Client-Source");
    const source = client === "flutter" ? "flutter"
      : req.get("Referer")?.includes("/api-docs/") ? "swagger"
      : client === "internal" ? "internal_reported" : "external";
    const method = methods.has(req.method) ? req.method : "OTHER";
    let check: ReturnType<typeof startDuplicateCheck>;
    let matched: string | undefined;
    const route = () => matched ??= routes().find(r =>
      (r.method === method || (method === "HEAD" && r.method === "GET") || method === "OPTIONS") &&
      r.pattern.test(req.path),
    )?.path ?? (req.path.startsWith("/api-docs/") ? "/api-docs/*" : "unmatched");
    const context: RequestContext = { requestId, active: true, dbMs: 0, dbCalls: 0, dbSlow: 0, dbErrors: 0, dbOperations: new Map() };
    res.setHeader("X-Request-ID", requestId);
    res.setHeader("X-Correlation-ID", correlationId);
    const writeHead = res.writeHead;
    res.writeHead = function (this: Response, ...args: Parameters<typeof writeHead>) {
      if (!res.headersSent) {
        const timing = `app;dur=${(performance.now() - start).toFixed(2)}`;
        const prior = res.getHeader("Server-Timing");
        res.setHeader("Server-Timing", prior ? `${prior}, ${timing}` : timing);
        const endpoint = route();
        if (endpoint.startsWith("/api/")) res.setHeader("X-Route-Template", endpoint);
      }
      return Reflect.apply(writeHead, this, args);
    } as typeof writeHead;

    activeRequest(1);
    const finish = (aborted: boolean) => {
      if (!context.active) return;
      context.active = false;
      activeRequest(-1);
      const elapsed = performance.now() - start;
      const endpoint = route();
      const status = aborted && !res.headersSent ? "aborted" : String(res.statusCode);
      const labels = { method, endpoint, status };
      increment("http_requests_total", labels);
      observe("http_duration_seconds", elapsed / 1000, labels);
      if (res.statusCode === 408 || res.statusCode === 504 || context.error === "TimeoutError") {
        increment("http_timeouts_total", { method, endpoint });
      }
      if (retry) increment("http_retries_total", { method, endpoint });
      if (aborted) increment("http_aborted_total", { method, endpoint });
      observe("http_db_operations", context.dbCalls, { method, endpoint }, "count");
      observe("http_db_operation_seconds", context.dbMs / 1000, { method, endpoint });
      const duplicate = check?.duplicate;
      check?.end();
      if (duplicate) increment("http_potential_duplicates_total", { method, endpoint, trigger });
      const band = latencyBand(method, endpoint, elapsed);
      const level = aborted || res.statusCode >= 500 ? "error" : duplicate || band === "critical" || band === "warning" ? "warn" : "info";
      if (level === "info" && Math.random() >= requestLogSample) return;
      const round = (value: number | undefined) => value === undefined ? undefined : Number(value.toFixed(2));
      const length = res.getHeader("content-length");
      const responseBytes = method === "HEAD" || [204, 304].includes(res.statusCode) ? 0
        : !aborted && length !== undefined && Number.isSafeInteger(Number(length)) ? Number(length) : undefined;
      logger[level]({
        requestId, correlationId, source, method, endpoint, status, trigger, retry, aborted,
        durationMs: round(elapsed), latencyBand: band, processPhase: process.uptime() < 30 ? "warmup" : "running",
        authMs: round(context.authMs),
        authorizationSumMs: round(context.authorizationMs), dbOperations: context.dbCalls,
        dbOperationSumMs: round(context.dbMs), dbErrors: context.dbErrors, dbSlow: context.dbSlow,
        repeatedDbOperations: [...context.dbOperations].filter(([, count]) => count >= 3),
        serviceSumMs: round(context.serviceMs), transactionSumMs: round(context.transactionMs),
        externalSumMs: round(context.externalMs), responseBytes, cache: context.cache,
        errorCode: context.error, potentialDuplicate: duplicate,
      }, `${method} ${endpoint} | ${status} | ${elapsed.toFixed(1)}ms`);
    };
    const finalize = (aborted: boolean) => {
      try { finish(aborted); } catch { /* A monitoring failure cannot affect delivery. */ }
    };
    res.once("finish", () => finalize(false));
    res.once("close", () => finalize(!res.writableFinished));
    res.locals.observeRequestIdentity = () => {
      try { check = startDuplicateCheck(req, route(), trigger); } catch { /* Detection is best effort. */ }
    };
    requestContext.run(context, next);
  };
}

export const observeRequestIdentity: RequestHandler = (_req, res, next) => {
  res.locals.observeRequestIdentity?.();
  next();
};

export function recordRequestError(code: string) {
  const context = currentRequest();
  if (context) context.error = code;
}
