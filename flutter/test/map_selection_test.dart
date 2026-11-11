import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart' show Either, Right;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_map.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/pick_location_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/pick_location_provider.dart';

const _cafe = Place(id: 'catalog', name: 'Cairo Cafe', area: 'Downtown');
const _lobby = Place(name: 'Lobby', area: '', latitude: 30, longitude: 31);
const _roof = Place(name: 'Rooftop', area: '', latitude: 30, longitude: 31);
const _l10n = L10n(Locale('en'));

class _Lookup implements LocationRepository {
  final searches = <Completer<LocationLookup>>[];
  final reverses = <Completer<LocationLookup>>[];
  int cancelled = 0;

  @override
  Future<LocationLookup> search(
    String query, {
    required String language,
    required Future<void> cancelled,
  }) {
    unawaited(cancelled.then((_) => this.cancelled++));
    final request = Completer<LocationLookup>();
    searches.add(request);
    return request.future;
  }

  @override
  Future<LocationLookup> reverseGeocode({
    required double latitude,
    required double longitude,
    required String language,
    required Future<void> cancelled,
  }) {
    unawaited(cancelled.then((_) => this.cancelled++));
    final request = Completer<LocationLookup>();
    reverses.add(request);
    return request.future;
  }
}

class _Denied extends MapLocation {
  const _Denied();
  @override
  Future<({LatLng? point, MapLocationIssue? issue})> locate({
    required bool requestPermission,
  }) async => (point: null, issue: MapLocationIssue.denied);
}

class _Tiles extends TileProvider {
  static final _pixel = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
    ),
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _pixel;
}

class _NotificationsRepository implements NotificationsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DiscoverRepository implements DiscoverRepository {
  static const cafe = SuggestedPlace(
    id: 'discover-cafe',
    name: 'Cairo Cafe',
    area: 'Downtown',
    latitude: 30,
    longitude: 31,
    vibe: OutingVibe.food,
    coverImageUrl: '',
  );

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getPlaces({
    OutingVibe? vibe,
    bool forceRefresh = false,
  }) async => const Right([cafe]);

  @override
  Future<Either<Failure, List<SuggestedPlace>>> getFeaturedPlaces({
    bool forceRefresh = false,
  }) async => const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: const [
    L10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('ar')],
  home: home,
);

LocationLookup _result(String name) => LocationLookup(
  hits: [
    LocationHit(id: name, name: name, area: '', latitude: 30, longitude: 31),
  ],
);

void main() {
  testWidgets('debounces input and cancels stale search and reverse requests', (
    tester,
  ) async {
    final lookup = _Lookup();
    final picker = PickLocationProvider(
      geocoding: lookup,
      catalog: const [_cafe],
      language: 'en',
      maxSelections: 1,
    );
    addTearDown(picker.dispose);

    picker.search('Ca');
    await tester.pump(const Duration(milliseconds: 200));
    picker.search('Cairo');
    expect(picker.results.single.id, _cafe.id);
    await tester.pump(const Duration(milliseconds: 349));
    expect(lookup.searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(lookup.searches, hasLength(1));
    picker.search('Roof');
    await tester.pump(const Duration(milliseconds: 350));
    lookup.searches.last.complete(_result('New'));
    await tester.pump();
    lookup.searches.first.complete(_result('Old'));
    await tester.pump();
    expect(picker.results.single.name, 'New');

    final oldPin = picker.pin(const LatLng(30, 31), 'Custom');
    picker.startMoving();
    final newPin = picker.pin(const LatLng(32, 33), 'Custom');
    lookup.reverses.last.complete(_result('Latest'));
    await newPin;
    lookup.reverses.first.complete(_result('Stale'));
    await oldPin;
    expect(picker.candidate?.name, 'Latest');
    expect(picker.candidate?.latitude, 32);
    expect(lookup.cancelled, 2);
  });

  test('ordered candidates and catalog UUID survive drafts', () {
    final picker = PickLocationProvider(
      geocoding: _Lookup(),
      catalog: const [_cafe],
      language: 'en',
      maxSelections: 5,
    );
    addTearDown(picker.dispose);
    picker.choose(_lobby);
    expect(picker.add(), true);
    picker.choose(_lobby);
    expect(picker.add(), false);
    picker.choose(_roof);
    expect(picker.add(), true);
    picker.choose(_cafe);
    expect(picker.add(), true);
    picker.move(2, 0);
    picker.remove(1);
    final form = CreateOutingProvider(
      groups: const [],
      contacts: const [],
      catalogPlaces: const [_cafe],
      specialEventImage: (_) => '',
      letVote: true,
    );
    addTearDown(form.dispose);
    form.replaceMapSelection(picker.selected);
    final draft = OutingDraft.fromJson(form.toDraft().toJson());
    expect(draft.selectedPlaces.map((p) => p.name), ['Cairo Cafe', 'Rooftop']);
    expect(draft.selectedPlaces.first.id, 'catalog');
    expect(draft.selectedPlaces.first.latitude, isNull);
    form.setLetVote(false);
    form.replaceMapSelection(const [_cafe]);
    final fixed = OutingDraft.fromJson(form.toDraft().toJson()).location;
    expect(fixed.placeId, 'catalog');
    expect(fixed.latitude, isNull);
  });

  testWidgets(
    'route cancellation, permission denial and catalog single selection',
    (tester) async {
      final lookup = _Lookup();
      List<Place>? result;
      await tester.pumpWidget(
        Provider<LocationRepository>.value(
          value: lookup,
          child: _app(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<List<Place>>(
                      MaterialPageRoute(
                        builder: (_) => PickLocationPage(
                          catalog: const [_cafe],
                          tileProvider: _Tiles(),
                          location: const _Denied(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(find.byType(AppMap), findsOneWidget);
      await tester.tap(find.byTooltip(_l10n.yourLocation));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.locationPermissionDenied), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Cairo');
      await tester.pump();
      await tester.tap(find.text('Cairo Cafe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.confirmLocation));
      await tester.pumpAndSettle();
      expect(result?.single.id, _cafe.id);
      expect(lookup.searches, isEmpty);
    },
  );

  testWidgets(
    'map waits for the pointer to lift before resolving camera center',
    (tester) async {
      final idle = <LatLng>[];
      var movements = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AppMap(
              center: cairoMapCenter,
              tileProvider: _Tiles(),
              onUserMove: () => movements++,
              onUserIdle: idle.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(300, 180));
      await gesture.moveBy(const Offset(80, 0));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(movements, 1);
      expect(idle, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      expect(idle, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Discover filters its map and selects a place preview', (
    tester,
  ) async {
    final discover = DiscoverProvider(repository: _DiscoverRepository());
    addTearDown(discover.dispose);
    await discover.load();
    await tester.binding.setSurfaceSize(const Size(420, 1040));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: discover),
          ChangeNotifierProvider(
            create: (_) =>
                NotificationsProvider(repository: _NotificationsRepository()),
          ),
        ],
        child: _app(
          Scaffold(
            body: DiscoverPage(
              tileProvider: _Tiles(),
              location: const _Denied(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.byType(AppMap), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Unknown');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cairo Cafe'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Cairo');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Cairo Cafe'));
    await tester.tap(find.byTooltip('Cairo Cafe'));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.createOutingAt('Cairo Cafe')), findsOneWidget);
  });
}
