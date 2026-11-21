import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/viewport_region.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';

typedef CatalogSyncState = ({String? cursor, DateTime? syncedAt});

/// Public data is scoped by backend origin. Private data also requires an owner.
class PlacesLocalStore {
  PlacesLocalStore(
    String origin, {
    this.freshness = const Duration(hours: 24),
    this.maxViewportRows = 50000,
    this.bufferFraction = .2,
    this.maxCoverageRegions = 2048,
  }) : _name = sha256.convert(utf8.encode(origin)).toString();
  final Duration freshness;
  final int maxViewportRows;
  final double bufferFraction;
  final int maxCoverageRegions;
  final String _name;
  Future<Database?>? _opening;
  Future<CatalogSyncState?>? _checkpoint;

  Future<Database?> open() => _opening ??= _open();

  Future<({DateTime fetchedAt, List<Map<String, dynamic>> places})?>
  recommendations() async {
    final db = await open();
    if (db == null) return null;
    final result = await db.query(
      'catalog',
      columns: ['updated', 'data'],
      where: "kind = 'recommendations' AND id = 'home'",
    );
    final record = result.firstOrNull;
    if (record == null) return null;
    return (
      fetchedAt: DateTime.parse(record['updated'] as String),
      places: (jsonDecode(record['data'] as String) as List)
          .cast<Map<String, dynamic>>(),
    );
  }

  Future<void> storeRecommendations(List<Map<String, dynamic>> places) async {
    final db = await open();
    await db?.insert('catalog', {
      'kind': 'recommendations',
      'id': 'home',
      'updated': DateTime.now().toUtc().toIso8601String(),
      'data': jsonEncode(places),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Database?> _open() async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return null;
    }
    try {
      final directory = await getDatabasesPath();
      return await openDatabase(
        '$directory/places-v1-$_name.db',
        version: 2,
        onUpgrade: (db, old, _) async {
          if (old < 2) await _upgrade(db);
        },
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE catalog (
              kind TEXT NOT NULL, id TEXT NOT NULL, data TEXT,
              lat REAL, lng REAL, category TEXT, vibes TEXT, legacy_vibe TEXT,
              brand TEXT, featured INTEGER, terms TEXT, updated TEXT, detailed INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (kind, id)
            )
          ''');
          await db.execute(
            "CREATE INDEX catalog_bounds ON catalog(lat,lng) WHERE kind='place' AND data IS NOT NULL",
          );
          await db.execute(
            "CREATE INDEX catalog_brand ON catalog(brand) WHERE kind='place' AND data IS NOT NULL",
          );
          await db.execute(
            "CREATE INDEX catalog_latest ON catalog(updated DESC,id) WHERE kind='place' AND data IS NOT NULL",
          );
          await db.execute(
            'CREATE TABLE checkpoint (id INTEGER PRIMARY KEY, cursor TEXT NOT NULL, synced_at INTEGER)',
          );
          await _upgrade(db);
        },
      );
    } on Exception {
      return null;
    }
  }

  static Future<void> _upgrade(Database db) async {
    await db.execute('ALTER TABLE catalog ADD COLUMN viewport_sync INTEGER');
    await db.execute(
      'CREATE TABLE coverage (region TEXT PRIMARY KEY, synced INTEGER NOT NULL)',
    );
  }

  Future<Database>? _privateOpening;
  Future<Database> _privateDb() =>
      _privateOpening ??= _openPrivate().catchError((Object error) {
        _privateOpening = null;
        throw error;
      });

  Future<Database> _openPrivate() async {
    final directory = '${await getDatabasesPath()}/device_places';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await const MethodChannel('yalla5roga/places_backup')
          .invokeMethod<void>('excludeDirectory', directory);
    }
    return openDatabase(
      '$directory/$_name.db',
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE previous_fix (owner TEXT PRIMARY KEY, lat REAL NOT NULL, lng REAL NOT NULL, accuracy REAL, measured INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE private_places (owner TEXT NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL, category TEXT, address TEXT, created INTEGER NOT NULL, updated INTEGER NOT NULL, PRIMARY KEY(owner,id), UNIQUE(owner,lat,lng))',
        );
        await db.execute(
          'CREATE INDEX private_bounds ON private_places(owner,lat,lng)',
        );
      },
    );
  }

  Future<List<ViewportRegion>> missing(String bounds) async {
    final db = (await open())!;
    final cutoff = DateTime.now().subtract(freshness).millisecondsSinceEpoch;
    final covered = await db.query(
      'coverage',
      where: 'synced >= ?',
      whereArgs: [cutoff],
    );
    List<ViewportRegion> subtractCoverage(double padding) {
      var parts = ViewportRegion.buffered(bounds, padding: padding);
      for (final row in covered) {
        final [w, s, e, n] = (row['region'] as String)
            .split(',')
            .map(double.parse)
            .toList();
        parts = [
          for (final box in parts) ...box.subtract(ViewportRegion(w, s, e, n)),
        ];
        if (parts.isEmpty) break;
      }
      return parts;
    }

    if (subtractCoverage(0).isEmpty) return [];
    final parts = subtractCoverage(bufferFraction);
    return parts;
  }

  Future<List<Map<String, dynamic>>> privatePlaces(
    String owner,
    PlaceFilters filters,
  ) async {
    final [w, s, e, n] = filters.bounds!.split(',').map(double.parse).toList();
    final rows = await (await _privateDb()).query(
      'private_places',
      where:
          'owner=? AND lat BETWEEN ? AND ? AND ${w < e ? 'lng BETWEEN ? AND ?' : '(lng>=? OR lng<=?)'}',
      whereArgs: [owner, s, n, w, e],
    );
    return [
      for (final r in rows)
        {
          'id': r['id'],
          'name': r['name'],
          'category_id': r['category'],
          'address': r['address'],
          'source': 'private',
          'latitude': r['lat'],
          'longitude': r['lng'],
        },
    ];
  }

  Future<void> savePrivate(
    String owner,
    String id,
    String name,
    double lat,
    double lng,
    String category,
    String address,
  ) async {
    if (owner.isEmpty ||
        !id.startsWith('private:') ||
        name.trim().isEmpty ||
        name.trim().length > 120 ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      throw ArgumentError('Invalid private place');
    }
    final db = await _privateDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'private_places',
        {
          'name': name.trim(),
          'category': category,
          'address': address,
          'updated': now,
        },
        where: 'owner=? AND id=?',
        whereArgs: [owner, id],
      );
      if (updated == 0) {
        await txn.insert('private_places', {
          'owner': owner,
          'id': id,
          'name': name.trim(),
          'lat': lat,
          'lng': lng,
          'category': category,
          'address': address,
          'created': now,
          'updated': now,
        });
      }
    });
  }

  Future<void> deletePrivate(String owner, String id) async {
    await (await _privateDb()).delete(
      'private_places',
      where: 'owner=? AND id=?',
      whereArgs: [owner, id],
    );
  }

  Future<Map<String, Object?>?> previousFix(String owner) async {
    return (await (await _privateDb()).query(
      'previous_fix',
      where: 'owner=?',
      whereArgs: [owner],
    )).firstOrNull;
  }

  Future<void> rememberFix(
    String owner,
    double lat,
    double lng,
    double? accuracy,
    DateTime measured,
  ) async {
    await (await _privateDb()).insert('previous_fix', {
      'owner': owner,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'measured': measured.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> invalidateCoverage() async {
    await (await open())?.delete('coverage');
  }

  Future<void> completeRegion(
    ViewportRegion box,
    List<Map<String, dynamic>> records,
  ) async {
    final db = (await open())!;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rows = await compute(_encodeChanges, [
      for (final row in records)
        {'kind': 'place', 'id': row['id'], 'record': row},
    ]);
    await db.transaction((tx) async {
      const inside =
          "kind='place' AND lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?";
      final args = [box.south, box.north, box.west, box.east];
      final existing = await tx.query(
        'catalog',
        columns: ['id', 'updated', 'detailed', 'viewport_sync'],
        where: inside,
        whereArgs: args,
      );
      final previous = {for (final row in existing) row['id']: row};
      final displaced = <Object?, Map<String, Object?>>{};
      final ids = [
        for (final row in rows)
          if (!previous.containsKey(row['id'])) row['id'],
      ];
      for (var start = 0; start < ids.length; start += 500) {
        final batchIds = ids.skip(start).take(500).toList();
        final placeholders = List.filled(batchIds.length, '?').join(',');
        final found = await tx.query(
          'catalog',
          columns: ['id', 'updated', 'detailed', 'viewport_sync'],
          where: "kind='place' AND id IN ($placeholders)",
          whereArgs: batchIds,
        );
        displaced.addEntries(found.map((row) => MapEntry(row['id'], row)));
      }
      final batch = tx.batch();
      for (final row in rows) {
        final old = previous.remove(row['id']) ?? displaced[row['id']];
        if (old?['detailed'] == 1 && old?['updated'] == row['updated']) {
          continue;
        }
        final sync = old == null ? stamp : old['viewport_sync'];
        row['viewport_sync'] = sync == null ? null : stamp;
        batch.insert(
          'catalog',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final id in previous.keys) {
        batch.delete(
          'catalog',
          where: "kind='place' AND id=?",
          whereArgs: [id],
        );
      }
      batch.insert('coverage', {
        'region': box.key,
        'synced': stamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.delete(
        'coverage',
        where: 'synced < ?',
        whereArgs: [stamp - freshness.inMilliseconds],
      );
      await batch.commit(noResult: true);
      await tx.rawDelete(
        'DELETE FROM coverage WHERE region IN (SELECT region FROM coverage ORDER BY synced DESC,region LIMIT -1 OFFSET ?)',
        [maxCoverageRegions],
      );
    });
  }

  Future<void> evictOutside(String bounds) async {
    final db = (await open())!;
    final [w, s, e, n] = bounds.split(',').map(double.parse).toList();
    final inside =
        "lat BETWEEN ? AND ? AND ${w < e ? 'lng BETWEEN ? AND ?' : '(lng>=? OR lng<=?)'}";
    final args = [s, n, w, e];
    await db.transaction((tx) async {
      final count =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT count(*) FROM catalog WHERE viewport_sync IS NOT NULL AND $inside',
              args,
            ),
          ) ??
          0;
      final evicted = await tx.rawQuery(
        'SELECT id,lat,lng FROM catalog WHERE viewport_sync IS NOT NULL AND NOT($inside) ORDER BY viewport_sync DESC,id LIMIT -1 OFFSET ?',
        [...args, math.max(0, maxViewportRows - count)],
      );
      if (evicted.isEmpty) return;
      final batch = tx.batch();
      for (final row in evicted) {
        batch.delete(
          'catalog',
          where: "kind='place' AND id=?",
          whereArgs: [row['id']],
        );
      }
      final regions = await tx.query('coverage', columns: ['region']);
      for (final region in regions) {
        final key = region['region'] as String;
        final [west, south, east, north] = key
            .split(',')
            .map(double.parse)
            .toList();
        if (evicted.any((row) {
          final lat = row['lat'] as double, lng = row['lng'] as double;
          return lat >= south && lat <= north && lng >= west && lng <= east;
        })) {
          batch.delete('coverage', where: 'region=?', whereArgs: [key]);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<CatalogSyncState?> state() => _checkpoint ??= _readCheckpoint();

  Future<CatalogSyncState?> _readCheckpoint() async {
    final db = await open();
    if (db == null) return null;
    final rows = await db.query('checkpoint');
    final row = rows.firstOrNull;
    final syncedAt = row?['synced_at'] as int?;
    return (
      cursor: row?['cursor'] as String?,
      syncedAt: syncedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(syncedAt),
    );
  }

  Future<void> apply(
    List<Map<String, dynamic>> changes,
    String cursor, {
    required DateTime? syncedAt,
  }) async {
    final db = await open();
    if (db == null) return;
    final rows = await compute(_encodeChanges, changes);
    await db.transaction((tx) async {
      final batch = tx.batch();
      for (final row in rows) {
        batch.insert(
          'catalog',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      batch.insert('checkpoint', {
        'id': 1,
        'cursor': cursor,
        'synced_at': syncedAt?.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
    _checkpoint = Future.value((cursor: cursor, syncedAt: syncedAt));
  }

  Future<void> seed(
    String kind,
    List<Map<String, dynamic>> records, {
    bool detailed = false,
  }) async {
    if (records.isEmpty) return;
    final db = await open();
    if (db == null) return;
    final rows = await compute(_encodeChanges, [
      for (final row in records)
        if (kind != 'place' ||
            row['is_active'] != false && row['status'] == 'active')
          {'kind': kind, 'id': row['id'], 'record': row},
    ]);
    final batch = db.batch();
    for (final row in rows) {
      if (detailed) {
        row['viewport_sync'] = null;
        batch.update(
          'catalog',
          row,
          where: 'kind = ? AND id = ? AND (detailed = 0 OR viewport_sync IS NOT NULL) AND data IS NOT NULL',
          whereArgs: [kind, row['id']],
        );
      }
      batch.insert(
        'catalog',
        row,
        conflictAlgorithm: kind == 'place'
            ? ConflictAlgorithm.ignore
            : ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> definitions(String kind) async {
    final db = await open();
    if (db == null) return [];
    final rows = await db.query(
      'catalog',
      columns: ['data'],
      where: 'kind = ? AND data IS NOT NULL',
      whereArgs: [kind],
    );
    final values = await compute(_decodeRows, rows);
    return values..sort((a, b) {
      final order = ((a['sort_order'] as num?) ?? 0).compareTo(
        (b['sort_order'] as num?) ?? 0,
      );
      return order == 0
          ? (a['id'] as String).compareTo(b['id'] as String)
          : order;
    });
  }

  Future<Map<String, dynamic>?> place(String id) async {
    final db = await open();
    if (db == null) return null;
    final rows = await db.rawQuery(
      'SELECT $_fields FROM catalog p WHERE $_active AND p.id = ?',
      [id],
    );
    return (await compute(_decodeRows, rows)).firstOrNull;
  }

  static const _active = "p.kind = 'place' AND p.data IS NOT NULL";
  static const _fields = '''
    p.data,
    (SELECT data FROM catalog b WHERE b.kind='brand' AND b.id=p.brand) AS brand_data,
    CASE WHEN p.brand IS NOT NULL THEN
      (SELECT count(*) FROM catalog b WHERE b.kind='place' AND b.data IS NOT NULL AND b.brand=p.brand)
    END AS branch_count
  ''';

  Future<List<Map<String, dynamic>>> places(
    PlaceFilters filters, {
    int skip = 0,
    int limit = 50,
    bool featured = false,
    OutingVibe? vibe,
  }) async {
    final db = await open();
    if (db == null) return [];
    final predicates = <String>[_active];
    final args = <Object>[];
    void where(String sql, Iterable<Object> values) {
      predicates.add(sql);
      args.addAll(values);
    }

    if (filters.bounds case final bounds?) {
      final box = bounds.split(',').map(double.parse).toList();
      final longitude = box[0] < box[2]
          ? 'p.lng BETWEEN ? AND ?'
          : '(p.lng >= ? OR p.lng <= ?)';
      where('p.lat BETWEEN ? AND ? AND $longitude', [
        box[1],
        box[3],
        box[0],
        box[2],
      ]);
    }
    if (filters.brandId case final id?) where('p.brand = ?', [id]);
    if (filters.categories.isNotEmpty) {
      final placeholders = List.filled(
        filters.categories.length,
        '?',
      ).join(',');
      where('p.category IN ($placeholders)', filters.categories);
    }
    if (filters.vibes.isNotEmpty) {
      final clauses = List.filled(
        filters.vibes.length,
        'instr(p.vibes, ?) > 0',
      ).join(' OR ');
      where('($clauses)', filters.vibes.map((vibe) => '|$vibe|'));
    }
    if (filters.search.trim().isNotEmpty) {
      where('instr(p.terms, ?) > 0', [filters.search.trim().toLowerCase()]);
    }
    if (featured) where('p.featured = 1', []);
    if (vibe != null) where('p.legacy_vibe = ?', [vibe.name]);

    var order = 'p.updated DESC, p.id';
    if (filters.latitude != null && filters.longitude != null) {
      final lat = filters.latitude!;
      final lng = filters.longitude!;
      final cos = math.cos(lat * math.pi / 180);
      where('p.lat IS NOT NULL AND p.lng IS NOT NULL', []);
      if (filters.brandId == null) {
        final width = filters.radiusKm / 110;
        where('p.lat BETWEEN ? AND ?', [lat - width, lat + width]);
        if (cos > 0.1 && lng.abs() + width / cos < 180) {
          where('p.lng BETWEEN ? AND ?', [
            lng - width / cos,
            lng + width / cos,
          ]);
        }
      }
      order = '(p.lat-?)*(p.lat-?) + (p.lng-?)*(p.lng-?)*?, p.id';
      args.addAll([lat, lat, lng, lng, cos * cos]);
    }
    final conditions = predicates.join(' AND ');
    final rows = await db.rawQuery(
      'SELECT $_fields FROM catalog p WHERE $conditions ORDER BY $order LIMIT ? OFFSET ?',
      [...args, limit, skip],
    );
    final decoded = await compute(_decodeRows, rows);
    if (filters.latitude == null || filters.longitude == null) return decoded;
    return [
      for (final row in decoded)
        if (_setDistance(row, filters)) row,
    ];
  }

  static bool _setDistance(Map<String, dynamic> row, PlaceFilters filters) {
    const radians = math.pi / 180;
    final lat = (row['latitude'] as num) * radians;
    final lng = (row['longitude'] as num) * radians;
    final originLat = filters.latitude! * radians;
    final originLng = filters.longitude! * radians;
    final a =
        math.pow(math.sin((lat - originLat) / 2), 2) +
        math.cos(originLat) *
            math.cos(lat) *
            math.pow(math.sin((lng - originLng) / 2), 2);
    final distance = 6371.0088 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
    row['distance_km'] = distance;
    return filters.brandId != null || distance <= filters.radiusKm;
  }
}

List<Map<String, Object?>> _encodeChanges(List<Map<String, dynamic>> changes) =>
    [for (final change in changes) _encodeChange(change)];

Map<String, Object?> _encodeChange(Map<String, dynamic> change) {
  final row = change['record'] as Map?;
  final vibes = (row?['vibes'] as List? ?? const []).join('|');
  return {
    'kind': change['kind'] as String,
    'id': change['id'] as String,
    'data': row == null ? null : jsonEncode(row),
    if (row != null && change['kind'] == 'place') ...{
      'detailed': row.containsKey('place_images') ? 1 : 0,
      'lat': row['latitude'] as num?,
      'lng': row['longitude'] as num?,
      'brand': row['brand_id'] as String?,
      'category': row['category_id'] as String?,
      'legacy_vibe': row['vibe'] as String?,
      'vibes': '|$vibes|',
      'featured': row['featured'] == true ? 1 : 0,
      'terms': [
        row['name'],
        row['name_ar'],
        row['name_en'],
        row['area'],
        row['address'],
      ].map((value) => value ?? '').join(' ').toLowerCase(),
      'updated': row['updated_at'] as String?,
    },
  };
}

List<Map<String, dynamic>> _decodeRows(List<Map<String, Object?>> rows) => [
  for (final row in rows) _decodeRow(row),
];

Map<String, dynamic> _decodeRow(Map<String, Object?> row) {
  final value = jsonDecode(row['data'] as String) as Map<String, dynamic>;
  if (row['brand_data'] case final String brand) {
    value['brand_name'] = (jsonDecode(brand) as Map)['name'];
    value['branch_count'] ??= row['branch_count'];
  }
  return value;
}
