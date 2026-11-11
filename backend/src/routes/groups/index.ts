import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import groupCrudRoutes from "./group.crud.routes.js";
import groupInvitationsRoutes from "./group.invitations.routes.js";
import groupMembersRoutes from "./group.members.routes.js";

const api = Router();
api.use(authMiddleware);

// Static collection routes precede dynamic IDs.
api.use(groupCrudRoutes);
api.use(groupInvitationsRoutes);
api.use(groupMembersRoutes);

const router = Router();
router.use("/api/groups", api);

export default router;
