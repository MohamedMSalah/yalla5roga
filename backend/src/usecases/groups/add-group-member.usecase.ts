import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { assertGroupOwner } from "../../services/groups/group-access.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import { FirebaseVerifiedPhoneLookup } from "../../services/phone/firebase-verified-phone.js";
import type {
  AddGroupMemberByPhoneInput,
  GroupMember,
} from "../../types/groups/group.types.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";

export class AddGroupMemberUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
    private readonly users: IUserRepository = new UserRepository(),
    private readonly phones = new FirebaseVerifiedPhoneLookup(),
  ) {}

  async execute(
    callerUid: string,
    input: AddGroupMemberByPhoneInput,
  ): Promise<GroupMember> {
    if (!input.group_id || !input.phoneNumber) {
      throw new ValidationError("group_id and phoneNumber are required");
    }

    await assertGroupOwner(this.groups, input.group_id, callerUid);

    const phone = normalizePhoneNumber(input.phoneNumber);
    const user = await this.users.findByPhone(phone);
    if (!user || await this.phones.findUserIdByVerifiedPhone(phone) !== user.id) {
      throw new NotFoundError("User with this phone number");
    }

    return this.groups.addMember({
      group_id: input.group_id,
      user_id: user.id,
      role: input.role ?? "member",
    });
  }
}
