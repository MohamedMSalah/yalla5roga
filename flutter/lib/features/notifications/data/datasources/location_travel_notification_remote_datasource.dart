import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

class LocationTravelNotificationRemoteDataSource {
  const LocationTravelNotificationRemoteDataSource(this._api);
  final ApiClient _api;

  Options _bound(String account) =>
      Options(extra: {expectedUserIdKey: account});

  Future<Map<String, dynamic>> requestLocation(
    String account,
    String sessionId,
    String target,
  ) async => _payload(
    await _api.post<Map<String, dynamic>>(
      ApiConstants.meetupLocationRequests(sessionId),
      data: {'target_user_id': target},
      options: _bound(account),
    ),
  );

  Future<Map<String, dynamic>> preferences(String account) async => _payload(
    await _api.get<Map<String, dynamic>>(
      ApiConstants.departureReminderPreferences,
      options: _bound(account),
    ),
  );

  Future<Map<String, dynamic>> updatePreferences(
    String account, {
    bool? enabled,
    int? bufferMinutes,
  }) async => _payload(
    await _api.patch<Map<String, dynamic>>(
      ApiConstants.departureReminderPreferences,
      data: <String, dynamic>{
        'enabled': ?enabled,
        'preparation_buffer_minutes': ?bufferMinutes,
      },
      options: _bound(account),
    ),
  );

  Future<Map<String, dynamic>> departureReminder(
    String account,
    String outingId,
    bool schedule,
  ) async {
    final path = ApiConstants.myDepartureReminder(outingId);
    final options = _bound(account);
    return _payload(
      schedule
          ? await _api.put<Map<String, dynamic>>(path, options: options)
          : await _api.get<Map<String, dynamic>>(path, options: options),
    );
  }

  Future<void> clearDepartureReminder(String account, String outingId) async {
    await _api.delete<Map<String, dynamic>>(
      ApiConstants.myDepartureReminder(outingId),
      options: _bound(account),
    );
  }

  Map<String, dynamic> _payload(Response<Map<String, dynamic>> response) =>
      apiPayload(response.data);
}
