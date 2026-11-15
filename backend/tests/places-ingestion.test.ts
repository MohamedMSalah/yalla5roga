import { test } from "node:test";
import assert from "node:assert/strict";
import { classifyOverture } from "../src/services/places/overture-taxonomy.js";
import { normalizedName, normalizedPhone, normalizeSource, insideBoundary, duplicateMatch, safeWebsite } from "../src/services/places/import-normalization.js";
import { parseHours, sourcePrices } from "../src/services/places/import-ancillary.js";
import { PlaceVibeClassifier } from "../src/services/places/place-vibe-classifier.js";
import { catalogQuerySchema } from "../src/validators/places/catalog.validator.js";
import { decodeCatalogCursor, encodeCatalogCursor } from "../src/services/places/catalog-cursor.js";
import { publicPlace } from "../src/services/places/public-place.js";

const polygon = { type: "Polygon", coordinates: [[[31, 29], [32, 29], [32, 31], [31, 31], [31, 29]], [[31.5,30],[31.6,30],[31.6,30.1],[31.5,30.1],[31.5,30]]] };
const boundary = { features: [{ properties: { region: "EG-C" }, geometry: polygon }] };
const source = () => ({ region: "EG-C", record: { id: "00000000-0000-4000-8000-000000000001", names: { primary: "اختبار مقهى" },
  latitude: 30, longitude: 31.2, basic_category: "cafe", taxonomy: { primary: "cafe", hierarchy: ["food_and_drink", "cafe"] },
  confidence: .9, operating_status: "open", sources: [{ dataset: "meta", license: "CDLA-Permissive-2.0" }], version: 1 } });

test("current Overture hierarchy handles specialized restaurants and never reads legacy categories", () => {
  assert.equal(classifyOverture("food_and_drink", { primary: "regional_specialty", hierarchy: ["food_and_drink", "restaurant", "regional_specialty"] }).primary, "restaurants");
  assert.equal(classifyOverture("parking", { primary: "car_park", alternates: ["park"] }).primary, null);
  assert.equal(classifyOverture("park").primary, "parks");
  assert.equal(classifyOverture("medical_center").primary, null);
});
test("administrative inclusion supports holes and multipolygons", () => {
  assert.equal(insideBoundary(31.2, 30, polygon), true);
  assert.equal(insideBoundary(31.55, 30.05, polygon), false);
  assert.equal(insideBoundary(33, 30, polygon), false);
  assert.equal(insideBoundary(31.2, 30, { type: "MultiPolygon", coordinates: [polygon.coordinates] }), true);
});
test("source quality, coordinates, identity and licensing fail closed", () => {
  const good = normalizeSource("overture", source(), boundary, .7);
  assert.equal(good.data.category_id, "cafes"); assert.equal(good.data.address, null);
  assert.equal(good.data.city, null);
  assert.ok(!("rating" in good.data)); assert.ok(!("cover_image_url" in good.data));
  for (const mutation of [
    (r: any) => r.id = "bad", (r: any) => r.confidence = .4,
    (r: any) => r.confidence = null, (r: any) => r.longitude = 33,
    (r: any) => r.names.primary = " ", (r: any) => r.sources[0].license = "restricted",
  ]) { const input = source(); mutation(input.record); assert.throws(() => normalizeSource("overture", input, boundary, .7)); }
  const closed = source(); closed.record.operating_status = "permanently_closed"; closed.record.confidence = 0;
  assert.equal(normalizeSource("overture", closed, boundary, .7).data.status, "permanently_closed");
  const unknown = source(); (unknown.record as any).operating_status = null;
  const eligible = normalizeSource("overture", unknown, boundary, .7);
  assert.equal(eligible.data.status, "active");
  assert.equal(eligible.data.source_tags.operating_status, null);
});
test("Arabic/English normalization preserves original text while comparing variants", () => {
  assert.equal(normalizedName("أَهْلاً ـ كافيه"), normalizedName("اهلا كافيه"));
  assert.equal(normalizedName("Café  Nile"), "cafe nile");
  assert.equal(normalizedPhone("01012345678"), "+201012345678");
  assert.equal(normalizedPhone("not a phone"), null);
  assert.equal(safeWebsite("javascript:alert(1)"), null);
  assert.equal(safeWebsite("https://user:secret@example.com"), null);
});
test("cross-source duplicate matching protects co-located venues and nearby branches", () => {
  const a = { name: "Nile Cafe", category_id: "cafes", latitude: 30, longitude: 31.2, phone: "+201012345678" };
  assert.equal(duplicateMatch(a, { ...a }), true);
  assert.equal(duplicateMatch(a, { ...a, name: "Other cafe" }), false);
  assert.equal(duplicateMatch(a, { ...a, phone: null }), false);
  assert.equal(duplicateMatch(a, { ...a, latitude: 30.01 }), false);
  assert.equal(duplicateMatch(a, { ...a, category_id: "restaurants" }), false);
});
test("vibes infer broad activities but require evidence for sensitive characteristics", () => {
  const classifier = new PlaceVibeClassifier();
  const ordinary = classifier.classify("cafes", { internet_access: "wlan", description: "cheap luxury romantic cafe" });
  for (const forbidden of ["study_work", "romantic", "budget_friendly", "luxury", "kids_friendly"]) assert.ok(!ordinary.some((v) => v.id === forbidden));
  assert.ok(classifier.classify("cafes", { coworking: "yes" }).some((v) => v.id === "study_work"));
  assert.ok(classifier.classify("cinemas").some((v) => v.id === "date_night"));
  assert.ok(classifier.classify("parks").every((v) => v.confidence > 0 && v.confidence <= 1));
});
test("hours parser keeps unsupported or unknown schedules raw without inventing a day", () => {
  assert.deepEqual(parseHours(null), { rows: [], supported: true });
  const hours = parseHours("Mo-Fr 09:00-18:00; Sa off");
  assert.equal(hours.supported, true); assert.equal(hours.rows.length, 6);
  assert.equal(hours.rows[0].opens_at.toISOString(), "1970-01-01T09:00:00.000Z");
  for (const expression of ["24/7", "Mo 20:00-02:00", "Mo 09:00-12:00,13:00-18:00", "PH off", "Mo 25:00-26:00"]) assert.deepEqual(parseHours(expression), { rows: [], supported: false });
  assert.deepEqual(sourcePrices({}), []); assert.deepEqual(sourcePrices({ charge: "cheap" }), []);
  assert.equal(sourcePrices({ charge: "150 EGP" })[0]!.amount, "150");
});
test("bounds aliases and scoped keyset cursor reject changed filters and malformed cursors", () => {
  const q = catalogQuerySchema.parse({ minLat: "29", minLng: "31", maxLat: "31", maxLng: "32", category: "cafes", sort: "name" });
  assert.deepEqual(q.bbox, [31, 29, 32, 31]); assert.deepEqual(q.categories, ["cafes"]);
  const cursor = encodeCatalogCursor(q, { id: "00000000-0000-4000-8000-000000000001", name: "Nile" });
  assert.equal(decodeCatalogCursor({ ...q, cursor })!.value, "Nile");
  assert.throws(() => decodeCatalogCursor({ ...q, cursor, categories: ["parks"] }));
  assert.throws(() => decodeCatalogCursor({ ...q, cursor: "garbage" }));
  assert.equal(catalogQuerySchema.safeParse({ minLat: "29" }).success, false);
});
test("public projection excludes internal import and curator state", () => {
  const result = publicPlace({ id: "p", name: "N", source: "manual", source_tags: { secret: "internal" }, manually_managed: true, missing_sync_count: 2, source_records: [] });
  assert.equal(result.id, "p"); assert.equal(result.name, "N");
  for (const key of ["source_tags", "manually_managed", "missing_sync_count", "source_records", "brand"]) assert.ok(!(key in result));
  assert.equal(result.branch_id, "p"); assert.equal(result.brand_id, null);
  assert.equal(result.external_source, "manual:");
});
