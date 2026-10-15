import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';

abstract class NotificationsRepository {
  Future<Either<Failure, NotificationsFeed>> getNotifications({
    bool forceRefresh = false,
  });

  Future<Either<Failure, int>> markAllRead();

  Future<Either<Failure, int>> markRead(String id);
}
