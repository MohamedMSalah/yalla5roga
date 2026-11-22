import { prisma } from "../../config/database.js";
import { Prisma } from "@prisma/client";
import { accountDeletionKey, deletedAccountPlaceholder } from "../../services/users/account-deletion-access.js";
import { NotFoundError } from "../../utils/errors.js";

export async function recordAccountDeletion(uid: string) {
  for (let attempt = 0; ; attempt++) {
    try {
      return await recordDeletionTransaction(uid);
    } catch (error) {
      if (attempt >= 2 || !(error instanceof Prisma.PrismaClientKnownRequestError) ||
        !(error.code === "P2034" || error.code === "P2010" && error.meta?.code === "40P01")) throw error;
    }
  }
}

async function recordDeletionTransaction(uid: string) {
  const accountKey = accountDeletionKey(uid);
  return prisma.$transaction(async tx => {
    const [user] = await tx.$queryRaw<Array<{ phone: string }>>`
      SELECT phone FROM users WHERE id = ${uid} FOR UPDATE
    `;
    if (!user) {
      if (await tx.account_deletions.findUnique({ where: { account_key: accountKey } })) {
        return { accountKey, groups: [], outings: [] };
      }
      throw new NotFoundError("User");
    }
    const now = new Date();
    const memberships = await tx.group_members.findMany({
      where: { user_id: uid }, select: { group_id: true },
    });
    const groups = await tx.$queryRaw<Array<{ id: string }>>`
      SELECT id FROM groups WHERE created_by = ${uid} ORDER BY id FOR UPDATE
    `;
    const outings = await tx.$queryRaw<Array<{ id: string }>>`
      SELECT id FROM outings WHERE created_by = ${uid} ORDER BY id FOR UPDATE
    `;
    // This identity has no Firebase user, credentials, or personal metadata.
    await tx.users.upsert({
      where: { id: deletedAccountPlaceholder },
      create: { id: deletedAccountPlaceholder, name: "Deleted account", phone: "+0" },
      update: {},
    });
    await tx.account_deletions.create({ data: { account_key: accountKey, firebase_uid: uid } });

    for (const { id } of groups) {
      const successor = await tx.group_members.findFirst({
        where: { group_id: id, user_id: { not: uid } },
        orderBy: [{ joined_at: "asc" }, { user_id: "asc" }],
      });
      if (successor) {
        await tx.group_members.update({
          where: { group_id_user_id: { group_id: id, user_id: successor.user_id } },
          data: { role: "owner" },
        });
      } else if (!await tx.outings.count({ where: { group_id: id } })) {
        await tx.notification_events.deleteMany({ where: { group_id: id } });
        await tx.groups.delete({ where: { id } });
        continue;
      } else {
        await tx.group_members.upsert({
          where: { group_id_user_id: { group_id: id, user_id: deletedAccountPlaceholder } },
          create: { group_id: id, user_id: deletedAccountPlaceholder, role: "owner" },
          update: {},
        });
      }
      await tx.groups.update({
        where: { id }, data: { created_by: successor?.user_id ?? deletedAccountPlaceholder },
      });
    }

    const ownedOutings = outings.map(({ id }) => id);
    await tx.outings.updateMany({
      where: { id: { in: ownedOutings }, status: { in: ["draft", "voting", "confirmed"] } },
      data: { status: "cancelled" },
    });
    await tx.outings.updateMany({
      where: { id: { in: ownedOutings } },
      data: { created_by: deletedAccountPlaceholder, create_request_key: null },
    });
    // Preserve recipients' inbox history, with no copy of the removed text or sender.
    await tx.$executeRaw`
      UPDATE notifications
      SET body = 'Message removed',
          data = (data - ARRAY['senderId', 'senderName', 'senderAvatar']) ||
            jsonb_build_object('title', 'Message removed', 'body', 'Message removed')
      WHERE data->>'messageId' IN (SELECT id::text FROM chat_messages WHERE sender_id = ${uid})
    `;
    await tx.$executeRaw`
      DELETE FROM notification_events
      WHERE payload->>'messageId' IN (SELECT id::text FROM chat_messages WHERE sender_id = ${uid})
    `;
    const messages = await tx.chat_messages.updateManyAndReturn({
      where: { sender_id: uid }, select: { outing_id: true },
      data: { sender_id: deletedAccountPlaceholder, text: "", client_message_id: null },
    });

    const removedInvitations = await tx.group_invitations.findMany({
      where: {
        OR: [{ user_id: uid }, { invited_phone: user.phone },
          { invited_by_user_id: uid, status: "pending" }],
      },
      select: { id: true },
    });
    await tx.group_invitations.deleteMany({
      where: { id: { in: removedInvitations.map(({ id }) => id) } },
    });
    if (removedInvitations.length) {
      await tx.$executeRaw`
        UPDATE notifications SET action_required = false
        WHERE data->>'invitationId' = ANY(${removedInvitations.map(({ id }) => id)}::text[])
      `;
    }
    await tx.group_invitations.updateMany({
      where: { invited_by_user_id: uid }, data: { invited_by_user_id: deletedAccountPlaceholder },
    });
    await tx.notification_events.deleteMany({
      where: { OR: [
        { recipient_user_id: uid },
        { recipient_phone: user.phone },
        { invitation_id: { in: removedInvitations.map(({ id }) => id) } },
      ] },
    });
    // Old outbox jobs must not send obsolete reminders for canceled outings.
    await tx.notification_events.updateMany({
      where: { outing_id: { in: ownedOutings }, status: { in: ["pending", "processing", "failed"] } },
      data: { status: "dead" },
    });

    const assets = await tx.$queryRaw<Array<{
      id: string; bucket: string; object_key: string; upload_expires_at: Date | null;
      purpose: "profile" | "group" | "outing" | "chat" | "place";
      visibility: "public" | "private"; status: "pending" | "ready" | "failed";
      place_id: string | null;
    }>>`
      SELECT id, bucket, object_key, upload_expires_at, purpose, visibility, status, place_id
      FROM media_assets WHERE owner_id = ${uid} ORDER BY id FOR UPDATE
    `;
    const purge = [];
    for (const asset of assets) {
      if (asset.purpose === "place" && asset.visibility === "public" && asset.status === "ready" && asset.place_id) {
        await tx.media_assets.update({ where: { id: asset.id }, data: { owner_id: deletedAccountPlaceholder } });
      } else {
        purge.push(asset);
      }
    }
    if (purge.length) {
      await tx.account_deletion_media.createMany({ data: purge.map(asset => ({
        account_key: accountKey,
        object_key: asset.object_key,
        bucket: asset.bucket,
        purpose: asset.purpose,
        visibility: asset.visibility,
        // Allow any previously issued direct upload capability to expire.
        purge_after: new Date(Math.max(asset.upload_expires_at?.getTime() ?? 0, now.getTime() + 900_000)),
      })) });
      const references = purge.map(asset => `media://${asset.id}`);
      await tx.groups.updateMany({ where: { image_url: { in: references } }, data: { image_url: "" } });
      await tx.outings.updateMany({ where: { image_url: { in: references } }, data: { image_url: "" } });
      await tx.users.updateMany({ where: { image_url: { in: references } }, data: { image_url: null } });
    }

    // Deletes account-only relations via their existing cascades, including
    // memberships, RSVPs, votes, arrivals, drafts, saves and push registrations.
    await tx.users.delete({ where: { id: uid } });
    return {
      accountKey,
      groups: [...new Set([...groups.map(({ id }) => id), ...memberships.map(({ group_id }) => group_id)])],
      outings: [...new Set([...ownedOutings, ...messages.map(({ outing_id }) => outing_id)])],
    };
  });
}
