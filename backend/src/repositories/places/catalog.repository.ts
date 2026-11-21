import { CatalogDatasource } from "../../datasources/places/catalog.datasource.js";
import type { CatalogQuery } from "../../validators/places/catalog.validator.js";
import { readCatalogChanges } from "../../datasources/places/catalog-changes.datasource.js";
import type { ChangeCursor } from "../../services/places/catalog-cursor.js";
export class CatalogRepository {
  syncHistory(limit: number, offset: number) {
    return this.source.syncHistory(limit, offset);
  }
  constructor(private readonly source = new CatalogDatasource()) {}
  recommendations(limit: number) { return this.source.recommendations(limit); }
  nearbyRecommendations(limit: number, lat: number, lng: number) {
    return this.source.nearbyRecommendations(limit, lat, lng);
  }
  list(q: CatalogQuery) {
    return this.source.list(q);
  }
  brand(id: string) { return this.source.brand(id); }
  geojson(q: CatalogQuery) { return this.source.geojson(q); }
  categories() {
    return this.source.categories();
  }
  vibes() {
    return this.source.vibes();
  }
  changes(cursor: ChangeCursor, limit: number) {
    return readCatalogChanges(cursor, limit);
  }
  version() {
    return this.source.version();
  }
}
