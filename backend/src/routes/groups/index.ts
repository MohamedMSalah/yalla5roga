import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import groupCrudRoutes from "./group.crud.routes.js";
import groupInvitationsRoutes from "./group.invitations.routes.js";
import groupMembersRoutes from "./group.members.routes.js";

const api = Router();
api.use(authMiddleware);

// `/cuser` (crud) and static decline (invitations) before bare `/:id` consumers.
// Crud first so `/cuser` precedes `/:id` in the stack; invitations still match
// `/invitations/:invitationId/decline` and `/:id/invitations` (extra segments).
api.use(groupCrudRoutes);
api.use(groupInvitationsRoutes);
api.use(groupMembersRoutes);

const router = Router();
router.use("/api/groups", api);

export default router;
