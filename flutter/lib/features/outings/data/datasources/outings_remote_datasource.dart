import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';

abstract class OutingsDataSource {
  Future<OutingSnapshot> load();
  Future<OutingSnapshot> add(Outing outing, {String? creatorId});
  Future<OutingSnapshot> suggestPlaces({
    required String groupId,
    required String title,
    required List<Place> places,
    required int deadlineHours,
    required String createdBy,
    String? createdById,
    String? image,
    DateTime? scheduledAt,
  });
  Future<OutingSnapshot> selectVote(String outingId, int optionIndex);
  Future<OutingSnapshot> finalizeVote(String outingId);
  Future<TieBreakResult> breakTie(String outingId);
  Future<OutingSnapshot> clearVotes(String outingId);
  Future<OutingSnapshot> setAttendance({
    required String outingId,
    required String memberId,
    required AttendanceStatus status,
  });
  Future<OutingSnapshot> refreshLifecycle();
  List<Place> get catalogPlaces;
  List<GroupMember> membersForOuting(Outing outing);
  String specialEventImage(OutingOccasion occasion);
}

class OutingsRemoteDataSource implements OutingsDataSource {
  OutingsRemoteDataSource(this._client);

  final ApiClient _client;

  /// Cached vote options by outing for index → option_id mapping.
  final _optionsByOuting = <String, List<Map<String, dynamic>>>{};

  @override
  List<Place> get catalogPlaces => const [];

  @override
  String specialEventImage(OutingOccasion occasion) => '';

  @override
  List<GroupMember> membersForOuting(Outing outing) => const [];

  @override
  Future<OutingSnapshot> load() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.outingsCuser,
      );
      final items = apiObjectList(
        response.data,
        aliases: const ['outings', 'items'],
      );
      final outings = <Outing>[
        for (final item in items) _outingFromJson(item),
      ];

      final votesByOuting = <String, PlaceVote>{};
      final attendanceByOuting = <String, Map<String, AttendanceStatus>>{};

      for (final outing in outings) {
        if (outing.id.isEmpty) continue;
        votesByOuting[outing.id] = await _loadVotes(outing.id);
        attendanceByOuting[outing.id] = await _loadAttendance(outing.id);
      }

      return OutingSnapshot(
        outings: outings,
        suggestions: const [],
        votesByOuting: votesByOuting,
        attendanceByOuting: attendanceByOuting,
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> add(Outing outing, {String? creatorId}) async {
    try {
      final body = <String, dynamic>{
        'title': outing.title,
        if (outing.image.isNotEmpty) 'image_url': outing.image,
        'group_id': outing.groupId,
        'status': outing.status.name,
        'occasion': outing.occasion.name,
        if (outing.scheduledAt != null)
          'scheduled_at': outing.scheduledAt!.toIso8601String(),
        if (outing.location != null) ...{
          'location_name': outing.location!.name,
          'location_area': outing.location!.area,
          'location_latitude': outing.location!.latitude,
          'location_longitude': outing.location!.longitude,
        },
        if (outing.voteDeadlineHours != null)
          'vote_deadline_hours': outing.voteDeadlineHours,
      };

      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.outings,
        data: body,
      );
      final created = apiPayload(response.data);
      final outingId = apiString(created['id']) ?? '';

      for (var i = 0; i < outing.votePlaces.length; i++) {
        final place = outing.votePlaces[i];
        await _client.post<Map<String, dynamic>>(
          ApiConstants.outingVoteOptions(outingId),
          data: {
            if (place.id.isNotEmpty) 'place_id': place.id,
            'label': place.name,
            if (place.area.isNotEmpty) 'area': place.area,
            if (place.imageUrl.isNotEmpty) 'image_url': place.imageUrl,
            'vibe': place.vibe.name,
            'latitude': place.latitude,
            'longitude': place.longitude,
            'sort_order': i,
          },
        );
      }

      for (final guestId in outing.guestIds) {
        await _client.post<Map<String, dynamic>>(
          ApiConstants.outingGuests(outingId),
          data: {'user_id': guestId},
        );
      }

      return await load();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> suggestPlaces({
    required String groupId,
    required String title,
    required List<Place> places,
    required int deadlineHours,
    required String createdBy,
    String? createdById,
    String? image,
    DateTime? scheduledAt,
  }) {
    return add(
      Outing(
        id: '',
        image: image ?? '',
        title: title,
        meta: '',
        date: '',
        time: '',
        going: 0,
        groupId: groupId,
        status: OutingStatus.voting,
        votePlaces: places,
        voteDeadlineHours: deadlineHours,
        suggestedBy: createdBy,
        scheduledAt: scheduledAt,
        createdById: createdById,
      ),
    );
  }

  @override
  Future<OutingSnapshot> selectVote(String outingId, int optionIndex) async {
    try {
      final options = await _ensureOptions(outingId);
      if (optionIndex < 0 || optionIndex >= options.length) {
        throw const ServerException('Invalid vote option');
      }
      final optionId = apiString(options[optionIndex]['id']);
      if (optionId == null || optionId.isEmpty) {
        throw const ServerException('Missing vote option id');
      }
      await _client.post<Map<String, dynamic>>(
        ApiConstants.outingVotes(outingId),
        data: {'option_id': optionId},
      );
      return await load();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> finalizeVote(String outingId) async {
    // Closure is server-authoritative; clients only refresh state.
    return load();
  }

  @override
  Future<TieBreakResult> breakTie(String outingId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.outingTieBreak(outingId),
      );
      final payload = apiPayload(response.data);
      final winning =
          apiString(payload['winningOptionId']) ??
          apiString(payload['winning_option_id']) ??
          '';
      final snapshot = await load();
      return TieBreakResult(
        snapshot: snapshot,
        winningOptionId: winning,
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> clearVotes(String outingId) async {
    try {
      final vote = await _loadVotes(outingId);
      for (final optionId in vote.cuserOptionIds) {
        await _client.delete<Map<String, dynamic>>(
          '${ApiConstants.outingVotes(outingId)}/$optionId',
        );
      }
      return await load();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> setAttendance({
    required String outingId,
    required String memberId,
    required AttendanceStatus status,
  }) async {
    try {
      // Backend binds attendance to the Bearer token user; memberId is ignored.
      await _client.put<Map<String, dynamic>>(
        ApiConstants.outingAttendance(outingId),
        data: {'status': attendanceStatusToApi(status.name)},
      );
      return await load();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> refreshLifecycle() => load();

  Future<List<Map<String, dynamic>>> _ensureOptions(String outingId) async {
    final cached = _optionsByOuting[outingId];
    if (cached != null) return cached;
    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.outingVoteOptions(outingId),
    );
    final items = apiObjectList(response.data, aliases: const ['items']);
    _optionsByOuting[outingId] = items;
    return items;
  }

  Future<PlaceVote> _loadVotes(String outingId) async {
    final options = await _ensureOptions(outingId);
    final votesResponse = await _client.get<Map<String, dynamic>>(
      ApiConstants.outingVotes(outingId),
    );
    final voteRows = apiObjectList(votesResponse.data, aliases: const ['items']);

    var finalized = false;
    DateTime? endsAt;
    try {
      final stateResponse = await _client.get<Map<String, dynamic>>(
        ApiConstants.outingVotingState(outingId),
      );
      final state = apiPayload(stateResponse.data);
      finalized = apiBool(state['isClosed']) || apiBool(state['is_closed']);
      final outingMap = state['outing'];
      if (outingMap is Map) {
        endsAt = DateTime.tryParse(
          apiString(outingMap['vote_ends_at']) ?? '',
        );
        finalized =
            finalized ||
            apiString(outingMap['vote_closed_at']) != null ||
            apiString(outingMap['status']) == 'confirmed';
      }
    } catch (_) {
      // Voting-state is best-effort; counts still load from votes.
    }

    final countByOption = <String, int>{};
    for (final row in voteRows) {
      final optionId = apiString(row['option_id']) ?? '';
      if (optionId.isEmpty) continue;
      countByOption[optionId] = (countByOption[optionId] ?? 0) + 1;
    }
    final total = voteRows.length;

    final voteOptions = <VoteOption>[
      for (final option in options)
        VoteOption(
          apiString(option['place_id']) ?? apiString(option['id']) ?? '',
          apiString(option['label']) ?? '',
          countByOption[apiString(option['id']) ?? ''] ?? 0,
          total == 0
              ? 0
              : (((countByOption[apiString(option['id']) ?? ''] ?? 0) / total) *
                        100)
                    .round(),
        ),
    ];

    return PlaceVote(
      outingId: outingId,
      options: voteOptions,
      cuserOptionIds: const [],
      finalized: finalized,
      endsAt: endsAt,
    );
  }

  Future<Map<String, AttendanceStatus>> _loadAttendance(String outingId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.outingAttendance(outingId),
    );
    final rows = apiObjectList(response.data, aliases: const ['items']);
    final result = <String, AttendanceStatus>{};
    for (final row in rows) {
      final userId = apiString(row['user_id']) ?? '';
      if (userId.isEmpty) continue;
      final wire = attendanceStatusFromApi(apiString(row['status']));
      result[userId] = AttendanceStatus.values.firstWhere(
        (item) => item.name == wire,
        orElse: () => AttendanceStatus.unset,
      );
    }
    return result;
  }

  Outing _outingFromJson(Map<String, dynamic> json) {
    final votePlacesRaw = json['votePlaces'] ?? json['vote_places'];
    final locationName = apiString(json['location_name']);
    final locationArea = apiString(json['location_area']);
    PlaceLocation? location;
    if (locationName != null ||
        locationArea != null ||
        json['location_latitude'] != null) {
      location = PlaceLocation(
        name: locationName ?? '',
        area: locationArea ?? '',
        latitude: (json['location_latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['location_longitude'] as num?)?.toDouble() ?? 0,
      );
    } else if (json['location'] is Map) {
      location = PlaceLocation.fromJson(
        Map<String, dynamic>.from(json['location'] as Map),
      );
    }

    final statusWire = apiString(json['status']) ?? 'draft';
    final normalizedStatus =
        statusWire == 'upcoming' ? 'confirmed' : statusWire;
    final occasionWire = apiString(json['occasion']) ?? 'none';
    final typeWire = apiString(json['type']) ?? 'group';
    final parsedType = switch (typeWire) {
      'special_event' || 'specialEvent' => OutingType.specialEvent,
      _ => OutingType.group,
    };

    return Outing(
      id: apiString(json['id']) ?? '',
      image:
          apiString(json['image_url']) ??
          apiString(json['image']) ??
          apiString(json['coverUrl']) ??
          '',
      title: apiString(json['title']) ?? '',
      meta: apiString(json['meta']) ?? '',
      date: apiString(json['date']) ?? '',
      time: apiString(json['time']) ?? '',
      going: apiInt(json['going']),
      groupId: apiString(json['group_id']) ?? apiString(json['groupId']),
      location: location,
      occasion: OutingOccasion.values.firstWhere(
        (item) => item.name == occasionWire,
        orElse: () => OutingOccasion.none,
      ),
      type: parsedType,
      guestIds: [
        for (final item in json['guestIds'] as List? ??
            json['guest_ids'] as List? ??
            const [])
          if (item is String) item,
      ],
      status: OutingStatus.values.firstWhere(
        (item) => item.name == normalizedStatus,
        orElse: () => OutingStatus.draft,
      ),
      votePlaces: [
        if (votePlacesRaw is List)
          for (final item in votePlacesRaw)
            if (item is Map) Place.fromJson(Map<String, dynamic>.from(item)),
      ],
      voteDeadlineHours:
          json['vote_deadline_hours'] as int? ??
          json['voteDeadlineHours'] as int?,
      suggestedBy:
          apiString(json['suggested_by_user_id']) ??
          apiString(json['suggestedBy']),
      scheduledAt: DateTime.tryParse(
        apiString(json['scheduled_at']) ??
            apiString(json['scheduledAt']) ??
            '',
      ),
      createdById:
          apiString(json['created_by']) ?? apiString(json['createdById']),
    );
  }

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(error.message ?? 'Server error');
  }
}
