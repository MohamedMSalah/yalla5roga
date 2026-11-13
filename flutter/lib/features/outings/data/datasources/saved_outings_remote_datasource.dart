import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/core/utils/remote_image_url.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';

class SavedOutingsRemoteDataSource {
  SavedOutingsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<OutingDraft>> getDrafts() async {
    final response = await _api.get(ApiConstants.outingDrafts);
    return [for (final row in apiObjectList(response.data)) _draft(row)];
  }

  Future<OutingDraft> createDraft(OutingDraft draft) async {
    final response = await _api.post(
      ApiConstants.outingDrafts,
      data: _draftBody(draft),
      options: Options(headers: {'Idempotency-Key': draft.id}),
    );
    return _draft(apiPayload(response.data));
  }

  Future<OutingDraft> updateDraft(OutingDraft draft) async {
    final response = await _api.patch(
      ApiConstants.outingDraft(draft.id),
      data: _draftBody(draft),
      options: Options(headers: {'If-Match': draft.remoteVersion}),
    );
    return _draft(apiPayload(response.data));
  }

  Future<void> deleteDraft(OutingDraft draft) async {
    await _api.delete(
      ApiConstants.outingDraft(draft.id),
      options: Options(
        headers: {
          if (draft.remoteVersion != null) 'If-Match': draft.remoteVersion,
        },
      ),
    );
  }

  bool sameDraft(OutingDraft a, OutingDraft b) =>
      jsonEncode(_draftBody(a)) == jsonEncode(_draftBody(b));

  Map<String, dynamic> _draftBody(OutingDraft draft) => {
    'title': draft.title,
    'image_url': remoteImageUrlOrNull(draft.image) ?? '',
    'group_id': draft.groupId,
    'occasion': draft.occasion.name,
    'special_event': draft.specialEvent,
    'vibe': OutingVibe
        .values[draft.vibe.clamp(0, OutingVibe.values.length - 1)]
        .name,
    'scheduled_date':
        '${draft.date.year.toString().padLeft(4, '0')}-${draft.date.month.toString().padLeft(2, '0')}-${draft.date.day.toString().padLeft(2, '0')}T00:00:00.000Z',
    'scheduled_hour': draft.hour,
    'scheduled_minute': draft.minute,
    'location_name': draft.location.name,
    'location_area': draft.location.area,
    'location_latitude': draft.location.latitude,
    'location_longitude': draft.location.longitude,
    'let_vote': draft.letVote,
    'vote_deadline_hours': draft.voteDeadlineHours,
    'guest_ids': draft.guestIds,
    'selected_places': [for (final p in draft.selectedPlaces) p.toJson()],
  };

  OutingDraft _draft(Map<String, dynamic> row) => OutingDraft.fromJson({
    'id': row['id'],
    'title': row['title'],
    'image': row['image_url'],
    'groupId': row['group_id'],
    'occasion': row['occasion'],
    'specialEvent': row['special_event'],
    'vibe': OutingVibe.values
        .indexWhere((v) => v.name == row['vibe'])
        .clamp(0, OutingVibe.values.length - 1),
    'date': row['scheduled_date'],
    'hour': row['scheduled_hour'],
    'minute': row['scheduled_minute'],
    'location': {
      'name': row['location_name'] ?? '',
      'area': row['location_area'] ?? '',
      'latitude': row['location_latitude'],
      'longitude': row['location_longitude'],
    },
    'letVote': row['let_vote'],
    'voteDeadlineHours': row['vote_deadline_hours'],
    'guestIds': row['guest_ids'],
    'selectedPlaces': row['selected_places'],
    'remoteVersion': row['updated_at'],
  });

  Future<List<SavedOuting>> getSaved() async {
    final response = await _api.get(ApiConstants.savedOutings);
    final raw = response.data;
    final list = raw is Map && raw['data'] is List
        ? raw['data'] as List
        : raw is List
        ? raw
        : const [];
    return list
        .whereType<Map>()
        .map((item) => _mapSaved(item.cast<String, dynamic>()))
        .where((outing) => outing.id.isNotEmpty)
        .toList();
  }

  Future<void> save(String outingId) async {
    await _api.post(ApiConstants.savedOuting(outingId));
  }

  Future<void> unsave(String outingId) async {
    await _api.delete(ApiConstants.savedOuting(outingId));
  }

  SavedOuting _mapSaved(Map<String, dynamic> json) {
    final outing = (json['outing'] as Map?)?.cast<String, dynamic>();
    final id =
        outing?['id'] as String? ??
        json['outing_id'] as String? ??
        json['id'] as String? ??
        '';
    final title = outing?['title'] as String? ?? json['title'] as String? ?? '';
    final image =
        outing?['image_url'] as String? ?? json['image'] as String? ?? '';
    final locationName =
        outing?['location_name'] as String? ??
        (json['location'] is Map
            ? (json['location'] as Map)['name'] as String?
            : null) ??
        '';
    final lat = outing?['location_latitude'];
    final lng = outing?['location_longitude'];
    return SavedOuting(
      id: id,
      title: title,
      image: image,
      occasion: OutingOccasion.values.firstWhere(
        (item) => item.name == (outing?['occasion'] ?? json['occasion']),
        orElse: () => OutingOccasion.none,
      ),
      location: PlaceLocation(
        name: locationName,
        latitude: lat is num ? lat.toDouble() : null,
        longitude: lng is num ? lng.toDouble() : null,
      ),
    );
  }
}
