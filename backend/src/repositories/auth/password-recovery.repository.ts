import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { AppError, UnauthorizedError } from "../../utils/errors.js";

export type Recovery = {
  request_hash: string; user_id: string; phone: string; password_version: string;
  created_at: Date; expires_at: Date; proof_hash: string | null;
  reset_hash: string | null; consumed_at: Date | null;
};

export class PasswordRecoveryRepository {
  async limit(key: string, maximum: number, seconds: number, now: Date): Promise<void> {
    // One atomic database upsert; limits apply across processes and restarts.
    const schema = process.env.DATABASE_URL
      ? new URL(process.env.DATABASE_URL).searchParams.get("schema") ?? "public" : "public";
    const table = Prisma.raw(`"${schema.replaceAll('"', '""')}"."password_recovery_limits"`);
    const rows = await prisma.$queryRaw<Array<{ attempts: number }>>`
      INSERT INTO ${table} AS limits (key, attempts, expires_at)
      VALUES (${key}, 1, ${new Date(now.getTime() + seconds * 1000)})
      ON CONFLICT (key) DO UPDATE SET
        attempts = CASE WHEN limits.expires_at <= ${now}
          THEN 1 ELSE limits.attempts + 1 END,
        expires_at = CASE WHEN limits.expires_at <= ${now}
          THEN EXCLUDED.expires_at ELSE limits.expires_at END
      RETURNING attempts`;
    if (rows[0].attempts > maximum) throw new AppError(429, "Too many recovery attempts. Try again later");
  }

  async create(row: Recovery): Promise<void> {
    await prisma.password_recoveries.create({ data: row });
  }
  find(request_hash: string): Promise<Recovery | null> {
    return prisma.password_recoveries.findUnique({ where: { request_hash } });
  }
  findReset(reset_hash: string): Promise<Recovery | null> {
    return prisma.password_recoveries.findUnique({ where: { reset_hash } });
  }
  async authorize(request_hash: string, proof_hash: string, reset_hash: string, now: Date): Promise<void> {
    try {
      const result = await prisma.password_recoveries.updateMany({
        where: { request_hash, proof_hash: null, consumed_at: null, expires_at: { gt: now } },
        data: { proof_hash, reset_hash, expires_at: new Date(now.getTime() + 300_000) },
      });
      if (result.count !== 1) throw new UnauthorizedError("Recovery expired. Start again");
    } catch (error) {
      if ((error as { code?: string }).code === "P2002") {
        throw new UnauthorizedError("Phone proof already used. Request a new code");
      }
      throw error;
    }
  }
  async consume(row: Recovery, passwordHash: string, currentHash: string, now: Date): Promise<void> {
    await prisma.$transaction(async tx => {
      const consumed = await tx.password_recoveries.updateMany({
        where: { request_hash: row.request_hash, reset_hash: row.reset_hash,
          consumed_at: null, expires_at: { gt: now } },
        data: { consumed_at: now },
      });
      if (consumed.count !== 1) throw new UnauthorizedError("Recovery expired. Start again");
      const updated = await tx.users.updateMany({
        where: { id: row.user_id, phone: row.phone, password_hash: currentHash },
        data: { password_hash: passwordHash },
      });
      if (updated.count !== 1) throw new UnauthorizedError("Account changed. Start recovery again");
      // All other grants for the previous password become unusable too.
      await tx.password_recoveries.updateMany({
        where: { user_id: row.user_id, consumed_at: null }, data: { consumed_at: now },
      });
    });
  }
  async cleanup(now: Date): Promise<void> {
    // Retain proof replay markers beyond the maximum acceptable proof age.
    await prisma.password_recoveries.deleteMany({ where: { expires_at: { lt: new Date(now.getTime() - 86_400_000) } } });
    await prisma.password_recovery_limits.deleteMany({ where: { expires_at: { lt: now } } });
  }
}
