import '../../domain/entities/meetup_results.dart';
import '../../domain/entities/meetup_session.dart';
import 'meetup_calculation_model.dart';
import 'meetup_preferences_model.dart';
import 'meetup_recommendation_model.dart';

abstract final class MeetupResultsModel {
  static MeetupResults fromJson(Map<String, dynamic> json) {
    final calculation = json['calculation'] as Map<String, dynamic>?;
    final status = MeetupCalculationStatus.values.firstWhere(
      (value) => MeetupPreferencesModel.enumToApi(value) == json['status'],
    );
    final ranked =
        (json['recommendations'] as List)
            .map(
              (row) => MeetupRecommendationModel.fromJson(
                row as Map<String, dynamic>,
              ),
            )
            .toList()
          ..sort((a, b) => a.rank.compareTo(b.rank));
    if (ranked.length > 5 ||
        ranked.map((row) => row.place.id).toSet().length != ranked.length ||
        ranked.indexed.any((entry) => entry.$2.rank != entry.$1 + 1)) {
      throw const FormatException('Invalid meetup recommendations');
    }
    return MeetupResults(
      status: status,
      sessionStatus: MeetupSessionStatus.values.firstWhere(
        (value) =>
            MeetupPreferencesModel.enumToApi(value) == json['sessionStatus'],
        orElse: () => MeetupSessionStatus.active,
      ),
      inputVersion: json['inputVersion'] as int,
      intendedParticipantCount: json['intendedParticipantCount'] as int,
      includedParticipantCount: json['includedParticipantCount'] as int,
      unavailableParticipantCount: json['unavailableParticipantCount'] as int,
      isPartial: json['isPartial'] as bool,
      preferences: MeetupPreferencesModel.fromJson(
        json['preferences'] as Map<String, dynamic>,
      ),
      calculation: calculation == null
          ? null
          : MeetupCalculationModel.fromJson(calculation),
      recommendations: List.unmodifiable(ranked),
    );
  }
}
