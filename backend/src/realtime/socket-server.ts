import type { Server as HttpServer } from "node:http";
import { Server } from "socket.io";
import { bindChatEmitter } from "./chat-emitter.js";
import { registerChatGateway } from "./chat.gateway.js";
import { registerGroupGateway } from "./group.gateway.js";
import { authenticateSocket } from "./socket-auth.js";
import { userRealtimeRoom } from "./rooms.js";
import { corsOrigin } from "../config/cors.js";
import { reconcileDataChanges } from "./data-changes.js";

/**
 * Attaches Socket.IO to the existing HTTP server (same port as Express).
 *
 * Hosting note: designed for a single long-lived Node process (current
 * architecture). No Redis adapter — multi-instance sticky sessions would
 * require a later ADR. Serverless/request-scoped hosts that cannot keep
 * persistent WebSocket connections are incompatible without a different
 * topology.
 */
export function attachRealtime(httpServer: HttpServer): Server {
  const io = new Server(httpServer, {
    path: "/socket.io",
    cors: {
      origin: corsOrigin,
      credentials: true,
      allowedHeaders: ["Authorization", "Content-Type", "Accept"],
    },
    // Prefer websocket; polling still allowed for environments that need it.
    transports: ["websocket", "polling"],
  });

  io.use((socket, next) => {
    void authenticateSocket(socket, next);
  });

  registerChatGateway(io);
  registerGroupGateway(io);
  bindChatEmitter(io);

  io.on("connection", (socket) => {
    void socket.join(userRealtimeRoom(socket.data.uid));
    socket.on("data:reconcile", (cursor: unknown, ack: unknown) => {
      if (typeof ack === "function") ack(reconcileDataChanges(socket.data.uid, cursor));
    });
    if (process.env.NODE_ENV !== "production") {
      console.log(`[realtime] connected uid=${socket.data.uid} id=${socket.id}`);
    }
    socket.on("disconnect", (reason) => {
      if (process.env.NODE_ENV !== "production") {
        console.log(
          `[realtime] disconnected uid=${socket.data.uid} id=${socket.id} reason=${reason}`,
        );
      }
    });
  });

  return io;
}
