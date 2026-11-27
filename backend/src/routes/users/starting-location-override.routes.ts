
import { Router } from "express";
import { z } from "zod";
import { StartingLocationOverrideController } from "../../controllers/users/starting-location-override.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import { startingLocationOverrideBody } from "../../validators/users/starting-location-override.validator.js";

const router = Router();
const controller = new StartingLocationOverrideController();
const empty = z.strictObject({}).optional();

for (const [kind, collection, param] of [
  ["meetup", "smart-meetups", "sessionId"],
  ["outing", "outings", "outingId"],
] as const) {
  const path = `/api/${collection}/:${param}/my-starting-location`;
  const handlers = controller.forContext(kind, param);
  const params = z.object({ [param]: z.uuid() });
  const noBody = validate({ params, query: empty, body: empty });
  router.get(path, authMiddleware, noBody, handlers.get);
  router.put(path, authMiddleware, validate({ params, query: empty, body: startingLocationOverrideBody }), handlers.set);
  router.delete(path, authMiddleware, noBody, handlers.clear);
}

export default router;
