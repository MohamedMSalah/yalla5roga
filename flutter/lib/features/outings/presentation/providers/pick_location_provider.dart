import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';

class PickLocationProvider extends ChangeNotifier {
  PickLocationProvider({
    required this.geocoding,
    required this.catalog,
    required this.language,
    required this.maxSelections,
    this.location = const MapLocation(),
    Place? initial,
    List<Place> selected = const [],
  }) : _candidate = initial,
       _selected = List.unmodifiable(selected),
       nameController = TextEditingController(text: initial?.name);

  final LocationRepository geocoding;
  final List<Place> catalog;
  final String language;
  final int maxSelections;
  final MapLocation location;
  final TextEditingController nameController;

  Place? _candidate;
  Place? get candidate => _candidate;
  List<Place> _selected;
  List<Place> get selected => _selected;
  bool get multiple => maxSelections > 1;
  bool moving = false;
  bool locating = false;
  bool lookingUp = false;
  bool lookupFailed = false;
  bool searchFailed = false;
  bool searching = false;
  bool providerAvailable = true;
  String? attribution;
  List<Place> results = const [];
  bool _disposed = false;
  int _pointRevision = 0;
  String _query = '';
  Timer? _debounce;
  Completer<void>? _search;
  Completer<void>? _reverse;
  final _cache = <String, ({DateTime expires, LocationLookup value})>{};

  bool get duplicate =>
      _candidate != null && _selected.any(_candidate!.matchesSelection);
  bool get canUseCandidate =>
      !moving &&
      (_candidate?.name.trim().isNotEmpty ?? false) &&
      (!multiple || (_selected.length < maxSelections && !duplicate));

  void startMoving() {
    _cancelReverse();
    moving = true;
    notifyListeners();
  }

  void choose(Place place) {
    _cancelReverse();
    _setCandidate(place);
    notifyListeners();
  }

  void _setCandidate(Place place) {
    _candidate = place;
    nameController.text = place.name;
    moving = false;
    lookupFailed = false;
  }

  void rename(String value) {
    final candidate = _candidate;
    if (candidate == null || candidate.id.isNotEmpty) return;
    if (lookingUp) _cancelReverse();
    _candidate = candidate.copyWith(name: _limit(value.trim()));
    notifyListeners();
  }

  void _cancelReverse() {
    _pointRevision++;
    _reverse?.complete();
    _reverse = null;
    lookingUp = false;
  }

  Future<void> pin(LatLng point, String fallback) async {
    _cancelReverse();
    final longitude = (point.longitude + 540) % 360 - 180;
    _setCandidate(
      Place(
        name: fallback,
        area: '',
        latitude: point.latitude,
        longitude: longitude,
      ),
    );
    if (!providerAvailable) {
      notifyListeners();
      return;
    }

    final request = _reverse = Completer<void>();
    lookingUp = true;
    notifyListeners();
    final key = 'r:$language:${point.latitude}:$longitude';
    try {
      final result =
          _cached(key) ??
          await geocoding.reverseGeocode(
            latitude: point.latitude,
            longitude: longitude,
            language: language,
            cancelled: request.future,
          );
      if (_reverse != request) return;
      _record(key, result);
      final hit = result.hits.firstOrNull;
      if (hit != null) {
        _setCandidate(
          Place(
            name: _limit(hit.name),
            area: _limit(hit.area),
            latitude: point.latitude,
            longitude: longitude,
          ),
        );
      }
    } catch (_) {
      if (_reverse == request) lookupFailed = true;
    } finally {
      if (_reverse == request) {
        _reverse = null;
        lookingUp = false;
        notifyListeners();
      }
    }
  }

  Future<({LatLng? point, MapLocationIssue? issue})> locate() async {
    if (locating) return (point: null, issue: null);
    final revision = _pointRevision;
    locating = true;
    notifyListeners();
    final result = await location.locate(requestPermission: true);
    if (_disposed) return (point: null, issue: null);
    locating = false;
    notifyListeners();
    return revision == _pointRevision ? result : (point: null, issue: null);
  }

  void search(String input, {bool retry = false}) {
    final query = input.trim().toLowerCase();
    if (!retry && query == _query) return;
    _query = query;
    _debounce?.cancel();
    _search?.complete();
    _search = null;
    final local = query.isEmpty
        ? const <Place>[]
        : [
            for (final place in catalog)
              if ('${place.name} ${place.area}'.toLowerCase().contains(query))
                place,
          ].take(12).toList();
    results = local;
    searchFailed = false;
    searching = query.length >= 2 && query.length <= 120 && providerAvailable;
    if (searching) {
      final request = _search = Completer<void>();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        unawaited(_searchRemote(input.trim(), local, request));
      });
    }
    notifyListeners();
  }

  Future<void> _searchRemote(
    String input,
    List<Place> local,
    Completer<void> request,
  ) async {
    final key = 's:$language:$_query';
    try {
      final result =
          _cached(key) ??
          await geocoding.search(
            input,
            language: language,
            cancelled: request.future,
          );
      if (_search != request) return;
      _record(key, result);
      final combined = [...local];
      for (final hit in result.hits) {
        final place = Place(
          sourceId: hit.id,
          name: _limit(hit.name),
          area: _limit(hit.area),
          latitude: hit.latitude,
          longitude: hit.longitude,
        );
        if (!combined.any(place.matchesSelection)) combined.add(place);
      }
      results = combined;
    } catch (_) {
      if (_search == request) searchFailed = true;
    } finally {
      if (_search == request) {
        _search = null;
        searching = false;
        notifyListeners();
      }
    }
  }

  LocationLookup? _cached(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.expires.isAfter(DateTime.now())) return entry.value;
    _cache.remove(key);
    return null;
  }

  void _record(String key, LocationLookup value) {
    providerAvailable = value.available;
    attribution = value.attribution ?? attribution;
    if (!value.available || value.cacheSeconds == 0) return;
    if (_cache.length >= 32) _cache.remove(_cache.keys.first);
    _cache[key] = (
      expires: DateTime.now().add(Duration(seconds: value.cacheSeconds)),
      value: value,
    );
  }

  static String _limit(String value) {
    if (value.length <= 100) return value;
    var end = 100;
    final last = value.codeUnitAt(end - 1);
    if (last >= 0xd800 && last <= 0xdbff) end--;
    return value.substring(0, end).trimRight();
  }

  bool add() {
    if (!multiple || !canUseCandidate) return false;
    _cancelReverse();
    _selected = List.unmodifiable([..._selected, _candidate!]);
    _candidate = null;
    nameController.clear();
    notifyListeners();
    return true;
  }

  void remove(int index) {
    _selected = List.unmodifiable([..._selected]..removeAt(index));
    notifyListeners();
  }

  void move(int from, int to) {
    if (to < 0 || to >= _selected.length || from == to) return;
    final items = [..._selected];
    items.insert(to, items.removeAt(from));
    _selected = List.unmodifiable(items);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _search?.complete();
    _search = null;
    _cancelReverse();
    nameController.dispose();
    super.dispose();
  }
}
