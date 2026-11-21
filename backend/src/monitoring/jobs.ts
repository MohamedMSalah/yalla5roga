import { collect, increment, observe } from "./metrics.js";
import { errorCode, logger } from "./logger.js";
import { performance } from "node:perf_hooks";

const jobs = new Map<string, { running: boolean; lastSuccess: number; failed: boolean }>();
collect("jobs", () => ({
  jobs_running: [...jobs.values()].filter(job => job.running).length,
  jobs_failed: [...jobs.values()].filter(job => job.failed).length,
}));

export function jobHealth() {
  return Object.fromEntries(jobs);
}

export function scheduleJob(name: string, intervalMs: number, task: () => Promise<void>) {
  const state = { running: false, lastSuccess: 0, failed: false };
  jobs.set(name, state);
  let inFlight = Promise.resolve();
  const trigger = () => {
    if (state.running) return;
    state.running = true;
    const start = performance.now();
    inFlight = task().then(() => {
      state.lastSuccess = Date.now();
      state.failed = false;
    }).catch(error => {
      if (!state.failed) logger.warn({ job: name, errorCode: errorCode(error) }, "Background job failed");
      state.failed = true;
    }).finally(() => {
      state.running = false;
      const labels = { job: name, result: state.failed ? "error" : "ok" };
      increment("job_runs_total", labels);
      observe("job_duration_seconds", (performance.now() - start) / 1000, labels);
    });
  };
  trigger();
  const timer = setInterval(trigger, intervalMs);
  timer.unref();
  return async () => {
    clearInterval(timer);
    await inFlight;
  };
}
