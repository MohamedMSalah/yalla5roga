import type { ISavedLocationRepository } from "../../repositories/users/i-saved-location.repository.js";
import { EffectiveStartingLocationResolver } from "../../services/users/effective-starting-location-resolver.js";
import type { SavedLocationInput, StartingLocationSelection } from "../../types/users/saved-location.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class CreateSavedLocationUseCase {
  constructor(private readonly repository: ISavedLocationRepository) {}

  execute(userId: string, input: SavedLocationInput) {
    return this.repository.create(userId, input);
  }
}

export class ListSavedLocationsUseCase {
  constructor(private readonly repository: ISavedLocationRepository) {}

  execute(userId: string) {
    return this.repository.list(userId);
  }
}

export class GetSavedLocationUseCase {
  constructor(private readonly repository: ISavedLocationRepository) {}

  async execute(userId: string, id: string) {
    const location = await this.repository.get(userId, id);
    if (!location) throw new NotFoundError("Saved location");
    return location;
  }
}

export class UpdateSavedLocationUseCase {
  constructor(private readonly repository: ISavedLocationRepository) {}

  execute(userId: string, id: string, input: Partial<SavedLocationInput>) {
    return this.repository.update(userId, id, input);
  }
}

export class DeleteSavedLocationUseCase {
  constructor(private readonly repository: ISavedLocationRepository) {}

  async execute(userId: string, id: string) {
    if (!await this.repository.delete(userId, id)) throw new NotFoundError("Saved location");
  }
}

export class GetDefaultStartingLocationUseCase {
  constructor(private readonly resolver: EffectiveStartingLocationResolver) {}

  execute(userId: string) {
    return this.resolver.resolveForOwner(userId);
  }
}

export class SetDefaultStartingLocationUseCase {
  constructor(private readonly repository: ISavedLocationRepository) {}

  execute(userId: string, selection: StartingLocationSelection) {
    return this.repository.setDefault(userId, selection);
  }
}

export class ClearDefaultStartingLocationUseCase {
  constructor(private readonly repository: ISavedLocationRepository) {}

  execute(userId: string) {
    return this.repository.clearDefault(userId);
  }
}
