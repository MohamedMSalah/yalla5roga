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

  const queryToken = socket.handshake.query.token;
  if (typeof queryToken === "string" && queryToken.trim()) {
    return queryToken.trim();
  }

  return extractBearerToken(socket.handshake.headers.authorization);
}

export async function authenticateSocket(
  socket: Socket,
  next: (err?: Error) => void,
): Promise<void> {
  try {
    const token = extractSocketToken(socket);
    if (!token) {
      next(new Error("UNAUTHORIZED"));
      return;
    }

    const decoded = await verifyAppSession(token);
    if (!decoded.uid) {
      next(new Error("UNAUTHORIZED"));
      return;
    }

    socket.data.uid = decoded.uid;
    next();
  } catch {
    next(new Error("UNAUTHORIZED"));
  }
}
