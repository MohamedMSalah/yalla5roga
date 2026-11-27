import 'package:dartz/dartz.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

class DiscoverProvider extends ChangeNotifier {
  DiscoverProvider({required this.repository, this.onSavedPlaceRemoved}) {
    _catalogChanges = repository.catalogChanges.listen((_) {
      if (!_hasLoaded && _loadingPlaces == null) return;
      if (_loadingPlaces != null) {
        _refreshPending = true;
      } else {
        unawaited(load());
      }
    });
  }
  late final StreamSubscription<void> _catalogChanges;
  @override
  void dispose() {
    _catalogChanges.cancel();
    super.dispose();
  }

  final DiscoverRepository repository;
  final ValueChanged<String>? onSavedPlaceRemoved;
  List<SuggestedPlace> savedPlaces = [];
  bool savedLoading = false, savedLoaded = false, savedFailed = false;
  String? savingPlaceId;
  int _savedEpoch = 0;
  Future<void>? _savedRequest;
  bool isPlaceSaved(String id) => savedPlaces.any((p) => p.id == id);
  Future<void> loadSavedPlaces({bool force = false}) {
    if (!force && savedLoaded) return Future<void>.value();
    final epoch = _savedEpoch;
    return _savedRequest ??= _loadSavedPlaces(force).whenComplete(() {
      if (epoch == _savedEpoch) _savedRequest = null;
    });
  }

  Future<void> _loadSavedPlaces(bool force) async {
    final epoch = _savedEpoch;
    savedLoading = true;
    notifyListeners();
    final result = await repository.getSavedPlaces(forceRefresh: force);
    if (epoch != _savedEpoch) return;
    result.fold(
      (_) {
        savedFailed = true;
      },
      (places) {
        savedPlaces = places;
        savedFailed = false;
      },
    );
    savedLoading = false;
    savedLoaded = true;
    notifyListeners();
  }

  Future<bool> toggleSavedPlace(SuggestedPlace place) async {
    if (place.id.startsWith('private:')) return false;
    if (!savedLoaded || savedFailed) return false;
    return _setSavedPlace(
      place.id,
      save: !isPlaceSaved(place.id),
      place: place,
    );
  }

  /// The caller already has an ownership-checked Saved Place reference.
  Future<bool> removeSavedPlace(String id) => _setSavedPlace(id, save: false);

  Future<bool> _setSavedPlace(
    String id, {
    required bool save,
    SuggestedPlace? place,
  }) async {
    if (savingPlaceId != null) return false;
    final epoch = _savedEpoch;
    savingPlaceId = id;
    notifyListeners();
    final result = await repository.setPlaceSaved(id, save);
    if (epoch != _savedEpoch) return false;
    final success = result.isRight();
    if (success) {
      if (!save) onSavedPlaceRemoved?.call(id);
      savedPlaces = [
        if (save && place != null) place,
        ...savedPlaces.where((p) => p.id != id),
      ];
    }
    notifyListeners();
    if (success) {
      await _savedRequest;
      if (epoch != _savedEpoch) return false;
      await loadSavedPlaces(force: true);
    }
    if (epoch != _savedEpoch) return false;
    savingPlaceId = null;
    notifyListeners();
    return success;
  }

  int _filter = 0;
  var _places = <SuggestedPlace>[];
  var _featuredAll = <SuggestedPlace>[];
  var _hasLoaded = false;
  String? _errorMessage;

  Future<Either<Failure, List<SuggestedPlace>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    OutingVibe? vibe,
  }) => repository.getNearbyPlaces(
    latitude: latitude,
    longitude: longitude,
    vibe: vibe,
  );

  int get filter => _filter;

  OutingVibe? get vibe => switch (_filter) {
    1 => OutingVibe.food,
    2 => OutingVibe.activity,
    3 => OutingVibe.outdoor,
    4 => OutingVibe.movie,
    _ => null,
  };

  List<SuggestedPlace> get places => List.unmodifiable(_places);

  List<SuggestedPlace> get featured => [
    for (final place in _featuredAll)
      if (vibe == null || place.vibe == vibe) place,
  ];

  List<SuggestedPlace> get featuredPlaces => featured;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  /// Places available for pickers — from the API cache, with image + vibe.
  List<Place> catalogPlaces() {
    final byId = <String, Place>{};
    for (final place in [..._featuredAll, ..._places]) {
      byId[place.id] = place.toOutingPlace();
    }
    if (byId.isNotEmpty) return byId.values.toList(growable: false);
    return repository.catalogPlaces();
  }

  SuggestedPlace? findById(String id) {
    for (final place in _places) {
      if (place.id == id) return place;
    }
    for (final place in _featuredAll) {
      if (place.id == id) return place;
    }
    return null;
  }

  SuggestedPlace placeById(String id) {
    return findById(id) ??
        (_places.isNotEmpty
            ? _places.first
            : SuggestedPlace(
                id: id,
                name: '',
                area: '',
                vibe: OutingVibe.food,
                coverImageUrl: '',
              ));
  }

  Future<void>? _loadingPlaces;
  bool _refreshPending = false;
  Future<void> load({bool forceRefresh = false}) =>
      _loadingPlaces ??= _loadPlaces(forceRefresh).whenComplete(() {
        _loadingPlaces = null;
        if (_refreshPending) {
          _refreshPending = false;
          unawaited(load());
        }
      });

  Future<void> _loadPlaces(bool forceRefresh) async {
    final featuredFuture = repository.getFeaturedPlaces(
      forceRefresh: forceRefresh,
    );
    final placesFuture = repository.getPlaces(
      vibe: vibe,
      forceRefresh: forceRefresh,
    );
    final featured = await featuredFuture;
    final places = await placesFuture;

    featured.fold((failure) {
      _errorMessage = AppErrorFeedback.messageOf(failure);
      AppErrorFeedback.report(
        failure,
        kind: AppErrorKind.load,
        context: 'discoverFeatured',
      );
    }, (items) => _featuredAll = List.of(items));

    places.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'discoverPlaces',
        );
      },
      (items) {
        _places = List.of(items);
        _errorMessage = null;
      },
    );

    _hasLoaded = true;
    notifyListeners();
  }

  void clear() {
    _savedEpoch++;
    _savedRequest = null;
    savedPlaces = [];
    savedLoading = false;
    savedLoaded = false;
    savedFailed = false;
    savingPlaceId = null;
    repository.clearCache();
    _filter = 0;
    _places = [];
    _featuredAll = [];
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> setFilter(int value) async {
    if (_filter == value) return;
    _filter = value;
    await _reloadPlaces();
  }

  Future<void> _reloadPlaces({
    bool notify = true,
    bool forceRefresh = false,
  }) async {
    final result = await repository.getPlaces(
      vibe: vibe,
      forceRefresh: forceRefresh,
    );
    result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.load,
          context: 'discoverPlaces',
        );
      },
      (items) {
        _places = List.of(items);
        _errorMessage = null;
      },
    );
    if (notify) notifyListeners();
  }
}
