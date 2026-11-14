import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';

class PlaceCatalogProvider extends ChangeNotifier {
  PlaceCatalogProvider(this.repository) {
    _changes = repository.catalogChanges.listen((_) {
      loadDefinitions(force: true);
      update(filters);
    });
  }
  final DiscoverRepository repository;
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
    if (searchController.text != value.search) {
      searchController.value = TextEditingValue(
        text: value.search,
        selection: TextSelection.collapsed(offset: value.search.length),
      );
    }
    _debounce?.cancel();
    _revision++;
    // Hide non-matching old markers immediately while the new request is pending.
    places = places.where((p) => filters.matches(p.toOutingPlace())).toList();
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
    final revision = ++_revision;
    final offset = more ? places.length : 0;
    loading = true;
    error = null;
    notifyListeners();
    final result = await repository.queryPlaces(
      filters,
      offset: offset,
      forceRefresh: force,
    );
    if (_disposed || revision != _revision) return;
    result.fold((_) => error = 'catalog_load_failed', (items) {
      final all = {
        for (final p in more ? places : <SuggestedPlace>[]) p.id: p,
        for (final p in items) p.id: p,
      };
      places = all.values.toList();
      hasMore = items.length == 50;
    });
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _changes.cancel();
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }
}
