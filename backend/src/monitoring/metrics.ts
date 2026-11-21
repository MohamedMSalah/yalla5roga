import { monitorEventLoopDelay } from "node:perf_hooks";
import { enabled, environment } from "./config.js";

type Labels = Record<string, string>;
type Series = { labels: Labels; value: number; buckets?: number[]; sum?: number };
type Family = { type: "counter" | "histogram"; bounds: readonly number[]; series: Map<string, Series> };
const families = new Map<string, Family>();
const seconds = [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30];
const counts = [0, 1, 2, 3, 5, 10, 20, 50, 100];
const eventLoop = enabled ? monitorEventLoopDelay({ resolution: 20 }) : undefined;
let active = 0;
const collectors = new Map<string, () => Record<string, number>>();

export function startMetrics() { eventLoop?.enable(); }
export function stopMetrics() { eventLoop?.disable(); }
export function collect(name: string, read: () => Record<string, number>) { collectors.set(name, read); }
export function activeRequest(change: number) { if (enabled) active += change; }

function seriesFor(name: string, labels: Labels, bounds?: readonly number[]) {
  if (!enabled) return;
  let family = families.get(name);
  if (!family) {
    family = { type: bounds ? "histogram" : "counter", bounds: bounds ?? [], series: new Map() };
    families.set(name, family);
  }
  const key = JSON.stringify(labels);
  let series = family.series.get(key);
  if (!series) {
    if (family.series.size >= 2500) return;
    series = { labels, value: 0, buckets: bounds?.map(() => 0), sum: bounds ? 0 : undefined };
    family.series.set(key, series);
  }
  return series;
}

export function increment(name: string, labels: Labels = {}, amount = 1) {
  const series = seriesFor(name, labels);
  if (series) series.value += amount;
}

export function observe(name: string, value: number, labels: Labels = {}, unit: "seconds" | "count" = "seconds") {
  if (!Number.isFinite(value) || value < 0) return;
  const bounds = unit === "seconds" ? seconds : counts;
  const series = seriesFor(name, labels, bounds);
  if (!series?.buckets) return;
  series.value++;
  series.sum! += value;
  let bucket = bounds.findIndex(bound => value <= bound);
  if (bucket < 0) bucket = bounds.length;
  if (bucket < bounds.length) series.buckets[bucket]!++;
}

function sample(name: string, value: number, labels: Labels = {}) {
  const escape = (value: string) => value.replaceAll("\\", "\\\\").replaceAll('"', '\\"').replaceAll("\n", "\\n");
  const args = Object.entries({ environment, ...labels }).map(([key, value]) => `${key}="${escape(value)}"`);
  return `yalla_${name}{${args.join(",")}} ${value}`;
}

export function metricsText() {
  const lines: string[] = [];
  for (const [name, family] of families) {
    lines.push(`# TYPE yalla_${name} ${family.type}`);
    for (const { labels, value, buckets, sum } of family.series.values()) {
      if (!buckets) {
        lines.push(sample(name, value, labels));
        continue;
      }
      let cumulative = 0;
      family.bounds.forEach((le, index) => {
        cumulative += buckets[index]!;
        lines.push(sample(`${name}_bucket`, cumulative, { ...labels, le: String(le) }));
      });
      lines.push(sample(`${name}_bucket`, value, { ...labels, le: "+Inf" }));
      lines.push(sample(`${name}_sum`, sum!, labels), sample(`${name}_count`, value, labels));
    }
  }
  const memory = process.memoryUsage();
  const cpu = process.cpuUsage();
  const gauges = {
    http_active: active, process_uptime_seconds: process.uptime(),
    process_rss_bytes: memory.rss, process_heap_bytes: memory.heapUsed,
    event_loop_p99_seconds: eventLoop?.count ? eventLoop.percentile(99) / 1e9 : 0,
  };
  for (const read of collectors.values()) {
    try { Object.assign(gauges, read()); } catch { /* A failed collector cannot fail the scrape. */ }
  }
  for (const [name, value] of Object.entries(gauges)) lines.push(`# TYPE yalla_${name} gauge`, sample(name, value));
  lines.push("# TYPE yalla_process_cpu_seconds_total counter", sample("process_cpu_seconds_total", (cpu.system + cpu.user) / 1e6));
  return lines.join("\n") + "\n";
}
