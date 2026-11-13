import type { NextFunction, Request, Response } from "express";
import { ForbiddenError, UnauthorizedError } from "../utils/errors.js";
import { isPlaceCurator } from "../services/auth/place-curator.js";

export { isPlaceCurator, placeCuratorUids } from "../services/auth/place-curator.js";

/**
 * Gate for place catalog mutations (place, hours, images, prices).
 *
 * The existing authorization model has no global admin/curator role (only group
 * roles and outing owners), so the allowlist is server configuration: a
 * comma-separated list of Firebase UIDs in `PLACES_CURATOR_UIDS`.
 *
 * Fails closed when the variable is missing or empty, so ordinary authenticated
 * users can never write the catalog. Reads stay unchanged.
 */
export function requirePlaceCurator(
  req: Request,
  _res: Response,
  next: NextFunction,
) {
  if (!req.user?.uid) {
    next(new UnauthorizedError());
    return;
  }
  if (!isPlaceCurator(req.user.uid)) {
    next(new ForbiddenError("Place catalog changes require a curator account"));
    return;
  }
  next();
}
