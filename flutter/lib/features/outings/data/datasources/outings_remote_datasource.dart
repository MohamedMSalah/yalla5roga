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
        ApiConstants.outings,
      );
      final payload = apiPayload(response.data);
      final raw = payload['items'] ?? payload['outings'] ?? payload;
      final outings = <Outing>[
        if (raw is List)
          for (final item in raw)
            if (item is Map) _outingFromJson(Map<String, dynamic>.from(item)),
      ];
      return OutingSnapshot(
        outings: outings,
        suggestions: const [],
        votesByOuting: _votesFromJson(payload['votesByOuting']),
        attendanceByOuting: _attendanceFromJson(payload['attendanceByOuting']),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> add(Outing outing, {String? creatorId}) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiConstants.outings,
        data: _outingToJson(outing),
      );
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
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiConstants.outings,
        data: {
          'groupId': groupId,
          'title': title,
          'places': [for (final place in places) place.toJson()],
          'deadlineHours': deadlineHours,
          'createdBy': createdBy,
          'createdById': createdById,
          'image': image,
          'scheduledAt': scheduledAt?.toIso8601String(),
          'status': OutingStatus.voting.name,
        },
      );
      return await load();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> selectVote(String outingId, int optionIndex) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiConstants.outingVotes(outingId),
        data: {'optionIndex': optionIndex, 'toggle': true},
      );
      return await load();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> finalizeVote(String outingId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiConstants.outingVotes(outingId),
        data: {'finalize': true},
      );
      return await load();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> clearVotes(String outingId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiConstants.outingVotes(outingId),
        data: {'clear': true},
      );
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
      await _client.post<Map<String, dynamic>>(
        ApiConstants.outingAttendance(outingId),
        data: {'userId': memberId, 'status': status.name},
      );
      return await load();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingSnapshot> refreshLifecycle() => load();


  Map<String, PlaceVote> _votesFromJson(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, PlaceVote>{};
    raw.forEach((key, value) {
      if (value is! Map) return;
      final map = Map<String, dynamic>.from(value);
      final optionsRaw = map['options'];
      final options = <VoteOption>[
        if (optionsRaw is List)
          for (final item in optionsRaw)
            if (item is Map)
              VoteOption.fromJson(Map<String, dynamic>.from(item)),
      ];
      result['$key'] = PlaceVote(
        outingId: apiString(map['outingId']) ?? '$key',
        options: options,
        endsAt: DateTime.tryParse(apiString(map['endsAt']) ?? ''),
        cuserOptionIds: [
          for (final id in map['cuserOptionIds'] as List? ?? const [])
            if (id is String) id,
        ],
        suggestedById: apiString(map['suggestedById']),
        finalized: apiBool(map['finalized']),
      );
    });
    return result;
  }

  Map<String, Map<String, AttendanceStatus>> _attendanceFromJson(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, Map<String, AttendanceStatus>>{};
    raw.forEach((outingId, value) {
      if (value is! Map) return;
      final members = <String, AttendanceStatus>{};
      value.forEach((userId, status) {
        members['$userId'] = AttendanceStatus.values.firstWhere(
          (item) => item.name == '$status',
          orElse: () => AttendanceStatus.notVoted,
        );
      });
      result['$outingId'] = members;
    });
    return result;
  }
  Outing _outingFromJson(Map<String, dynamic> json) {
    final votePlacesRaw = json['votePlaces'];
    return Outing(
      id: apiString(json['id']) ?? '',
      image: apiString(json['image']) ?? apiString(json['coverUrl']) ?? '',
      title: apiString(json['title']) ?? '',
      meta: apiString(json['meta']) ?? '',
      date: apiString(json['date']) ?? '',
      time: apiString(json['time']) ?? '',
      going: apiInt(json['going']),
      groupId: apiString(json['groupId']),
      location: json['location'] is Map
          ? PlaceLocation.fromJson(
              Map<String, dynamic>.from(json['location'] as Map),
            )
          : null,
      occasion: OutingOccasion.values.firstWhere(
        (item) => item.name == json['occasion'],
        orElse: () => OutingOccasion.none,
      ),
      guestIds: [
        for (final item in json['guestIds'] as List? ?? const [])
          if (item is String) item,
      ],
      status: OutingStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => OutingStatus.upcoming,
      ),
      votePlaces: [
        if (votePlacesRaw is List)
          for (final item in votePlacesRaw)
            if (item is Map) Place.fromJson(Map<String, dynamic>.from(item)),
      ],
      voteDeadlineHours: json['voteDeadlineHours'] as int?,
      suggestedBy: apiString(json['suggestedBy']),
      scheduledAt: DateTime.tryParse(apiString(json['scheduledAt']) ?? ''),
      createdById: apiString(json['createdById']),
    );
  }

  Map<String, dynamic> _outingToJson(Outing outing) => {
    'id': outing.id,
    'title': outing.title,
    'image': outing.image,
    'meta': outing.meta,
    'date': outing.date,
    'time': outing.time,
    'going': outing.going,
    'groupId': outing.groupId,
    'location': outing.location?.toJson(),
    'occasion': outing.occasion.name,
    'guestIds': outing.guestIds,
    'status': outing.status.name,
    'votePlaces': [for (final place in outing.votePlaces) place.toJson()],
    'voteDeadlineHours': outing.voteDeadlineHours,
    'suggestedBy': outing.suggestedBy,
    'scheduledAt': outing.scheduledAt?.toIso8601String(),
    'createdById': outing.createdById,
  };

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(error.message ?? 'Server error');
  }
}
