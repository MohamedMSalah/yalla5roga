import type { NextFunction, Request, Response } from "express";
import { getFirebaseAuth } from "../config/firebase.js";
import { UnauthorizedError } from "../utils/errors.js";

type FirebaseDecodedToken = {
  uid: string;
  email?: string;
  name?: string;
  phone_number?: string;
  firebase?: { sign_in_provider?: string };
};

export type FirebaseTokenVerifier = (
  token: string,
) => Promise<FirebaseDecodedToken>;

const AUTH_DEBUG = process.env.NODE_ENV !== "production";

function debugLog(event: string, details: Record<string, unknown>) {
  if (!AUTH_DEBUG) return;
  console.error(`[Firebase Auth] ${event}`, details);
}

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

type IdTokenClaimPreview = {
  aud: unknown;
  iss: unknown;
  iat: unknown;
  exp: unknown;
};

function readIdTokenClaims(token: string): IdTokenClaimPreview | null {
  const segment = token.split(".")[1];
  if (!segment) return null;

  try {
    const payload: unknown = JSON.parse(
      Buffer.from(segment, "base64url").toString("utf8"),
    );
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
      return null;
    }

    const record = payload as Record<string, unknown>;
    return {
      aud: record.aud ?? null,
      iss: record.iss ?? null,
      iat: record.iat ?? null,
      exp: record.exp ?? null,
    };
  } catch {
    return null;
  }
}

function looksLikeJwt(token: string): boolean {
  const segments = token.split(".");
  return segments.length === 3 && segments.every((segment) => segment.length > 0);
}

function tokenKindHint(token: string, claims: IdTokenClaimPreview | null): string {
  if (!looksLikeJwt(token)) return "not_jwt_possible_fcm_or_opaque_token";

  const aud = typeof claims?.aud === "string" ? claims.aud : "";
  const iss = typeof claims?.iss === "string" ? claims.iss : "";

  if (iss.includes("accounts.google.com") || aud.includes("apps.googleusercontent.com")) {
    return "google_oauth_id_token";
  }
  if (iss.includes("appleid.apple.com")) return "apple_identity_token";
  if (iss.startsWith("https://securetoken.google.com/")) return "firebase_id_token";
  return "jwt_unknown_issuer";
}

function logInboundToken(
  header: string | string[] | undefined,
  token: string | null,
  configuredProjectId: string | null,
) {
  const raw = readHeaderValue(header);
  const scheme = raw?.trim().split(/\s+/)[0] ?? null;
  const claims = token ? readIdTokenClaims(token) : null;
  const expectedIssuer = configuredProjectId
    ? `https://securetoken.google.com/${configuredProjectId}`
    : null;
  const nowSec = Math.floor(Date.now() / 1000);
  const exp =
    typeof claims?.exp === "number"
      ? claims.exp
      : typeof claims?.exp === "string"
        ? Number(claims.exp)
        : null;

  debugLog("Inbound request", {
    authorizationHeaderPresent: Boolean(raw && raw.trim()),
    scheme,
    tokenPresent: Boolean(token),
    tokenLength: token?.length ?? 0,
    segmentCount: token ? token.split(".").length : 0,
    tokenKindHint: token ? tokenKindHint(token, claims) : "missing",
    aud: claims?.aud ?? null,
    iss: claims?.iss ?? null,
    iat: claims?.iat ?? null,
    exp: claims?.exp ?? null,
    expired: typeof exp === "number" && Number.isFinite(exp) ? exp <= nowSec : null,
    configuredProjectId,
    audienceMatchesProject:
      typeof claims?.aud === "string" && claims.aud === configuredProjectId,
    issuerMatchesProject:
      typeof claims?.iss === "string" && claims.iss === expectedIssuer,
    hasSurroundingQuotes: Boolean(raw && /^Bearer\s+['"]/i.test(raw.trim())),
    hasDuplicatedBearerPrefix: Boolean(
      raw && /^Bearer\s+Bearer\s+/i.test(raw.trim()),
    ),
  });
}

export async function verifyAppSession(token: string): Promise<FirebaseDecodedToken> {
  const decoded = await getFirebaseAuth().verifyIdToken(token);
  if (!["custom", "phone"].includes(decoded.firebase.sign_in_provider)) {
    throw new UnauthorizedError("Sign in with your verified phone");
  }
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

function errorDetails(error: unknown) {
  if (error instanceof Error) {
    const coded = error as Error & { code?: unknown };
    return {
      code: coded.code,
      name: error.name,
      message: error.message,
    };
  }

  return {
    code: undefined,
    name: undefined,
    message: typeof error === "string" ? error : "Unknown error",
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

function isFirebaseConfigError(error: unknown): boolean {
  return error instanceof Error && error.message.startsWith("Missing Firebase config");
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
      const projectId = process.env.FIREBASE_PROJECT_ID ?? null;
      logInboundToken(header, token, projectId);

      if (!token) {
        debugLog("Rejected", {
          reason: header ? "malformed_bearer_header" : "missing_authorization_header",
          configuredProjectId: projectId,
        });
        throw new UnauthorizedError("Missing Bearer token");
      }

      const decoded = await verifyToken(token);
      req.user = toAuthUser(decoded);

      debugLog("Verified", {
        uid: decoded.uid,
        signInProvider: decoded.firebase?.sign_in_provider ?? null,
        hasEmail: Boolean(decoded.email),
        hasVerifiedPhone: Boolean(decoded.phone_number),
        configuredProjectId: projectId,
        databaseUserLookup:
          "skipped in auth middleware; identity is the Firebase UID; upsert via POST /api/users/sync",
      });

      next();
    } catch (error) {
      if (error instanceof UnauthorizedError) {
        return next(error);
      }

      const details = errorDetails(error);
      if (isFirebaseConfigError(error)) {
        console.error("[Firebase Auth] Admin SDK is not configured", details);
        return next(error);
      }

      if (isFirebaseAuthError(error)) {
        debugLog("Token verification failed", {
          code: details.code,
          message: details.message,
          configuredProjectId: process.env.FIREBASE_PROJECT_ID ?? null,
        });
        return next(new UnauthorizedError("Invalid or expired Firebase token"));
      }

      console.error("[Auth Middleware] Unexpected error", details);
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
        req.user = toAuthUser(await verifyToken(token));
      }
    } catch {
      // Optional auth never blocks the request.
    }
    next();
  };
}

export const authMiddleware = createAuthMiddleware();
export const optionalAuthMiddleware = createOptionalAuthMiddleware();
