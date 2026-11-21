import { z } from "zod";
import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  castVoteBodySchema,
  replaceBallotBodySchema,
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
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
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [options]
 *             properties:
 *               options:
 *                 type: array
 *                 items:
 *                   $ref: "#/components/schemas/CreateVoteOptionRequest"
 *     responses:
 *       "200":
 *         description: Replaced vote options
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteOptionListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
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
 *   put:
 *     tags: [Outing Voting]
 *     summary: Replace my complete multi-location ballot atomically
 *     operationId: replaceOutingBallot
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [option_ids]
 *             properties:
 *               round_number: { type: integer, minimum: 1, description: Required after the initial round }
 *               option_ids:
 *                 type: array
 *                 maxItems: 5
 *                 uniqueItems: true
 *                 items:
 *                   type: string
 *                   format: uuid
 *     responses:
 *       "200":
 *         description: Complete ballot persisted for the active round
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/BallotResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: Voting closed or deadline passed
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
 *     description: Idempotently add one selection for the authenticated Firebase UID. Use PUT to replace the complete ballot.
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
 *       - in: query
 *         name: round_number
 *         schema: { type: integer, minimum: 1 }
 *         description: Current voting round; required after round 1
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
 *       - in: query
 *         name: round_number
 *         schema: { type: integer, minimum: 1 }
 *         description: Current voting round; required after round 1
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
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               method: { type: string, enum: [random] }
 *               round_number: { type: integer, minimum: 1, description: Required after the initial round }
 *     responses:
 *       "200":
 *         description: Tie broken
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteResolutionResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: Voting is not awaiting a tie-break
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
router.put(
  "/:id/votes",
  validate({ params: outingIdParamsSchema, body: replaceBallotBodySchema }),
  controller.replaceBallot,
);
router.post(
  "/:id/votes",
  validate({ params: outingIdParamsSchema, body: castVoteBodySchema }),
  controller.vote,
);
router.delete(
  "/:id/votes",
  validate({ params: outingIdParamsSchema, query: z.object({ round_number: z.coerce.number().int().positive().optional() }) }),
  controller.unvote,
);
router.delete(
  "/:id/votes/:optionId",
  validate({ params: voteParamsSchema, query: z.object({ round_number: z.coerce.number().int().positive().optional() }) }),
  controller.unvote,
);
router.get(
  "/:id/voting-state",
  validate({ params: outingIdParamsSchema }),
  controller.getVotingState,
);
router.post(
  "/:id/tie-break",
  validate({ params: outingIdParamsSchema, body: z.object({ method: z.literal("random").optional(), round_number: z.number().int().positive().optional() }).optional() }),
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

/**
 * @openapi
 * /api/outings/{id}/voting/revote:
 *   post:
 *     tags: [Outing Voting]
 *     operationId: startOutingRevote
 *     summary: Creator starts a new round restricted to persisted tied locations
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [deadline]
 *             properties:
 *               deadline: { type: string, format: date-time }
 *               round_number: { type: integer, minimum: 1, description: Required after the initial round }
 *     responses:
 *       "200":
 *         description: Current voting state with new empty round
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VotingStateResponse"
 *       "400": { description: Invalid deadline or request }
 *       "401": { $ref: "#/components/responses/Unauthorized" }
 *       "403": { $ref: "#/components/responses/Forbidden" }
 *       "404": { $ref: "#/components/responses/NotFound" }
 *       "409": { description: Round changed or voting is not tie pending }
 */
router.post("/:id/voting/revote", validate({ params: outingIdParamsSchema, body: z.object({ deadline: z.iso.datetime({ offset: true }), round_number: z.number().int().positive().optional() }) }), controller.revote);

export default router;
