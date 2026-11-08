import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import outingChatRoutes from "./outing.chat.routes.js";
import outingCrudRoutes from "./outing.crud.routes.js";
import outingDraftsRoutes from "./outing.drafts.routes.js";
import outingParticipantsRoutes from "./outing.participants.routes.js";
import outingSavedRoutes from "./outing.saved.routes.js";
import outingVotingRoutes from "./outing.voting.routes.js";

const api = Router();
api.use(authMiddleware);

// Static collections before any `/:id` handlers.
api.use(outingDraftsRoutes);
api.use(outingSavedRoutes);
// CRUD includes `/cuser` and bare `/:id` (one segment only; sub-resources below still match).
api.use(outingCrudRoutes);
api.use(outingParticipantsRoutes);
api.use(outingVotingRoutes);
api.use(outingChatRoutes);

const router = Router();
router.use("/api/outings", api);

export default router;
