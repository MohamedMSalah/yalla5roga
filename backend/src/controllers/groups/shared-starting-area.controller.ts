import { LocationUsageAuthorizationService } from "../../services/users/location-usage-authorization.service.js";
import { ownerResponse } from "../users/saved-location.controller.js";

export class SharedStartingAreaController {
  constructor(authorization = new LocationUsageAuthorizationService()) {
    this.get = ownerResponse((uid, req) =>
      authorization.sharedArea(req.params.groupId as string, uid, req.params.userId as string),
    );
  }

  readonly get;
}
