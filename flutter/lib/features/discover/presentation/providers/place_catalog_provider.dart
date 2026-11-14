import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';

class PlaceCatalogProvider extends ChangeNotifier {
  PlaceCatalogProvider(this.repository, {this.searchAcrossBounds = false}) {
    _changes = repository.catalogChanges.listen((_) {
      loadDefinitions(force: true);
      update(filters);
    });
  }
  final DiscoverRepository repository;
  final bool searchAcrossBounds;
  final mapController = YallaMapController();
  final searchController = TextEditingController();
  PlaceFilters filters = const PlaceFilters();
  List<CatalogDefinition> categories = const [], vibes = const [];
  List<SuggestedPlace> places = const [];
  bool loading = false, hasMore = false;
  String? error;
  bool taxonomyFailed = false;
  bool definitionsLoaded = false;
  int _revision = 0;
  bool _disposed = false;
  Timer? _debounce;
  Completer<void>? _request;
  int _nextOffset = 0;
  String? _viewport;
  bool _viewportNeedsLoad = false;
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

  void setBounds(String value) {
    if (_viewport == value && filters.bounds == value && !_viewportNeedsLoad) {
      return;
    }
    _viewport = value;
    update(filters.copyWith(bounds: value), debounce: true);
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

  Future<void> update(PlaceFilters value, {bool debounce = false}) async {
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
    places = places.where((p) => filters.matches(p.toOutingPlace())).toList();
    loading = debounce;
    notifyListeners();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 350), () => load());
    } else {
      await load();
    }
  }

  Future<void> load({bool more = false, bool force = false}) async {
    if (_disposed) return;
    if (more && (loading || !hasMore)) return;
    cancelPending();
    final revision = ++_revision;
    final request = _request = Completer<void>();
    var offset = more ? _nextOffset : 0;
    final requestedFilters = filters;
    loading = true;
    _viewportNeedsLoad = false;
    error = null;
    notifyListeners();
    // Paginate a viewport progressively; cap each burst to keep panning responsive.
    for (var page = 0; page < (filters.bounds == null ? 1 : 10); page++) {
      final result = await repository.queryPlaces(
        requestedFilters,
        offset: offset,
        forceRefresh: force,
        cancelled: request.future,
      );
      if (_disposed || revision != _revision) return;
      var count = 0;
      result.fold((_) => error = 'catalog_load_failed', (items) {
        count = items.length;
        places = {
          for (final p in (more || page > 0) ? places : <SuggestedPlace>[])
            p.id: p,
          for (final p in items)
            if (requestedFilters.matches(p.toOutingPlace())) p.id: p,
        }.values.toList();
        offset += count;
        _nextOffset = offset;
        hasMore = count == 50;
      });
      notifyListeners();
      if (error != null || !hasMore) break;
    }
    _request = null;
    loading = false;
    notifyListeners();
  }

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
