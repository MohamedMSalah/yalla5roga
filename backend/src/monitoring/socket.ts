import type { Server, Socket } from "socket.io";
import { createHmac, randomBytes } from "node:crypto";
import { performance } from "node:perf_hooks";
import { enabled } from "./config.js";
import { logger } from "./logger.js";
import { collect, increment, observe } from "./metrics.js";

const known = new Set(["data:reconcile", "data:changed", "catalog:changed", "outing:join", "outing:leave",
  "outing:message", "outing:read", "group:join", "group:leave", "outing:arrival_changed",
  "outing:voting_round_updated", "outing:voting_closed", "outing:location_confirmed"]);
const event = (name: string) => known.has(name) ? name : "other";
const secret = randomBytes(32);

export function watchSocketServer(io: Server) {
  if (!enabled) return;
  const namespace = io.of("/");
  const recentDisconnects = new Map<string, number>();
  const accountKey = (socket: Socket) => createHmac("sha256", secret).update(String(socket.data.uid)).digest("base64url");

  collect("socket", () => {
    const rooms = namespace.adapter.rooms;
    let activeRooms = 0;
    let memberships = 0;
    for (const [name, members] of rooms) {
      if (!namespace.sockets.has(name)) {
        activeRooms++;
        memberships += members.size;
      }
    }
    return {
      socket_connections: io.engine.clientsCount, socket_authenticated: namespace.sockets.size,
      socket_rooms: activeRooms, socket_room_memberships: memberships,
      socket_authenticated_accounts: new Set([...namespace.sockets.values()].map(socket => socket.data.uid)).size,
    };
  });
  io.engine.on("connection_error", () => increment("socket_connection_failures_total"));
  namespace.on("connection", socket => {
    const key = accountKey(socket);
    const recent = recentDisconnects.get(key);
    recentDisconnects.delete(key);
    if (recent !== undefined && performance.now() - recent < 60000) increment("socket_reconnects_total");
    increment("socket_connections_total");
    const incoming = (name: string) => increment("socket_events_total", { direction: "in", event: event(name) });
    const outgoing = (name: string) => increment("socket_events_total", { direction: "out", event: event(name) });
    socket.onAny(incoming);
    socket.onAnyOutgoing(outgoing);
    setImmediate(() => {
      if (!socket.connected) return;
      for (const name of ["group:join", "group:leave", "outing:join", "outing:leave", "data:reconcile"]) {
        if (socket.listeners(name).length > 1) increment("socket_duplicate_listeners_total", { event: name });
      }
    });
    logger.debug("Socket authenticated");
    socket.once("disconnect", () => {
      logger.debug("Socket disconnected");
      increment("socket_disconnections_total");
      if (recentDisconnects.size >= 2048) recentDisconnects.delete(recentDisconnects.keys().next().value!);
      recentDisconnects.set(key, performance.now());
      socket.offAny(incoming);
      socket.offAnyOutgoing(outgoing);
    });
  });
}

export function observeSocketAck(name: string, callback: unknown): ((payload: unknown) => void) | undefined {
  if (typeof callback !== "function") return;
  if (!enabled) return callback as (payload: unknown) => void;
  const started = performance.now();
  return (payload) => {
    observe("socket_ack_handler_seconds", (performance.now() - started) / 1000, { event: event(name) });
    callback(payload);
  };
}
