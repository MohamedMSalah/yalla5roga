import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { IUserRepository } from "../src/repositories/users/i-user.repository.js";
import type { User } from "../src/types/users/user.types.js";
import { SyncUserUseCase } from "../src/usecases/users/sync-user.usecase.js";
import { UpdateUserUseCase } from "../src/usecases/users/update-user.usecase.js";
import {
  syncUserBodySchema,
  updateUserBodySchema,
} from "../src/validators/users/user.validator.js";
import { ConflictError, UnauthorizedError, ValidationError } from "../src/utils/errors.js";
import { UserController } from "../src/controllers/users/user.controller.js";
import type { NextFunction, Request, Response } from "express";

const NOW = new Date("2026-11-04T00:00:00.000Z");
const USER_ID = "firebase-uid-1";
const OTHER_ID = "firebase-uid-2";
const E164 = "+201001234567";
const OTHER_E164 = "+201112345678";
const GROUP_ID = "11111111-1111-4111-8111-111111111111";

class FakeUsers implements IUserRepository {
  users = new Map<string, User>();

  findById(id: string) {
    return Promise.resolve(this.users.get(id) ?? null);
  }

  findByEmail(email: string) {
    for (const user of this.users.values()) {
      if (user.email === email) return Promise.resolve(user);
    }
    return Promise.resolve(null);
  }

  findByPhone(phone: string) {
    for (const user of this.users.values()) {
      if (user.phone === phone) return Promise.resolve(user);
    }
    return Promise.resolve(null);
  }

  findMany(): Promise<User[]> {
    return Promise.resolve([...this.users.values()]);
  }

  create(data: {
    id: string;
    name: string;
    phone: string | null;
    email: string | null;
    image_url?: string | null;
    password_hash?: string | null;
    password_updated_at?: Date | null;
  }) {
    if (this.users.has(data.id)) {
      throw new Error("duplicate user");
    }
    const user = {
      id: data.id,
      name: data.name,
      phone: data.phone,
      email: data.email,
      password_hash: data.password_hash ?? null,
      password_updated_at: data.password_updated_at ?? null,
      image_url: data.image_url ?? null,
      created_at: NOW,
      updated_at: NOW,
    } as User;
    this.users.set(user.id, user);
    return Promise.resolve(user);
  }

  update(id: string, data: Partial<User>) {
    const existing = this.users.get(id);
    if (!existing) throw new Error("missing user");
    const user = { ...existing, ...data, updated_at: NOW } as User;
    this.users.set(id, user);
    return Promise.resolve(user);
  }

  sync(): Promise<User> {
    throw new Error("legacy sync must not be used by SyncUserUseCase");
  }

  delete(id: string) {
    const user = this.users.get(id);
    if (!user) throw new Error("missing user");
    this.users.delete(id);
    return Promise.resolve(user);
  }
}

function syncHarness(options?: {
  claim?: (input: { userId: string; verifiedPhone?: string | null }) => Promise<
    Array<{ group_id: string }>
  >;
}) {
  const users = new FakeUsers();
  const claimed: Array<{ userId: string; verifiedPhone?: string | null }> = [];
  const claim = {
    execute: async (input: {
      userId: string;
      verifiedPhone?: string | null;
    }) => {
      claimed.push(input);
      if (options?.claim) return options.claim(input);
      return [{ group_id: GROUP_ID }];
    },
  };
  return {
    users,
    claimed,
    useCase: new SyncUserUseCase(users, claim),
  };
}

describe("POST /api/users/sync identity vs profile", () => {
  it("requires a verified phone to create a profile", async () => {
    const { users, claimed, useCase } = syncHarness();
    await assert.rejects(
      useCase.execute({ id: USER_ID, tokenName: "Nour", phone: E164 }),
      UnauthorizedError,
    );
    assert.equal(users.users.size, 0);
    assert.equal(claimed.length, 0);
  });

  it("returns an existing Google profile without overwriting profile fields", async () => {
    const { users, useCase } = syncHarness();
    users.users.set(USER_ID, {
      id: USER_ID,
      name: "Stored Name",
      email: "stored@example.com",
      phone: OTHER_E164,
      image_url: "https://cdn.example.com/avatar.png",
      created_at: NOW,
      updated_at: NOW,
    } as User);

    const result = await useCase.execute({
      id: USER_ID,
      name: "Wrong Name From Client",
      email: "wrong@example.com",
      phone: E164,
      image_url: "https://evil.example.com/overwrite.png",
      tokenEmail: "token@example.com",
      tokenName: "Token Name",
      signInProvider: "google.com",
    });

    assert.equal(users.users.size, 1);
    assert.equal(result.user.name, "Stored Name");
    assert.equal(result.user.email, "stored@example.com");
    assert.equal(result.user.phone, OTHER_E164);
    assert.equal(result.user.image_url, "https://cdn.example.com/avatar.png");
  });

  it("is idempotent and does not create duplicates on repeated sync", async () => {
    const { users, useCase } = syncHarness();

    await useCase.execute({
      id: USER_ID,
      verifiedPhone: E164,
      tokenName: "Nour",
      signInProvider: "google.com",
    });
    await useCase.execute({
      id: USER_ID,
      name: "Changed",
      email: "changed@example.com",
      image_url: "https://cdn.example.com/x.png",
      tokenEmail: "nour@example.com",
      signInProvider: "google.com",
    });

    assert.equal(users.users.size, 1);
    assert.equal(users.users.get(USER_ID)?.name, "Nour");
    assert.equal(users.users.get(USER_ID)?.phone, E164);
  });

  it("keeps a valid name and image when sync body is empty or incorrect", async () => {
    const { users, useCase } = syncHarness();
    users.users.set(USER_ID, {
      id: USER_ID,
      name: "Valid Name",
      email: "valid@example.com",
      phone: null,
      image_url: "https://cdn.example.com/keep.png",
      created_at: NOW,
      updated_at: NOW,
    } as User);

    const result = await useCase.execute({
      id: USER_ID,
      name: " ",
      email: "spoofed@example.com",
      image_url: null,
      signInProvider: "apple.com",
    });

    assert.equal(result.user.name, "Valid Name");
    assert.equal(result.user.image_url, "https://cdn.example.com/keep.png");
    assert.equal(result.user.email, "valid@example.com");
  });

  it("does not treat an unverified body phone as verified or claim invitations", async () => {
    const { users, claimed, useCase } = syncHarness();
    await users.create({ id: USER_ID, name: "Nour", phone: null, email: null });
    const result = await useCase.execute({ id: USER_ID, phone: "01001234567" });
    assert.equal(result.user.phone, null);
    assert.equal(result.invitations.phoneVerified, false);
    assert.equal(result.invitations.status, "phone_verification_required");
    assert.deepEqual(result.invitations.claimedGroupIds, []);
    assert.equal(claimed.length, 0);
  });

  it("applies a verified Firebase phone and claims invitations", async () => {
    const { users, claimed, useCase } = syncHarness();

    const result = await useCase.execute({
      id: USER_ID,
      tokenName: "Nour",
      tokenEmail: "nour@example.com",
      verifiedPhone: "01001234567",
      signInProvider: "phone",
    });

    assert.equal(result.user.phone, E164);
    assert.equal(result.invitations.phoneVerified, true);
    assert.equal(result.invitations.status, "claimed");
    assert.deepEqual(result.invitations.claimedGroupIds, [GROUP_ID]);
    assert.deepEqual(claimed, [{ userId: USER_ID, verifiedPhone: E164 }]);
    assert.equal(users.users.size, 1);
  });

  it("returns 409 when a verified phone belongs to another account", async () => {
    const { users, claimed, useCase } = syncHarness();
    users.users.set(OTHER_ID, {
      id: OTHER_ID,
      name: "Other",
      phone: E164,
      email: "other@example.com",
      image_url: null,
      created_at: NOW,
      updated_at: NOW,
    } as User);

    await assert.rejects(
      () =>
        useCase.execute({
          id: USER_ID,
          tokenName: "Nour",
          tokenEmail: "nour@example.com",
          verifiedPhone: E164,
          signInProvider: "google.com",
        }),
      (error: unknown) => {
        assert.ok(error instanceof ConflictError);
        assert.equal(error.statusCode, 409);
        return true;
      },
    );

    assert.equal(users.users.has(USER_ID), false);
    assert.equal(claimed.length, 0);
  });

  it("does not replace an existing phone with an unverified body phone", async () => {
    const { users, useCase } = syncHarness();
    users.users.set(USER_ID, {
      id: USER_ID,
      name: "Nour",
      email: "nour@example.com",
      phone: OTHER_E164,
      image_url: null,
      created_at: NOW,
      updated_at: NOW,
    } as User);

    const result = await useCase.execute({
      id: USER_ID,
      phone: E164,
      verifiedPhone: null,
      signInProvider: "google.com",
    });

    assert.equal(result.user.phone, OTHER_E164);
  });

  it("ignores legacy email values in sync", async () => {
    const { users, useCase } = syncHarness();
    users.users.set(USER_ID, {
      id: USER_ID,
      name: "Nour",
      email: null,
      phone: null,
      image_url: null,
      created_at: NOW,
      updated_at: NOW,
    } as User);

    const filled = await useCase.execute({
      id: USER_ID,
      email: "body-should-not-win@example.com",
      tokenEmail: "token@example.com",
      signInProvider: "google.com",
    });
    assert.equal(filled.user.email, null);

    const kept = await useCase.execute({
      id: USER_ID,
      tokenEmail: null,
      email: null,
      signInProvider: "google.com",
    });
    assert.equal(kept.user.email, null);
    assert.equal(users.users.size, 1);
  });

  it("does not overwrite the profile created by phone/password signup", async () => {
    const { users, useCase } = syncHarness();
    await users.create({ id: USER_ID, name: "Nour", phone: E164, email: null, password_hash: "hash" });
    const synced = await useCase.execute({
      id: USER_ID,
      name: "Other",
      phone: OTHER_E164,
      verifiedPhone: E164,
    });
    assert.equal(users.users.size, 1);
    assert.equal(synced.user.name, "Nour");
    assert.equal(synced.user.phone, E164);
    assert.equal(synced.user.password_hash, "hash");
  });

  it("updates a verified phone on an existing account and claims invitations", async () => {
    const { users, claimed, useCase } = syncHarness();
    users.users.set(USER_ID, {
      id: USER_ID,
      name: "Nour",
      email: "nour@example.com",
      phone: null,
      image_url: "https://cdn.example.com/a.png",
      created_at: NOW,
      updated_at: NOW,
    } as User);

    const linked = await useCase.execute({
      id: USER_ID,
      name: "Should Not Overwrite",
      image_url: "https://evil.example.com/x.png",
      verifiedPhone: E164,
      signInProvider: "google.com",
    });

    assert.equal(linked.user.name, "Nour");
    assert.equal(linked.user.image_url, "https://cdn.example.com/a.png");
    assert.equal(linked.user.phone, E164);
    assert.equal(linked.invitations.status, "claimed");
    assert.equal(users.users.size, 1);
    assert.deepEqual(claimed, [{ userId: USER_ID, verifiedPhone: E164 }]);
  });
});

describe("sync request body validation", () => {
  it("accepts an empty body for sync", () => {
    const parsed = syncUserBodySchema.parse({});
    assert.equal(parsed.phone, null);
    assert.equal(parsed.image_url, null);
  });

  it("rejects conflicting phone and phoneNumber aliases", () => {
    assert.throws(() =>
      syncUserBodySchema.parse({
        phone: "+201001234567",
        phoneNumber: "+201112345678",
      }),
    );
  });

  it("accepts matching phone aliases", () => {
    const parsed = syncUserBodySchema.parse({
      phone: "01001234567",
      phoneNumber: "+201001234567",
    });
    // phoneNumber wins when both are present and equivalent after normalize.
    assert.equal(parsed.phone, "+201001234567");
  });
});

describe("PATCH /api/users/cuser profile updates", () => {
  it("updates profile fields independently of sync", async () => {
    const users = new FakeUsers();
    users.users.set(USER_ID, {
      id: USER_ID,
      name: "Nour",
      email: "nour@example.com",
      phone: E164,
      image_url: null,
      created_at: NOW,
      updated_at: NOW,
    } as User);

    const update = new UpdateUserUseCase(users);
    const updated = await update.execute(USER_ID, {
      name: "Nour Updated",
      image_url: "https://cdn.example.com/new.png",
    });

    assert.equal(updated.name, "Nour Updated");
    assert.equal(updated.image_url, "https://cdn.example.com/new.png");
    assert.equal(updated.phone, E164);

    // Sync must not undo the profile edit.
    const sync = new SyncUserUseCase(users, {
      execute: () => Promise.resolve([]),
    });
    const afterSync = await sync.execute({
      id: USER_ID,
      name: "Client Spoof",
      email: "spoof@example.com",
      image_url: "https://evil.example.com/x.png",
      phone: OTHER_E164,
      signInProvider: "google.com",
    });

    assert.equal(afterSync.user.name, "Nour Updated");
    assert.equal(afterSync.user.image_url, "https://cdn.example.com/new.png");
    assert.equal(afterSync.user.phone, E164);
  });

  it("rejects conflicting phone aliases on update", () => {
    assert.throws(() =>
      updateUserBodySchema.parse({
        phone: "+201001234567",
        phoneNumber: "+201112345678",
      }),
    );
  });

  it("requires Firebase proof for profile phone changes", async () => {
    const users = new FakeUsers();
    users.users.set(USER_ID, {
      id: USER_ID,
      name: "Nour",
      email: "a@example.com",
      phone: null,
      image_url: null,
      created_at: NOW,
      updated_at: NOW,
    } as User);
    users.users.set(OTHER_ID, {
      id: OTHER_ID,
      name: "Other",
      email: "b@example.com",
      phone: E164,
      image_url: null,
      created_at: NOW,
      updated_at: NOW,
    } as User);

    const update = new UpdateUserUseCase(users);
    await assert.rejects(
      () => update.execute(USER_ID, { phone: E164 }),
      (error: unknown) => error instanceof ValidationError,
    );
  });
});

describe("sync controller identity binding", () => {
  it("uses req.user.uid and ignores body id/role", async () => {
    const users = new FakeUsers();
    const useCase = new SyncUserUseCase(users, {
      execute: () => Promise.resolve([]),
    });
    await users.create({ id: USER_ID, name: "Stored Name", phone: E164, email: null });
    const controller = new UserController(useCase);

    const req = {
      user: {
        uid: USER_ID,
        email: "token@example.com",
        name: "Token Name",
        phone: undefined,
        signInProvider: "google.com",
      },
      body: {
        id: "attacker-uid",
        uid: "attacker-uid",
        role: "admin",
        name: "Body Name",
        email: "body@example.com",
      },
    } as unknown as Request;

    let statusCode = 0;
    let payload: { data?: User } | null = null;
    const res = {
      status(code: number) {
        statusCode = code;
        return this;
      },
      json(body: { data?: User }) {
        payload = body;
        return this;
      },
    } as unknown as Response;

    const next: NextFunction = (error?: unknown) => {
      if (error) throw error;
    };

    await controller.sync(req, res, next);

    assert.equal(statusCode, 200);
    assert.equal(payload?.data?.id, USER_ID);
    assert.equal(users.users.has("attacker-uid"), false);
    assert.equal(users.users.get(USER_ID)?.name, "Stored Name");
  });

  it("returns 401 when the Firebase user is missing", async () => {
    const controller = new UserController();
    const req = { user: undefined, body: {} } as unknown as Request;
    const res = {} as Response;
    let caught: unknown;
    const next: NextFunction = (error?: unknown) => {
      caught = error;
    };

    await controller.sync(req, res, next);
    assert.ok(caught instanceof UnauthorizedError);
  });
});
