import { TransportationPreferenceRepository } from "../../repositories/users/transportation-preference.repository.js";
import {
  GetTransportationPreferencesUseCase,
  UpdateBookmarkTransportationPreferenceUseCase,
  UpdateTransportationPreferencesUseCase,
} from "../../usecases/users/transportation-preferences.usecases.js";
import { ownerResponse } from "./saved-location.controller.js";

export class TransportationPreferencesController {
  constructor(
    repository = new TransportationPreferenceRepository(),
  ) {
    const get = new GetTransportationPreferencesUseCase(repository);
    const update = new UpdateTransportationPreferencesUseCase(repository);
    const bookmark = new UpdateBookmarkTransportationPreferenceUseCase(repository);
    this.get = ownerResponse((uid) => get.execute(uid));
    this.update = ownerResponse((uid, req) => update.execute(uid, req.body));
    this.patchBookmark = ownerResponse((uid, req) => bookmark.execute(uid, req.params.id as string, req.body));
  }

  readonly get;
  readonly update;
  readonly patchBookmark;
}
