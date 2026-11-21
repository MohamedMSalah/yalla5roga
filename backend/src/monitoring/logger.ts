import pino from "pino";
import { createRequire } from "node:module";
import { environment } from "./config.js";

const require = createRequire(import.meta.url);
const pretty = environment === "development" && process.env.OBS_LOG_FORMAT !== "json";
function output() {
  if (!pretty) return undefined;
  try {
    return require("pino-pretty")({ colorize: true, translateTime: "SYS:HH:MM:ss.l", singleLine: true, ignore: "pid,hostname" });
  } catch {
    return undefined;
  }
}

const options: pino.LoggerOptions = {
  level: ["trace", "debug", "info", "warn", "error", "fatal", "silent"].includes(process.env.LOG_LEVEL ?? "")
    ? process.env.LOG_LEVEL : environment === "test" ? "silent" : "info",
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: { paths: ["req", "res", "headers", "body", "password", "token", "authorization", "params", "query", "err"], remove: true },
};
const stream = output();
export const logger = stream ? pino(options, stream) : pino(options);

export function errorCode(error: unknown): string {
  if (error && typeof error === "object") {
    const value = error as { code?: unknown; errorCode?: unknown };
    const code = value.code ?? value.errorCode;
    if (typeof code === "string" && /^(?:P\d{4}|E[A-Z_]{2,30}|auth\/[a-z-]{2,50}|\d{5})$/.test(code)) return code;
    if (error instanceof Error && ["AbortError", "TimeoutError", "ZodError", "SyntaxError"].includes(error.name)) return error.name;
  }
  return "unexpected";
}
