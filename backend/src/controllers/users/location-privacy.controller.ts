import {
  GetLocationPrivacyUseCase,
  GrantLocationUsageConsentUseCase,
  ListGroupLocationExclusionsUseCase,
  SetGroupLocationExclusionUseCase,
  UpdateLocationVisibilityUseCase,
  WithdrawLocationUsageConsentUseCase,
} from "../../usecases/users/location-privacy.usecases.js";
import { ownerResponse } from "./saved-location.controller.js";

export class LocationPrivacyController {
  constructor(
    read = new GetLocationPrivacyUseCase(),
    update = new UpdateLocationVisibilityUseCase(),
    grant = new GrantLocationUsageConsentUseCase(),
    withdraw = new WithdrawLocationUsageConsentUseCase(),
    exclusions = new ListGroupLocationExclusionsUseCase(),
    setExclusion = new SetGroupLocationExclusionUseCase(),
  ) {
    this.get = ownerResponse((uid) => read.execute(uid));
    this.update = ownerResponse((uid, req) => update.execute(uid, req.body.location_visibility));
    this.grant = ownerResponse((uid, req) => grant.execute(uid, req.body.consent_policy_version));
    this.withdraw = ownerResponse((uid) => withdraw.execute(uid));
    this.listExclusions = ownerResponse((uid) => exclusions.execute(uid));
    this.exclude = ownerResponse((uid, req) => setExclusion.execute(uid, req.params.groupId as string, true));
    this.include = ownerResponse((uid, req) => setExclusion.execute(uid, req.params.groupId as string, false));
  }

  readonly get;
  readonly update;
  readonly grant;
  readonly withdraw;
  readonly listExclusions;
  readonly exclude;
  readonly include;
}
