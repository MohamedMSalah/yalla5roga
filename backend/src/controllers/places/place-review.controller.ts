import type { Request, Response } from "express";
import {
  BlockPlaceReviewAuthorUseCase, DeletePlaceRatingUseCase, GetMyPlaceRatingUseCase,
  GetPlaceRatingStatisticsUseCase, GetPlaceReviewsUseCase, ModeratePlaceReviewsUseCase,
  ReportPlaceReviewUseCase, SubmitPlaceRatingUseCase, UpdatePlaceRatingUseCase,
} from "../../usecases/places/place-review.usecases.js";
import { reviewPageQuery } from "../../validators/places/place-review.validator.js";

const submit = new SubmitPlaceRatingUseCase();
const update = new UpdatePlaceRatingUseCase();
const remove = new DeletePlaceRatingUseCase();
const own = new GetMyPlaceRatingUseCase();
const reviews = new GetPlaceReviewsUseCase();
const statistics = new GetPlaceRatingStatisticsUseCase();
const report = new ReportPlaceReviewUseCase();
const blocks = new BlockPlaceReviewAuthorUseCase();
const moderation = new ModeratePlaceReviewsUseCase();

function result(res: Response, data: unknown) {
  return res.json({ success: true, data });
}

export class PlaceReviewController {
  statistics = async (req: Request<{ placeId: string }>, res: Response) =>
    result(res, await statistics.execute(req.params.placeId));

  list = async (req: Request<{ placeId: string }>, res: Response) => {
    const { limit, cursor } = reviewPageQuery.parse(req.query);
    return result(res, await reviews.execute(req.params.placeId, req.user!.uid, limit, cursor));
  };

  own = async (req: Request<{ placeId: string }>, res: Response) =>
    result(res, await own.execute(req.params.placeId, req.user!.uid));

  submit = async (req: Request<{ placeId: string }>, res: Response) =>
    result(res, await submit.execute(req.params.placeId, req.user!.uid, req.body));

  update = async (req: Request<{ placeId: string }>, res: Response) =>
    result(res, await update.execute(req.params.placeId, req.user!.uid, req.body));

  remove = async (req: Request<{ placeId: string }>, res: Response) =>
    result(res, await remove.execute(req.params.placeId, req.user!.uid));

  report = async (req: Request<{ placeId: string; reviewId: string }>, res: Response) =>
    result(res, await report.execute(req.params.placeId, req.params.reviewId, req.user!.uid, req.body.reason));

  block = async (req: Request<{ placeId: string; reviewId: string }>, res: Response) =>
    result(res, await blocks.block(req.params.placeId, req.params.reviewId, req.user!.uid));

  listBlocks = async (req: Request, res: Response) => {
    const { limit, cursor } = reviewPageQuery.parse(req.query);
    return result(res, await blocks.list(req.user!.uid, limit, cursor));
  };

  unblock = async (req: Request<{ id: string }>, res: Response) =>
    result(res, await blocks.unblock(req.user!.uid, req.params.id));

  queue = async (req: Request, res: Response) => {
    const { limit, cursor } = reviewPageQuery.parse(req.query);
    return result(res, await moderation.queue(req.user!.uid, limit, cursor));
  };

  moderate = async (req: Request<{ placeId: string; reviewId: string }>, res: Response) =>
    result(res, await moderation.moderate(req.user!.uid, req.params.placeId, req.params.reviewId,
      req.body.moderationStatus));

  dismiss = async (req: Request<{ id: string }>, res: Response) =>
    result(res, await moderation.dismiss(req.user!.uid, req.params.id));
}
