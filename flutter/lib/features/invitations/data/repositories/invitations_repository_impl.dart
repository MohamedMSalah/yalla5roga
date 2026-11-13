import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/features/invitations/data/datasources/invitations_remote_datasource.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';
import 'package:yalla_5roga/features/invitations/domain/repositories/invitations_repository.dart';

class InvitationsRepositoryImpl implements InvitationsRepository {
  InvitationsRepositoryImpl({
    required this.remote,
    required this.networkInfo,
  });

  final InvitationsRemoteDataSource remote;
  final NetworkInfo networkInfo;

  static const _listKey = 'invitations';
  final _cache = TtlCache<List<GroupInvitation>>(
    ttl: CachePolicy.invitations,
  );

  @override
  Future<Either<Failure, List<GroupInvitation>>> getInvitations({
    bool forceRefresh = false,
  }) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _cache,
      key: _listKey,
      forceRefresh: forceRefresh,
      reason: 'getInvitations',
      feature: 'invitations',
      source: 'InvitationsRepositoryImpl',
      fetch: remote.getInvitations,
    );
  }

  @override
  Future<Either<Failure, void>> acceptInvitation(String invitationId) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.acceptInvitation(invitationId),
      reason: 'acceptInvitation',
    );
    return result.fold(
      (failure) => Left(failure),
      (_) {
        _cache.invalidate(_listKey);
        return const Right(null);
      },
    );
  }

  @override
  Future<Either<Failure, void>> declineInvitation(String invitationId) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.declineInvitation(invitationId),
      reason: 'declineInvitation',
    );
    return result.fold(
      (failure) => Left(failure),
      (_) {
        _cache.invalidate(_listKey);
        return const Right(null);
      },
    );
  }

  @override
  void clearCache() {
    _cache.invalidate();
  }
}
