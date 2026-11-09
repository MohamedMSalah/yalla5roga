import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/core/network/request_deduper.dart';
import 'package:yalla_5roga/core/utils/async_pool.dart';
import 'package:yalla_5roga/core/utils/remote_image_url.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';

abstract class OutingsDataSource {
  Future<OutingSnapshot> load();

  /// Reloads votes/attendance (and optionally the outing row) for one id.
  Future<OutingSnapshot> reloadOutingDetails(
    String outingId, {
    bool includeOutingRow = true,
  });

  Future<void> delete(String outingId);

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
  Future<OutingSnapshot> refreshLifecycle({String? outingId});
  void clearCache();
  List<Place> get catalogPlaces;
  List<GroupMember> membersForOuting(Outing outing);
  String specialEventImage(OutingOccasion occasion);
}

class OutingsRemoteDataSource implements OutingsDataSource {
  OutingsRemoteDataSource(this._client, {RequestDeduper? deduper})
    : _deduper = deduper ?? RequestDeduper();

  final ApiClient _client;
  final RequestDeduper _deduper;

  /// Cached vote options by outing for index → option_id mapping.
  final _optionsByOuting = <String, List<Map<String, dynamic>>>{};

  /// Last successful snapshot for single-outing merges.
  OutingSnapshot? _lastSnapshot;

  /// Closure hints parsed from list/detail JSON (avoids voting-state when set).
  final _lifecycleHints = <String, _OutingLifecycleHint>{};

  static const _hydrateConcurrency = 4;

  @override
  List<Place> get catalogPlaces => const [];

  @override
  String specialEventImage(OutingOccasion occasion) => '';

  @override
  List<GroupMember> membersForOuting(Outing outing) => const [];

  @override
  void clearCache() {
    _optionsByOuting.clear();
    _lifecycleHints.clear();
    _lastSnapshot = null;
    _deduper.clear();
  }

  @override
  Future<void> delete(String outingId) async {
    try {
      await _client.delete<Map<String, dynamic>>(ApiConstants.outing(outingId));
      _optionsByOuting.remove(outingId);
      _lifecycleHints.remove(outingId);
      final snapshot = _lastSnapshot;
      if (snapshot != null) _store(snapshot.withoutOuting(outingId));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

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

      final outings = <Outing>[];
      for (final item in items) {
        final outing = _outingFromJson(item);
        outings.add(outing);
        if (outing.id.isNotEmpty) {
          _lifecycleHints[outing.id] = _hintFromJson(item);
        }
      }

      final votesByOuting = <String, PlaceVote>{};
      final attendanceByOuting = <String, Map<String, AttendanceStatus>>{};

      // List screens only need tallies for open votes; detail pages hydrate
      // attendance (and non-voting rows) via reloadOutingDetails.
      final toHydrate = [
        for (final outing in outings)
          if (outing.id.isNotEmpty && outing.status == OutingStatus.voting)
            outing,
      ];

      final hydrated = await mapPool(
        toHydrate,
        (outing) =>
            _hydrateOuting(outing.id, loadVotes: true, loadAttendance: true),
        concurrency: _hydrateConcurrency,
      );

      for (final piece in hydrated) {
        if (piece.vote != null) {
          votesByOuting[piece.outingId] = piece.vote!;
        }
        if (piece.attendance != null) {
          attendanceByOuting[piece.outingId] = piece.attendance!;
        }
      }

      return _store(
        OutingSnapshot(
          outings: outings,
          suggestions: const [],
          votesByOuting: votesByOuting,
          attendanceByOuting: attendanceByOuting,
        ),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> reloadOutingDetails(
    String outingId, {
    bool includeOutingRow = true,
  }) async {
    try {
      return await _deduper.run(
        RequestDeduper.keyFor(method: 'GET', path: 'outing-details:$outingId'),
        () => _reloadOutingDetailsUnlocked(
          outingId,
          includeOutingRow: includeOutingRow,
        ),
        feature: 'outings',
        source: 'OutingsRemoteDataSource',
        operation: 'reloadOutingDetails',
        endpoint: ApiConstants.outing(outingId),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  Future<OutingSnapshot> _reloadOutingDetailsUnlocked(
    String outingId, {
    required bool includeOutingRow,
  }) async {
    final base = _lastSnapshot;
    var outings = List<Outing>.of(base?.outings ?? const []);
    final votesByOuting = Map<String, PlaceVote>.of(
      base?.votesByOuting ?? const {},
    );
    final attendanceByOuting = Map<String, Map<String, AttendanceStatus>>.of(
      base?.attendanceByOuting ?? const {},
    );

    Outing? outing;
    if (includeOutingRow) {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.outing(outingId),
      );
      final payload = apiPayload(response.data);
      outing = _outingFromJson(payload);
      _lifecycleHints[outingId] = _hintFromJson(payload);
      final index = outings.indexWhere((item) => item.id == outingId);
      if (index >= 0) {
        outings[index] = outing;
      } else {
        outings = [outing, ...outings];
      }
    } else {
      for (final item in outings) {
        if (item.id == outingId) {
          outing = item;
          break;
        }
      }
    }

    final status = outing?.status ?? OutingStatus.voting;
    final piece = await _hydrateOuting(
      outingId,
      loadVotes: status == OutingStatus.voting,
      loadAttendance:
          status == OutingStatus.voting || status == OutingStatus.confirmed,
    );
    if (piece.vote != null) {
      votesByOuting[outingId] = piece.vote!;
    }
    if (piece.attendance != null) {
      attendanceByOuting[outingId] = piece.attendance!;
    }

    return _store(
      OutingSnapshot(
        outings: outings,
        suggestions: base?.suggestions ?? const [],
        votesByOuting: votesByOuting,
        attendanceByOuting: attendanceByOuting,
      ),
    );
  }

  @override
  Future<OutingSnapshot> add(Outing outing, {String? creatorId}) async {
    try {
      final imageUrl = remoteImageUrlOrNull(outing.image);
      // Backend requires a voting deadline on every create.
      final deadlineHours = outing.voteDeadlineHours ?? 3;
      final body = <String, dynamic>{
        'title': outing.title,
        if (imageUrl != null) 'image_url': imageUrl,
        'group_id': outing.groupId,
        'status': outing.status.name,
        'occasion': outing.occasion.name,
        'vote_deadline_hours': deadlineHours,
        if (outing.scheduledAt != null)
          'scheduled_at': outing.scheduledAt!.toIso8601String(),
        if (outing.location != null) ...{
          'location_name': outing.location!.name,
          'location_area': outing.location!.area,
          'location_latitude': outing.location!.latitude,
          'location_longitude': outing.location!.longitude,
        },
      };

      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.outings,
        data: body,
      );
      final created = apiPayload(response.data);
      final outingId = apiString(created['id']) ?? '';

      for (var i = 0; i < outing.votePlaces.length; i++) {
        final place = outing.votePlaces[i];
        final placeImageUrl = remoteImageUrlOrNull(place.imageUrl);
        await _client.post<Map<String, dynamic>>(
          ApiConstants.outingVoteOptions(outingId),
          data: {
            if (place.id.isNotEmpty) 'place_id': place.id,
            'label': place.name,
            if (place.area.isNotEmpty) 'area': place.area,
            if (placeImageUrl != null) 'image_url': placeImageUrl,
            'vibe': place.vibe.name,
            'latitude': place.latitude,
            'longitude': place.longitude,
            'sort_order': i,
          },
        );
      }
      _optionsByOuting.remove(outingId);

      for (final guestId in outing.guestIds) {
        await _client.post<Map<String, dynamic>>(
          ApiConstants.outingGuests(outingId),
          data: {'user_id': guestId},
        );
      }

      // New outing changes the feed membership — full list reload once.
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
      return await reloadOutingDetails(outingId, includeOutingRow: false);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> finalizeVote(String outingId) async {
    // Closure is server-authoritative; clients only refresh that outing.
    return reloadOutingDetails(outingId);
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
      final snapshot = await reloadOutingDetails(outingId);
      return TieBreakResult(snapshot: snapshot, winningOptionId: winning);
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
      return await reloadOutingDetails(outingId, includeOutingRow: false);
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
      return await reloadOutingDetails(outingId, includeOutingRow: false);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> refreshLifecycle({String? outingId}) {
    if (outingId != null && outingId.isNotEmpty) {
      return reloadOutingDetails(outingId);
    }
    return load();
  }

  Future<_HydratedOuting> _hydrateOuting(
    String outingId, {
    required bool loadVotes,
    required bool loadAttendance,
  }) async {
    PlaceVote? vote;
    Map<String, AttendanceStatus>? attendance;

    if (loadVotes && loadAttendance) {
      final results = await Future.wait<Object>([
        _loadVotes(outingId),
        _loadAttendance(outingId),
      ]);
      vote = results[0] as PlaceVote;
      attendance = results[1] as Map<String, AttendanceStatus>;
    } else if (loadVotes) {
      vote = await _loadVotes(outingId);
    } else if (loadAttendance) {
      attendance = await _loadAttendance(outingId);
    }

    return _HydratedOuting(
      outingId: outingId,
      vote: vote,
      attendance: attendance,
    );
  }

  Future<List<Map<String, dynamic>>> _ensureOptions(String outingId) {
    return _deduper.run(
      RequestDeduper.keyFor(
        method: 'GET',
        path: ApiConstants.outingVoteOptions(outingId),
      ),
      () async {
        final cached = _optionsByOuting[outingId];
        if (cached != null) return cached;
        final response = await _client.get<Map<String, dynamic>>(
          ApiConstants.outingVoteOptions(outingId),
        );
        final items = apiObjectList(response.data, aliases: const ['items']);
        _optionsByOuting[outingId] = items;
        return items;
      },
      feature: 'outings',
      source: 'OutingsRemoteDataSource',
      operation: 'voteOptions',
      endpoint: ApiConstants.outingVoteOptions(outingId),
    );
  }

  Future<PlaceVote> _loadVotes(String outingId) async {
    final options = await _ensureOptions(outingId);
    final votesResponse = await _client.get<Map<String, dynamic>>(
      ApiConstants.outingVotes(outingId),
    );
    final voteRows = apiObjectList(
      votesResponse.data,
      aliases: const ['items'],
    );

    var finalized = false;
    DateTime? endsAt;
    final hint = _lifecycleHints[outingId];
    if (hint != null) {
      endsAt = hint.voteEndsAt;
      finalized = hint.isClosed;
    }

    final needsVotingState = endsAt == null && !finalized;
    if (needsVotingState) {
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
          _lifecycleHints[outingId] = _OutingLifecycleHint(
            voteEndsAt: endsAt,
            isClosed: finalized,
          );
        }
      } catch (_) {
        // Voting-state is best-effort; counts still load from votes.
      }
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

  OutingSnapshot _store(OutingSnapshot snapshot) {
    _lastSnapshot = snapshot;
    return snapshot;
  }

  _OutingLifecycleHint _hintFromJson(Map<String, dynamic> json) {
    final endsAt = DateTime.tryParse(
      apiString(json['vote_ends_at']) ?? apiString(json['voteEndsAt']) ?? '',
    );
    final closed =
        apiString(json['vote_closed_at']) != null ||
        apiString(json['voteClosedAt']) != null ||
        apiBool(json['is_closed']) ||
        apiBool(json['isClosed']) ||
        apiString(json['status']) == 'confirmed';
    return _OutingLifecycleHint(voteEndsAt: endsAt, isClosed: closed);
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
    final normalizedStatus = statusWire == 'upcoming'
        ? 'confirmed'
        : statusWire;
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
        for (final item
            in json['guestIds'] as List? ??
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
        apiString(json['scheduled_at']) ?? apiString(json['scheduledAt']) ?? '',
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

class _HydratedOuting {
  const _HydratedOuting({required this.outingId, this.vote, this.attendance});

  final String outingId;
  final PlaceVote? vote;
  final Map<String, AttendanceStatus>? attendance;
}

class _OutingLifecycleHint {
  const _OutingLifecycleHint({this.voteEndsAt, this.isClosed = false});

  final DateTime? voteEndsAt;
  final bool isClosed;
}
