import "dotenv/config";
import http from "node:http";
import os from "node:os";
import app from "./app.js";
import { prisma } from "./config/database.js";
import { startOutingCompletionJob } from "./jobs/complete-outings.job.js";
import { startVotingDeadlineJob } from "./jobs/close-voting-deadline.job.js";
import { startNotificationWorker } from "./jobs/notification-worker.job.js";
import { attachRealtime } from "./realtime/index.js";

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || "0.0.0.0";

/** Non-internal IPv4 addresses for physical-device / LAN access logs. */
function detectLanIPv4Addresses(): string[] {
  const results: string[] = [];
  const interfaces = os.networkInterfaces();
  for (const entries of Object.values(interfaces)) {
    if (!entries) continue;
    for (const entry of entries) {
      if (entry.family !== "IPv4" || entry.internal) continue;
      results.push(entry.address);
    }
  }
  return results;
}

async function start() {
  try {
    if (process.env.NODE_ENV === "production" && process.env.WHATSAPP_PROVIDER === "stub") {
      throw new Error("WHATSAPP_PROVIDER=stub is not allowed in production");
    }
    if (process.env.NODE_ENV === "production" && !process.env.CORS_ORIGINS) {
      throw new Error("CORS_ORIGINS must be set in production");
    }
    await prisma.$connect();
    console.log("Database connected successfully");

    const httpServer = http.createServer(app);
    attachRealtime(httpServer);

    httpServer.listen(PORT, HOST, () => {
      console.log(`Server listening on ${HOST}:${PORT}`);
      console.log(`  Local:   http://localhost:${PORT}`);
      console.log(`  Socket.IO path: /socket.io`);
      const lanIps = detectLanIPv4Addresses();
      if (lanIps.length === 0) {
        console.log(
          "  LAN:     (no non-internal IPv4 detected — physical devices cannot reach this host yet)",
        );
      } else {
        for (const ip of lanIps) {
          console.log(`  LAN:     http://${ip}:${PORT}`);
        }
      }
    });

    startOutingCompletionJob();
    startVotingDeadlineJob();
    startNotificationWorker();
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
}

start();
