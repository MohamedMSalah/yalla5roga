import 'package:yalla_5roga/features/transportation/data/models/transportation_preference_model.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../../domain/entities/meetup_session.dart';
import '../../domain/entities/standalone_participant.dart';
import 'meetup_preferences_model.dart';

abstract final class MeetupSessionModel {
  static MeetupSession fromJson(Map<String, dynamic> json) {
    final readiness = json['readiness'] as Map<String, dynamic>?;
    final preferences = json['preferences'] as Map<String, dynamic>?;
    return MeetupSession(
      id: json['id'] as String,
      status: _parse(MeetupSessionStatus.values, json['status']),
      calculation: _parse(
        MeetupCalculationStatus.values,
        json['calculation_status'],
      ),
      preferences: preferences != null
          ? MeetupPreferencesModel.fromJson(preferences)
          : MeetupPreferences(
              travelFairnessMode: json['optimization'] == 'SHORTEST_TOTAL_TIME'
                  ? TravelFairnessMode.fastestOverall
                  : TravelFairnessMode.balanced,
            ),
      inputVersion: json['input_version'] as int,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      canManage: json['can_manage'] as bool,
      readiness: readiness == null ? null : _readiness(readiness),
      manualParticipantLimit: json['manual_participant_limit'] as int? ?? 0,
      standaloneParticipants: List.unmodifiable(
        (json['standalone_participants'] as List<dynamic>? ?? const []).map((
          item,
        ) {
          final participant = item as Map<String, dynamic>;
          return StandaloneParticipant(
            id: participant['id'] as String,
            isOwner: participant['participant_type'] == 'OWNER',
            displayName: participant['display_name'] as String?,
            approximateArea: participant['approximate_area'] as String?,
            latitude: (participant['latitude'] as num?)?.toDouble(),
            longitude: (participant['longitude'] as num?)?.toDouble(),
            transportation: TransportationPreferenceModel.modeFromJson(
              participant['transportation_mode'],
            ),
          );
        }),
      ),
    );
  }

  static Map<String, dynamic> participantToJson(ManualParticipantDraft draft) =>
      {
        'display_name': draft.displayName,
        'approximate_area': draft.approximateArea,
        'latitude': draft.latitude,
        'longitude': draft.longitude,
        'transportation_mode': draft.transportation?.code,
      };

  static MeetupReadinessSummary _readiness(Map<String, dynamic> json) =>
      MeetupReadinessSummary(
        intended: json['intended'] as int,
        usable: json['usable'] as int,
        requiringSetup: json['requiring_setup'] as int,
        status: _parse(MeetupReadinessStatus.values, json['status']),
        participants: List.unmodifiable(
          (json['participants'] as List<dynamic>).map((item) {
            final member = item as Map<String, dynamic>;
            return MeetupParticipantReadiness(
              name: member['display_name'] as String,
              isSelf: member['is_self'] as bool,
              ready: member['status'] == 'READY',
              district: member['district'] as String?,
              requestTargetUserId: member['request_target_user_id'] as String?,
            );
          }),
        ),
      );

  static T _parse<T extends Enum>(List<T> values, Object? raw) => values
      .firstWhere((value) => MeetupPreferencesModel.enumToApi(value) == raw);
}
