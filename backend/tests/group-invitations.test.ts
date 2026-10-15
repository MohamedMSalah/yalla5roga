import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { describe, it } from "node:test";
import type { IGroupInvitationRepository } from "../src/repositories/groups/i-group-invitation.repository.js";
import type { IGroupRepository } from "../src/repositories/groups/i-group.repository.js";
import type { IUserRepository } from "../src/repositories/users/i-user.repository.js";
import {
  claimPendingInvitations,
  type InvitationClaimStore,
  type InvitationRecord,
} from "../src/services/groups/claim-pending-invitations.js";
import { invitationExpiresAt } from "../src/services/groups/invitation-policy.js";
import type { VerifiedPhoneLookup } from "../src/services/phone/firebase-verified-phone.js";
import {
  normalizePhoneNumber,
  tryNormalizePhoneNumber,
} from "../src/services/phone/normalize-phone.js";
import {
  buildInvitationMessage,
  buildWhatsAppClickToChatUrl,
} from "../src/services/whatsapp/invitation-message.js";
import type { GroupInvitation } from "../src/types/groups/group-invitation.types.js";
import type { Group, GroupMember } from "../src/types/groups/group.types.js";
import type { User } from "../src/types/users/user.types.js";
import { ClaimGroupInvitationsUseCase } from "../src/usecases/groups/claim-group-invitations.usecase.js";
import { InviteToGroupUseCase } from "../src/usecases/groups/invite-to-group.usecase.js";
import { SyncUserUseCase } from "../src/usecases/users/sync-user.usecase.js";
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from "../src/utils/errors.js";

const GROUP_ID = "11111111-1111-4111-8111-111111111111";
const OTHER_GROUP_ID = "22222222-2222-4222-8222-222222222222";
const INVITER_ID = "inviter";
const EXISTING_ID = "existing-user";
const NEW_USER_ID = "new-user";
const E164 = "+201001234567";
const OTHER_E164 = "+201112345678";
const NOW = new Date("2026-10-12T00:00:00.000Z");

function member(groupId: string, userId: string, role: "owner" | "member" = "member"): GroupMember {
  return {
    group_id: groupId,
    user_id: userId,
    role,
    joined_at: NOW,
  };
}

function invitation(overrides: Partial<InvitationRecord> = {}): InvitationRecord {
  return {
    id: "invite-1",
    group_id: GROUP_ID,
    invited_by_user_id: INVITER_ID,
    invited_phone: E164,
    user_id: null,
    status: "pending",
    expires_at: invitationExpiresAt(NOW),
    created_at: NOW,
    updated_at: NOW,
    ...overrides,
  };
}

class FakeGroups implements IGroupRepository {
  group: Group | null = { id: GROUP_ID } as Group;
  members: GroupMember[] = [member(GROUP_ID, INVITER_ID, "owner")];
  added: Array<{ groupId: string; userId: string }> = [];

  findById(id: string): Promise<Group | null> {
    return Promise.resolve(this.group?.id === id ? this.group : null);
  }
  findMany(): Promise<Group[]> {
    throw new Error("not used");
  }
  findByUserId(): Promise<Group[]> {
    throw new Error("not used");
  }
  create(): Promise<Group> {
    throw new Error("not used");
  }
  update(): Promise<Group> {
    throw new Error("not used");
  }
  delete(): Promise<Group> {
    throw new Error("not used");
  }
  addMember(): Promise<GroupMember> {
    throw new Error("not used");
  }
  addInvitedMember(groupId: string, userId: string) {
    this.added.push({ groupId, userId });
    const existing = this.members.find(
      (item) => item.group_id === groupId && item.user_id === userId,
    );
    if (existing) return Promise.resolve({ member: existing, created: false });
    const created = member(groupId, userId, "member");
    this.members.push(created);
    return Promise.resolve({ member: created, created: true });
  }
  findMember(groupId: string, userId: string) {
    return Promise.resolve(
      this.members.find(
        (item) => item.group_id === groupId && item.user_id === userId,
      ) ?? null,
    );
  }
  removeMember(): Promise<GroupMember> {
    throw new Error("not used");
  }
  listMembers(): Promise<GroupMember[]> {
    throw new Error("not used");
  }
}

class FakeInvitations implements IGroupInvitationRepository {
  rows: GroupInvitation[] = [];
  failCreate = false;

  findPending(groupId: string, phone: string) {
    return Promise.resolve(
      this.rows.find(
        (row) =>
          row.group_id === groupId &&
          row.invited_phone === phone &&
          row.status === "pending",
      ) ?? null,
    );
  }

  createPending(input: {
    group_id: string;
    invited_by_user_id: string;
    invited_phone: string;
    expires_at: Date;
  }) {
    if (this.failCreate) return Promise.reject(new Error("database unavailable"));
    const existing = this.rows.find(
      (row) =>
        row.group_id === input.group_id &&
        row.invited_phone === input.invited_phone &&
        row.status === "pending",
    );
    if (existing) return Promise.resolve({ invitation: existing, created: false });
    const row = invitation({
      id: `invite-${this.rows.length + 1}`,
      group_id: input.group_id,
      invited_by_user_id: input.invited_by_user_id,
      invited_phone: input.invited_phone,
      expires_at: input.expires_at,
    }) as GroupInvitation;
    this.rows.push(row);
    return Promise.resolve({ invitation: row, created: true });
  }

  claimForVerifiedPhone(): Promise<GroupInvitation[]> {
    throw new Error("not used");
  }
}

class FakeUsers implements IUserRepository {
  users = new Map<string, User>();
  synced: User | null = null;

  findById(id: string) {
    return Promise.resolve(this.users.get(id) ?? null);
  }
  findByPhone(phone: string) {
    for (const user of this.users.values()) {
      if (user.phone === phone) return Promise.resolve(user);
    }
    return Promise.resolve(null);
  }
  findMany(): Promise<User[]> {
    throw new Error("not used");
  }
  create(): Promise<User> {
    throw new Error("not used");
  }
  update(): Promise<User> {
    throw new Error("not used");
  }
  sync(data: {
    id: string;
    name: string;
    phone: string | null;
    email: string;
    image_url?: string | null;
  }) {
    const user = {
      ...data,
      image_url: data.image_url ?? null,
      created_at: NOW,
      updated_at: NOW,
    } as User;
    this.users.set(user.id, user);
    this.synced = user;
    return Promise.resolve(user);
  }
  delete(): Promise<User> {
    throw new Error("not used");
  }
}

class FakeVerifiedPhones implements VerifiedPhoneLookup {
  ids = new Map<string, string>();

  findUserIdByVerifiedPhone(e164: string) {
    return Promise.resolve(this.ids.get(e164) ?? null);
  }
}

function inviteUseCase(options?: {
  groups?: FakeGroups;
  invitations?: FakeInvitations;
  users?: FakeUsers;
  phones?: FakeVerifiedPhones;
}) {
  const groups = options?.groups ?? new FakeGroups();
  const invitations = options?.invitations ?? new FakeInvitations();
  const users = options?.users ?? new FakeUsers();
  const phones = options?.phones ?? new FakeVerifiedPhones();
  return {
    groups,
    invitations,
    users,
    phones,
    useCase: new InviteToGroupUseCase(
      groups,
      invitations,
      users,
      phones,
      () => NOW,
    ),
  };
}

type ClaimState = {
  invitations: InvitationRecord[];
  members: Array<{ group_id: string; user_id: string; role: "owner" | "member" }>;
  groups: string[];
  profiles: Array<{ id: string; phone: string }>;
};

class MemoryClaimStore implements InvitationClaimStore {
  acceptAttempts = 0;

  constructor(
    private readonly state: ClaimState,
    private readonly failOnAcceptAttempt?: number,
  ) {}

  listPendingByPhone(phone: string) {
    return Promise.resolve(
      this.state.invitations.filter(
        (row) => row.status === "pending" && row.invited_phone === phone,
      ),
    );
  }

  getById(id: string) {
    return Promise.resolve(
      this.state.invitations.find((row) => row.id === id) ?? null,
    );
  }

  async markExpired(id: string, now: Date) {
    const row = await this.required(id);
    row.status = "expired";
    row.updated_at = now;
  }

  async markRevoked(id: string, now: Date) {
    const row = await this.required(id);
    row.status = "revoked";
    row.updated_at = now;
  }

  async markAccepted(id: string, userId: string, now: Date) {
    this.acceptAttempts += 1;
    if (this.failOnAcceptAttempt === this.acceptAttempts) {
      throw new Error("database unavailable");
    }
    const row = await this.required(id);
    row.status = "accepted";
    row.user_id = userId;
    row.updated_at = now;
    return { ...row };
  }

  groupExists(groupId: string) {
    return Promise.resolve(this.state.groups.includes(groupId));
  }

  addInvitedMember(groupId: string, userId: string) {
    const existing = this.state.members.find(
      (item) => item.group_id === groupId && item.user_id === userId,
    );
    if (!existing) {
      this.state.members.push({ group_id: groupId, user_id: userId, role: "member" });
    }
    return Promise.resolve();
  }

  private async required(id: string) {
    const row = await this.getById(id);
    if (!row) throw new Error(`missing invitation ${id}`);
    return row;
  }
}

async function claimInTransaction(
  state: ClaimState,
  userId: string,
  phone: string,
  now = NOW,
  failOnAcceptAttempt?: number,
) {
  const draft: ClaimState = structuredClone(state);
  const store = new MemoryClaimStore(draft, failOnAcceptAttempt);
  try {
    const accepted = await claimPendingInvitations(store, { userId, phone, now });
    state.invitations = draft.invitations;
    state.members = draft.members;
    state.groups = draft.groups;
    state.profiles = draft.profiles;
    return accepted;
  } catch (error) {
    throw error;
  }
}

describe("phone normalization", () => {
  it("normalizes an Egyptian mobile number to E.164", () => {
    assert.equal(normalizePhoneNumber("010 0123 4567"), E164);
    assert.equal(normalizePhoneNumber(E164), E164);
  });

  it("rejects an invalid phone number", () => {
    assert.equal(tryNormalizePhoneNumber("not-a-phone"), null);
    assert.equal(tryNormalizePhoneNumber("12345"), null);
    assert.throws(() => normalizePhoneNumber("abc"), ValidationError);
  });
});

describe("WhatsApp click-to-chat", () => {
  it("encodes the message and omits the leading plus", () => {
    const message = "Hello & welcome?\nSee you 🎉";
    const url = buildWhatsAppClickToChatUrl(E164, message);
    const parsed = new URL(url);

    assert.equal(parsed.origin, "https://wa.me");
    assert.equal(parsed.pathname, "/201001234567");
    assert.equal(parsed.searchParams.get("text"), message);
    assert.equal(url.includes("+"), false);
  });

  it("keeps store links out of the default invitation message", () => {
    const message = buildInvitationMessage();
    assert.match(message, /App download links will be available here soon\./);
    assert.equal(message.includes("play.google.com"), false);
    assert.equal(message.includes("apps.apple.com"), false);
    assert.equal(message.includes("http"), false);

    const withLinks = buildInvitationMessage({
      googlePlay: "https://example.com/play",
      appStore: "https://example.com/app-store",
    });
    assert.match(withLinks, /https:\/\/example.com\/play/);
    assert.match(withLinks, /https:\/\/example.com\/app-store/);
  });
});

describe("invite to group", () => {
  it("saves a pending invitation when no account has that verified phone", async () => {
    const { useCase, invitations, groups } = inviteUseCase();

    const result = await useCase.execute({
      groupId: GROUP_ID,
      phoneNumber: "01001234567",
      invitedByUserId: INVITER_ID,
    });

    assert.equal(result.outcome, "invited");
    if (result.outcome !== "invited") return;
    assert.equal(result.invitation.invited_phone, E164);
    assert.equal(result.invitation.status, "pending");
    assert.equal(result.invitation.user_id, null);
    assert.match(result.whatsappUrl, /^https:\/\/wa\.me\/201001234567\?text=/);
    assert.equal(invitations.rows.length, 1);
    assert.equal(groups.added.length, 0);
  });

  it("adds an existing user whose Firebase phone is verified", async () => {
    const users = new FakeUsers();
    users.users.set(EXISTING_ID, { id: EXISTING_ID, phone: E164 } as User);
    const phones = new FakeVerifiedPhones();
    phones.ids.set(E164, EXISTING_ID);
    const { useCase, invitations, groups } = inviteUseCase({ users, phones });

    const result = await useCase.execute({
      groupId: GROUP_ID,
      phoneNumber: E164,
      invitedByUserId: INVITER_ID,
    });

    assert.equal(result.outcome, "member_added");
    if (result.outcome !== "member_added") return;
    assert.equal(result.member.user_id, EXISTING_ID);
    assert.equal(result.member.role, "member");
    assert.equal(invitations.rows.length, 0);
    assert.deepEqual(groups.added, [{ groupId: GROUP_ID, userId: EXISTING_ID }]);
    assert.equal(
      groups.members.filter((item) => item.user_id === EXISTING_ID).length,
      1,
    );
  });

  it("does not grant membership from a profile phone Firebase has not verified", async () => {
    const users = new FakeUsers();
    users.users.set(EXISTING_ID, { id: EXISTING_ID, phone: E164 } as User);
    const { useCase, groups, invitations } = inviteUseCase({ users });

    const result = await useCase.execute({
      groupId: GROUP_ID,
      phoneNumber: E164,
      invitedByUserId: INVITER_ID,
    });

    assert.equal(result.outcome, "invited");
    assert.equal(groups.added.length, 0);
    assert.equal(invitations.rows.length, 1);
    assert.equal(users.users.get(EXISTING_ID)?.id, EXISTING_ID);
  });

  it("keeps the invitation pending when Firebase knows the phone but the profile is not synced", async () => {
    const phones = new FakeVerifiedPhones();
    phones.ids.set(E164, EXISTING_ID);
    const { useCase, groups } = inviteUseCase({ phones });

    const result = await useCase.execute({
      groupId: GROUP_ID,
      phoneNumber: E164,
      invitedByUserId: INVITER_ID,
    });

    assert.equal(result.outcome, "invited");
    assert.equal(groups.added.length, 0);
  });

  it("rejects an invalid phone number", async () => {
    const { useCase } = inviteUseCase();
    await assert.rejects(
      () =>
        useCase.execute({
          groupId: GROUP_ID,
          phoneNumber: "12345",
          invitedByUserId: INVITER_ID,
        }),
      ValidationError,
    );
  });

  it("rejects an invitation from someone who is not in the group", async () => {
    const { useCase } = inviteUseCase();
    await assert.rejects(
      () =>
        useCase.execute({
          groupId: GROUP_ID,
          phoneNumber: E164,
          invitedByUserId: "outsider",
        }),
      (error: unknown) => {
        assert.ok(error instanceof ForbiddenError);
        assert.equal(error.message, "Only group members can invite");
        return true;
      },
    );
  });

  it("rejects an invitation for a missing group", async () => {
    const groups = new FakeGroups();
    groups.group = null;
    const { useCase } = inviteUseCase({ groups });
    await assert.rejects(
      () =>
        useCase.execute({
          groupId: GROUP_ID,
          phoneNumber: E164,
          invitedByUserId: INVITER_ID,
        }),
      NotFoundError,
    );
  });

  it("returns the existing pending invitation instead of creating another", async () => {
    const { useCase, invitations } = inviteUseCase();
    await useCase.execute({
      groupId: GROUP_ID,
      phoneNumber: E164,
      invitedByUserId: INVITER_ID,
    });
    const duplicate = await useCase.execute({
      groupId: GROUP_ID,
      phoneNumber: "01001234567",
      invitedByUserId: INVITER_ID,
    });

    assert.equal(duplicate.outcome, "already_pending");
    assert.equal(invitations.rows.length, 1);
    if (duplicate.outcome !== "already_pending") return;
    assert.match(duplicate.whatsappUrl, /^https:\/\/wa\.me\/201001234567\?text=/);
  });

  it("does not add a duplicate membership", async () => {
    const users = new FakeUsers();
    users.users.set(EXISTING_ID, { id: EXISTING_ID } as User);
    const phones = new FakeVerifiedPhones();
    phones.ids.set(E164, EXISTING_ID);
    const groups = new FakeGroups();
    groups.members.push(member(GROUP_ID, EXISTING_ID));
    const { useCase } = inviteUseCase({ users, phones, groups });

    const result = await useCase.execute({
      groupId: GROUP_ID,
      phoneNumber: E164,
      invitedByUserId: INVITER_ID,
    });

    assert.equal(result.outcome, "already_member");
    assert.equal(groups.added.length, 0);
    assert.equal(
      groups.members.filter((item) => item.user_id === EXISTING_ID).length,
      1,
    );
  });

  it("propagates a database failure", async () => {
    const invitations = new FakeInvitations();
    invitations.failCreate = true;
    const { useCase } = inviteUseCase({ invitations });

    await assert.rejects(
      () =>
        useCase.execute({
          groupId: GROUP_ID,
          phoneNumber: E164,
          invitedByUserId: INVITER_ID,
        }),
      /database unavailable/,
    );
  });
});

describe("claim pending invitations", () => {
  it("creates memberships for every pending invitation and marks them accepted", async () => {
    const state: ClaimState = {
      invitations: [
        invitation({ id: "a", group_id: GROUP_ID }),
        invitation({ id: "b", group_id: OTHER_GROUP_ID, invited_phone: E164 }),
        invitation({
          id: "other-phone",
          group_id: GROUP_ID,
          invited_phone: OTHER_E164,
        }),
      ],
      members: [],
      groups: [GROUP_ID, OTHER_GROUP_ID],
      profiles: [{ id: EXISTING_ID, phone: E164 }],
    };

    const accepted = await claimInTransaction(state, NEW_USER_ID, E164);

    assert.deepEqual(
      accepted.map((row) => row.group_id).sort(),
      [GROUP_ID, OTHER_GROUP_ID].sort(),
    );
    assert.equal(state.members.length, 2);
    assert.equal(
      state.members.every((item) => item.role === "member" && item.user_id === NEW_USER_ID),
      true,
    );
    assert.equal(
      state.invitations.filter((row) => row.status === "accepted").length,
      2,
    );
    assert.equal(
      state.invitations.find((row) => row.id === "other-phone")?.status,
      "pending",
    );
    assert.deepEqual(state.profiles, [{ id: EXISTING_ID, phone: E164 }]);
  });

  it("is idempotent when synchronization runs again", async () => {
    const state: ClaimState = {
      invitations: [invitation()],
      members: [],
      groups: [GROUP_ID],
      profiles: [],
    };

    await claimInTransaction(state, NEW_USER_ID, E164);
    await claimInTransaction(state, NEW_USER_ID, E164);

    assert.equal(state.members.length, 1);
    assert.equal(state.invitations[0]?.status, "accepted");
    assert.equal(state.invitations[0]?.user_id, NEW_USER_ID);
  });

  it("expires an invitation instead of creating a membership", async () => {
    const state: ClaimState = {
      invitations: [
        invitation({ expires_at: new Date("2026-10-01T00:00:00.000Z") }),
      ],
      members: [],
      groups: [GROUP_ID],
      profiles: [],
    };

    const accepted = await claimInTransaction(state, NEW_USER_ID, E164);
    assert.deepEqual(accepted, []);
    assert.equal(state.members.length, 0);
    assert.equal(state.invitations[0]?.status, "expired");
  });

  it("leaves revoked invitations untouched", async () => {
    const state: ClaimState = {
      invitations: [invitation({ status: "revoked" })],
      members: [],
      groups: [GROUP_ID],
      profiles: [],
    };

    const accepted = await claimInTransaction(state, NEW_USER_ID, E164);
    assert.deepEqual(accepted, []);
    assert.equal(state.members.length, 0);
    assert.equal(state.invitations[0]?.status, "revoked");
    assert.equal(state.invitations[0]?.user_id, null);
  });

  it("does not join a deleted group", async () => {
    const state: ClaimState = {
      invitations: [invitation()],
      members: [],
      groups: [],
      profiles: [],
    };

    const accepted = await claimInTransaction(state, NEW_USER_ID, E164);
    assert.deepEqual(accepted, []);
    assert.equal(state.members.length, 0);
    assert.equal(state.invitations[0]?.status, "revoked");
  });

  it("rolls back membership and acceptance when a later write fails", async () => {
    const state: ClaimState = {
      invitations: [
        invitation({ id: "a", group_id: GROUP_ID }),
        invitation({ id: "b", group_id: OTHER_GROUP_ID }),
      ],
      members: [],
      groups: [GROUP_ID, OTHER_GROUP_ID],
      profiles: [{ id: EXISTING_ID, phone: "untouched" }],
    };
    const before = structuredClone(state);

    await assert.rejects(
      () => claimInTransaction(state, NEW_USER_ID, E164, NOW, 2),
      /database unavailable/,
    );

    assert.deepEqual(state, before);
  });

  it("does not claim when the token has no verified phone", async () => {
    let calls = 0;
    const repository: IGroupInvitationRepository = {
      findPending: () => Promise.resolve(null),
      createPending: () => Promise.reject(new Error("not used")),
      claimForVerifiedPhone: () => {
        calls += 1;
        return Promise.resolve([]);
      },
    };
    const useCase = new ClaimGroupInvitationsUseCase(repository);

    assert.deepEqual(
      await useCase.execute({ userId: NEW_USER_ID, verifiedPhone: null }),
      [],
    );
    assert.deepEqual(
      await useCase.execute({ userId: NEW_USER_ID, verifiedPhone: "12345" }),
      [],
    );
    assert.equal(calls, 0);

    await useCase.execute({ userId: NEW_USER_ID, verifiedPhone: "01001234567" });
    assert.equal(calls, 1);
  });
});

describe("account sync", () => {
  function syncHarness() {
    const users = new FakeUsers();
    const claimed: Array<{ userId: string; verifiedPhone?: string | null }> = [];
    const claim = {
      execute: (input: { userId: string; verifiedPhone?: string | null }) => {
        claimed.push(input);
        return Promise.resolve([
          invitation({ group_id: GROUP_ID }) as GroupInvitation,
        ]);
      },
    };
    return { users, claimed, useCase: new SyncUserUseCase(users, claim) };
  }

  it("claims invitations for a verified phone and keeps that phone on later syncs", async () => {
    const { users, claimed, useCase } = syncHarness();

    const first = await useCase.execute({
      id: NEW_USER_ID,
      name: "Nour",
      email: "nour@example.com",
      phone: OTHER_E164,
      verifiedPhone: E164,
      signInProvider: "phone",
    });
    const second = await useCase.execute({
      id: NEW_USER_ID,
      name: "Nour",
      email: "nour@example.com",
      phone: OTHER_E164,
      verifiedPhone: null,
      signInProvider: "phone",
    });

    assert.equal(first.invitations.status, "claimed");
    assert.deepEqual(first.invitations.claimedGroupIds, [GROUP_ID]);
    assert.equal(first.user.phone, E164);
    assert.equal(second.invitations.status, "phone_verification_required");
    assert.deepEqual(second.invitations.claimedGroupIds, []);
    assert.equal(users.synced?.phone, E164);
    assert.equal(users.users.size, 1);
    assert.deepEqual(claimed, [{ userId: NEW_USER_ID, verifiedPhone: E164 }]);
  });

  it("lets Google and Apple accounts register without claiming by email", async () => {
    for (const signInProvider of ["google.com", "apple.com"] as const) {
      const { users, claimed, useCase } = syncHarness();
      const result = await useCase.execute({
        id: signInProvider,
        name: "Nour",
        email: "nour@example.com",
        signInProvider,
      });

      assert.equal(result.user.id, signInProvider);
      assert.equal(result.user.phone, null);
      assert.equal(result.invitations.phoneVerified, false);
      assert.equal(result.invitations.status, "phone_verification_required");
      assert.deepEqual(result.invitations.claimedGroupIds, []);
      assert.equal(JSON.stringify(result.invitations).includes("invite"), false);
      assert.equal(claimed.length, 0);
      assert.equal(users.users.size, 1);
    }
  });

  it("claims after Google or Apple links a verified phone on the same account", async () => {
    for (const signInProvider of ["google.com", "apple.com"] as const) {
      const { users, claimed, useCase } = syncHarness();
      await useCase.execute({
        id: "social-user",
        name: "Nour",
        email: "nour@example.com",
        signInProvider,
      });
      const linked = await useCase.execute({
        id: "social-user",
        name: "Nour",
        email: "nour@example.com",
        verifiedPhone: "01001234567",
        signInProvider,
      });

      assert.equal(users.users.size, 1);
      assert.equal(linked.user.id, "social-user");
      assert.equal(linked.user.phone, E164);
      assert.equal(linked.invitations.phoneVerified, true);
      assert.equal(linked.invitations.status, "claimed");
      assert.deepEqual(claimed, [
        { userId: "social-user", verifiedPhone: E164 },
      ]);
    }
  });

  it("does not claim an unverified phone submitted in the profile", async () => {
    const { users, claimed, useCase } = syncHarness();
    const result = await useCase.execute({
      id: NEW_USER_ID,
      name: "Nour",
      email: "nour@example.com",
      phone: "01001234567",
      verifiedPhone: null,
      signInProvider: "password",
    });

    assert.equal(result.user.phone, E164);
    assert.equal(result.invitations.status, "phone_verification_required");
    assert.equal(claimed.length, 0);
    assert.equal(users.users.size, 1);
  });

  it("refuses to attach a phone that already belongs to another account", async () => {
    const { users, claimed, useCase } = syncHarness();
    users.users.set("other-account", {
      id: "other-account",
      phone: E164,
      name: "Other",
    } as User);

    await assert.rejects(
      () =>
        useCase.execute({
          id: NEW_USER_ID,
          name: "Nour",
          email: "nour@example.com",
          verifiedPhone: E164,
          signInProvider: "google.com",
        }),
      (error: unknown) => {
        assert.ok(error instanceof ConflictError);
        assert.equal(
          error.message,
          "This phone number is already associated with another account",
        );
        return true;
      },
    );

    assert.equal(users.users.get("other-account")?.id, "other-account");
    assert.equal(users.users.get("other-account")?.phone, E164);
    assert.equal(users.users.has(NEW_USER_ID), false);
    assert.equal(claimed.length, 0);
  });

  it("repeated sync creates one membership per invited group", async () => {
    const state: ClaimState = {
      invitations: [
        invitation({ id: "a", group_id: GROUP_ID }),
        invitation({ id: "b", group_id: OTHER_GROUP_ID }),
      ],
      members: [member(GROUP_ID, INVITER_ID, "owner")],
      groups: [GROUP_ID, OTHER_GROUP_ID],
      profiles: [{ id: EXISTING_ID, phone: E164 }],
    };
    const repository: IGroupInvitationRepository = {
      findPending: () => Promise.resolve(null),
      createPending: () => Promise.reject(new Error("not used")),
      claimForVerifiedPhone: (userId, phone) =>
        claimInTransaction(state, userId, phone) as Promise<GroupInvitation[]>,
    };
    const useCase = new SyncUserUseCase(
      new FakeUsers(),
      new ClaimGroupInvitationsUseCase(repository),
    );
    const input = {
      id: NEW_USER_ID,
      name: "Nour",
      email: "nour@example.com",
      phone: "01099999999",
      verifiedPhone: E164,
    };

    await useCase.execute(input);
    await useCase.execute(input);

    assert.equal(
      state.members.filter((item) => item.user_id === NEW_USER_ID).length,
      2,
    );
    assert.equal(
      state.members.filter((item) => item.user_id === INVITER_ID && item.role === "owner")
        .length,
      1,
    );
    assert.deepEqual(state.profiles, [{ id: EXISTING_ID, phone: E164 }]);
  });
});

describe("invitation feature boundaries", () => {
  it("does not add an email field or email delivery for invitations", () => {
    const root = process.cwd();
    const schema = fs.readFileSync(path.join(root, "prisma", "schema.prisma"), "utf8");
    const model = schema.slice(
      schema.indexOf("model group_invitations"),
      schema.indexOf("model user_fcm_tokens"),
    );
    assert.equal(model.includes("email"), false);
    assert.match(model, /invited_phone/);

    const files = [
      "src/services/whatsapp/invitation-message.ts",
      "src/usecases/groups/invite-to-group.usecase.ts",
      "src/usecases/groups/claim-group-invitations.usecase.ts",
      "src/datasources/groups/group-invitation.datasource.ts",
      "src/services/groups/claim-pending-invitations.ts",
    ];
    for (const file of files) {
      const source = fs.readFileSync(path.join(root, file), "utf8").toLowerCase();
      assert.equal(source.includes("nodemailer"), false, file);
      assert.equal(source.includes("sendmail"), false, file);
      assert.equal(source.includes("email"), false, file);
    }
  });

  it("places invitation and account sync routes behind Firebase authentication", () => {
    const groups = fs.readFileSync(
      path.join(process.cwd(), "src", "routes", "groups", "group.routes.ts"),
      "utf8",
    );
    const groupAuth = groups.indexOf("api.use(authMiddleware)");
    const inviteAt = groups.indexOf('"/:id/invitations"');
    assert.equal(groupAuth > -1 && inviteAt > groupAuth, true);

    const users = fs.readFileSync(
      path.join(process.cwd(), "src", "routes", "users", "user.routes.ts"),
      "utf8",
    );
    const userAuth = users.indexOf("api.use(authMiddleware)");
    const syncAt = users.indexOf('"/sync"');
    assert.equal(userAuth > -1 && syncAt > userAuth, true);
  });
});
