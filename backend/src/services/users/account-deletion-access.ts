import { createHash } from "node:crypto";

const deletedAccounts = new Set<string>();
export const deletedAccountPlaceholder = "system:deleted-account";

export function accountDeletionKey(uid: string): string {
  return createHash("sha256").update(uid).digest("hex");
}

export function rememberDeletedAccounts(keys: Iterable<string>): void {
  for (const key of keys) deletedAccounts.add(key);
}

export function isDeletedAccount(uid: string): boolean {
  return uid === deletedAccountPlaceholder || deletedAccounts.has(accountDeletionKey(uid));
}
