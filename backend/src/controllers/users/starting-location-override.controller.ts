
import type { Request } from "express";
import type { StartingLocationContext } from "../../types/users/starting-location-override.js";
import {
  ClearStartingLocationOverrideUseCase, GetEffectiveStartingLocationUseCase, SetStartingLocationOverrideUseCase,
} from "../../usecases/users/starting-location-override.usecases.js";
import { ownerResponse } from "./saved-location.controller.js";

export class StartingLocationOverrideController {
  constructor(
    private readonly get = new GetEffectiveStartingLocationUseCase(),
    private readonly set = new SetStartingLocationOverrideUseCase(),
    private readonly clear = new ClearStartingLocationOverrideUseCase(),
  ) {}

  forContext(kind: StartingLocationContext["kind"], param: string) {
    const context = (req: Request): StartingLocationContext => ({ kind, id: req.params[param] as string });
    return {
      get: ownerResponse((uid, req) => this.get.execute(uid, context(req))),
      set: ownerResponse((uid, req) => this.set.execute(uid, context(req), req.body)),
      clear: ownerResponse((uid, req) => this.clear.execute(uid, context(req))),
    };
  }
}
