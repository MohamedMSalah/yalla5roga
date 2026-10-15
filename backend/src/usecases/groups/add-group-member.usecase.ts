import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import type {
  AddGroupMemberByPhoneInput,
  GroupMember,
} from "../../types/groups/group.types.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";

export class AddGroupMemberUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
    private readonly users: IUserRepository = new UserRepository(),
  ) {}

  async execute(input: AddGroupMemberByPhoneInput): Promise<GroupMember> {
    if (!input.group_id || !input.phoneNumber) {
      throw new ValidationError("group_id and phoneNumber are required");
    }

    const group = await this.groups.findById(input.group_id);
    if (!group) throw new NotFoundError("Group");

    const user = await this.users.findByPhone(input.phoneNumber);
    if (!user) {
      throw new NotFoundError("User with this phone number");
    }

    return this.groups.addMember({
      group_id: input.group_id,
      user_id: user.id,
      role: input.role ?? "member",
    });
  }
}
