import { CatalogRepository } from "../../repositories/places/catalog.repository.js";
import type { CatalogQuery } from "../../validators/places/catalog.validator.js";
import {
  syncStatus,
  synchronizePlaces,
  type SyncOptions,
} from "../../services/places/places-sync.js";
import type { ChangeCursor } from "../../services/places/catalog-cursor.js";
export class CatalogUseCase {
  static readonly maxRecommendations = 24;
  private readonly recommendationsCache = new Map<string, {
    expiresAt: number;
    rows: Array<Record<string, unknown>>;
  }>();
  private readonly recommendationRequests = new Map<string, Promise<Array<Record<string, unknown>>>>();

  async recommendations(limit: number, area?: { lat: number; lng: number }) {
    const center = area && {
      lat: Number(area.lat.toFixed(2)), lng: Number(area.lng.toFixed(2)),
    };
    const key = center ? `${center.lat},${center.lng}` : "general";
    const cached = this.recommendationsCache.get(key);
    if (cached && Date.now() < cached.expiresAt) {
      return cached.rows.slice(0, limit);
    }
    const inFlight = this.recommendationRequests.get(key);
    if (inFlight) return (await inFlight).slice(0, limit);
    const configured = Number(process.env.PLACE_RECOMMENDATIONS_TTL_SECONDS);
    const ttl = Number.isSafeInteger(configured) && configured > 0 ? configured : 900;
    const max = CatalogUseCase.maxRecommendations;
    const request = (center
      ? this.repository.nearbyRecommendations(max, center.lat, center.lng)
      : this.repository.recommendations(max))
      .then((items) => {
        this.recommendationsCache.delete(key);
        if (this.recommendationsCache.size >= 32) {
          this.recommendationsCache.delete(this.recommendationsCache.keys().next().value!);
        }
        this.recommendationsCache.set(key, { rows: items, expiresAt: Date.now() + ttl * 1000 });
        return items;
      })
      .finally(() => { this.recommendationRequests.delete(key); });
    this.recommendationRequests.set(key, request);
    return (await request).slice(0, limit);
  }

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
  changes(cursor: ChangeCursor, limit: number) {
    return this.repository.changes(cursor, limit);
  }
  version() {
    return this.repository.version();
  }
}
