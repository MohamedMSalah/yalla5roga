import type { PublicUser, PublicUserSummary, User } from "../../types/users/user.types.js";

/** Allowlist protects responses even while legacy columns await migration. */
export function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
    image_url: user.image_url,
    created_at: user.created_at,
    updated_at: user.updated_at,
    has_password: Boolean(user.password_hash),
  };
}

export function toPublicUsers(users: User[]): PublicUser[] {
  return users.map(toPublicUser);
}

/**
 * Directory-safe projection. Used by `GET /api/users`, which must never
 * expose phone numbers or credential state to other authenticated users.
 */
export function toUserSummary(user: User): PublicUserSummary {
  return {
    id: user.id,
    name: user.name,
    image_url: user.image_url,
    created_at: user.created_at,
    updated_at: user.updated_at,
  };
}

export function toUserSummaries(users: User[]): PublicUserSummary[] {
  return users.map(toUserSummary);
}
