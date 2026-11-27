import 'package:yalla_5roga/features/discover/data/models/suggested_place_model.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../../domain/entities/meetup_results.dart';
import 'meetup_preferences_model.dart';

abstract final class MeetupRecommendationModel {
  static MeetupRecommendation fromJson(Map<String, dynamic> json) {
    final place = SuggestedPlaceModel.fromJson(
      json['place'] as Map<String, dynamic>,
    );
    final rank = json['rank'] as int;
    if (place.id.isEmpty ||
        place.id != json['placeId'] ||
        rank < 1 ||
        rank > 5) {
      throw const FormatException('Invalid ranked meetup place');
    }
    // A later privacy policy may explicitly release these public fields.
    final statistics = json['travelStatistics'] as Map<String, dynamic>?;
    final minutes = statistics?['averageDurationMinutes'] as int?;
    final match = (json['matchScore'] as num?)?.toDouble();
    return MeetupRecommendation(
      place: place,
      rank: rank,
      ratingCount: json['ratingCount'] as int,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      budgetLevel: BudgetLevel.values.firstWhere(
        (level) =>
            MeetupPreferencesModel.enumToApi(level) == json['budgetLevel'],
      ),
      explanationCodes: List.unmodifiable(
        (json['explanationCodes'] as List).cast<String>(),
      ),
      averageDurationMinutes: minutes != null && minutes > 0 ? minutes : null,
      matchScore: match != null && match.isFinite && match >= 0 && match <= 100
          ? match
          : null,
    );
  }
}
