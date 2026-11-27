import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

class MeetupResultHandoffModel {
  MeetupResultHandoffModel({
    required this.sessionId,
    required this.calculationId,
    required this.groupId,
    required Iterable<Place> places,
  }) : places = List.unmodifiable(places);

  final String sessionId, calculationId;
  final String? groupId;
  final List<Place> places;

  MeetupResultHandoffModel withPlaces(Iterable<Place> places) =>
      MeetupResultHandoffModel(
        sessionId: sessionId,
        calculationId: calculationId,
        groupId: groupId,
        places: places,
      );

  Map<String, Object> toCreateJson() => {
    'session_id': sessionId,
    'calculation_id': calculationId,
    'place_ids': [for (final place in places) place.id],
  };

  Map<String, Object> toDraftJson() => {
    ...toCreateJson(),
    'group_id': ?groupId,
  };

  static MeetupResultHandoffModel? fromDraftJson(
    Object? value,
    List<Place> places,
  ) {
    if (value is! Map ||
        value['session_id'] is! String ||
        value['calculation_id'] is! String ||
        places.isEmpty) {
      return null;
    }
    return MeetupResultHandoffModel(
      sessionId: value['session_id'] as String,
      calculationId: value['calculation_id'] as String,
      groupId: value['group_id'] as String?,
      places: places,
    );
  }
}
