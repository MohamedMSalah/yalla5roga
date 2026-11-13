import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { IGroupInvitationRepository } from "../src/repositories/groups/i-group-invitation.repository.js";
import type { IGroupRepository } from "../src/repositories/groups/i-group.repository.js";
import type { IOutingRepository } from "../src/repositories/outings/i-outing.repository.js";
import type { GroupInvitation } from "../src/types/groups/group-invitation.types.js";
import type { Outing } from "../src/types/outings/outing.types.js";
import type { User } from "../src/types/users/user.types.js";
import { AcceptGroupInvitationUseCase } from "../src/usecases/groups/accept-group-invitation.usecase.js";
import { DeclineGroupInvitationUseCase } from "../src/usecases/groups/decline-group-invitation.usecase.js";
import { CancelOutingUseCase } from "../src/usecases/outings/voting.usecase.js";
import { isPlaceCurator, placeCuratorUids } from "../src/middleware/place-curator.middleware.js";
import { toUserSummary } from "../src/services/auth/to-public-user.js";
import { listUsersQuerySchema } from "../src/validators/users/user.validator.js";
import { listNotificationsQuerySchema } from "../src/validators/notifications/notification.validator.js";

const GROUP_ID = "11111111-1111-4111-8111-111111111111";
const INVITATION_ID = "22222222-2222-4222-8222-222222222222";
const OUTING_ID = "44444444-4444-4444-8444-444444444444";
const USER_ID = "user-1";
const NOW = new Date("2026-11-13T00:00:00.000Z");

function invitation(overrides: Partial<GroupInvitation> = {}): GroupInvitation {
  return {
    id: INVITATION_ID,
    group_id: GROUP_ID,
    invited_by_user_id: "owner-1",
    invited_phone: "+201001234567",
    user_id: null,
    status: "pending",
    expires_at: NOW,
    created_at: NOW,
    updated_at: NOW,
    ...overrides,
  } as GroupInvitation;
}

class FakeInvitations {
  rows: GroupInvitation[] = [];
  acceptCalls = 0;
  declineCalls = 0;

  findById(id: string) {
    return Promise.resolve(this.rows.find((row) => row.id === id) ?? null);
  }

  accept(id: string, userId: string) {
    this.acceptCalls += 1;
    const row = this.rows.find((item) => item.id === id);
    if (!row) return Promise.resolve(null);
    row.status = "accepted";
    row.user_id = userId;
    return Promise.resolve({ ...row });
  }

  decline(id: string) {
    this.declineCalls += 1;
    const row = this.rows.find((item) => item.id === id);
    if (!row) return Promise.resolve(null);
    row.status = "declined";
    return Promise.resolve({ ...row });
  }
}

function acceptUseCase(invitations: FakeInvitations) {
  return new AcceptGroupInvitationUseCase(
    invitations as unknown as IGroupInvitationRepository,
    {} as IGroupRepository,
  );
}

function declineUseCase(invitations: FakeInvitations) {
  return new DeclineGroupInvitationUseCase(
    invitations as unknown as IGroupInvitationRepository,
  );
}

describe("invitation decisions return the persisted status", () => {
  it("accept returns accepted for a pending phone invitation", async () => {
    const invitations = new FakeInvitations();
    invitations.rows = [invitation()];

    const result = await acceptUseCase(invitations).execute({
      invitationId: INVITATION_ID,
      userId: USER_ID,
      userPhone: "+201001234567",
    });

    assert.equal(result.status, "accepted");
    assert.equal(invitations.acceptCalls, 1);
    assert.equal(invitations.rows[0]?.user_id, USER_ID);
  });

  it("accept replays the stored status without rewriting a declined row", async () => {
    const invitations = new FakeInvitations();
    invitations.rows = [invitation({ status: "declined", user_id: USER_ID })];

    const result = await acceptUseCase(invitations).execute({
      invitationId: INVITATION_ID,
      userId: USER_ID,
    });

    assert.equal(result.status, "declined");
    assert.equal(invitations.acceptCalls, 0);
    assert.equal(invitations.rows[0]?.status, "declined");
  });

  it("decline returns declined for a pending phone invitation", async () => {
    const invitations = new FakeInvitations();
    invitations.rows = [invitation()];

    const result = await declineUseCase(invitations).execute({
      invitationId: INVITATION_ID,
      userId: USER_ID,
      userPhone: "+201001234567",
    });

    assert.equal(result.status, "declined");
    assert.equal(invitations.declineCalls, 1);
  });

  it("decline replays the stored status without rewriting an accepted row", async () => {
    const invitations = new FakeInvitations();
    invitations.rows = [invitation({ status: "accepted", user_id: USER_ID })];

    const result = await declineUseCase(invitations).execute({
      invitationId: INVITATION_ID,
      userId: USER_ID,
    });

    assert.equal(result.status, "accepted");
    assert.equal(invitations.declineCalls, 0);
    assert.equal(invitations.rows[0]?.status, "accepted");
  });

  it("rejects a caller who is not the invitee", async () => {
    const invitations = new FakeInvitations();
    invitations.rows = [invitation({ user_id: "someone-else" })];

    await assert.rejects(
      () => acceptUseCase(invitations).execute({
        invitationId: INVITATION_ID,
        userId: USER_ID,
      }),
      /not for you/,
    );
  });
});

describe("place catalog curator allowlist", () => {
  it("fails closed when the allowlist is unset or empty", () => {
    assert.deepEqual(placeCuratorUids(undefined), []);
    assert.deepEqual(placeCuratorUids("   "), []);
    assert.equal(isPlaceCurator("uid-1", undefined), false);
    assert.equal(isPlaceCurator("uid-1", ""), false);
    assert.equal(isPlaceCurator(undefined, "uid-1"), false);
  });

  it("matches only listed Firebase UIDs", () => {
    const raw = " uid-1, uid-2 ,, ";
    assert.deepEqual(placeCuratorUids(raw), ["uid-1", "uid-2"]);
    assert.equal(isPlaceCurator("uid-1", raw), true);
    assert.equal(isPlaceCurator("uid-2", raw), true);
    assert.equal(isPlaceCurator("uid-3", raw), false);
  });
});

describe("user directory query", () => {
  it("requires an explicit filter", () => {
    assert.throws(() => listUsersQuerySchema.parse({}));
  });

  it("accepts a bounded id list and deduplicates it", () => {
    const parsed = listUsersQuerySchema.parse({ ids: "a, b, a" });
    assert.deepEqual(parsed.ids, ["a", "b"]);
    assert.equal(parsed.phone, null);
  });

  it("normalizes an exact phone lookup", () => {
    const parsed = listUsersQuerySchema.parse({ phone: "010 0123 4567" });
    assert.equal(parsed.phone, "+201001234567");
  });

  it("rejects invalid phones and oversized id lists", () => {
    assert.throws(() => listUsersQuerySchema.parse({ phone: "not-a-phone" }));
    const ids = Array.from({ length: 101 }, (_, index) => `uid-${index}`).join(",");
    assert.throws(() => listUsersQuerySchema.parse({ ids }));
  });
});

describe("notification pagination query", () => {
  it("keeps the legacy request valid", () => {
    assert.deepEqual(listNotificationsQuerySchema.parse({}), {});
  });

  it("coerces limit and accepts a uuid cursor", () => {
    const cursor = "33333333-3333-4333-8333-333333333333";
    assert.deepEqual(
      listNotificationsQuerySchema.parse({ limit: "25", cursor }),
      { limit: 25, cursor },
    );
  });

  it("rejects out-of-range limits and non-uuid cursors", () => {
    assert.throws(() => listNotificationsQuerySchema.parse({ limit: "0" }));
    assert.throws(() => listNotificationsQuerySchema.parse({ limit: "101" }));
    assert.throws(() => listNotificationsQuerySchema.parse({ cursor: "not-a-uuid" }));
  });
});
