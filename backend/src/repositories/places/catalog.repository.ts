import { CatalogDatasource } from "../../datasources/places/catalog.datasource.js";
import type { CatalogQuery } from "../../validators/places/catalog.validator.js";
export class CatalogRepository {
  syncHistory(limit: number, offset: number) {
    return this.source.syncHistory(limit, offset);
  }
  constructor(private readonly source = new CatalogDatasource()) {}
  list(q: CatalogQuery) {
    return this.source.list(q);
  }
  geojson(q: CatalogQuery) { return this.source.geojson(q); }
  categories() {
    return this.source.categories();
  }
  vibes() {
    return this.source.vibes();
  }
  version() {
    return this.source.version();
  }
}
