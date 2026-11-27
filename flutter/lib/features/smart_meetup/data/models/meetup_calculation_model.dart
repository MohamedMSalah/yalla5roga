import '../../domain/entities/meetup_results.dart';

abstract final class MeetupCalculationModel {
  static MeetupCalculation fromJson(Map<String, dynamic> json) {
    final calculatedAt = json['calculatedAt'] as String?;
    final expiresAt = json['expiresAt'] as String?;
    return MeetupCalculation(
      id: json['id'] as String,
      inputVersion: json['inputVersion'] as int,
      attempt: json['attempt'] as int? ?? 1,
      optimizationPolicyVersion: json['optimizationPolicyVersion'] as String,
      calculatedAt: calculatedAt == null ? null : DateTime.parse(calculatedAt),
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt),
      safeFailureCode: json['safeFailureCode'] as String?,
    );
  }
}
