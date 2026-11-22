import type { NextFunction, Request, Response } from "express";
import { getFirebaseAuth } from "../config/firebase.js";
import { AppError, UnauthorizedError } from "../utils/errors.js";
import { measure } from "../monitoring/context.js";
import { isDeletedAccount } from "../services/users/account-deletion-access.js";

type FirebaseDecodedToken = {
  uid: string;
  email?: string;
  name?: string;
  phone_number?: string;
  exp?: number;
  firebase?: { sign_in_provider?: string };
};

export type FirebaseTokenVerifier = (
  token: string,
) => Promise<FirebaseDecodedToken>;

function readHeaderValue(
  value: string | string[] | undefined,
): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value;
}

/**
 * Reads a Firebase ID token from `Authorization: Bearer <token>`.
 * Tolerates Swagger/copy-paste mistakes: extra spaces, quotes, newlines,
 * and a duplicated Bearer prefix. Never returns the raw header.
 */
export function extractBearerToken(
  authorizationHeader: string | string[] | undefined,
): string | null {
  const raw = readHeaderValue(authorizationHeader);
  if (typeof raw !== "string" || raw.trim() === "") return null;

  const trimmed = raw.trim();
  const match = trimmed.match(/^Bearer\s+(.+)$/is);
  if (!match?.[1]) return null;

  let token = match[1].trim();
  while (/^Bearer\s+/i.test(token)) {
    token = token.replace(/^Bearer\s+/i, "").trim();
  }

  if (
    (token.startsWith('"') && token.endsWith('"') && token.length >= 2) ||
    (token.startsWith("'") && token.endsWith("'") && token.length >= 2)
  ) {
    token = token.slice(1, -1).trim();
  }

  // JWTs are base64url and cannot contain whitespace. Console copies wrap.
  token = token.replace(/\s+/g, "");
  return token.length > 0 ? token : null;
}

export async function verifyAppSession(
  token: string,
  checkRevoked = process.env.NODE_ENV === "production",
): Promise<FirebaseDecodedToken> {
  const decoded = await getFirebaseAuth().verifyIdToken(token, checkRevoked);
  if (!["custom", "phone"].includes(decoded.firebase.sign_in_provider)) {
    throw new UnauthorizedError("Sign in with your verified phone");
  }
  if (isDeletedAccount(decoded.uid)) throw new UnauthorizedError("Account deleted");
  return decoded;
}

function toAuthUser(decoded: FirebaseDecodedToken) {
  return {
    uid: decoded.uid,
    email: decoded.email,
    name: decoded.name,
    phone: decoded.phone_number,
    signInProvider: decoded.firebase?.sign_in_provider,
  };
}

function isFirebaseAuthError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;

  const details = error as { code?: unknown; codePrefix?: unknown; name?: unknown };
  return (
    details.name === "FirebaseAuthError" ||
    details.codePrefix === "auth" ||
    (typeof details.code === "string" && details.code.startsWith("auth/"))
  );
}

export function createAuthMiddleware(
  verifyToken: FirebaseTokenVerifier = verifyAppSession,
) {
  return async function authMiddleware(
    req: Request,
    _res: Response,
    next: NextFunction,
  ) {
    const header = req.headers.authorization;
    const token = extractBearerToken(header);

    try {
      const decoded = await measure("authMs", async () => {
        if (!token) throw new UnauthorizedError("Missing Bearer token");
        return verifyToken(token);
      });
      req.user = toAuthUser(decoded);
      next();
    } catch (error) {
      if (error instanceof UnauthorizedError) {
        return next(error);
      }

      if (isFirebaseAuthError(error)) {
        const { code } = error as { code?: string };
        if (code === "auth/internal-error" || code === "auth/network-request-failed") {
          return next(new AppError(503, "Authentication service unavailable"));
        }
        return next(new UnauthorizedError("Invalid or expired Firebase token"));
      }
      return next(error);
    }
  };
}

export function createOptionalAuthMiddleware(
  verifyToken: FirebaseTokenVerifier = verifyAppSession,
) {
  return async function optionalAuthMiddleware(
    req: Request,
    _res: Response,
    next: NextFunction,
  ) {
    try {
      const token = extractBearerToken(req.headers.authorization);
      if (token) {
        req.user = toAuthUser(await measure("authMs", () => verifyToken(token)));
      }
    } catch {
      // Optional auth never blocks the request.
    }
    next();
  };
}

export const authMiddleware = createAuthMiddleware();
export const optionalAuthMiddleware = createOptionalAuthMiddleware();
