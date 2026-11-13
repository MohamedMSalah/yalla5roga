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

  @override
  OutingSnapshot? applyAttendanceChange(
    String outingId,
    String userId,
    AttendanceStatus status,
    DateTime updatedAt,
  ) {
    final snapshot = remote.applyAttendanceChange(
      outingId,
      userId,
      status,
      updatedAt,
    );
    if (snapshot != null) _storeSnapshot(snapshot);
    return snapshot;
  }

  int _generation = 0;
  String get _snapshotKey => 'outings:snapshot:$_generation';
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
  void clearCache() {
    _generation++;
    _snapshotCache.invalidate();
    remote.clearCache();
  }

  @override
  Future<Either<Failure, OutingSnapshot>> load({bool forceRefresh = false}) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _snapshotCache,
      key: _snapshotKey,
      forceRefresh: forceRefresh,
      reason: 'loadOutings',
      offlineRead: true,
      feature: 'outings',
      source: 'OutingsRepositoryImpl',
      fetch: remote.load,
    );
  }

  @override
  Future<Either<Failure, void>> delete(String outingId) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.delete(outingId),
      reason: 'deleteOuting',
    );
    if (result.isRight()) _snapshotCache.invalidate();
    return result;
  }

  Future<Either<Failure, OutingSnapshot>> _mutate(
    Future<OutingSnapshot> Function() action,
  ) async {
    final result = await guardRemote(
      networkInfo,
      action,
      reason: 'manageOuting',
    );
    result.fold((_) {}, _storeSnapshot);
    return result;
  }

  @override
  Future<Either<Failure, OutingSnapshot>> update(
    String id,
    Map<String, dynamic> changes,
  ) => _mutate(() => remote.update(id, changes));
  @override
  Future<Either<Failure, OutingSnapshot>> cancel(String id) =>
      _mutate(() => remote.cancel(id));
  @override
  Future<Either<Failure, OutingSnapshot>> removeGuest(
    String id,
    String userId,
  ) => _mutate(() => remote.removeGuest(id, userId));
  @override
  Future<Either<Failure, OutingSnapshot>> respondToInvitation(
    String id, {
    required bool accept,
  }) => _mutate(() => remote.respondToInvitation(id, accept: accept));
  @override
  Future<Either<Failure, List<GroupMember>>> guests(String id) => guardRemote(
    networkInfo,
    () => remote.guests(id),
    reason: 'outingGuests',
    offlineRead: true,
  );

  @override
  Future<Either<Failure, OutingCreation>> add(
    Outing outing, {
    String? creatorId,
  }) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.add(outing, creatorId: creatorId),
      reason: 'addOuting',
    );
    result.fold((_) {}, (created) => _storeSnapshot(created.snapshot));
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
  Future<Either<Failure, OutingSnapshot>> setBallot(
    String outingId,
    Set<int> indexes,
  ) => _mutate(() => remote.setBallot(outingId, indexes));

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
  Future<Either<Failure, OutingSnapshot>> confirmVenue(
    String outingId,
    String optionId,
  ) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.confirmVenue(outingId, optionId),
      reason: 'confirmVenue',
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
  Future<Either<Failure, TieBreakResult>> breakTie(String outingId) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.breakTie(outingId),
      reason: 'breakTie',
    );
    result.fold((_) {}, (value) => _storeSnapshot(value.snapshot));
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
  Future<Either<Failure, OutingSnapshot>> refreshLifecycle({
    String? outingId,
    bool forceRefresh = false,
  }) async {
    if (outingId != null && outingId.isNotEmpty) {
      final result = await guardRemote(
        networkInfo,
        () => remote.refreshLifecycle(outingId: outingId),
        reason: 'refreshLifecycleOuting',
        offlineRead: true,
      );
      result.fold((_) {}, _storeSnapshot);
      return result;
    }

    // Full feed refresh respects TTL unless forced.
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _snapshotCache,
      key: _snapshotKey,
      forceRefresh: forceRefresh,
      reason: 'refreshLifecycle',
      offlineRead: true,
      feature: 'outings',
      source: 'OutingsRepositoryImpl',
      fetch: () => remote.refreshLifecycle(),
    );
  }
}
