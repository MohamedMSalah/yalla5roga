import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

/// Active place suggestion on a group.
class GroupPlaceSuggestion {
  const GroupPlaceSuggestion({
    required this.id,
    required this.groupId,
    required this.title,
    required this.places,
    required this.deadlineHours,
    required this.createdBy,
    required this.outingId,
  });

  final String id;
  final String groupId;
  final String title;
  final List<Place> places;
  final int deadlineHours;
  final String createdBy;
  final String outingId;
}
