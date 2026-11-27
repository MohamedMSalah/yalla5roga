enum TravelFairnessMode { balanced, equalTravel, fastestOverall }

enum BudgetLevel { affordable, moderate, expensive, unknown }

enum OptimizationPriority { topRated, budgetFriendly, shortestDistance }

class MeetupPreferences {
  const MeetupPreferences({
    this.categoryIds = const {},
    this.budgetLevels = const {},
    this.minimumRating,
    this.travelFairnessMode = TravelFairnessMode.balanced,
    this.maximumTravelDurationSeconds,
    this.additionalPriorities = const {},
    this.plannedMeetupAt,
    this.requireOpenAtMeetupTime = false,
  });

  static const selectableBudgets = [
    BudgetLevel.affordable,
    BudgetLevel.moderate,
    BudgetLevel.expensive,
  ];
  static const minimumRatings = <double?>[null, 3, 4, 4.5];
  static const maximumTravelDurations = <int?>[
    null,
    900,
    1800,
    2700,
    3600,
    5400,
  ];

  final Set<String> categoryIds;
  final Set<BudgetLevel> budgetLevels;
  final double? minimumRating;
  final TravelFairnessMode travelFairnessMode;
  final int? maximumTravelDurationSeconds;
  final Set<OptimizationPriority> additionalPriorities;
  final DateTime? plannedMeetupAt;
  final bool requireOpenAtMeetupTime;

  static const _unchanged = Object();

  MeetupPreferences copyWith({
    Set<String>? categoryIds,
    Set<BudgetLevel>? budgetLevels,
    Object? minimumRating = _unchanged,
    TravelFairnessMode? travelFairnessMode,
    Object? maximumTravelDurationSeconds = _unchanged,
    Set<OptimizationPriority>? additionalPriorities,
  }) => MeetupPreferences(
    categoryIds: categoryIds ?? this.categoryIds,
    budgetLevels: budgetLevels ?? this.budgetLevels,
    minimumRating: identical(minimumRating, _unchanged)
        ? this.minimumRating
        : minimumRating as double?,
    travelFairnessMode: travelFairnessMode ?? this.travelFairnessMode,
    maximumTravelDurationSeconds:
        identical(maximumTravelDurationSeconds, _unchanged)
        ? this.maximumTravelDurationSeconds
        : maximumTravelDurationSeconds as int?,
    additionalPriorities: additionalPriorities ?? this.additionalPriorities,
    plannedMeetupAt: plannedMeetupAt,
    requireOpenAtMeetupTime: requireOpenAtMeetupTime,
  );
}

class MeetupCategoryOption {
  const MeetupCategoryOption(this.id, this.nameEn, this.nameAr);

  final String id;
  final String nameEn;
  final String nameAr;

  String label(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}
