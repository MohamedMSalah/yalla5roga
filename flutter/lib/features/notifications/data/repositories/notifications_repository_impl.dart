import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({
    required this.remote,
    required this.networkInfo,
  });

  final NotificationsRemoteDataSource remote;
  final NetworkInfo networkInfo;

  static const _feedKey = 'feed';
  final _feedCache = TtlCache<NotificationsFeed>(
    ttl: CachePolicy.notifications,
  );

  @override
  Future<Either<Failure, NotificationsFeed>> getNotifications({
    bool forceRefresh = false,
  }) {
    return cachedRemote(
      networkInfo: networkInfo,
      cache: _feedCache,
      key: _feedKey,
      forceRefresh: forceRefresh,
      reason: 'getNotifications',
      fetch: remote.getNotifications,
    );
  }

  @override
  Future<Either<Failure, int>> markAllRead() async {
    final result = await guardRemote(
      networkInfo,
      remote.markAllRead,
      reason: 'markAllRead',
    );
    // Unread state changed — drop feed cache.
    result.fold((_) {}, (_) => _feedCache.invalidate(_feedKey));
    return result;
  }

  @override
  Future<Either<Failure, int>> markRead(String id) async {
    final result = await guardRemote(
      networkInfo,
      () => remote.markRead(id),
      reason: 'markRead',
    );
    result.fold((_) {}, (_) => _feedCache.invalidate(_feedKey));
    return result;
  }
}
