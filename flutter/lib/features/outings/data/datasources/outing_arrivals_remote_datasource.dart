import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_arrival.dart';

class OutingArrivalsRemoteDataSource {
  const OutingArrivalsRemoteDataSource(this._client);

  final ApiClient _client;

  Future<OutingArrivalRoster> list(String outingId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.outingArrivals(outingId),
    );
    final data = apiPayload(response.data);
    final venue = data['venue'];
    final latitude = venue is Map ? venue['latitude'] : null;
    final longitude = venue is Map ? venue['longitude'] : null;
    return OutingArrivalRoster(
      arrivals: [
        for (final row in apiObjectList(data['arrivals']))
          if (DateTime.tryParse(apiString(row['arrived_at']) ?? '')
              case final time?)
            OutingArrival(
              userId: apiString(row['user_id']) ?? '',
              name: apiString(row['name']) ?? '',
              arrivedAt: time.toLocal(),
              method: apiString(row['verification_method']) ?? 'legacy',
            ),
      ],
      unconfirmed: [
        for (final row in apiObjectList(data['unconfirmed']))
          if (apiString(row['id']) case final id?)
            (id: id, name: apiString(row['name']) ?? ''),
      ],
      open: data['open'] == true,
      closesAt: DateTime.tryParse(apiString(data['closes_at']) ?? ''),
      radiusMeters: (data['radius_meters'] as num?)?.toDouble() ?? 100,
      opensAt: DateTime.tryParse(apiString(data['opens_at']) ?? ''),
      maxAccuracyMeters:
          (data['max_accuracy_meters'] as num?)?.toDouble() ?? 50,
      venue: latitude is num && longitude is num
          ? (latitude: latitude.toDouble(), longitude: longitude.toDouble())
          : null,
    );
  }

  Future<bool> record(
    String outingId, {
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime capturedAt,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '${ApiConstants.outingArrivals(outingId)}/self',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'method': 'gps',
      },
    );
    return apiPayload(response.data)['arrived'] == true;
  }
}
