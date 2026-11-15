"""Official free source acquisition. Emits disk-backed, boundary-clipped NDJSON.

Run via the Node places CLI. No Overpass or paid service is used. Every completed
artifact has a manifest and SHA256; interrupted outputs are never accepted.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import urllib.request

import duckdb
import osmium
from shapely.geometry import Point, mapping, shape

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(os.environ.get("PLACES_DATA_DIR", ROOT / ".places-data"))
REGIONS = ("EG-C", "EG-GZ")


def remote(url, dest):
    """Stream to a temporary file; conditionally reuse only unchanged upstream data."""
    dest = Path(dest)
    meta = dest.with_suffix(dest.suffix + ".http.json")
    headers = {"User-Agent": "Yalla5roga-Places/1.0 (official open data importer)"}
    if dest.exists() and meta.exists():
        old = json.loads(meta.read_text())
        if old.get("etag"):
            headers["If-None-Match"] = old["etag"]
        if old.get("modified"):
            headers["If-Modified-Since"] = old["modified"]
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as response:
                with dest.with_suffix(dest.suffix + ".part").open("wb") as out:
                    while chunk := response.read(1024 * 1024):
                        out.write(chunk)
                os.replace(dest.with_suffix(dest.suffix + ".part"), dest)
                meta.write_text(json.dumps({"url": url, "etag": response.headers.get("ETag"),
                                            "modified": response.headers.get("Last-Modified")}), encoding="utf-8")
                return
        except urllib.error.HTTPError as error:
            if error.code == 304 and dest.exists():
                return
            if attempt == 3:
                raise
        except (OSError, TimeoutError):
            if attempt == 3:
                raise
        time.sleep(2 ** attempt)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as data:
        while chunk := data.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()


def cleanup_index(path):
    # Windows can retain a mapped index until pyosmium's C++ objects are released.
    # A successful extraction must not fail solely because a disposable index is open.
    try:
        Path(path).unlink(missing_ok=True)
    except PermissionError:
        print(f"Temporary node index retained until process exit: {path}", file=sys.stderr)


def boundaries(pbf, fingerprint):
    path = CACHE / f"boundaries-{fingerprint[:16]}.geojson"
    if path.exists():
        prior = json.loads(path.read_text(encoding="utf-8"))
        if prior.get("extract_sha256") == fingerprint:
            return path, prior
    features = []
    factory = osmium.geom.GeoJSONFactory()

    class BoundaryReader(osmium.SimpleHandler):
        def area(self, area):
            code = area.tags.get("ISO3166-2")
            if code not in REGIONS or area.tags.get("boundary") != "administrative":
                return
            geom = json.loads(factory.create_multipolygon(area))
            polygon = shape(geom)
            if not polygon.is_valid or polygon.is_empty:
                raise ValueError(f"Invalid administrative boundary: {code}")
            features.append({"type": "Feature", "properties": {"region": code,
                             "osm_relation_id": area.orig_id()}, "geometry": geom})

    # Disk node index bounds RAM independently of the number of Egypt nodes.
    index = str(CACHE / "boundary-nodes.idx")
    BoundaryReader().apply_file(str(pbf), locations=True, idx="sparse_file_array," + index)
    if len(features) != 2 or {f["properties"]["region"] for f in features} != set(REGIONS):
        raise ValueError("Egypt extract did not contain exactly one Cairo and Giza admin boundary")
    result = {"type": "FeatureCollection", "extract_sha256": fingerprint, "features": features}
    path.write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
    cleanup_index(index)
    return path, result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", choices=("overture", "osm"), required=True)
    parser.add_argument("--city", choices=("cairo", "giza", "all"), default="all")
    parser.add_argument("--reuse", action="store_true", help="Reuse a checksum-verified completed artifact")
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    output = CACHE / f"{args.source}-{args.city}.ndjson"
    manifest = output.with_suffix(".manifest.json")
    if args.reuse and output.exists() and manifest.exists():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        if data["sha256"] == digest(output):
            print(str(manifest))
            return
        raise ValueError("Cached artifact checksum mismatch")
    pbf = CACHE / "egypt-latest.osm.pbf"
    print("Fetching/checking official Geofabrik Egypt extract", file=sys.stderr, flush=True)
    # Verify the publisher checksum before parsing the extract.
    checksum_path = CACHE / "egypt-latest.osm.pbf.md5"
    if not (args.reuse and pbf.exists() and checksum_path.exists()):
        remote("https://download.geofabrik.de/africa/egypt-latest.osm.pbf", pbf)
        remote("https://download.geofabrik.de/africa/egypt-latest.osm.pbf.md5", checksum_path)
    md5 = hashlib.md5()
    with pbf.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            md5.update(chunk)
    if md5.hexdigest() != checksum_path.read_text().split()[0]:
        raise ValueError("Geofabrik publisher checksum mismatch; retry with a stable release")
    fingerprint = digest(pbf)
    print("Assembling Cairo / Giza administrative polygons", file=sys.stderr, flush=True)
    boundary_path, boundary_data = boundaries(pbf, fingerprint)
    selected = [f for f in boundary_data["features"] if args.city == "all" or
                f["properties"]["region"] == {"cairo": "EG-C", "giza": "EG-GZ"}[args.city]]
    polygons = [(f["properties"]["region"], shape(f["geometry"])) for f in selected]

    def region_for(lon, lat):
        for code, polygon in polygons:
            if polygon.covers(Point(lon, lat)):
                return code
        return None

    counts = {region: 0 for region, _ in polygons}
    temp = output.with_suffix(".ndjson.part")
    release = fingerprint
    with temp.open("w", encoding="utf-8", newline="\n") as out:
        def emit(region, record):
            counts[region] += 1
            out.write(json.dumps({"region": region, "record": record}, ensure_ascii=False, separators=(",", ":"), default=str) + "\n")

        if args.source == "osm":
            factory = osmium.geom.GeoJSONFactory()
            # Keep only POIs with a potential supported tag; business rules stay in TypeScript.
            keys = {"amenity", "shop", "leisure", "tourism", "historic", "sport"}

            def relevant(tags):
                return any(k.split(":")[-1] in keys for k in tags) and any(
                    k in tags for k in ("name", "name:en", "name:ar"))

            class PoiReader(osmium.SimpleHandler):
                def save(self, obj, kind, lon, lat):
                    tags = dict(obj.tags)
                    if not relevant(tags):
                        return
                    region = region_for(lon, lat)
                    if region:
                        emit(region, {"type": kind, "id": obj.orig_id() if kind == "relation" else obj.id,
                                      "lat": lat, "lon": lon, "tags": tags, "version": obj.version,
                                      "timestamp": str(obj.timestamp)})

                def node(self, node):
                    if node.location.valid() and relevant(dict(node.tags)):
                        self.save(node, "node", node.lon, node.lat)

                def way(self, way):
                    if not relevant(dict(way.tags)):
                        return
                    try:
                        geom = shape(json.loads(factory.create_linestring(way)))
                        point = geom.centroid
                        self.save(way, "way", point.x, point.y)
                    except (RuntimeError, ValueError):
                        print(f"Skipping invalid way geometry {way.id}", file=sys.stderr)

                def area(self, area):
                    if area.from_way() or not relevant(dict(area.tags)):
                        return
                    try:
                        point = shape(json.loads(factory.create_multipolygon(area))).representative_point()
                        self.save(area, "relation", point.x, point.y)
                    except (RuntimeError, ValueError):
                        print(f"Skipping invalid relation geometry {area.orig_id()}", file=sys.stderr)

            index = str(CACHE / "poi-nodes.idx")
            PoiReader().apply_file(str(pbf), locations=True, idx="sparse_file_array," + index)
            cleanup_index(index)
        else:
            catalog_path = CACHE / "overture-catalog.json"
            remote("https://stac.overturemaps.org/catalog.json", catalog_path)
            catalog = json.loads(catalog_path.read_text())
            release = catalog.get("latest") or next(link["href"].split("/")[-2] for link in catalog["links"] if link.get("latest"))
            if not __import__("re").fullmatch(r"\d{4}-\d{2}-\d{2}\.\d+", release):
                raise ValueError("Invalid Overture release identifier")
            print(f"Querying official Overture release {release}", file=sys.stderr, flush=True)
            db = duckdb.connect()
            db.execute("SET memory_limit='512MB'; SET threads=4;")
            db.execute(f"SET temp_directory='{str(CACHE / 'duckdb-temp').replace(chr(92), '/')}';")
            db.execute("INSTALL httpfs; LOAD httpfs; INSTALL spatial; LOAD spatial;")
            db.execute("SET s3_region='us-west-2';")
            path = f"s3://overturemaps-us-west-2/release/{release}/theme=places/type=place/*.parquet"
            bounds = (min(p.bounds[0] for _, p in polygons), min(p.bounds[1] for _, p in polygons),
                      max(p.bounds[2] for _, p in polygons), max(p.bounds[3] for _, p in polygons))
            cursor = db.execute("""SELECT id,names,basic_category,taxonomy,confidence,addresses,phones,websites,
                sources,operating_status,version,ST_X(geometry) AS longitude,ST_Y(geometry) AS latitude
                FROM read_parquet(?) WHERE bbox.xmin >= ? AND bbox.xmax <= ?
                AND bbox.ymin >= ? AND bbox.ymax <= ?""", [path, bounds[0], bounds[2], bounds[1], bounds[3]])
            columns = [c[0] for c in cursor.description]
            while rows := cursor.fetchmany(500):
                for values in rows:
                    row = dict(zip(columns, values))
                    region = region_for(row["longitude"], row["latitude"])
                    if region:
                        emit(region, row)
            db.close()
    os.replace(temp, output)
    artifact_hash = digest(output)
    archive = CACHE / f"{args.source}-{args.city}-{artifact_hash[:16]}.ndjson"
    if not archive.exists():
        try:
            os.link(output, archive)
        except OSError:
            __import__("shutil").copyfile(output, archive)
    data = {"source": args.source, "city": args.city, "release": release, "records": counts,
            "path": str(archive.resolve()), "boundary_path": str(boundary_path.resolve()),
            "boundary_sha256": digest(boundary_path), "sha256": artifact_hash,
            "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "complete": True,
            "url": "https://download.geofabrik.de/africa/egypt-latest.osm.pbf" if args.source == "osm" else
            f"s3://overturemaps-us-west-2/release/{release}/theme=places/type=place/"}
    manifest.write_text(json.dumps(data, indent=2), encoding="utf-8")
    archived_manifest = archive.with_suffix(".manifest.json")
    archived_manifest.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(str(archived_manifest), flush=True)


if __name__ == "__main__":
    main()
