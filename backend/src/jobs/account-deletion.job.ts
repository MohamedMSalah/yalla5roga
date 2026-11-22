import { prisma } from "../config/database.js";
import { getFirebaseAuth } from "../config/firebase.js";
import { scheduleJob } from "../monitoring/jobs.js";
import { errorCode, logger } from "../monitoring/logger.js";
import { MediaService } from "../services/media/media.service.js";
import { rememberDeletedAccounts } from "../services/users/account-deletion-access.js";

// Firebase custom tokens can be exchanged for up to one hour. Keep the UID
// disabled until outstanding custom tokens have expired, with clock skew room.
const customTokenLifetimeMs = 65 * 60_000;
const firebaseIdentity = {
  disable: (uid: string) => getFirebaseAuth().updateUser(uid, { disabled: true }),
  delete: (uid: string) => getFirebaseAuth().deleteUser(uid),
};

export async function loadDeletedAccounts(): Promise<void> {
  const rows = await prisma.account_deletions.findMany({ select: { account_key: true } });
  rememberDeletedAccounts(rows.map(({ account_key }) => account_key));
}

export async function processAccountDeletions(
  identity: { disable(uid: string): Promise<unknown>; delete(uid: string): Promise<void> } = firebaseIdentity,
  media = new MediaService(),
): Promise<void> {
  const now = new Date();
  const canDeleteIdentitiesRequestedBy = new Date(now.getTime() - customTokenLifetimeMs);
  const jobs = await prisma.account_deletions.findMany({
    where: {
      completed_at: null,
      retry_after: { lte: now },
      OR: [
        { firebase_uid: { not: null }, OR: [
          { firebase_disabled_at: null },
          { requested_at: { lte: canDeleteIdentitiesRequestedBy } },
        ] },
        { media: { some: { purge_after: { lte: now } } } },
        { firebase_uid: null, media: { none: {} } },
      ],
    },
    orderBy: { requested_at: "asc" },
    include: {
      media: { where: { purge_after: { lte: now } }, take: 50, orderBy: { purge_after: "asc" } },
    },
    take: 20,
  });
  let failed = false;
  for (const job of jobs) {
    let jobFailed = false;
    try {
      if (job.firebase_uid) {
        if (!job.firebase_disabled_at) {
          try {
            await identity.disable(job.firebase_uid);
          } catch (error) {
            if (errorCode(error) !== "auth/user-not-found") throw error;
          }
          await prisma.account_deletions.update({
            where: { account_key: job.account_key }, data: { firebase_disabled_at: now },
          });
        }
        if (job.requested_at <= canDeleteIdentitiesRequestedBy) {
          try {
            await identity.delete(job.firebase_uid);
          } catch (error) {
            if (errorCode(error) !== "auth/user-not-found") throw error;
          }
          await prisma.account_deletions.update({
            where: { account_key: job.account_key }, data: { firebase_uid: null },
          });
        }
      }
    } catch (error) {
      jobFailed = true;
      logger.warn({ errorCode: errorCode(error) }, "Account deletion identity cleanup failed");
    }
    for (const object of job.media) {
      try {
        await media.purgeObject(object);
        await prisma.account_deletion_media.deleteMany({
          where: { account_key: job.account_key, object_key: object.object_key },
        });
      } catch (error) {
        jobFailed = true;
        logger.warn({ errorCode: errorCode(error) }, "Account deletion media cleanup failed");
      }
    }
    if (jobFailed) {
      failed = true;
      await prisma.account_deletions.update({
        where: { account_key: job.account_key },
        data: { retry_after: new Date(Date.now() + 5 * 60_000) },
      });
      continue;
    }
    await prisma.account_deletions.updateMany({
      where: { account_key: job.account_key, firebase_uid: null, media: { none: {} } },
      data: { completed_at: now },
    });
  }
  if (failed) throw new Error("Account deletion cleanup will be retried");
}

export function startAccountDeletionJob() {
  const media = new MediaService();
  return scheduleJob("account_deletion", 60_000, () => processAccountDeletions(undefined, media));
}
