import { performance } from "node:perf_hooks";
import { once } from "node:events";
import app from "../src/app.js";

const routes = [
  ["GET", "/", 200],
  ["GET", "/health/live", 200],
  ["GET", "/api/places/licenses", 200],
  ["GET", "/api/places/geojson", 400],
  ["GET", "/api/groups/cuser", 401],
  ["GET", "/api/notifications", 401],
] as const;

const server = app.listen(0, "127.0.0.1");
await once(server, "listening");
const address = server.address();
if (!address || typeof address === "string") throw new Error("TCP listener unavailable");
const base = `http://127.0.0.1:${address.port}`;
const count = Number(process.env.BENCH_SAMPLES ?? 45);
if (!Number.isInteger(count) || count < 1 || count > 49) throw new Error("BENCH_SAMPLES must be in 1–49");
const percentile = (sorted: number[], fraction: number) =>
  +sorted[Math.ceil(sorted.length * fraction) - 1]!.toFixed(3);
const results = [];
try {
  for (const [method, endpoint, expected] of routes) {
    const values: number[] = [];
    let errors = 0;
    const request = async () => {
      const start = performance.now();
      const response = await fetch(base + endpoint, { method });
      await response.arrayBuffer();
      return { status: response.status, elapsed: performance.now() - start };
    };
    if ((await request()).status === 404 && endpoint === "/health/live") continue;
    for (let i = 0; i < 25; i++) await request();
    const cpu = process.cpuUsage();
    const start = performance.now();
    for (let i = 0; i < count; i++) {
      const sample = await request();
      if (sample.status !== expected) errors++;
      values.push(sample.elapsed);
    }
    const elapsed = performance.now() - start;
    const usage = process.cpuUsage(cpu);
    values.sort((a, b) => a - b);
    results.push({
      method, endpoint, expected, samples: count, errors,
      p50: percentile(values, 0.5), p95: percentile(values, 0.95), p99: percentile(values, 0.99),
      requestsPerSecond: +(count * 1000 / elapsed).toFixed(2),
      cpuMs: +((usage.user + usage.system) / 1000).toFixed(2),
      rssMiB: +(process.memoryUsage().rss / 1048576).toFixed(2),
    });
  }
  console.log(JSON.stringify(results, null, 2));
  if (results.some(row => row.errors)) process.exitCode = 1;
} finally {
  server.closeAllConnections();
  await new Promise<void>(resolve => server.close(() => resolve()));
}

