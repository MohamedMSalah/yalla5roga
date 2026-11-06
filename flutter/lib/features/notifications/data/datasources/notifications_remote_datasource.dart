import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/notifications/data/models/notification_model.dart';

abstract class NotificationsRemoteDataSource {
  Future<NotificationsFeedModel> getNotifications();

  Future<int> markAllRead();

  Future<int> markRead(String id);
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  const NotificationsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<NotificationsFeedModel> getNotifications() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.notifications,
      );
      final items = apiObjectList(
        response.data,
        aliases: const ['notifications', 'items'],
      );
      final models = [
        for (final item in items) NotificationModel.fromJson(_normalize(item)),
      ];
      final unreadCount = models.where((item) => item.unread).length;
      return NotificationsFeedModel(unreadCount: unreadCount, items: models);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<int> markAllRead() async {
    try {
      await _client.patch<Map<String, dynamic>>(
        ApiConstants.notificationsReadAll,
      );
      final feed = await getNotifications();
      return feed.unreadCount;
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<int> markRead(String id) async {
    try {
      await _client.patch<Map<String, dynamic>>(
        ApiConstants.notificationRead(id),
      );
      final feed = await getNotifications();
      return feed.unreadCount;
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> json) {
    final isRead = apiBool(json['is_read']) || apiBool(json['isRead']);
    return {
      ...json,
      'unread': json.containsKey('unread') ? apiBool(json['unread']) : !isRead,
      'image':
          apiString(json['image_url']) ??
          apiString(json['image']) ??
          apiString(json['imageUrl']),
      'outingId':
          apiString(json['outing_id']) ??
          apiString(json['outingId']) ??
          apiString(json['eventId']),
      'groupId': apiString(json['group_id']) ?? apiString(json['groupId']),
      'action': apiBool(json['action_required']) || apiBool(json['action']),
      'createdAt':
          apiString(json['created_at']) ?? apiString(json['createdAt']),
      'time': apiString(json['time']) ?? apiString(json['created_at']) ?? '',
    };
  }

  AppException _unwrap(DioException error) {
    if (error.error is AppException) {
      return error.error as AppException;
    }
    return ServerException(error.message ?? 'Server error');
  }
}
