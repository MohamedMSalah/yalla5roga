import type { Socket } from "socket.io";
import { extractBearerToken, verifyAppSession } from "../middleware/auth.middleware.js";

export type AuthenticatedSocket = Socket & {
  data: {
    uid: string;
  };
};

/**
 * Resolves a Firebase ID token from Socket.IO handshake auth / headers.
 * Never trusts a client-supplied userId as identity.
 */
export function extractSocketToken(socket: Socket): string | null {
  const auth = socket.handshake.auth as Record<string, unknown> | undefined;
  const fromAuth =
    typeof auth?.token === "string"
      ? auth.token
      : typeof auth?.idToken === "string"
        ? auth.idToken
        : null;
  if (fromAuth && fromAuth.trim()) return fromAuth.trim();

  return extractBearerToken(socket.handshake.headers.authorization);
}

export async function authenticateSocket(
  socket: Socket,
  next: (err?: Error) => void,
  recheckMs = 30_000,
): Promise<void> {
  try {
    const token = extractSocketToken(socket);
    if (!token) {
      next(new Error("UNAUTHORIZED"));
      return;
    }

    const decoded = await verifyAppSession(token, true);
    if (!decoded.uid) {
      next(new Error("UNAUTHORIZED"));
      return;
    }

    socket.data.uid = decoded.uid;
    const expiresIn = decoded.exp === undefined ? Infinity : decoded.exp * 1000 - Date.now();
    if (expiresIn <= 0 || socket.conn.readyState !== "open") {
      next(new Error("UNAUTHORIZED"));
      return;
    }

    // Close the transport so the client can reconnect with its refreshed token.
    // Use a deadline even if a revocation lookup is still in flight.
    const close = () => socket.conn.close();
    const expiry = Number.isFinite(expiresIn) ? setTimeout(close, expiresIn) : undefined;
    expiry?.unref();
    let refresh: ReturnType<typeof setTimeout>;
    const schedule = () => {
      refresh = setTimeout(() => {
        if (!socket.connected) return;
        let timeout: ReturnType<typeof setTimeout>;
        void Promise.race([
          verifyAppSession(token, true),
          new Promise<never>((_, reject) => {
            timeout = setTimeout(() => reject(new Error("Session verification timed out")), 5_000);
            timeout.unref();
          }),
        ]).then(session => {
          if (session.uid !== decoded.uid) close();
          else if (socket.connected) schedule();
        }, close).finally(() => clearTimeout(timeout));
      }, recheckMs);
      refresh.unref();
    };
    const clearSessionTimers = () => {
      clearTimeout(refresh);
      clearTimeout(expiry);
      socket.conn.off("close", clearSessionTimers);
    };
    socket.conn.once("close", clearSessionTimers);
    socket.once("disconnect", clearSessionTimers);
    schedule();
    next();
  } catch {
    next(new Error("UNAUTHORIZED"));
  }
}
