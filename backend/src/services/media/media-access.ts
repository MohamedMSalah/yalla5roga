import { prisma } from "../../config/database.js";
import type { MediaAsset, MediaPurpose } from "../../types/media/media.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";
import { isPlaceCurator } from "../auth/place-curator.js";
import { assertEligibleVoter } from "../outings/outing-participants.js";

/**
 * Media access policy.
 *
 * Upload authorization (who may create an asset for a purpose):
 * - profile → the authenticated user (self avatar)
 * - group   → the group owner
 * - outing  → the outing creator
 * - place   → a place curator (`PLACES_CURATOR_UIDS`, fail-closed)
 * - chat    → any outing participant (attachment inside their outing)
 *
 * View authorization (who may receive a URL):
 * - public assets → any authenticated caller (public ones also live on the CDN)
 * - profile       → any authenticated caller (avatars render for other users)
 * - group/outing/chat → participants of the linked entity
 * - otherwise → the owner only
 */
export async function assertCanUploadPurpose(input: {
  purpose: MediaPurpose;
  entityId: string | null;
  uid: string;
}): Promise<void> {
  const { purpose, entityId, uid } = input;

  switch (purpose) {
    case "profile":
      return;
    case "group": {
      // Without an entity the asset is an unattached private upload: attach
      // permission is enforced when a group create/update persists the ref.
      if (!entityId) return;
      const membership = await prisma.group_members.findUnique({
        where: { group_id_user_id: { group_id: entityId, user_id: uid } },
        select: { role: true },
      });
      if (!membership) {
        if (!(await prisma.groups.findUnique({ where: { id: entityId }, select: { id: true } }))) {
          throw new NotFoundError("Group");
        }
        throw new ForbiddenError("Only the group owner can upload group media");
      }
      if (membership.role !== "owner") {
        throw new ForbiddenError("Only the group owner can upload group media");
      }
      return;
    }
    case "outing": {
      if (!entityId) return;
      const outing = await prisma.outings.findUnique({ where: { id: entityId } });
      if (!outing) throw new NotFoundError("Outing");
      if (outing.created_by !== uid) {
        throw new ForbiddenError("Only the outing creator can upload outing media");
      }
      return;
    }
    case "chat": {
      if (!entityId) throw new ForbiddenError("outingId is required for chat media");
      const outing = await prisma.outings.findUnique({ where: { id: entityId } });
      if (!outing) throw new NotFoundError("Outing");
      await assertEligibleVoter(outing, uid);
      return;
    }
    case "place":
      // Catalog media follows the same curator allowlist as the place catalog
      // APIs. Without this, any authenticated user could mint public objects
      // under the `places/` prefix and attach them through a later catalog write.
      if (!isPlaceCurator(uid)) {
        throw new ForbiddenError("Place media requires a curator account");
      }
      return;
    default: {
      const exhaustive: never = purpose;
      throw new ForbiddenError(`Unsupported media purpose ${String(exhaustive)}`);
    }
  }
}

export async function canViewMedia(
  asset: MediaAsset,
  uid: string | null,
): Promise<boolean> {
  if (asset.owner_id === uid) return true;
  if (asset.visibility === "public") return uid !== null;
  if (!uid) return false;

  if (asset.purpose === "profile") return true;
  if (asset.purpose === "place") return true;

  if (asset.group_id) {
    const membership = await prisma.group_members.findUnique({
      where: { group_id_user_id: { group_id: asset.group_id, user_id: uid } },
      select: { group_id: true },
    });
    if (membership) return true;
  }

  if (asset.outing_id) {
    const outing = await prisma.outings.findUnique({ where: { id: asset.outing_id } });
    if (outing) {
      try {
        await assertEligibleVoter(outing, uid);
        return true;
      } catch {
        return false;
      }
    }
  }

  return false;
}

export async function assertCanViewMedia(
  asset: MediaAsset,
  uid: string | null,
): Promise<void> {
  if (!(await canViewMedia(asset, uid))) {
    throw new ForbiddenError("You do not have access to this media");
  }
}
