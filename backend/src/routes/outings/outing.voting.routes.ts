import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  castVoteBodySchema,
  createVoteOptionBodySchema,
  outingIdParamsSchema,
  replaceVoteOptionsBodySchema,
  voteParamsSchema,
} from "../../validators/outings/outing.validator.js";

/**
 * @openapi
 * /api/outings/{id}/vote-options:
 *   get:
 *     tags: [Outing Voting]
 *     summary: List voting options
 *     operationId: listVoteOptions
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Vote options
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteOptionListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *   post:
 *     tags: [Outing Voting]
 *     summary: Add a voting option
 *     operationId: createVoteOption
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreateVoteOption"
 *     responses:
 *       "201":
 *         description: Created vote option
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteOptionResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   put:
 *     tags: [Outing Voting]
 *     summary: Replace voting options
 *     operationId: replaceVoteOptions
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreateVoteOption"
 *     responses:
 *       "200":
 *         description: Replaced vote options
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteOptionListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 * /api/outings/{id}/vote-options/{optionId}:
 *   delete:
 *     tags: [Outing Voting]
 *     summary: Delete a voting option
 *     operationId: deleteVoteOption
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/OptionId"
 *     responses:
 *       "200":
 *         description: Deleted vote option
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteOptionResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/outings/{id}/votes:
 *   get:
 *     tags: [Outing Voting]
 *     summary: List votes
 *     operationId: listVotes
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Votes
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *   post:
 *     tags: [Outing Voting]
 *     summary: Cast a vote
 *     description: The voter is the authenticated Firebase UID.
 *     operationId: castVote
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/CastVote"
 *     responses:
 *       "201":
 *         description: Recorded vote
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/CastVoteResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *   delete:
 *     tags: [Outing Voting]
 *     summary: Remove my vote
 *     operationId: removeMyVotes
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Removed vote(s)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/outings/{id}/votes/{optionId}:
 *   delete:
 *     tags: [Outing Voting]
 *     summary: Remove my vote for an option
 *     operationId: removeVote
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/OptionId"
 *     responses:
 *       "200":
 *         description: Removed vote
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/outings/{id}/voting-state:
 *   get:
 *     tags: [Outing Voting]
 *     summary: Get voting state
 *     operationId: getVotingState
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Voting tallies and closure meta
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VotingStateResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 * /api/outings/{id}/tie-break:
 *   post:
 *     tags: [Outing Voting]
 *     summary: Break a voting tie
 *     operationId: breakTie
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Tie broken
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteResolutionResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 */
const router = Router();
const controller = new OutingController();

router.get(
  "/:id/vote-options",
  validate({ params: outingIdParamsSchema }),
  controller.getVoteOptions,
);
router.post(
  "/:id/vote-options",
  validate({
    params: outingIdParamsSchema,
    body: createVoteOptionBodySchema,
  }),
  controller.addVoteOption,
);
router.put(
  "/:id/vote-options",
  validate({
    params: outingIdParamsSchema,
    body: replaceVoteOptionsBodySchema,
  }),
  controller.replaceOptions,
);
router.delete(
  "/:id/vote-options/:optionId",
  validate({ params: voteParamsSchema }),
  controller.removeVoteOption,
);

router.get(
  "/:id/votes",
  validate({ params: outingIdParamsSchema }),
  controller.getVotes,
);
router.post(
  "/:id/votes",
  validate({ params: outingIdParamsSchema, body: castVoteBodySchema }),
  controller.vote,
);
router.delete(
  "/:id/votes",
  validate({ params: outingIdParamsSchema }),
  controller.unvote,
);
router.delete(
  "/:id/votes/:optionId",
  validate({ params: voteParamsSchema }),
  controller.unvote,
);
router.get(
  "/:id/voting-state",
  validate({ params: outingIdParamsSchema }),
  controller.getVotingState,
);
router.post(
  "/:id/tie-break",
  validate({ params: outingIdParamsSchema }),
  controller.breakTie,
);

/**
 * @openapi
 * /api/outings/{id}/confirmed-venue:
 *   put:
 *     tags: [Outing Voting]
 *     summary: Creator confirms a proposed venue and closes voting
 *     operationId: confirmOutingVenue
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/CastVote"
 *     responses:
 *       "200":
 *         description: Confirmed outing and selected option
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteResolutionResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: Outing is no longer awaiting a venue
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 */
router.put(
  "/:id/confirmed-venue",
  validate({ params: outingIdParamsSchema, body: castVoteBodySchema }),
  controller.confirmVenue,
);

export default router;
