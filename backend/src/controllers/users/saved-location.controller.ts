import type { Request, RequestHandler } from "express";
import type { ISavedLocationRepository } from "../../repositories/users/i-saved-location.repository.js";
import { SavedLocationRepository } from "../../repositories/users/saved-location.repository.js";
import { EffectiveStartingLocationResolver } from "../../services/users/effective-starting-location-resolver.js";
import {
  ClearDefaultStartingLocationUseCase,
  CreateSavedLocationUseCase,
  DeleteSavedLocationUseCase,
  GetDefaultStartingLocationUseCase,
  GetSavedLocationUseCase,
  ListSavedLocationsUseCase,
  SetDefaultStartingLocationUseCase,
  UpdateSavedLocationUseCase,
} from "../../usecases/users/saved-locations.usecases.js";
import { UnauthorizedError } from "../../utils/errors.js";

export function ownerResponse(
  action: (userId: string, req: Request) => Promise<unknown>,
  status = 200,
): RequestHandler {
  return async (req, res, next) => {
    res.set("Cache-Control", "private, no-store");
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await action(req.user.uid, req);
      res.status(status).json({ success: true, data: data ?? null });
    } catch (error) {
      next(error);
    }
  };
}

export class SavedLocationController {
  readonly create: RequestHandler;
  readonly list: RequestHandler;
  readonly get: RequestHandler;
  readonly update: RequestHandler;
  readonly delete: RequestHandler;
  readonly getDefault: RequestHandler;
  readonly setDefault: RequestHandler;
  readonly clearDefault: RequestHandler;

  constructor(repository: ISavedLocationRepository = new SavedLocationRepository()) {
    const create = new CreateSavedLocationUseCase(repository);
    const list = new ListSavedLocationsUseCase(repository);
    const get = new GetSavedLocationUseCase(repository);
    const update = new UpdateSavedLocationUseCase(repository);
    const remove = new DeleteSavedLocationUseCase(repository);
    const getDefault = new GetDefaultStartingLocationUseCase(new EffectiveStartingLocationResolver(repository));
    const setDefault = new SetDefaultStartingLocationUseCase(repository);
    const clearDefault = new ClearDefaultStartingLocationUseCase(repository);

    this.create = ownerResponse((uid, req) => create.execute(uid, req.body), 201);
    this.list = ownerResponse((uid) => list.execute(uid));
    this.get = ownerResponse((uid, req) => get.execute(uid, req.params.id as string));
    this.update = ownerResponse((uid, req) => update.execute(uid, req.params.id as string, req.body));
    this.delete = ownerResponse((uid, req) => remove.execute(uid, req.params.id as string));
    this.getDefault = ownerResponse((uid) => getDefault.execute(uid));
    this.setDefault = ownerResponse((uid, req) => setDefault.execute(uid, req.body));
    this.clearDefault = ownerResponse((uid) => clearDefault.execute(uid));
  }
}
