import '../../domain/entities/meetup_preferences.dart';

abstract final class MeetupPreferencesModel {
  static MeetupPreferences fromJson(Map<String, dynamic> json) {
    final time = json['plannedMeetupAt'] as String?;
    return MeetupPreferences(
      categoryIds: Set.unmodifiable(
        (json['categoryIds'] as List).cast<String>(),
      ),
      budgetLevels: Set.unmodifiable(
        (json['budgetLevels'] as List).map(
          (value) => _parse(BudgetLevel.values, value),
        ),
      ),
      minimumRating: (json['minimumRating'] as num?)?.toDouble(),
      travelFairnessMode: _parse(
        TravelFairnessMode.values,
        json['travelFairnessMode'],
      ),
      maximumTravelDurationSeconds:
          json['maximumTravelDurationSeconds'] as int?,
      additionalPriorities: Set.unmodifiable(
        (json['additionalPriorities'] as List).map(
          (value) => _parse(OptimizationPriority.values, value),
        ),
      ),
      plannedMeetupAt: time == null ? null : DateTime.parse(time),
      requireOpenAtMeetupTime: json['requireOpenAtMeetupTime'] as bool,
    );
  }

  static Map<String, dynamic> toJson(MeetupPreferences preferences) => {
    'categoryIds': preferences.categoryIds.toList(),
    'budgetLevels': preferences.budgetLevels.map(enumToApi).toList(),
    'minimumRating': preferences.minimumRating,
    'travelFairnessMode': enumToApi(preferences.travelFairnessMode),
    'maximumTravelDurationSeconds': preferences.maximumTravelDurationSeconds,
    'additionalPriorities': preferences.additionalPriorities
        .map(enumToApi)
        .toList(),
    'plannedMeetupAt': preferences.plannedMeetupAt?.toUtc().toIso8601String(),
    'requireOpenAtMeetupTime': preferences.requireOpenAtMeetupTime,
  };

  static List<MeetupCategoryOption> readCategories(Map<String, dynamic> json) =>
      List.unmodifiable(
        (json['categories'] as List).map((item) {
          final category = item as Map<String, dynamic>;
          return MeetupCategoryOption(
            category['id'] as String,
            category['name_en'] as String,
            category['name_ar'] as String,
          );
        }),
      );

  static String enumToApi(Enum value) => value.name
      .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match[0]}')
      .toUpperCase();

  static T _parse<T extends Enum>(List<T> values, Object? raw) =>
      values.firstWhere((value) => enumToApi(value) == raw);
}
