import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

class DiscoverProvider extends ChangeNotifier {
  DiscoverProvider({required this.repository});

  final DiscoverRepository repository;

  int _filter = 0;
  var _places = <SuggestedPlace>[];
  var _featuredAll = <SuggestedPlace>[];
  var _hasLoaded = false;
  String? _errorMessage;

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

  Future<void> load({bool forceRefresh = false}) async {
    final featured = await repository.getFeaturedPlaces(
      forceRefresh: forceRefresh,
    );
    featured.fold((failure) {
      _errorMessage = failure.message;
      AppErrorFeedback.report(
        failure,
        kind: AppErrorKind.load,
        context: 'discoverFeatured',
      );
    }, (items) => _featuredAll = List.of(items));
    await _reloadPlaces(notify: false, forceRefresh: forceRefresh);
    _hasLoaded = true;
    notifyListeners();
  }

  void clear() {
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
        _errorMessage = failure.message;
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
