import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { IGroupRepository } from "../src/repositories/groups/i-group.repository.js";
import type { INotificationRepository } from "../src/repositories/notifications/i-notification.repository.js";
import type { IOutingRepository } from "../src/repositories/outings/i-outing.repository.js";
import type { IUserRepository } from "../src/repositories/users/i-user.repository.js";
import type { Group, GroupMember } from "../src/types/groups/group.types.js";
import type { Notification } from "../src/types/notifications/notification.types.js";
import type {
  Outing,
  OutingGuest,
  OutingVoteOption,
  UpdateOutingInput,
} from "../src/types/outings/outing.types.js";
import type { User } from "../src/types/users/user.types.js";
import { AddGroupMemberUseCase } from "../src/usecases/groups/add-group-member.usecase.js";
import { DeleteGroupUseCase } from "../src/usecases/groups/delete-group.usecase.js";
import { RemoveGroupMemberUseCase } from "../src/usecases/groups/remove-group-member.usecase.js";
import { UpdateGroupUseCase } from "../src/usecases/groups/update-group.usecase.js";
import { MarkAllNotificationsReadUseCase } from "../src/usecases/notifications/mark-all-notifications-read.usecase.js";
import { MarkNotificationReadUseCase } from "../src/usecases/notifications/mark-notification-read.usecase.js";
import { DeleteOutingUseCase } from "../src/usecases/outings/delete-outing.usecase.js";
import {
  AddGuestUseCase,
  RemoveGuestUseCase,
} from "../src/usecases/outings/guests.usecase.js";
import { UpdateOutingUseCase } from "../src/usecases/outings/update-outing.usecase.js";
import {
  CreateVoteOptionUseCase,
  DeleteVoteOptionUseCase,
} from "../src/usecases/outings/voting.usecase.js";
import {
  ForbiddenError,
  NotFoundError,
} from "../src/utils/errors.js";

// Keep fixture clocks relative to wall time so vote deadline checks stay open.
const NOW = new Date();
const CREATOR = "creator-uid";
const OTHER = "other-uid";
const OWNER = "owner-uid";
const MEMBER = "member-uid";
const GROUP_ID = "11111111-1111-4111-8111-111111111111";
const OUTING_ID = "22222222-2222-4222-8222-222222222222";
const OPTION_ID = "33333333-3333-4333-8333-333333333333";
const NOTIF_ID = "44444444-4444-4444-8444-444444444444";

function baseOuting(overrides: Partial<Outing> = {}): Outing {
  return {
    id: OUTING_ID,
    title: "Picnic",
    image_url: "",
    group_id: GROUP_ID,
    created_by: CREATOR,
    status: "draft",
    type: "group",
    occasion: "none",
    scheduled_at: NOW,
    ends_at: null,
    location_place_id: null,
    location_name: null,
    location_area: null,
    location_latitude: null,
    location_longitude: null,
    vote_deadline_hours: 24,
    vote_ends_at: new Date(NOW.getTime() + 24 * 60 * 60 * 1000),
    vote_closed_at: null,
    vote_close_reason: null,
    winning_option_id: null,
    suggested_by_user_id: null,
    created_at: NOW,
    updated_at: NOW,
    ...overrides,
  } as Outing;
}

class FakeOutings implements Partial<IOutingRepository> {
  outing: Outing | null = baseOuting();
  guests: OutingGuest[] = [];
  options = new Map<string, OutingVoteOption>();
  updated: UpdateOutingInput | null = null;
  deleted = false;

  findById(id: string) {
    return Promise.resolve(this.outing?.id === id ? this.outing : null);
  }
  update(id: string, data: UpdateOutingInput) {
    assert.equal(id, OUTING_ID);
    this.updated = data;
    this.outing = { ...this.outing!, ...data, updated_at: NOW } as Outing;
    return Promise.resolve(this.outing);
  }
  delete(id: string) {
    assert.equal(id, OUTING_ID);
    this.deleted = true;
    const row = this.outing!;
    this.outing = null;
    return Promise.resolve(row);
  }
  addGuest(data: {
    outing_id: string;
    user_id: string;
    status?: OutingGuest["status"];
  }) {
    const guest = {
      outing_id: data.outing_id,
      user_id: data.user_id,
      status: data.status ?? "pending",
      invited_at: NOW,
    } as OutingGuest;
    this.guests.push(guest);
    return Promise.resolve(guest);
  }
  clearVotes() {
    return Promise.resolve(0);
  }
  removeGuest(outingId: string, userId: string) {
    const idx = this.guests.findIndex(
      (g) => g.outing_id === outingId && g.user_id === userId,
    );
    const [guest] = this.guests.splice(idx, 1);
    return Promise.resolve(guest);
  }
  createVoteOption(data: {
    outing_id: string;
    label: string;
  }) {
    const option = {
      id: OPTION_ID,
      outing_id: data.outing_id,
      place_id: null,
      label: data.label,
      area: "",
      image_url: "",
      vibe: "food",
      latitude: null,
      longitude: null,
      sort_order: 0,
    } as OutingVoteOption;
    this.options.set(option.id, option);
    return Promise.resolve(option);
  }
  findVoteOptionById(id: string) {
    return Promise.resolve(this.options.get(id) ?? null);
  }
  deleteVoteOption(id: string) {
    const option = this.options.get(id)!;
    this.options.delete(id);
    return Promise.resolve(option);
  }
}

class FakeGroups implements IGroupRepository {
  group: Group | null = {
    id: GROUP_ID,
    name: "Friends",
    bio: "",
    image_url: "",
    created_by: OWNER,
    created_at: NOW,
    updated_at: NOW,
  } as Group;
  members: GroupMember[] = [
    {
      group_id: GROUP_ID,
      user_id: OWNER,
      role: "owner",
      joined_at: NOW,
    },
    {
      group_id: GROUP_ID,
      user_id: MEMBER,
      role: "member",
      joined_at: NOW,
    },
  ];

  findById(id: string) {
    return Promise.resolve(this.group?.id === id ? this.group : null);
  }
  findMany() {
    return Promise.resolve([]);
  }
  findByUserId() {
    return Promise.resolve([]);
  }
  create() {
    throw new Error("not used");
  }
  update(id: string, data: { name?: string }) {
    this.group = { ...this.group!, ...data, updated_at: NOW } as Group;
    return Promise.resolve(this.group);
  }
  delete(id: string) {
    const row = this.group!;
    assert.equal(id, GROUP_ID);
    this.group = null;
    return Promise.resolve(row);
  }
  addMember(data: {
    group_id: string;
    user_id: string;
    role?: "owner" | "member";
  }) {
    const member = {
      group_id: data.group_id,
      user_id: data.user_id,
      role: data.role ?? "member",
      joined_at: NOW,
    } as GroupMember;
    this.members.push(member);
    return Promise.resolve(member);
  }
  addInvitedMember() {
    throw new Error("not used");
  }
  findMember(groupId: string, userId: string) {
    return Promise.resolve(
      this.members.find(
        (m) => m.group_id === groupId && m.user_id === userId,
      ) ?? null,
    );
  }
  removeMember(groupId: string, userId: string) {
    const idx = this.members.findIndex(
      (m) => m.group_id === groupId && m.user_id === userId,
    );
    const [member] = this.members.splice(idx, 1);
    return Promise.resolve(member);
  }
  async listRoster(groupId: string) {
    return { members: await this.listMembers(groupId), pendingMembers: [] };
  }
  listMembers(groupId: string) {
    return Promise.resolve(
      this.members
        .filter((m) => m.group_id === groupId)
        .map((m) => ({
          ...m,
          name: m.user_id,
          phone: null,
          image_url: null,
        })),
    );
  }
}

class FakeUsers implements Partial<IUserRepository> {
  users = new Map<string, User>([
    [
      "phone-user",
      {
        id: "phone-user",
        name: "Phone",
        phone: "+201001234567",
        email: null,
        password_hash: null,
        password_updated_at: null,
        image_url: null,
        created_at: NOW,
        updated_at: NOW,
      } as User,
    ],
  ]);

  findByPhone(phone: string) {
    for (const user of this.users.values()) {
      if (user.phone === phone) return Promise.resolve(user);
    }
    return Promise.resolve(null);
  }
}

class FakeNotifications implements Partial<INotificationRepository> {
  rows = new Map<string, Notification>([
    [
      NOTIF_ID,
      {
        id: NOTIF_ID,
        user_id: CREATOR,
        body: "Hello",
        image_url: null,
        type: "system",
        outing_id: null,
        group_id: null,
        action_required: false,
        is_read: false,
        created_at: NOW,
      } as Notification,
    ],
    [
      "55555555-5555-4555-8555-555555555555",
      {
        id: "55555555-5555-4555-8555-555555555555",
        user_id: CREATOR,
        body: "Second",
        image_url: null,
        type: "system",
        outing_id: null,
        group_id: null,
        action_required: false,
        is_read: false,
        created_at: NOW,
      } as Notification,
    ],
    [
      "66666666-6666-4666-8666-666666666666",
      {
        id: "66666666-6666-4666-8666-666666666666",
        user_id: OTHER,
        body: "Other user",
        image_url: null,
        type: "system",
        outing_id: null,
        group_id: null,
        action_required: false,
        is_read: false,
        created_at: NOW,
      } as Notification,
    ],
  ]);

  findById(id: string) {
    return Promise.resolve(this.rows.get(id) ?? null);
  }
  update(id: string, data: { is_read?: boolean }) {
    const existing = this.rows.get(id)!;
    const next = { ...existing, ...data } as Notification;
    this.rows.set(id, next);
    return Promise.resolve(next);
  }
  markAllRead(userId: string) {
    let count = 0;
    for (const [id, row] of this.rows) {
      if (row.user_id !== userId || row.is_read) continue;
      this.rows.set(id, { ...row, is_read: true } as Notification);
      count += 1;
    }
    return Promise.resolve({ count });
  }
}

describe("Outing creator authorization", () => {
  it("allows the creator to update an outing", async () => {
    const repo = new FakeOutings();
    const useCase = new UpdateOutingUseCase(repo as unknown as IOutingRepository);
    const result = await useCase.execute(OUTING_ID, CREATOR, {
      title: "Updated",
    });
    assert.equal(result.title, "Updated");
  });

  it("forbids a non-creator from updating an outing", async () => {
    const repo = new FakeOutings();
    const useCase = new UpdateOutingUseCase(repo as unknown as IOutingRepository);
    await assert.rejects(
      () => useCase.execute(OUTING_ID, OTHER, { title: "Hacked" }),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("forbids a non-creator from deleting an outing", async () => {
    const repo = new FakeOutings();
    const useCase = new DeleteOutingUseCase(repo as unknown as IOutingRepository);
    await assert.rejects(
      () => useCase.execute(OUTING_ID, OTHER),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("allows the creator to delete an outing", async () => {
    const repo = new FakeOutings();
    const useCase = new DeleteOutingUseCase(repo as unknown as IOutingRepository);
    await useCase.execute(OUTING_ID, CREATOR);
    assert.equal(repo.deleted, true);
  });

  it("returns 404 when the outing is missing", async () => {
    const repo = new FakeOutings();
    repo.outing = null;
    const useCase = new DeleteOutingUseCase(repo as unknown as IOutingRepository);
    await assert.rejects(
      () => useCase.execute(OUTING_ID, CREATOR),
      (error: unknown) => error instanceof NotFoundError,
    );
  });

  it("forbids a non-creator from adding a guest", async () => {
    const repo = new FakeOutings();
    const useCase = new AddGuestUseCase(repo as unknown as IOutingRepository);
    await assert.rejects(
      () => useCase.execute(OUTING_ID, OTHER, "guest-1"),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("allows the creator to add and remove a guest", async () => {
    const repo = new FakeOutings();
    const add = new AddGuestUseCase(repo as unknown as IOutingRepository);
    const remove = new RemoveGuestUseCase(repo as unknown as IOutingRepository);
    await add.execute(OUTING_ID, CREATOR, "guest-1");
    await remove.execute(OUTING_ID, CREATOR, "guest-1");
    assert.equal(repo.guests.length, 0);
  });

  it("forbids a non-creator from creating a vote option", async () => {
    const repo = new FakeOutings();
    const useCase = new CreateVoteOptionUseCase(
      repo as unknown as IOutingRepository,
    );
    await assert.rejects(
      () =>
        useCase.execute(OTHER, {
          outing_id: OUTING_ID,
          label: "Cafe",
        }),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("allows the creator to create and delete a vote option", async () => {
    const repo = new FakeOutings();
    const create = new CreateVoteOptionUseCase(
      repo as unknown as IOutingRepository,
    );
    const remove = new DeleteVoteOptionUseCase(
      repo as unknown as IOutingRepository,
    );
    const option = await create.execute(CREATOR, {
      outing_id: OUTING_ID,
      label: "Cafe",
    });
    await remove.execute(option.id, CREATOR);
    assert.equal(repo.options.size, 0);
  });
});

describe("Notification ownership authorization", () => {
  it("allows the recipient to mark a notification as read", async () => {
    const repo = new FakeNotifications();
    const useCase = new MarkNotificationReadUseCase(
      repo as unknown as INotificationRepository,
    );
    const result = await useCase.execute(NOTIF_ID, CREATOR);
    assert.equal(result.is_read, true);
  });

  it("forbids another user from marking a notification as read", async () => {
    const repo = new FakeNotifications();
    const useCase = new MarkNotificationReadUseCase(
      repo as unknown as INotificationRepository,
    );
    await assert.rejects(
      () => useCase.execute(NOTIF_ID, OTHER),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("returns 404 for an unknown notification", async () => {
    const repo = new FakeNotifications();
    const useCase = new MarkNotificationReadUseCase(
      repo as unknown as INotificationRepository,
    );
    await assert.rejects(
      () => useCase.execute("missing", CREATOR),
      (error: unknown) => error instanceof NotFoundError,
    );
  });

  it("marks all of the caller's unread notifications in one update", async () => {
    const repo = new FakeNotifications();
    const useCase = new MarkAllNotificationsReadUseCase(
      repo as unknown as INotificationRepository,
    );
    const result = await useCase.execute(CREATOR);
    assert.equal(result.count, 2);
    assert.equal(repo.rows.get(NOTIF_ID)?.is_read, true);
    assert.equal(
      repo.rows.get("55555555-5555-4555-8555-555555555555")?.is_read,
      true,
    );
    assert.equal(
      repo.rows.get("66666666-6666-4666-8666-666666666666")?.is_read,
      false,
    );
  });
});

describe("Group owner authorization", () => {
  it("allows the owner to update the group", async () => {
    const groups = new FakeGroups();
    const useCase = new UpdateGroupUseCase(groups);
    const result = await useCase.execute(GROUP_ID, OWNER, { name: "Renamed" });
    assert.equal(result.name, "Renamed");
  });

  it("forbids a non-owner member from updating the group", async () => {
    const groups = new FakeGroups();
    const useCase = new UpdateGroupUseCase(groups);
    await assert.rejects(
      () => useCase.execute(GROUP_ID, MEMBER, { name: "Nope" }),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("forbids a non-owner from deleting the group", async () => {
    const groups = new FakeGroups();
    const useCase = new DeleteGroupUseCase(groups);
    await assert.rejects(
      () => useCase.execute(GROUP_ID, MEMBER),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("allows the owner to add a member by phone", async () => {
    const groups = new FakeGroups();
    const users = new FakeUsers();
    const useCase = new AddGroupMemberUseCase(
      groups,
      users as unknown as IUserRepository,
      { findUserIdByVerifiedPhone: async () => "phone-user" },
    );
    const member = await useCase.execute(OWNER, {
      group_id: GROUP_ID,
      phoneNumber: "01001234567",
    });
    assert.equal(member.user_id, "phone-user");
  });

  it("forbids a non-owner from adding a member by phone", async () => {
    const groups = new FakeGroups();
    const users = new FakeUsers();
    const useCase = new AddGroupMemberUseCase(
      groups,
      users as unknown as IUserRepository,
    );
    await assert.rejects(
      () =>
        useCase.execute(MEMBER, {
          group_id: GROUP_ID,
          phoneNumber: "+201001234567",
        }),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("forbids removing the last owner", async () => {
    const groups = new FakeGroups();
    const useCase = new RemoveGroupMemberUseCase(groups);
    await assert.rejects(
      () => useCase.execute(GROUP_ID, OWNER, OWNER),
      (error: unknown) => error instanceof ForbiddenError,
    );
  });

  it("allows the owner to remove a regular member", async () => {
    const groups = new FakeGroups();
    const useCase = new RemoveGroupMemberUseCase(groups);
    await useCase.execute(GROUP_ID, OWNER, MEMBER);
    assert.equal(
      groups.members.some((m) => m.user_id === MEMBER),
      false,
    );
  });
});
