import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { IGroupRepository } from "../src/repositories/groups/i-group.repository.js";
import type {
  Group,
  GroupMember,
  GroupMemberView,
} from "../src/types/groups/group.types.js";
import { CreateGroupUseCase } from "../src/usecases/groups/create-group.usecase.js";
import { ListGroupMembersUseCase } from "../src/usecases/groups/list-group-members.usecase.js";
import { ValidationError } from "../src/utils/errors.js";

const NOW = new Date("2026-11-08T00:00:00.000Z");
const OWNER_ID = "owner-1";

class FakeGroups implements IGroupRepository {
  group: Group | null = null;
  members: GroupMemberView[] = [];

  findById(id: string): Promise<Group | null> {
    if (!this.group || this.group.id !== id) return Promise.resolve(null);
    return Promise.resolve({
      ...this.group,
      member_count: this.members.filter((m) => m.group_id === id).length,
    });
  }
  findMany(): Promise<Group[]> {
    throw new Error("not used");
  }
  findByUserId(): Promise<Group[]> {
    throw new Error("not used");
  }
  create(data: {
    name: string;
    bio?: string;
    image_url?: string;
    created_by: string;
  }): Promise<Group> {
    this.group = {
      id: "group-1",
      name: data.name,
      bio: data.bio ?? "",
      image_url: data.image_url ?? "",
      created_by: data.created_by,
      created_at: NOW,
      updated_at: NOW,
      member_count: 0,
    };
    return Promise.resolve(this.group);
  }
  update(): Promise<Group> {
    throw new Error("not used");
  }
  delete(): Promise<Group> {
    throw new Error("not used");
  }
  addMember(data: {
    group_id: string;
    user_id: string;
    role?: "owner" | "member";
  }): Promise<GroupMember> {
    const member: GroupMemberView = {
      group_id: data.group_id,
      user_id: data.user_id,
      role: data.role ?? "member",
      joined_at: NOW,
      name: "Owner Name",
      phone: "+201001234567",
      image_url: null,
    };
    this.members.push(member);
    return Promise.resolve(member);
  }
  addInvitedMember() {
    throw new Error("not used");
  }
  findMember(): Promise<GroupMember | null> {
    throw new Error("not used");
  }
  removeMember(): Promise<GroupMember> {
    throw new Error("not used");
  }
  listMembers(groupId: string): Promise<GroupMemberView[]> {
    return Promise.resolve(
      this.members.filter((member) => member.group_id === groupId),
    );
  }
}

describe("CreateGroupUseCase", () => {
  it("adds the creator as owner and returns member_count 1", async () => {
    const groups = new FakeGroups();
    const created = await new CreateGroupUseCase(groups).execute({
      name: "Friday Squad",
      created_by: OWNER_ID,
    });

    assert.equal(created.member_count, 1);
    assert.equal(created.my_role, "owner");
    assert.equal(groups.members.length, 1);
    assert.equal(groups.members[0]?.user_id, OWNER_ID);
    assert.equal(groups.members[0]?.role, "owner");
  });

  it("requires name and created_by", async () => {
    const groups = new FakeGroups();
    await assert.rejects(
      () =>
        new CreateGroupUseCase(groups).execute({
          name: "",
          created_by: OWNER_ID,
        }),
      (error: unknown) => error instanceof ValidationError,
    );
  });
});

describe("ListGroupMembersUseCase", () => {
  it("returns the creator profile card after create", async () => {
    const groups = new FakeGroups();
    await new CreateGroupUseCase(groups).execute({
      name: "Friday Squad",
      created_by: OWNER_ID,
    });

    const members = await new ListGroupMembersUseCase(groups).execute(
      "group-1",
    );
    assert.equal(members.length, 1);
    assert.equal(members[0]?.user_id, OWNER_ID);
    assert.equal(members[0]?.role, "owner");
    assert.equal(members[0]?.name, "Owner Name");
  });
});
