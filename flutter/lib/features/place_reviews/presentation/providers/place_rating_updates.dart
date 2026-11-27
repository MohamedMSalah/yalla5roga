import 'package:flutter/foundation.dart';

import '../../domain/entities/place_rating_statistics.dart';

/// Keeps currently mounted cards in sync with responses acknowledged by the API.
class PlaceRatingUpdates extends ChangeNotifier {
  PlaceRatingUpdates(this.onChanged);

  final void Function(String, PlaceRatingStatistics) onChanged;

  void changed(String placeId, PlaceRatingStatistics value) {
    accept(placeId, value);
    onChanged(placeId, value);
  }

  final _latest = <String, PlaceRatingStatistics>{};

  PlaceRatingStatistics? forPlace(String id, PlaceRatingStatistics? snapshot) {
    final latest = _latest[id];
    return latest != null && latest.isNewerThan(snapshot) ? latest : snapshot;
  }

  void accept(String id, PlaceRatingStatistics statistics) {
    if (!statistics.isNewerThan(_latest[id])) return;
    _latest.remove(id);
    _latest[id] = statistics;
    if (_latest.length > 256) _latest.remove(_latest.keys.first);
    notifyListeners();
  }

  void clear() {
    if (_latest.isEmpty) return;
    _latest.clear();
    notifyListeners();
  }
}
