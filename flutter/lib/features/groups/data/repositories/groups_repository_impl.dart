import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/repositories/groups_repository.dart';

class GroupsRepositoryImpl implements GroupsRepository {
  GroupsRepositoryImpl({required this.remote, required this.networkInfo});

  final GroupsDataSource remote;
  final NetworkInfo networkInfo;

  static const _groupsKey = 'groups';
  final _groupsCache = TtlCache<List<Group>>(ttl: CachePolicy.groups);
  final _groupCache = TtlCache<Group>(ttl: CachePolicy.groups);

  @override
  Future<Either<Failure, List<Group>>> getGroups({bool forceRefresh = false}) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _groupsCache,
      key: _groupsKey,
      forceRefresh: forceRefresh,
      reason: 'getGroups',
      fetch: remote.getGroups,
    );
  }

  @override
  Future<Either<Failure, Group>> getGroup(
    String groupId, {
    bool forceRefresh = false,
  }) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _groupCache,
      key: groupId,
      forceRefresh: forceRefresh,
      reason: 'getGroup',
      fetch: () => remote.getGroup(groupId),
    );
  }

  @override
  Future<Either<Failure, Group>> createGroup(Group group) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.createGroup(group),
      reason: 'createGroup',
    );
    result.fold((_) {}, (created) {
      _groupCache.set(created.id, created);
      _groupsCache.invalidate(_groupsKey);
    });
    return result;
  }

  @override
  Future<Either<Failure, Group>> updateGroup(Group group) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.updateGroup(group),
      reason: 'updateGroup',
    );
    result.fold((_) {}, (updated) {
      _groupCache.set(updated.id, updated);
      _groupsCache.invalidate(_groupsKey);
    });
    return result;
  }

  @override
  Future<Either<Failure, Group>> addMember(
    String groupId,
    GroupMember member,
  ) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.addMember(groupId, member),
      reason: 'addMember',
    );
    result.fold((_) {}, (updated) {
      _groupCache.set(updated.id, updated);
      _groupsCache.invalidate(_groupsKey);
    });
    return result;
  }

  @override
  Future<Either<Failure, Group>> removeMember(
    String groupId,
    String memberId,
  ) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.removeMember(groupId, memberId),
      reason: 'removeMember',
    );
    result.fold((_) {}, (updated) {
      _groupCache.set(updated.id, updated);
      _groupsCache.invalidate(_groupsKey);
    });
    return result;
  }

  @override
  Future<Either<Failure, void>> leaveGroup(String groupId) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.leaveGroup(groupId),
      reason: 'leaveGroup',
    );
    result.fold((_) {}, (_) {
      _groupCache.invalidate(groupId);
      _groupsCache.invalidate(_groupsKey);
    });
    return result;
  }

  @override
  GroupMember? memberById(String id) => remote.memberById(id);

  @override
  GroupMember? memberByPhone(String phone) => remote.memberByPhone(phone);

  @override
  String groupsForMember(String id) => remote.groupsForMember(id);

  @override
  List<GroupMember> get contacts => remote.contacts;
}
