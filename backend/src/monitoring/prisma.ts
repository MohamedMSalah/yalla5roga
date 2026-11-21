import { performance } from "node:perf_hooks";
import { Prisma, type PrismaClient } from "@prisma/client";
import { enabled, queryCriticalMs, queryWarningMs } from "./config.js";
import { currentRequest, measure } from "./context.js";
import { errorCode, logger } from "./logger.js";
import { increment, observe } from "./metrics.js";

const extension = Prisma.defineExtension({
  name: "request-observability",
  query: {
    async $allOperations({ model, operation, args, query }) {
      const context = currentRequest();
      const start = performance.now();
      let failure: string | undefined;
      try { return await query(args); }
      catch (error) { failure = errorCode(error); throw error; }
      finally {
        const elapsed = performance.now() - start;
        const band = elapsed >= queryCriticalMs ? "critical" : elapsed >= queryWarningMs ? "warning" : "normal";
        const label = `${model ?? "raw"}.${operation}`;
        observe("db_operation_seconds", elapsed / 1000, { result: failure ? "error" : "ok" });
        if (band !== "normal") increment("db_slow_operations_total", { band });
        if (failure === "P2024") increment("db_pool_timeouts_total");
        if (context?.active) {
          context.dbCalls++;
          context.dbMs += elapsed;
          if (failure) context.dbErrors++;
          if (band !== "normal") context.dbSlow++;
          if (context.dbOperations.has(label) || context.dbOperations.size < 30) {
            context.dbOperations.set(label, (context.dbOperations.get(label) ?? 0) + 1);
          }
        } else if (!context && band !== "normal") {
          logger.warn({ operation: label, durationMs: Number(elapsed.toFixed(2)), band, errorCode: failure }, "Slow Prisma operation");
        }
      }
    },
  },
});

export function instrumentPrisma(client: PrismaClient): PrismaClient {
  if (!enabled) return client;
  // The extension only observes calls and preserves the base client's model surface.
  const extended = client.$extends(extension) as unknown as PrismaClient;
  return new Proxy(extended, {
    get(target, key, receiver) {
      if (key !== "$transaction") return Reflect.get(target, key, receiver);
      const transaction = target.$transaction;
      return (...args: unknown[]) =>
        measure("transactionMs", () => Reflect.apply(transaction, target, args));
    },
  });
}
