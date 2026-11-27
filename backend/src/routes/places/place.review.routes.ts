import { Router } from "express";
import { PlaceReviewController } from "../../controllers/places/place-review.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { limitPlaceReviewActions } from "../../middleware/place-review-rate-limit.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  placeRatingBody, reviewEntityParams, reviewModerationBody, reviewPageQuery,
  reviewPlaceParams, reviewReportBody, reviewTargetParams,
} from "../../validators/places/place-review.validator.js";

export function createPlaceReviewRoutes(auth = authMiddleware) {
  const router = Router();
  const controller = new PlaceReviewController();
  const writeLimit = limitPlaceReviewActions(30);
  const safetyLimit = limitPlaceReviewActions(20);
  const place = validate({ params: reviewPlaceParams });
  const review = validate({ params: reviewTargetParams });
  const entity = validate({ params: reviewEntityParams });
  const page = validate({ query: reviewPageQuery });
  const rating = validate({ params: reviewPlaceParams, body: placeRatingBody });

  router.get("/review-blocks", auth, page, controller.listBlocks);
  router.delete("/review-blocks/:id", auth, safetyLimit, entity, controller.unblock);
  router.get("/review-reports", auth, page, controller.queue);
  router.patch("/review-reports/:id/dismiss", auth, entity, controller.dismiss);
  router.get("/:placeId/ratings", place, controller.statistics);
  router.get("/:placeId/reviews", auth, place, page, controller.list);
  router.get("/:placeId/my-rating", auth, place, controller.own);
  router.put("/:placeId/my-rating", auth, writeLimit, rating, controller.submit);
  router.patch("/:placeId/my-rating", auth, writeLimit, rating, controller.update);
  router.delete("/:placeId/my-rating", auth, writeLimit, place, controller.remove);
  router.post("/:placeId/reviews/:reviewId/report", auth, safetyLimit,
    validate({ params: reviewTargetParams, body: reviewReportBody }), controller.report);
  router.put("/:placeId/reviews/:reviewId/block", auth, safetyLimit, review, controller.block);
  router.patch("/:placeId/reviews/:reviewId/moderation", auth,
    validate({ params: reviewTargetParams, body: reviewModerationBody }), controller.moderate);
  return router;
}

export default createPlaceReviewRoutes();
