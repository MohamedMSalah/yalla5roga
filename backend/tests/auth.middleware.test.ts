import "dotenv/config";
import assert from "node:assert/strict";
import http from "node:http";
import { describe, it } from "node:test";
import express, { type NextFunction, type Request, type Response } from "express";
import cors from "cors";
import {
  authMiddleware,
  createAuthMiddleware,
  createOptionalAuthMiddleware,
  extractBearerToken,
} from "../src/middleware/auth.middleware.js";
import { AppError, UnauthorizedError } from "../src/utils/errors.js";
import { errorMiddleware } from "../src/middleware/error.middleware.js";

const JWT =
  "header.eyJhdWQiOiJ5YWxsYS01cm9nYSIsImlzcyI6Imh0dHBzOi8vc2VjdXJldG9rZW4uZ29vZ2xlLmNvbS95YWxsYS01cm9nYSJ9.sig";

function fakeReq(authorization?: string): Request {
  return {
    headers: authorization === undefined ? {} : { authorization },
  } as Request;
}

function collectNext() {
  const calls: unknown[] = [];
  const next: NextFunction = (error?: unknown) => {
    calls.push(error);
  };
  return { next, calls };
}

describe("extractBearerToken", () => {
  it("returns null when the header is missing", () => {
    assert.equal(extractBearerToken(undefined), null);
  });

  it("returns null for a non-Bearer scheme", () => {
    assert.equal(extractBearerToken("Basic abc"), null);
  });

  it("returns null for Bearer with no token", () => {
    assert.equal(extractBearerToken("Bearer"), null);
    assert.equal(extractBearerToken("Bearer "), null);
  });

  it("reads a normal Bearer token", () => {
    assert.equal(extractBearerToken(`Bearer ${JWT}`), JWT);
  });

  it("is case-insensitive on the scheme", () => {
    assert.equal(extractBearerToken(`bearer ${JWT}`), JWT);
  });

  it("strips a duplicated Bearer prefix from Swagger paste", () => {
    assert.equal(extractBearerToken(`Bearer Bearer ${JWT}`), JWT);
  });

  it("strips quotes and whitespace inserted by copy-paste", () => {
    assert.equal(extractBearerToken(`Bearer  "${JWT}"  `), JWT);
  });

  it("strips newlines wrapped into a JWT", () => {
    const wrapped = `Bearer ${JWT.slice(0, 10)}\n${JWT.slice(10)}`;
    assert.equal(extractBearerToken(wrapped), JWT);
  });
});

describe("authMiddleware", () => {
  it("rejects a missing Authorization header with 401", async () => {
    const { next, calls } = collectNext();
    const middleware = createAuthMiddleware(async () => {
      throw new Error("verify must not run");
    });

    await middleware(fakeReq(), {} as Response, next);

    assert.equal(calls.length, 1);
    assert.ok(calls[0] instanceof UnauthorizedError);
    assert.equal((calls[0] as UnauthorizedError).statusCode, 401);
    assert.equal((calls[0] as UnauthorizedError).message, "Missing Bearer token");
  });

  it("rejects a malformed Bearer header with 401", async () => {
    const { next, calls } = collectNext();
    const middleware = createAuthMiddleware(async () => {
      throw new Error("verify must not run");
    });

    await middleware(fakeReq("Token abc"), {} as Response, next);

    assert.equal((calls[0] as UnauthorizedError).message, "Missing Bearer token");
  });

  it("rejects an invalid Firebase token with 401 without leaking internals", async () => {
    const { next, calls } = collectNext();
    const middleware = createAuthMiddleware(async () => {
      const error = new Error("Firebase ID token has expired");
      (error as Error & { code: string; codePrefix: string }).code =
        "auth/id-token-expired";
      (error as Error & { codePrefix: string }).codePrefix = "auth";
      error.name = "FirebaseAuthError";
      throw error;
    });

    await middleware(fakeReq(`Bearer ${JWT}`), {} as Response, next);

    const err = calls[0] as UnauthorizedError;
    assert.equal(err.statusCode, 401);
    assert.equal(err.message, "Invalid or expired Firebase token");
  });

  it("attaches the decoded Firebase user on success", async () => {
    const req = fakeReq(`Bearer Bearer ${JWT}`);
    const { next, calls } = collectNext();
    const middleware = createAuthMiddleware(async (token) => {
      assert.equal(token, JWT);
      return {
        uid: "firebase-uid",
        email: "user@example.com",
        name: "Ada",
        phone_number: "+201001234567",
        firebase: { sign_in_provider: "phone" },
      };
    });

    await middleware(req, {} as Response, next);

    assert.equal(calls[0], undefined);
    assert.deepEqual(req.user, {
      uid: "firebase-uid",
      email: "user@example.com",
      name: "Ada",
      phone: "+201001234567",
      signInProvider: "phone",
    });
  });

  it("does not treat a missing database user as an auth failure", async () => {
    const req = fakeReq(`Bearer ${JWT}`);
    const { next, calls } = collectNext();
    const middleware = createAuthMiddleware(async () => ({
      uid: "new-firebase-uid",
      firebase: { sign_in_provider: "google.com" },
    }));

    await middleware(req, {} as Response, next);

    assert.equal(calls[0], undefined);
    assert.equal(req.user?.uid, "new-firebase-uid");
  });
});

describe("optionalAuthMiddleware", () => {
  it("continues without a user when the token is missing or invalid", async () => {
    const missing = fakeReq();
    const invalid = fakeReq(`Bearer ${JWT}`);
    const { next, calls } = collectNext();
    const middleware = createOptionalAuthMiddleware(async () => {
      throw new Error("invalid");
    });

    await middleware(missing, {} as Response, next);
    await middleware(invalid, {} as Response, next);

    assert.equal(calls.length, 2);
    assert.equal(missing.user, undefined);
    assert.equal(invalid.user, undefined);
  });
});

describe("errorMiddleware auth responses", () => {
  it("returns { success: false, message } for 401", () => {
    const res = {
      statusCode: 0,
      body: undefined as unknown,
      status(code: number) {
        this.statusCode = code;
        return this;
      },
      json(payload: unknown) {
        this.body = payload;
        return this;
      },
    };

    errorMiddleware(
      new UnauthorizedError("Missing Bearer token"),
      fakeReq(),
      res as unknown as Response,
      (() => undefined) as NextFunction,
    );

    assert.equal(res.statusCode, 401);
    assert.deepEqual(res.body, {
      success: false,
      message: "Missing Bearer token",
    });
    assert.ok(new AppError(401, "x") instanceof AppError);
  });
});

async function withServer(
  register: (app: express.Express) => void,
  run: (baseUrl: string) => Promise<void>,
) {
  const app = express();
  register(app);
  app.use(errorMiddleware);

  const server = await new Promise<http.Server>((resolve) => {
    const listening = app.listen(0, "127.0.0.1", () => resolve(listening));
  });
  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("Failed to bind test server");
  }

  try {
    await run(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

async function httpJson(
  url: string,
  headers: Record<string, string> = {},
): Promise<{ status: number; body: unknown; responseHeaders: Headers }> {
  const response = await fetch(url, { headers });
  const text = await response.text();
  let body: unknown = text;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: response.status, body, responseHeaders: response.headers };
}

describe("protected vs public HTTP routes", () => {
  it("keeps public routes open and rejects unauthenticated protected routes", async () => {
    await withServer(
      (app) => {
        app.get("/public", (_req, res) => {
          res.json({ success: true, data: "ok" });
        });
        app.get("/protected", authMiddleware, (req, res) => {
          res.json({ success: true, uid: req.user?.uid });
        });
      },
      async (baseUrl) => {
        const publicResult = await httpJson(`${baseUrl}/public`);
        assert.equal(publicResult.status, 200);

        const missing = await httpJson(`${baseUrl}/protected`);
        assert.equal(missing.status, 401);
        assert.deepEqual(missing.body, {
          success: false,
          message: "Missing Bearer token",
        });

        const malformed = await httpJson(`${baseUrl}/protected`, {
          Authorization: "Bearer",
        });
        assert.equal(malformed.status, 401);
      },
    );
  });

  it("rejects an invalid Firebase token with 401", async () => {
    await withServer(
      (app) => {
        app.get("/protected", authMiddleware, (_req, res) => {
          res.json({ success: true });
        });
      },
      async (baseUrl) => {
        const result = await httpJson(`${baseUrl}/protected`, {
          Authorization: "Bearer not-a-firebase-token",
        });
        assert.equal(result.status, 401);
        assert.deepEqual(result.body, {
          success: false,
          message: "Invalid or expired Firebase token",
        });
      },
    );
  });

  it("allows Authorization on CORS preflight", async () => {
    await withServer(
      (app) => {
        app.use(
          cors({
            origin: true,
            credentials: true,
            allowedHeaders: ["Authorization", "Content-Type", "Accept"],
            methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
          }),
        );
        app.get("/protected", authMiddleware, (_req, res) => {
          res.json({ success: true });
        });
      },
      async (baseUrl) => {
        const response = await fetch(`${baseUrl}/protected`, {
          method: "OPTIONS",
          headers: {
            Origin: "http://localhost:5173",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization,content-type",
          },
        });
        assert.equal(response.status, 204);
        const allowHeaders =
          response.headers.get("access-control-allow-headers") ?? "";
        assert.match(allowHeaders, /authorization/i);
        assert.match(allowHeaders, /content-type/i);
      },
    );
  });
});
