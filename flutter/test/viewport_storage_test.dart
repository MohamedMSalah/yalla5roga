import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/features/discover/data/datasources/places_local_store.dart';
import 'package:yalla_5roga/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:yalla_5roga/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/entities/viewport_region.dart';

class _Network implements NetworkInfo {
  bool online = true;
  @override
  Future<bool> get isConnected async => online;
}

class _Remote extends Fake implements DiscoverRemoteDataSource {
  final pages = <String?>[];
  bool fail = false;
  @override
  Future<({List<Map<String, dynamic>> rows, String? cursor})> areaPage(
    String bounds,
    String? cursor, {
    bool compact = false,
    Future<void>? cancelled,
  }) async {
    pages.add(cursor);
    if (fail && cursor != null) throw StateError('interrupted');
    return (
      rows: [
        {
          'id': cursor == null ? 'a' : 'b',
          'latitude': 1.0,
          'longitude': 1.0,
          'name': 'Venue',
          'category_id': 'cafes',
          'status': 'active',
        },
      ],
      cursor: cursor == null ? 'second' : null,
    );
  }

  @override
  SuggestedPlace parsePlace(Map<String, dynamic> r) => SuggestedPlace(
    id: r['id'],
    name: r['name'],
    area: '',
    vibe: OutingVibe.food,
    coverImageUrl: '',
    latitude: r['latitude'],
    longitude: r['longitude'],
    categoryId: r['category_id'] ?? '',
  );
}

class _Gps extends GeolocatorPlatform {
  int requests = 0;
  final pending = Completer<Position>();
  LocationPermission permission = LocationPermission.whileInUse;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    requests++;
    expect(locationSettings?.accuracy, LocationAccuracy.medium);
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const filter = PlaceFilters(bounds: '0,0,2,2');
  final box = ViewportRegion.buffered(filter.bounds!).single;
  late Directory directory;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('viewport-store-');
    await databaseFactory.setDatabasesPath(directory.path);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    for (final file
        in directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.db'))) {
      final db = await databaseFactory.openDatabase(file.path);
      await db.close();
    }
    await directory.delete(recursive: true);
  });
  test('upgrades version one without replacing the catalog', () async {
    final hash = sha256.convert(utf8.encode('old-origin')).toString();
    final path = '${directory.path}/places-v1-$hash.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE catalog(kind TEXT,id TEXT,data TEXT, PRIMARY KEY(kind,id))',
          );
          await db.insert('catalog', {
            'kind': 'category',
            'id': 'cafes',
            'data': '{"id":"cafes"}',
          });
        },
      ),
    );
    await old.close();
    final store = PlacesLocalStore('old-origin');
    expect(await store.definitions('category'), [
      {'id': 'cafes'},
    ]);
    expect(await store.missing(filter.bounds!), isNotEmpty);
  });

  test('automatic eviction invalidates coverage and preserves manual downloads', () async {
    final store = PlacesLocalStore('origin', maxViewportRows: 1);
    const far = ViewportRegion(10, 10, 11, 11);
    final downloaded = {
      'id': 'download',
      'name': 'Offline',
      'latitude': 10.6,
      'longitude': 10.6,
      'status': 'active',
      'place_images': [],
    };
    final old = {
      'id': 'old',
      'name': 'Old',
      'latitude': 10.5,
      'longitude': 10.5,
      'status': 'active',
    };
    await store.completeRegion(far, [downloaded, old]);
    await store.seed('place', [downloaded], detailed: true);
    await store.completeRegion(box, [
      {'id': 'visible', 'name': 'Visible', 'latitude': 1.0, 'longitude': 1.0},
    ]);
    await store.evictOutside(filter.bounds!);
    expect(await store.place('old'), isNull);
    expect(await store.place('download'), isNotNull);
    expect(await store.place('visible'), isNotNull);
    expect(await store.missing(far.key), isNotEmpty);
  });

  test(
    'buffer wraps at the date line, subtraction leaves only new coverage',
    () {
      final parts = ViewportRegion.buffered('179,-1,-179,1');
      expect(parts.length, 2);
      expect(parts.first.east, 180);
      expect(parts.last.west, -180);
      expect(box.subtract(box), isEmpty);
      expect(
        ViewportRegion.buffered('-180,-85,180,85').single.key,
        '-180.0,-90.0,180.0,90.0',
      );
    },
  );
  test('partial cursor traversal leaves old rows and coverage intact; restart and filters reuse SQLite', () async {
    final remote = _Remote(), net = _Network();
    final store = PlacesLocalStore('origin');
    final repo = DiscoverRepositoryImpl(
      remote: remote,
      networkInfo: net,
      local: store,
    );
    final cancel = Completer<void>();
    Stream<List<SuggestedPlace>> stream() =>
        repo.viewport(filter, cancelled: cancel.future);
    remote.fail = true;
    await expectLater(stream().toList(), throwsStateError);
    expect(await store.missing(filter.bounds!), isNotEmpty);
    expect(await store.places(filter), isEmpty);
    remote.fail = false;
    await Future.wait([stream().toList(), stream().toList()]);
    expect(remote.pages, [null, 'second', null, 'second']);
    expect(await store.missing('0.1,0.1,2.1,2.1'), isEmpty);
    await (await store.open())!.close();
    final reopened = PlacesLocalStore('origin');
    final restart = DiscoverRepositoryImpl(
      remote: remote,
      networkInfo: net,
      local: reopened,
    );
    expect(
      (await restart
              .viewport(
                filter.copyWith(categories: {'cafes'}),
                cancelled: cancel.future,
              )
              .first)
          .length,
      2,
    );
    net.online = false;
    expect(
      (await restart.viewport(filter, cancelled: cancel.future).last).length,
      2,
    );
    expect(remote.pages.length, 4);
    cancel.complete();
  });
  test('authoritative empty region removes only scoped public rows and survives reopen', () async {
    final store = PlacesLocalStore('origin');
    final far = ViewportRegion(10, 10, 11, 11);
    await store.completeRegion(far, [
      {'id': 'far', 'name': 'Far', 'latitude': 10.5, 'longitude': 10.5},
    ]);
    await store.completeRegion(box, [
      {'id': 'old', 'name': 'Old', 'latitude': 1.0, 'longitude': 1.0},
    ]);
    await store.savePrivate('alice', 'private:x', 'Garden', 1, 1, 'parks', '');
    await store.savePrivate('bob', 'private:x', 'Other', 1, 1, '', '');
    await store.savePrivate('alice', 'private:x', 'Renamed', 1, 1, 'parks', '');
    await expectLater(
      store.savePrivate('alice', 'private:y', 'Duplicate', 1, 1, '', ''),
      throwsA(isA<DatabaseException>()),
    );
    await store.completeRegion(box, []);
    expect(await store.place('old'), isNull);
    expect(await store.place('far'), isNotNull);
    expect(await store.missing(filter.bounds!), isEmpty);
    expect(
      (await store.privatePlaces('alice', filter)).single['name'],
      'Renamed',
    );
    await store.deletePrivate('bob', 'private:x');
    expect(await store.privatePlaces('bob', filter), isEmpty);
    expect(await store.privatePlaces('alice', filter), hasLength(1));
  });
  test('simultaneous GPS consumers share a balanced fix and permission revocation wins over cache', () async {
    final platform = GeolocatorPlatform.instance;
    final gps = _Gps();
    GeolocatorPlatform.instance = gps;
    addTearDown(() => GeolocatorPlatform.instance = platform);
    const service = MapLocation();
    final a = service.locateFix(requestPermission: false),
        b = service.locateFix(requestPermission: false);
    await Future<void>.delayed(Duration.zero);
    expect(gps.requests, 1);
    gps.pending.complete(
      Position(
        longitude: 0,
        latitude: 0,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    expect(await a, await b);
    expect(
      (await service.locateFix(requestPermission: false)).point,
      isNotNull,
    );
    expect(gps.requests, 1);
    gps.permission = LocationPermission.denied;
    expect((await service.locateFix(requestPermission: false)).point, isNull);
  });
}
