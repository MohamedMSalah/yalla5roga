import 'dart:async';

import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
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

  Future<OutingCreation> add(Outing outing, {String? creatorId});
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
  Future<OutingSnapshot> confirmVenue(String outingId, String optionId);
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
  int _generation = 0;

  void _checkSession(int generation) {
    if (generation != _generation) throw const AuthException('Account changed');
  }

  /// Cached vote options by outing for index Ã¢â€ â€™ option_id mapping.
  final _optionsByOuting = <String, List<Map<String, dynamic>>>{};

  /// Last successful snapshot for single-outing merges.
  OutingSnapshot? _lastSnapshot;
  final _attendanceRows =
      <String, Map<String, ({AttendanceStatus status, DateTime at})>>{};

  OutingSnapshot? applyAttendanceChange(
    String outingId,
    String userId,
    AttendanceStatus status,
    DateTime updatedAt,
  ) {
    final base = _lastSnapshot;
    if (base == null || !base.outings.any((outing) => outing.id == outingId)) {
      return null;
    }
    final rows = _attendanceRows.putIfAbsent(outingId, () => {});
    final previous = rows[userId];
    if (previous != null && !updatedAt.isAfter(previous.at)) return base;
    rows[userId] = (status: status, at: updatedAt);
    final next = _store(
      OutingSnapshot(
        outings: base.outings,
        suggestions: base.suggestions,
        votesByOuting: base.votesByOuting,
        attendanceByOuting: {
          ...base.attendanceByOuting,
          outingId: {...?base.attendanceByOuting[outingId], userId: status},
        },
      ),
    );
    _persistAttendance(outingId, next.attendanceByOuting[outingId]!);
    return next;
  }

  void _persistAttendance(
    String outingId,
    Map<String, AttendanceStatus> attendance,
  ) {
    final store = _client.snapshots;
    final key = store?.keyFor(ApiConstants.outingAttendance(outingId), null);
    if (key == null || OfflineSnapshots.cacheOnly) return;
    unawaited(
      store!.write(key, {
        'success': true,
        'data': [
          for (final row in attendance.entries)
            {
              'outing_id': outingId,
              'user_id': row.key,
              'status': attendanceStatusToApi(row.value.name),
              if (_attendanceRows[outingId]?[row.key] case final version?)
                'updated_at': version.at.toUtc().toIso8601String(),
            },
        ],
      }, store.generation),
    );
  }

  /// Lifecycle metadata from the outing and its voting state.
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
    _generation++;
    _optionsByOuting.clear();
    _lifecycleHints.clear();
    _lastSnapshot = null;
    _attendanceRows.clear();
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
    final generation = _generation;
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.outingsCuser,
      );
      _checkSession(generation);
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
      _checkSession(generation);

      final ids = outings.map((outing) => outing.id).toSet();
      final base = _lastSnapshot;
      final votesByOuting = Map.of(
        base?.votesByOuting ?? const <String, PlaceVote>{},
      )..removeWhere((id, _) => !ids.contains(id));
      final attendanceByOuting = Map.of(
        base?.attendanceByOuting ??
            const <String, Map<String, AttendanceStatus>>{},
      )..removeWhere((id, _) => !ids.contains(id));
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
        RequestDeduper.keyFor(
          method: 'GET',
          path: 'outing-details:$outingId',
          query: {
            'preview': OfflineSnapshots.cacheOnly,
            'row': includeOutingRow,
          },
        ),
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
    final generation = _generation;
    Outing? outing;
    if (includeOutingRow) {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.outing(outingId),
      );
      _checkSession(generation);
      final payload = apiPayload(response.data);
      outing = _outingFromJson(payload);
      _lifecycleHints[outingId] = _hintFromJson(payload);
    } else {
      for (final item in _lastSnapshot?.outings ?? const <Outing>[]) {
        if (item.id == outingId) {
          outing = item;
          break;
        }
      }
    }

    final status = outing?.status ?? OutingStatus.voting;
    final piece = await _hydrateOuting(
      outingId,
      loadVotes:
          status == OutingStatus.voting ||
          _lifecycleHints[outingId]?.hasWinner == true,
      loadAttendance: true,
    );
    _checkSession(generation);
    // Merge against the latest snapshot after the requests complete.
    final base = _lastSnapshot;
    final outings = List<Outing>.of(base?.outings ?? const []);
    if (includeOutingRow && outing != null) {
      final index = outings.indexWhere((item) => item.id == outingId);
      if (index < 0) {
        outings.insert(0, outing);
      } else {
        outings[index] = outing;
      }
    }
    final votesByOuting = {...?base?.votesByOuting};
    final attendanceByOuting = {...?base?.attendanceByOuting};
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
  Future<OutingCreation> add(Outing outing, {String? creatorId}) async {
    try {
      final imageUrl = remoteImageUrlOrNull(outing.image);
      // Backend requires a voting deadline on every create.
      final deadlineHours = outing.voteDeadlineHours ?? 3;
      final body = <String, dynamic>{
        'title': outing.title,
        'image_url': ?imageUrl,
        'group_id': outing.groupId,
        'status': outing.status.name,
        'occasion': outing.occasion.name,
        if (outing.guestPhones.isNotEmpty) ...{
          'guest_phones': outing.guestPhones,
          'guest_phones_whatsapp_opt_in': true,
        },
        'create_request_key': ?outing.createRequestKey,
        if (outing.votePlaces.isNotEmpty)
          'initial_vote_options': [
            for (final place in outing.votePlaces)
              {
                if (place.id.isNotEmpty) 'place_id': place.id,
                'label': place.name,
                'area': place.area,
                'image_url': ?remoteImageUrlOrNull(place.imageUrl),
                'vibe': place.vibe.name,
                'latitude': place.latitude,
                'longitude': place.longitude,
              },
          ],
        'vote_deadline_hours': deadlineHours,
        if (outing.scheduledAt != null)
          'scheduled_at': outing.scheduledAt!.toUtc().toIso8601String(),
        if (outing.location != null) ...{
          'location_place_id': ?outing.location!.placeId,
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

      _optionsByOuting.remove(outingId);

      for (final guestId in outing.guestIds) {
        await _client.post<Map<String, dynamic>>(
          ApiConstants.outingGuests(outingId),
          data: {'user_id': guestId},
        );
      }

      final snapshot = await load();
      return OutingCreation(
        outing:
            snapshot.outings.where((item) => item.id == outingId).firstOrNull ??
            _outingFromJson(created),
        snapshot: snapshot,
        manualWhatsAppUrls: [
          for (final url
              in created['manual_whatsapp_urls'] as List? ?? const [])
            if (url is String)
              if (Uri.tryParse(url)
                  case Uri(
                    scheme: 'https',
                    host: 'wa.me',
                    pathSegments: [final phone],
                  )
                  when RegExp(r'^\d+$').hasMatch(phone))
                url,
        ],
      );
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
  }) async {
    final creation = await add(
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
    return creation.snapshot;
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
      return await _refreshVote(outingId);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> confirmVenue(String outingId, String optionId) async {
    try {
      await _client.put<Map<String, dynamic>>(
        ApiConstants.outingConfirmedVenue(outingId),
        data: {'option_id': optionId},
      );
      return await _refreshVote(outingId);
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
      final snapshot = await _refreshVote(outingId);
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
      return await _refreshVote(outingId);
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
      final response = await _client.put<Map<String, dynamic>>(
        ApiConstants.outingAttendance(outingId),
        data: {'status': attendanceStatusToApi(status.name)},
      );
      final rows = response.data?['items'];
      final attendance = rows is List
          ? _parseAttendance(apiObjectList(rows), outingId)
          : await _loadAttendance(outingId);
      final base = _lastSnapshot;
      return _store(
        OutingSnapshot(
          outings: base?.outings ?? const [],
          suggestions: base?.suggestions ?? const [],
          votesByOuting: base?.votesByOuting ?? const {},
          attendanceByOuting: {
            ...?base?.attendanceByOuting,
            outingId: attendance,
          },
        ),
      );
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
    final votes = loadVotes
        ? _optionalRead(() => _loadVotes(outingId))
        : Future<PlaceVote?>.value();
    final attendance = loadAttendance
        ? _optionalRead(() => _loadAttendance(outingId))
        : Future<Map<String, AttendanceStatus>?>.value();
    final results = await Future.wait<Object?>([votes, attendance]);
    return _HydratedOuting(
      outingId: outingId,
      vote: results[0] as PlaceVote?,
      attendance: results[1] as Map<String, AttendanceStatus>?,
    );
  }

  Future<T?> _optionalRead<T>(Future<T> Function() load) async {
    try {
      return await load();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (error.error is NetworkException ||
          status == 403 ||
          status == 404 ||
          (status ?? 0) >= 500) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _ensureOptions(String outingId) {
    return _deduper.run(
      RequestDeduper.keyFor(
        method: 'GET',
        path: ApiConstants.outingVoteOptions(outingId),
      ),
      () async {
        final generation = _generation;
        final cached = _optionsByOuting[outingId];
        if (cached != null) return cached;
        final response = await _client.get<Map<String, dynamic>>(
          ApiConstants.outingVoteOptions(outingId),
        );
        _checkSession(generation);
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

  Future<PlaceVote> _loadVotes(String outingId) async =>
      (await _loadVoteState(outingId)).vote;

  Future<OutingSnapshot> _refreshVote(String outingId) async {
    final generation = _generation;
    final state = await _loadVoteState(outingId);
    _checkSession(generation);
    final base = _lastSnapshot;
    final outings = List<Outing>.of(base?.outings ?? const []);
    if (state.outing case final outing?) {
      final index = outings.indexWhere((item) => item.id == outingId);
      if (index < 0) {
        outings.insert(0, outing);
      } else {
        outings[index] = outing;
      }
    }
    return _store(
      OutingSnapshot(
        outings: outings,
        suggestions: base?.suggestions ?? const [],
        votesByOuting: {...?base?.votesByOuting, outingId: state.vote},
        attendanceByOuting: base?.attendanceByOuting ?? const {},
      ),
    );
  }

  Future<({PlaceVote vote, Outing? outing})> _loadVoteState(
    String outingId,
  ) async {
    final generation = _generation;
    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.outingVotingState(outingId),
    );
    _checkSession(generation);
    final state = apiPayload(response.data);
    final options = apiObjectList(state['options']);
    _optionsByOuting[outingId] = options;
    final outing = state['outing'];
    if (outing is Map<String, dynamic>) {
      _lifecycleHints[outingId] = _hintFromJson(outing);
    }
    final hint = _lifecycleHints[outingId];
    final total = options.fold(
      0,
      (sum, option) => sum + apiInt(option['vote_count']),
    );
    final selectedId = apiString(state['my_option_id']);
    final vote = PlaceVote(
      outingId: outingId,
      eligibleVoterCount: apiInt(state['eligible_voter_count']),
      options: [
        for (final option in options)
          VoteOption(
            apiString(option['id']) ?? '',
            apiString(option['label']) ?? '',
            apiInt(option['vote_count']),
            total == 0
                ? 0
                : (apiInt(option['vote_count']) * 100 / total).round(),
            area: apiString(option['area']) ?? '',
          ),
      ],
      cuserOptionIds: [?selectedId],
      finalized: hint?.isClosed ?? apiBool(state['isClosed']),
      endsAt: hint?.voteEndsAt,
    );
    return (
      vote: vote,
      outing: outing is Map<String, dynamic> ? _outingFromJson(outing) : null,
    );
  }

  Future<Map<String, AttendanceStatus>> _loadAttendance(String outingId) async {
    final generation = _generation;
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.outingAttendance(outingId),
      );
      _checkSession(generation);
      return _parseAttendance(apiObjectList(response.data), outingId);
    } on DioException catch (error) {
      _checkSession(generation);
      if (error.response?.statusCode == 403 ||
          error.response?.statusCode == 404) {
        _attendanceRows.remove(outingId);
        final base = _lastSnapshot;
        if (base != null) {
          _lastSnapshot = OutingSnapshot(
            outings: base.outings,
            suggestions: base.suggestions,
            votesByOuting: base.votesByOuting,
            attendanceByOuting: Map.of(base.attendanceByOuting)
              ..remove(outingId),
          );
        }
      }
      rethrow;
    }
  }

  Map<String, AttendanceStatus> _parseAttendance(
    List<Map<String, dynamic>> rows,
    String outingId,
  ) {
    final result = <String, AttendanceStatus>{};
    for (final row in rows) {
      final userId = apiString(row['user_id']) ?? '';
      if (userId.isEmpty) continue;
      final wire = attendanceStatusFromApi(apiString(row['status']));
      final status = AttendanceStatus.values.firstWhere(
        (item) => item.name == wire,
        orElse: () => AttendanceStatus.unset,
      );
      final at = DateTime.tryParse(apiString(row['updated_at']) ?? '');
      final versions = _attendanceRows.putIfAbsent(outingId, () => {});
      final previous = versions[userId];
      if (at != null && (previous == null || !at.isBefore(previous.at))) {
        versions[userId] = (status: status, at: at);
      }
      result[userId] = versions[userId]?.status ?? status;
    }
    _persistAttendance(outingId, result);
    return result;
  }

  OutingSnapshot _store(OutingSnapshot snapshot) {
    snapshot = OutingSnapshot(
      outings: snapshot.outings,
      suggestions: snapshot.suggestions,
      votesByOuting: snapshot.votesByOuting,
      attendanceByOuting: {
        for (final outing in snapshot.outings)
          if (_attendanceRows[outing.id] case final rows?)
            outing.id: {
              for (final row in rows.entries) row.key: row.value.status,
            },
        for (final entry in snapshot.attendanceByOuting.entries)
          entry.key: {
            ...entry.value,
            for (final row in (_attendanceRows[entry.key] ?? {}).entries)
              row.key: row.value.status,
          },
      },
    );
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
    return _OutingLifecycleHint(
      voteEndsAt: endsAt,
      isClosed: closed,
      hasWinner: apiString(json['winning_option_id']) != null,
    );
  }

  Outing _outingFromJson(Map<String, dynamic> json) {
    final votePlacesRaw = json['votePlaces'] ?? json['vote_places'];
    final locationName = apiString(json['location_name']);
    final locationArea = apiString(json['location_area']);
    final placeId = apiString(json['location_place_id']);
    PlaceLocation? location;
    if (placeId != null ||
        locationName != null ||
        locationArea != null ||
        json['location_latitude'] != null) {
      location = PlaceLocation(
        name: locationName ?? '',
        placeId: placeId,
        area: locationArea ?? '',
        latitude: (json['location_latitude'] as num?)?.toDouble(),
        longitude: (json['location_longitude'] as num?)?.toDouble(),
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
      endsAt: DateTime.tryParse(apiString(json['ends_at']) ?? ''),
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
  const _OutingLifecycleHint({
    this.voteEndsAt,
    this.isClosed = false,
    this.hasWinner = false,
  });

  final DateTime? voteEndsAt;
  final bool isClosed;
  final bool hasWinner;
}
