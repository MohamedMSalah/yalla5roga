import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';

class OutingsRepositoryImpl implements OutingsRepository {
  OutingsRepositoryImpl({required this.remote, required this.networkInfo});

  final OutingsRemoteDataSource remote;
  final NetworkInfo networkInfo;

  static const _snapshotKey = 'snapshot';
  final _snapshotCache = TtlCache<OutingSnapshot>(ttl: CachePolicy.outings);

  void _storeSnapshot(OutingSnapshot snapshot) {
    _snapshotCache.set(_snapshotKey, snapshot);
  }

  @override
  List<Place> get catalogPlaces => remote.catalogPlaces;

  @override
  String specialEventImage(OutingOccasion occasion) =>
      remote.specialEventImage(occasion);

  @override
  List<GroupMember> membersForOuting(Outing outing) =>
      remote.membersForOuting(outing);

  @override
  Future<Either<Failure, OutingSnapshot>> load({bool forceRefresh = false}) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _snapshotCache,
      key: _snapshotKey,
      forceRefresh: forceRefresh,
      reason: 'loadOutings',
      fetch: remote.load,
    );
  }

  @override
  Future<Either<Failure, OutingSnapshot>> add(
    Outing outing, {
    String? creatorId,
  }) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.add(outing, creatorId: creatorId),
      reason: 'addOuting',
    );
    result.fold((_) {}, _storeSnapshot);
    return result;
  }

  @override
  Future<Either<Failure, OutingSnapshot>> suggestPlaces({
    required String groupId,
    required String title,
    required List<Place> places,
    required int deadlineHours,
    required String createdBy,
    String? createdById,
    String? image,
    DateTime? scheduledAt,
  }) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.suggestPlaces(
        groupId: groupId,
        title: title,
        places: places,
        deadlineHours: deadlineHours,
        createdBy: createdBy,
        createdById: createdById,
        image: image,
        scheduledAt: scheduledAt,
      ),
      reason: 'suggestPlaces',
    );
    result.fold((_) {}, _storeSnapshot);
    return result;
  }

  @override
  Future<Either<Failure, OutingSnapshot>> selectVote(
    String outingId,
    int optionIndex,
  ) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.selectVote(outingId, optionIndex),
      reason: 'selectVote',
    );
    result.fold((_) {}, _storeSnapshot);
    return result;
  }

  @override
  Future<Either<Failure, OutingSnapshot>> finalizeVote(String outingId) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.finalizeVote(outingId),
      reason: 'finalizeVote',
    );
    result.fold((_) {}, _storeSnapshot);
    return result;
  }

  @override
  Future<Either<Failure, OutingSnapshot>> clearVotes(String outingId) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.clearVotes(outingId),
      reason: 'clearVotes',
    );
    result.fold((_) {}, _storeSnapshot);
    return result;
  }

  @override
  Future<Either<Failure, OutingSnapshot>> setAttendance({
    required String outingId,
    required String memberId,
    required AttendanceStatus status,
  }) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.setAttendance(
        outingId: outingId,
        memberId: memberId,
        status: status,
      ),
      reason: 'setAttendance',
    );
    result.fold((_) {}, _storeSnapshot);
    return result;
  }

  @override
  Future<Either<Failure, OutingSnapshot>> refreshLifecycle() async {
    // Lifecycle depends on clocks / deadlines — always hit network, then refresh cache.
    final result = await guardRemote(
      networkInfo,
      remote.refreshLifecycle,
      reason: 'refreshLifecycle',
    );
    result.fold((_) {}, _storeSnapshot);
    return result;
  }
}
