import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

enum YallaMapSelectionMode { browse, single, multiple }

/// Highlighting is separate from committing the route's ordered venue selection.
class YallaMapPlaceSelection {
  const YallaMapPlaceSelection({
    this.mode = YallaMapSelectionMode.browse,
    this.focusedId,
    this.selected = const [],
  });
  final YallaMapSelectionMode mode;
  final String? focusedId;
  final List<Place> selected;
  bool contains(Place place) => selected.any(place.matchesSelection);
}
