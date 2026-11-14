import { Prisma } from "@prisma/client";
import { ValidationError } from "../../utils/errors.js";
/** Invoked in the outing mutation transaction; historical reads are unaffected. */
export async function assertSelectablePlaces(
  tx: Prisma.TransactionClient,
  ids: (string | null | undefined)[],
) {
  const selected = [...new Set(ids.filter((id): id is string => !!id))];
  if (!selected.length) return;
  const rows = await tx.$queryRaw<
    { id: string; status: string; is_active: boolean }[]
  >`
    SELECT id,status,is_active FROM places WHERE id IN (${Prisma.join(selected.map((id) => Prisma.sql`${id}::uuid`))}) FOR SHARE`;
  if (
    rows.length !== selected.length ||
    rows.some((p) => p.status === "permanently_closed" || !p.is_active)
  )
    throw new ValidationError("A selected place is unavailable");
}
