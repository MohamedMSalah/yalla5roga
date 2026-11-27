import { increment } from "../monitoring/metrics.js";
import { observeSocketAck, watchSocketServer } from "../monitoring/socket.js";
import type { Server as HttpServer } from "node:http";
import { Server } from "socket.io";
import { bindChatEmitter } from "./chat-emitter.js";
import { registerChatGateway } from "./chat.gateway.js";
import { registerGroupGateway } from "./group.gateway.js";
import { authenticateSocket } from "./socket-auth.js";
import { userRealtimeRoom } from "./rooms.js";
import { corsOrigin, isAllowedOrigin } from "../config/cors.js";
import { reconcileDataChanges } from "./data-changes.js";
import { isDeletedAccount } from "../services/users/account-deletion-access.js";
import { SmartMeetupRealtimeService } from "../services/meetups/smart-meetup-realtime.service.js";

/**
 * Attaches Socket.IO to the existing HTTP server (same port as Express).
 *
 * Hosting note: designed for a single long-lived Node process (current
 * architecture). No Redis adapter — multi-instance sticky sessions would
 * require a later ADR. Serverless/request-scoped hosts that cannot keep
 * persistent WebSocket connections are incompatible without a different
 * topology.
 */
export function attachRealtime(httpServer: HttpServer, sessionRecheckMs?: number): Server {
  const io = new Server(httpServer, {
    path: "/socket.io",
    allowRequest: (request, callback) => callback(null, isAllowedOrigin(request.headers.origin)),
    cors: {
      origin: corsOrigin,
      credentials: true,
      allowedHeaders: ["Authorization", "Content-Type", "Accept"],
    },
    // Prefer websocket; polling still allowed for environments that need it.
    transports: ["websocket", "polling"],
  });

  io.use((socket, next) => {
    void authenticateSocket(socket, error => {
      if (error) increment("socket_auth_failures_total");
      next(error);
    }, sessionRecheckMs);
  });

  watchSocketServer(io);
  registerChatGateway(io);
  registerGroupGateway(io);
  new SmartMeetupRealtimeService().register(io);
  bindChatEmitter(io);

  io.on("connection", (socket) => {
    if (isDeletedAccount(socket.data.uid)) {
      socket.disconnect(true);
      return;
    }
    void socket.join(userRealtimeRoom(socket.data.uid));
    socket.on("data:reconcile", (cursor: unknown, ack: unknown) => {
      observeSocketAck("data:reconcile", ack)?.(reconcileDataChanges(socket.data.uid, cursor));
    });
  });

  return io;
}
