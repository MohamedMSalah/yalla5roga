// Read-only contract check. Import Express directly to avoid deployment and jobs.
import "dotenv/config";
import assert from "node:assert/strict";
import { once } from "node:events";
import app from "../src/app.js";
import { prisma } from "../src/config/database.js";

const server = app.listen(0, "127.0.0.1");
try {
  await once(server, "listening");
  const addr = server.address();
  assert(addr && typeof addr !== "string");
  const base = `http://127.0.0.1:${addr.port}`;
  const spec = await (await fetch(base + "/api-docs/swagger-ui-init.js")).text();
  assert(spec.includes('"/api/places"') && spec.includes("complete geographic cache synchronization"));
  assert(spec.includes('"location_category_id"') && spec.includes('"location_address"'));
  const params = new URLSearchParams({ bbox: "31.21,30.01,31.22,30.02", compact:"true", sort:"id",limit:"7" });
  const ids = new Set<string>();
  let pages = 0;
  do {
    const res = await fetch(base + "/api/places?" + params);
    assert.equal(res.status, 200);
    const body = await res.json();
    for(const place of body.data) {
      assert(!ids.has(place.id));
      assert(place.latitude >= 30.01 && place.latitude <= 30.02 && place.longitude >= 31.21 && place.longitude <=31.22);
      assert(!("place_images" in place));
      ids.add(place.id);
    }
    pages++;
    if (!body.pagination.has_more) break;
    assert(body.pagination.next_cursor && body.data.length === 7);
    params.set("cursor",body.pagination.next_cursor);
  } while(true);
  const expected = await prisma.places.count({where:{is_active:true,status:"active",latitude:{gte:30.01,lte:30.02},longitude:{gte:31.21,lte:31.22}}});
  assert.equal(ids.size,expected);
  const invalid = await fetch(base + "/api/places?bbox=0,90,1,-90");
  assert.equal(invalid.status,400);
  const empty = await (await fetch(base + "/api/places?bbox=0,-89,1,-88&compact=true&sort=id")).json();
  assert.deepEqual(empty.data, []);
  assert.equal(empty.pagination.has_more, false);
  assert.equal(empty.pagination.next_cursor, null);
  console.log(JSON.stringify({swagger:true,pages,unique:ids.size,expected,invalid:invalid.status,empty:true}));
} finally {
  server.close();
  await prisma.$disconnect();
}
