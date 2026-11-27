import { z } from "zod";
import type { place_review_visibility } from "@prisma/client";
import { PlaceReviewRepository } from "../../repositories/places/place-review.repository.js";
import { PlaceRatingStatisticsRepository } from "../../repositories/places/place-rating-statistics.repository.js";
import { placeCuratorUids } from "../../services/auth/place-curator.js";
import type { PlaceRatingInput, ReportReason, ReviewPageKey } from "../../types/places/place-review.types.js";
import { ForbiddenError, ValidationError } from "../../utils/errors.js";

const reviews = new PlaceReviewRepository();
const statistics = new PlaceRatingStatisticsRepository();
const cursorSchema = z.tuple([z.iso.datetime({ precision: 3 }), z.uuid()]);

function decodeCursor(raw?: string): ReviewPageKey | undefined {
  if (raw === undefined) return undefined;
  try {
    const [date, id] = cursorSchema.parse(JSON.parse(Buffer.from(raw, "base64url").toString("utf8")));
    return { createdAt: new Date(date), id };
  } catch {
    throw new ValidationError("Invalid review cursor");
  }
}

function page<T>({ items, next }: { items: T[]; next?: { id: string; created_at: Date } }) {
  return {
    items,
    nextCursor: next
      ? Buffer.from(JSON.stringify([next.created_at.toISOString(), next.id])).toString("base64url")
      : null,
  };
}

export class SubmitPlaceRatingUseCase {
  execute(placeId: string, uid: string, input: PlaceRatingInput) {
    return reviews.save(placeId, uid, input, "upsert");
  }
}
export class UpdatePlaceRatingUseCase {
  execute(placeId: string, uid: string, input: PlaceRatingInput) {
    return reviews.save(placeId, uid, input, "update");
  }
}
export class DeletePlaceRatingUseCase {
  execute(placeId: string, uid: string) { return reviews.remove(placeId, uid); }
}
export class GetPlaceReviewsUseCase {
  async execute(placeId: string, uid: string, limit: number, cursor?: string) {
    return page(await reviews.list(placeId, uid, limit, decodeCursor(cursor)));
  }
}
export class GetMyPlaceRatingUseCase {
  execute(placeId: string, uid: string) { return reviews.own(placeId, uid); }
}
export class GetPlaceRatingStatisticsUseCase {
  execute(placeId: string) { return statistics.get(placeId); }
}
export class ReportPlaceReviewUseCase {
  execute(placeId: string, reviewId: string, uid: string, reason: ReportReason) {
    return reviews.report(placeId, reviewId, uid, reason);
  }
}
export class BlockPlaceReviewAuthorUseCase {
  block(placeId: string, reviewId: string, uid: string) {
    return reviews.block(placeId, reviewId, uid);
  }
  async list(uid: string, limit: number, cursor?: string) {
    return page(await reviews.listBlocks(uid, limit, decodeCursor(cursor)));
  }
  unblock(uid: string, id: string) { return reviews.unblock(uid, id); }
}
export class ModeratePlaceReviewsUseCase {
  private authorize(uid: string) {
    const allowlist = placeCuratorUids(process.env.PLACE_REVIEW_MODERATOR_UIDS ?? "");
    if (!allowlist.includes(uid)) throw new ForbiddenError("Review moderation requires a moderator account");
  }

  async queue(uid: string, limit: number, cursor?: string) {
    this.authorize(uid);
    return page(await reviews.reportQueue(limit, decodeCursor(cursor)));
  }

  moderate(uid: string, placeId: string, reviewId: string, status: place_review_visibility) {
    this.authorize(uid);
    return reviews.moderate(placeId, reviewId, status);
  }

  dismiss(uid: string, id: string) {
    this.authorize(uid);
    return reviews.dismissReport(id);
  }
}
