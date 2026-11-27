import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';

import 'meetup_preferences.dart';
import 'meetup_session.dart';

class MeetupCalculation {
  const MeetupCalculation({
    required this.id,
    required this.inputVersion,
    required this.optimizationPolicyVersion,
    this.attempt = 1,
    this.calculatedAt,
    this.expiresAt,
    this.safeFailureCode,
  });

  final String id, optimizationPolicyVersion;
  final int inputVersion, attempt;
  final DateTime? calculatedAt, expiresAt;
  final String? safeFailureCode;
}

class MeetupRecommendation {
  const MeetupRecommendation({
    required this.place,
    required this.rank,
    required this.ratingCount,
    required this.budgetLevel,
    required this.explanationCodes,
    this.averageRating,
    this.averageDurationMinutes,
    this.matchScore,
  });

  final SuggestedPlace place;
  final int rank, ratingCount;
  final BudgetLevel budgetLevel;
  final List<String> explanationCodes;
  final double? averageRating, matchScore;
  final int? averageDurationMinutes;
}

class MeetupResults {
  const MeetupResults({
    required this.status,
    required this.inputVersion,
    required this.intendedParticipantCount,
    required this.includedParticipantCount,
    required this.unavailableParticipantCount,
    required this.isPartial,
    required this.preferences,
    required this.calculation,
    required this.recommendations,
    this.sessionStatus = MeetupSessionStatus.active,
  });

  final MeetupCalculationStatus status;
  final MeetupSessionStatus sessionStatus;
  final int inputVersion, intendedParticipantCount, includedParticipantCount;
  final int unavailableParticipantCount;
  final bool isPartial;
  final MeetupPreferences preferences;
  final MeetupCalculation? calculation;
  final List<MeetupRecommendation> recommendations;

  bool get hasPublishedRecommendations =>
      status == MeetupCalculationStatus.ready ||
      status == MeetupCalculationStatus.partial;

  bool get canConsume {
    final current = calculation;
    return sessionStatus == MeetupSessionStatus.active &&
        hasPublishedRecommendations &&
        recommendations.isNotEmpty &&
        current != null &&
        current.inputVersion == inputVersion &&
        current.calculatedAt != null &&
        (current.expiresAt?.isAfter(DateTime.now()) ?? false);
  }
}
