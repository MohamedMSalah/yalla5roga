/** Official style-spec validation + public vector data probe. No Flutter runtime. */
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
const require = createRequire(path.join(process.argv[2], 'package.json'));
const { validateStyleMin } = require('@maplibre/maplibre-gl-style-spec');
const { VectorTile } = require('@mapbox/vector-tile');
const { PbfReader } = require('pbf');
const variants = JSON.parse(readFileSync('../docs/audit/MAPLIBRE_STYLES.json', 'utf8'));
const results = [];
for (const [name, style] of Object.entries(variants)) {
  const errors = validateStyleMin(style);
  assert.deepEqual(errors.map(e => e.message), [], `${name}: invalid style`);
  assert.ok(Object.values(style.sources).every(s => s.type === 'vector'));
  const byId = Object.fromEntries(style.layers.map(l => [l.id, l]));
  assert.equal(byId.buildings.minzoom, 13);
  assert.equal(byId['building-heights'].minzoom, 16);
  assert.ok(byId['building-heights'].filter);
  if (name.startsWith('light')) {
    assert.equal(byId.land.paint['background-color'], '#F7F8F4');
    assert.equal(byId.water.paint['fill-color'], '#A9DCEB');
    assert.equal(byId.parks.paint['fill-color'], '#CFE8CF');
    assert.equal(byId.green.paint['fill-color'], '#DDEDD6');
    assert.equal(byId.buildings.paint['fill-outline-color'], '#D5D8D4');
    assert.ok(JSON.stringify(byId.buildings.paint).includes('#E8E9E6'));
  }
  assert.ok(!style.layers.some(l => l.type === 'raster'));
  assert.ok(!style.layers.some(l => l.id.includes('minor') && l.type === 'symbol'));
  results.push({ scenario: `${name}: official MapLibre style schema, palette, zoom thresholds and vector-only sources`, result: 'PASS', layers: style.layers.length });
}
const headers = { 'User-Agent': 'Yalla5roga-map-verification/1.0' };
async function get(url) {
  const response = await fetch(url, { headers, signal: AbortSignal.timeout(25000) });
  assert.equal(response.status, 200, `Provider request failed: ${new URL(url).pathname}`);
  return response;
}
const tileJson = await (await get(variants.light_en.sources.basemap.url)).json();
assert.ok(tileJson.tiles?.length); assert.equal(tileJson.maxzoom, 14);
results.push({ scenario: 'Free OpenFreeMap TileJSON responds with vector PBF endpoints, maxzoom 14', result: 'PASS' });
const totals = {}, names = { arabic: 0, english: 0, fallback: 0 };
let heights = 0, namedWaterways = 0;
for (const [lat, lng, z] of [[30.0444, 31.229, 14], [30.061, 31.219, 14], [30.04, 31.266, 14], [30.02, 31.23, 11]]) {
  const n = 2 ** z, r = lat * Math.PI / 180;
  const x = Math.floor((lng + 180) / 360 * n);
  const y = Math.floor((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * n);
  const url = tileJson.tiles[0].replace('{z}', z).replace('{x}', x).replace('{y}', y);
  const tile = new VectorTile(new PbfReader(new Uint8Array(await (await get(url)).arrayBuffer())));
  for (const [layerName, layer] of Object.entries(tile.layers)) {
    totals[layerName] = (totals[layerName] ?? 0) + layer.length;
    for (let i = 0; i < layer.length; i++) {
      const p = layer.feature(i).properties;
      if (p['name:ar'] || p.name_ar) names.arabic++;
      if (p['name:en'] || p.name_en) names.english++;
      if (p.name) names.fallback++;
      if (layerName === 'waterway' && (p.name || p['name:ar'] || p.name_ar)) namedWaterways++;
      if (layerName === 'building' && p.render_height > 0) heights++;
    }
  }
}
for (const layer of ['building', 'transportation', 'water', 'park', 'place', 'transportation_name']) assert.ok(totals[layer] > 0, `Missing Cairo geographic layer ${layer}`);
assert.ok(namedWaterways > 0 || totals.water_name > 0, 'Missing named water features');
assert.ok(names.arabic > 0 && names.english > 0 && names.fallback > 0);
results.push({ scenario: 'Live Cairo/Nile/Zamalek/Al-Azhar vector geometry and bilingual/fallback labels exist', result: 'PASS', featureCounts: totals, labelCounts: names, namedWaterways, buildingsWithHeightData: heights });
for (const range of ['0-255', '1536-1791']) {
  const url = variants.light_en.glyphs.replace('{fontstack}', encodeURIComponent('Noto Sans Regular')).replace('{range}', range);
  const bytes = await (await get(url)).arrayBuffer();
  assert.ok(bytes.byteLength > 100);
  results.push({ scenario: `Provider glyph range ${range} available for the configured font`, result: 'PASS', bytes: bytes.byteLength });
}
writeFileSync('../docs/audit/MAPLIBRE_STYLE_RESULTS.json', JSON.stringify({ checkedAt: new Date().toISOString(), scope: 'schema and live vector data only; no rendered UI or device verification', results }, null, 2) + '\n');
console.log(JSON.stringify({ passed: results.length, results }, null, 2));
