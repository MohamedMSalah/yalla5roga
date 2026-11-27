import { Prisma, type place_review_visibility } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type {
  PlaceRatingInput, PlaceReview, ReportReason, ReviewPageKey,
} from "../../types/places/place-review.types.js";
import { ConflictError, ForbiddenError, NotFoundError } from "../../utils/errors.js";
import { PlaceRatingStatisticsRepository } from "./place-rating-statistics.repository.js";

const reviewProfile = { user: { select: { name: true } } } as const;
type ReviewRow = Prisma.place_reviewsGetPayload<{ include: typeof reviewProfile }>;

function serialize(row: ReviewRow, viewerId?: string, moderation = false): PlaceReview {
  const isMine = row.user_id === viewerId;
  return {
    id: row.id, placeId: row.place_id, rating: row.rating, reviewText: row.review_text,
    createdAt: row.created_at, updatedAt: row.updated_at, isMine,
    reviewer: { name: row.user.name },
    ...((moderation || isMine) && { moderationStatus: row.moderation_status }),
  };
}

function earlierThan(cursor?: ReviewPageKey) {
  return cursor && {
    OR: [
      { created_at: { lt: cursor.createdAt } },
      { created_at: cursor.createdAt, id: { lt: cursor.id } },
    ],
  };
}

const newestFirst = [{ created_at: "desc" }, { id: "desc" }] as const;
const stats = new PlaceRatingStatisticsRepository();

async function targetReview(tx: Prisma.TransactionClient, placeId: string, reviewId: string,
  forUpdate = false) {
  const [review] = await tx.$queryRaw<{
    id: string; user_id: string; review_text: string | null; moderation_status: place_review_visibility;
  }[]>`
    SELECT id, user_id, review_text, moderation_status FROM place_reviews
    WHERE place_id = ${placeId}::uuid AND id = ${reviewId}::uuid
    ${forUpdate ? Prisma.sql`FOR UPDATE` : Prisma.sql`FOR SHARE`}
  `;
  if (!review) throw new NotFoundError("Review");
  return review;
}

export class PlaceReviewRepository {
  async own(placeId: string, userId: string) {
    const row = await prisma.places.findUnique({
      where: { id: placeId },
      select: {
        place_reviews: { where: { user_id: userId }, take: 1, include: reviewProfile },
      },
    });
    if (!row) throw new NotFoundError("Place");
    return row.place_reviews[0] ? serialize(row.place_reviews[0], userId) : null;
  }

  async list(placeId: string, viewerId: string, limit: number, cursor?: ReviewPageKey) {
    const place = await prisma.places.findUnique({
      where: { id: placeId },
      select: { place_reviews: {
        where: {
          moderation_status: "visible", review_text: { not: null },
          user: { place_review_blocks_received: { none: { viewer_id: viewerId } } },
          ...earlierThan(cursor),
        },
        include: reviewProfile,
        orderBy: [...newestFirst],
        take: limit + 1,
      } },
    });
    if (!place) throw new NotFoundError("Place");
    return {
      items: place.place_reviews.slice(0, limit).map((row) => serialize(row, viewerId)),
      next: place.place_reviews.length > limit ? place.place_reviews[limit - 1] : undefined,
    };
  }

  save(placeId: string, userId: string, input: PlaceRatingInput, operation: "upsert" | "update") {
    return prisma.$transaction(async (tx) => {
      const [place] = await tx.$queryRaw<{ is_active: boolean; status: string }[]>`
        SELECT is_active, status FROM places WHERE id = ${placeId}::uuid FOR SHARE
      `;
      if (!place) throw new NotFoundError("Place");
      if (!place.is_active || place.status !== "active")
        throw new ConflictError("This place is no longer accepting reviews");

      // Native upsert serializes concurrent submissions on the unique owner/branch key.
      const rows = operation === "update"
        ? await tx.$queryRaw<{ id: string }[]>`
            UPDATE place_reviews SET rating = ${input.rating}::integer,
              review_text = ${input.reviewText}, updated_at = clock_timestamp()
            WHERE place_id = ${placeId}::uuid AND user_id = ${userId} RETURNING id
          `
        : await tx.$queryRaw<{ id: string }[]>`
            INSERT INTO place_reviews(place_id, user_id, rating, review_text)
            VALUES (${placeId}::uuid, ${userId}, ${input.rating}::integer, ${input.reviewText})
            ON CONFLICT (place_id, user_id) DO UPDATE
              SET rating = excluded.rating, review_text = excluded.review_text, updated_at = clock_timestamp()
            RETURNING id
          `;
      if (!rows[0]) throw new NotFoundError("Rating");
      const row = await tx.place_reviews.findUniqueOrThrow({ where: { id: rows[0].id }, include: reviewProfile });
      return { review: serialize(row, userId), statistics: await stats.get(placeId, tx) };
    });
  }

  async remove(placeId: string, userId: string) {
    return prisma.$transaction(async (tx) => {
      await tx.place_reviews.deleteMany({ where: { place_id: placeId, user_id: userId } });
      return { review: null, statistics: await stats.get(placeId, tx) };
    });
  }

  report(placeId: string, reviewId: string, reporterId: string, reason: ReportReason) {
    return prisma.$transaction(async (tx) => {
      const review = await targetReview(tx, placeId, reviewId);
      if (review.user_id === reporterId) throw new ForbiddenError("You cannot report your own review");

      const where = { review_id_reporter_id: { review_id: review.id, reporter_id: reporterId } };
      const existing = await tx.place_review_reports.findUnique({ where, select: { id: true, status: true } });
      if (existing) return existing;
      if (review.moderation_status !== "visible" || !review.review_text) throw new NotFoundError("Review");
      await tx.place_review_reports.createMany({
        data: [{ review_id: review.id, reporter_id: reporterId, reason }], skipDuplicates: true,
      });
      return tx.place_review_reports.findUniqueOrThrow({ where, select: { id: true, status: true } });
    });
  }

  block(placeId: string, reviewId: string, viewerId: string) {
    return prisma.$transaction(async (tx) => {
      const review = await targetReview(tx, placeId, reviewId);
      if (review.user_id === viewerId) throw new ForbiddenError("You cannot block yourself");
      if (review.moderation_status !== "visible" || !review.review_text) throw new NotFoundError("Review");
      await tx.place_review_blocks.createMany({
        data: [{ viewer_id: viewerId, author_id: review.user_id }], skipDuplicates: true,
      });
      return tx.place_review_blocks.findUniqueOrThrow({
        where: { viewer_id_author_id: { viewer_id: viewerId, author_id: review.user_id } },
        select: { id: true },
      });
    });
  }

  async listBlocks(viewerId: string, limit: number, cursor?: ReviewPageKey) {
    const rows = await prisma.place_review_blocks.findMany({
      where: { viewer_id: viewerId, ...earlierThan(cursor) },
      orderBy: [...newestFirst], take: limit + 1,
      select: { id: true, created_at: true, author: { select: { name: true } } },
    });
    return {
      items: rows.slice(0, limit).map(({ id, author }) => ({ id, name: author.name })),
      next: rows.length > limit ? rows[limit - 1] : undefined,
    };
  }

  async unblock(viewerId: string, id: string) {
    await prisma.place_review_blocks.deleteMany({ where: { id, viewer_id: viewerId } });
    return { removed: true };
  }

  async reportQueue(limit: number, cursor?: ReviewPageKey) {
    const rows = await prisma.place_review_reports.findMany({
      where: { status: "open", ...earlierThan(cursor) },
      orderBy: [...newestFirst], take: limit + 1,
      select: { id: true, reason: true, status: true, created_at: true,
        review: { include: reviewProfile } },
    });
    return {
      items: rows.slice(0, limit).map((row) => ({
        id: row.id, reason: row.reason, status: row.status, createdAt: row.created_at,
        review: serialize(row.review, undefined, true),
      })),
      next: rows.length > limit ? rows[limit - 1] : undefined,
    };
  }

  moderate(placeId: string, reviewId: string, status: place_review_visibility) {
    return prisma.$transaction(async (tx) => {
      await targetReview(tx, placeId, reviewId, true);
      const review = await tx.place_reviews.update({
        where: { id: reviewId },
        data: { moderation_status: status },
        include: reviewProfile,
      });
      if (status === "hidden") {
        await tx.place_review_reports.updateMany({
          where: { review_id: reviewId, status: "open" }, data: { status: "actioned" },
        });
      }
      return { review: serialize(review, undefined, true), statistics: await stats.get(placeId, tx) };
    });
  }

  async dismissReport(id: string) {
    const { count } = await prisma.place_review_reports.updateMany({
      where: { id, status: "open" }, data: { status: "dismissed" },
    });
    if (!count) {
      const existing = await prisma.place_review_reports.findUnique({ where: { id } });
      if (!existing) throw new NotFoundError("Report");
      if (existing.status !== "dismissed") throw new ConflictError("Report has already been actioned");
    }
    return { id, status: "dismissed" };
  }
}
