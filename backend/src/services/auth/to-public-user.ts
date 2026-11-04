import type { PublicUser, User } from "../../types/users/user.types.js";

/** Strip credential fields before any API response. */
export function toPublicUser(user: User): PublicUser {
  const { password_hash: _hash, password_updated_at: _updated, ...publicUser } =
    user;
  return publicUser;
}

export function toPublicUsers(users: User[]): PublicUser[] {
  return users.map(toPublicUser);
}
