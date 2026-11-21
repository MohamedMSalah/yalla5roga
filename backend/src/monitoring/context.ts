import { AsyncLocalStorage } from "node:async_hooks";
import { performance } from "node:perf_hooks";
import { enabled } from "./config.js";
import { increment, observe } from "./metrics.js";

export type RequestContext = {
  active: boolean;
  requestId: string;
  authMs?: number;
  authorizationMs?: number;
  serviceMs?: number;
  externalMs?: number;
  dbMs: number;
  dbCalls: number;
  dbErrors: number;
  dbSlow: number;
  dbOperations: Map<string, number>;
  transactionMs?: number;
  cache?: string;
  error?: string;
};

export const requestContext = new AsyncLocalStorage<RequestContext>();
export function currentRequest() {
  const context = requestContext.getStore();
  return context?.active ? context : undefined;
}

type DurationField = "authMs" | "authorizationMs" | "serviceMs" | "externalMs" | "transactionMs";
export function finishedSpan(field: DurationField, started: number, context = currentRequest()) {
  const elapsed = performance.now() - started;
  if (context?.active) context[field] = (context[field] ?? 0) + elapsed;
  return elapsed;
}

export async function measure<T>(field: DurationField, action: () => PromiseLike<T>): Promise<T> {
  if (!enabled) return action();
  const context = currentRequest();
  const started = performance.now();
  let result = "ok";
  try { return await action(); }
  catch (error) { result = "error"; throw error; }
  finally {
    const elapsed = finishedSpan(field, started, context);
    if (field === "transactionMs" || field === "externalMs") {
      observe(field === "transactionMs" ? "db_transaction_seconds" : "external_call_seconds", elapsed / 1000, { result });
    }
  }
}

export function markCache(status: "hit" | "miss" | "stale") {
  const context = currentRequest();
  if (context) context.cache = status;
  increment("cache_operations_total", { layer: "backend", status });
}
