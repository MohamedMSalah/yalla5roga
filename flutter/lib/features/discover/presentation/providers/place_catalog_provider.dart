import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';

class PlaceCatalogProvider extends ChangeNotifier {
  PlaceCatalogProvider(
    this.repository, {
    this.searchAcrossBounds = false,
    this.maxPlaces,
  }) {
    _changes = repository.catalogChanges.listen((_) {
      if (_paused) {
        _refreshPending = true;
        return;
      }
      loadDefinitions(force: true);
      if (_hasLoaded) {
        if (loading) {
          _refreshPending = true;
        } else {
          unawaited(load());
        }
      }
    });
  }
  final DiscoverRepository repository;
  final bool searchAcrossBounds;
  final int? maxPlaces;
  final mapController = YallaMapController();
  final searchController = TextEditingController();
  PlaceFilters filters = const PlaceFilters();
  List<CatalogDefinition> categories = const [], vibes = const [];
  List<SuggestedPlace> places = const [];
  String? privateOwner;
  bool privateOnly = false;
  bool loading = false, hasMore = false;
  String? error;
  bool taxonomyFailed = false;
  bool definitionsLoaded = false;
  int _revision = 0;
  bool _disposed = false;
  bool _paused = false;
  Timer? _debounce;
  Completer<void>? _request;
  int _nextOffset = 0;
  String? _viewport;
  bool _hasLoaded = false, _refreshPending = false;
  bool _viewportNeedsLoad = false;
  void pauseBrowsing() {
    _paused = true;
    _viewportNeedsLoad = _viewportNeedsLoad || loading;
    cancelPending();
  }

  void resumeBrowsing() {
    if (!_paused || _disposed) return;
    _paused = false;
    if (_refreshPending) loadDefinitions(force: true);
    if ((_refreshPending || _viewportNeedsLoad) && _hasLoaded ||
        filters.search.trim().isNotEmpty && !_hasLoaded) {
      unawaited(load());
    }
  }

  void cameraMoving() {
    if (!loading && _debounce?.isActive != true) return;
    _viewportNeedsLoad = true;
    cancelPending();
    notifyListeners();
  }

  void cancelPending() {
    _revision++;
    _request?.complete();
    _request = null;
    _debounce?.cancel();
    loading = false;
  }

  void setBounds(String value, {double? zoom}) {
    final pageSize = zoom == null
        ? 50
        : zoom < 11
        ? 64
        : zoom < 15
        ? 48
        : 32;
    if (searchAcrossBounds && filters.search.trim().isNotEmpty) {
      _viewport = value;
      return;
    }
    if (_viewport == value &&
        filters.bounds == value &&
        filters.pageSize == pageSize &&
        !_viewportNeedsLoad) {
      return;
    }
    _viewport = value;
    update(
      filters.copyWith(bounds: value, pageSize: pageSize),
      retainPlaces: true,
    );
  }

  void clearBounds() {
    cancelPending();
    _viewport = null;
    update(filters.copyWith(clearBounds: true));
  }

  late final StreamSubscription<void> _changes;
  Future<void>? _definitions;
  Future<void> loadDefinitions({bool force = false}) =>
      _definitions ??= _loadDefinitions(force)
          .whenComplete(() => _definitions = null);
  Future<void> _loadDefinitions(bool force) async {
    if (!force && categories.isNotEmpty && vibes.isNotEmpty) return;
    final results = await Future.wait([
      repository.getDefinitions('categories', forceRefresh: force),
      repository.getDefinitions('vibes', forceRefresh: force),
    ]);
    if (_disposed) return;
    taxonomyFailed = false;
    definitionsLoaded = true;
    results[0].fold((_) => taxonomyFailed = true, (v) => categories = v);
    results[1].fold((_) => taxonomyFailed = true, (v) => vibes = v);
    notifyListeners();
  }

  Future<void> update(
    PlaceFilters value, {
    bool debounce = false,
    bool retainPlaces = false,
  }) async {
    if (_disposed) return;
    filters = value;
    // Clearing chips must not silently discard the map's geographic constraint.
    if (searchAcrossBounds && value.search.trim().isNotEmpty) {
      filters = value.copyWith(clearBounds: true, clearLocation: true);
    } else if (_viewport != null && value.bounds == null) {
      filters = value.copyWith(bounds: _viewport);
    }
    if (searchController.text != value.search) {
      searchController.value = TextEditingValue(
        text: value.search,
        selection: TextSelection.collapsed(offset: value.search.length),
      );
    }
    _debounce?.cancel();
    cancelPending();
    // Hide non-matching old markers immediately while the new request is pending.
    if (!retainPlaces && places.isNotEmpty) {
      places = places.where((p) => filters.matches(p.toOutingPlace())).toList();
    }
    loading = debounce;
    notifyListeners();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 350), () => load());
    } else {
      await load();
    }
  }

  Future<void> load({bool more = false, bool force = false}) async {
    if (_disposed || _paused) return;
    if (loading && _request != null && !force) return;
    if (more && (loading || !hasMore)) return;
    cancelPending();
    final revision = ++_revision;
    final request = _request = Completer<void>();
    final offset = more ? _nextOffset : 0;
    final requestedFilters = filters;
    _hasLoaded = true;
    loading = true;
    _viewportNeedsLoad = false;
    _refreshPending = false;
    error = null;
    notifyListeners();
    if (requestedFilters.bounds != null && repository is ViewportCatalog) {
      try {
        await for (final items in (repository as ViewportCatalog).viewport(
          requestedFilters,
          cancelled: request.future,
          owner: privateOwner,
          privateOnly: privateOnly,
        )) {
          if (_disposed || revision != _revision) return;
          final ordered = orderResults(items);
          if (!listEquals(places, ordered)) places = ordered;
          hasMore = false;
          notifyListeners();
        }
      } catch (_) {
        if (!_disposed && revision == _revision) error = 'catalog_load_failed';
      }
      if (_disposed || revision != _revision) return;
      loading = false;
      _request = null;
      if (!request.isCompleted) request.complete();
      notifyListeners();
      if (_refreshPending) unawaited(load());
      return;
    }
    final privateMatches =
        searchAcrossBounds &&
            privateOwner != null &&
            requestedFilters.search.trim().isNotEmpty &&
            offset == 0
        ? _findPrivatePlaces(requestedFilters, request.future)
        : Future.value(const <SuggestedPlace>[]);
    final result = await repository.queryPlaces(
      requestedFilters,
      offset: offset,
      forceRefresh: force,
      cancelled: request.future,
    );
    final matchingPrivate = await privateMatches;
    if (_disposed || revision != _revision) return;
    result.fold(
      (_) {
        error = 'catalog_load_failed';
        if (matchingPrivate.isNotEmpty) {
          places = [
            ...matchingPrivate,
            ...places.where((place) => !place.id.startsWith('private:')),
          ];
        }
      },
      (items) {
        final next = {
          if (more)
            for (final p in places) p.id: p,
          for (final p in matchingPrivate) p.id: p,
          for (final p in items) p.id: p,
        }.values.toList(growable: false);
        final cap = maxPlaces ?? next.length;
        final ordered = orderResults(next.take(cap).toList(growable: false));
        if (!listEquals(places, ordered)) places = ordered;
        _nextOffset = offset + items.length;
        hasMore =
            (maxPlaces == null || places.length < maxPlaces!) &&
            items.length >= requestedFilters.pageSize.clamp(1, 100);
      },
    );
    _request = null;
    loading = false;
    if (!request.isCompleted) request.complete();
    notifyListeners();
    if (_refreshPending) unawaited(load());
  }

  Future<List<SuggestedPlace>> _findPrivatePlaces(
    PlaceFilters filters,
    Future<void> cancelled,
  ) async {
    final catalog = repository;
    if (catalog is! ViewportCatalog) return const [];
    try {
      final matches = await (catalog as ViewportCatalog)
          .viewport(
            filters.copyWith(bounds: '-180,-85,180,85'),
            owner: privateOwner,
            privateOnly: true,
            cancelled: cancelled,
          )
          .first;
      return matches.take(filters.pageSize).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<SuggestedPlace> orderResults(List<SuggestedPlace> results) => results;

  @override
  void dispose() {
    _disposed = true;
    cancelPending();
    _changes.cancel();
    _debounce?.cancel();
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }
}
