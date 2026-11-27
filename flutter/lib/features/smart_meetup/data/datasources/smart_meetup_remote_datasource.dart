import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../../domain/entities/meetup_results.dart';
import '../../domain/entities/meetup_session.dart';
import '../../domain/entities/standalone_participant.dart';
import '../models/meetup_preferences_model.dart';
import '../models/meetup_results_model.dart';
import '../models/meetup_session_model.dart';

class SmartMeetupRemoteDataSource {
  const SmartMeetupRemoteDataSource(this._api);
  final ApiClient _api;

  Options _bound(String account) =>
      Options(extra: {expectedUserIdKey: account});

  Future<MeetupResults> results(
    String account,
    String id, {
    String? calculationId,
  }) async => MeetupResultsModel.fromJson(
    await _payload(
      _api.get<Map<String, dynamic>>(
        calculationId == null
            ? ApiConstants.meetupResults(id)
            : ApiConstants.meetupCalculation(id, calculationId),
        options: _bound(account),
      ),
    ),
  );

  Future<MeetupResults> calculate(String account, String id) async =>
      MeetupResultsModel.fromJson(
        await _payload(
          _api.post<Map<String, dynamic>>(
            ApiConstants.calculateMeetup(id),
            data: const <String, dynamic>{},
            options: _bound(account),
          ),
        ),
      );

  Future<MeetupSession> open(String account, String groupId) => _decode(
    _api.post<Map<String, dynamic>>(
      ApiConstants.groupSmartMeetup(groupId),
      data: const <String, dynamic>{},
      options: _bound(account),
    ),
  );

  Future<MeetupSession> refresh(String account, String id) => _decode(
    _api.get<Map<String, dynamic>>(
      ApiConstants.smartMeetup(id),
      options: _bound(account),
    ),
  );

  Future<MeetupSession> openStandalone(String account) => _decode(
    _api.post<Map<String, dynamic>>(
      ApiConstants.standaloneMeetup,
      data: const <String, dynamic>{},
      options: _bound(account),
    ),
  );

  Future<MeetupSession> saveParticipant(
    String account,
    String id,
    ManualParticipantDraft draft, {
    String? participantId,
  }) {
    final body = MeetupSessionModel.participantToJson(draft);
    final options = _bound(account);
    return _decode(
      participantId == null
          ? _api.post<Map<String, dynamic>>(
              ApiConstants.meetupParticipants(id),
              data: body,
              options: options,
            )
          : _api.patch<Map<String, dynamic>>(
              ApiConstants.meetupParticipant(id, participantId),
              data: body,
              options: options,
            ),
    );
  }

  Future<MeetupSession> removeParticipant(
    String account,
    String id,
    String participantId,
  ) => _decode(
    _api.delete<Map<String, dynamic>>(
      ApiConstants.meetupParticipant(id, participantId),
      options: _bound(account),
    ),
  );

  Future<MeetupSession> update(
    String account,
    String id,
    MeetupPreferences preferences,
  ) => _decode(
    _api.put<Map<String, dynamic>>(
      ApiConstants.meetupPreferences(id),
      data: MeetupPreferencesModel.toJson(preferences),
      options: _bound(account),
    ),
  );

  Future<MeetupSession> resetPreferences(String account, String id) => _decode(
    _api.post<Map<String, dynamic>>(
      ApiConstants.resetMeetupPreferences(id),
      data: const <String, dynamic>{},
      options: _bound(account),
    ),
  );

  Future<List<MeetupCategoryOption>> filterOptions(String account) async =>
      MeetupPreferencesModel.readCategories(
        await _payload(
          _api.get<Map<String, dynamic>>(
            ApiConstants.meetupFilterOptions,
            options: _bound(account),
          ),
        ),
      );

  Future<MeetupSession> cancel(String account, String id) => _decode(
    _api.delete<Map<String, dynamic>>(
      ApiConstants.smartMeetup(id),
      options: _bound(account),
    ),
  );

  Future<MeetupSession> _decode(
    Future<Response<Map<String, dynamic>>> request,
  ) async => MeetupSessionModel.fromJson(await _payload(request));

  Future<Map<String, dynamic>> _payload(
    Future<Response<Map<String, dynamic>>> request,
  ) async {
    final payload = (await request).data;
    if (payload == null || payload['success'] != true) {
      throw const FormatException('Invalid Smart Meetup response');
    }
    return payload['data'] as Map<String, dynamic>;
  }
}
