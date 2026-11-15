import { CatalogRepository } from "../../repositories/places/catalog.repository.js";
import type { CatalogQuery } from "../../validators/places/catalog.validator.js";
import {
  syncStatus,
  synchronizePlaces,
  type SyncOptions,
} from "../../services/places/places-sync.js";
export class CatalogUseCase {
  syncStatus() {
    return syncStatus();
  }
  sync(options: SyncOptions) {
    return synchronizePlaces(options);
  }
  syncHistory(limit: number, offset: number) {
    return this.repository.syncHistory(limit, offset);
  }
  constructor(private readonly repository = new CatalogRepository()) {}
  list(query: CatalogQuery) {
    return this.repository.list(query);
  }
  brand(id: string) { return this.repository.brand(id); }
  geojson(query: CatalogQuery) { return this.repository.geojson(query); }
  categories() {
    return this.repository.categories();
  }
  vibes() {
    return this.repository.vibes();
  }
  version() {
    return this.repository.version();
  }
}
