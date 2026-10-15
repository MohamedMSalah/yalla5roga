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
      return NotificationsFeedModel.fromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<int> markAllRead() {
    return _postUnreadCount(ApiConstants.notificationsRead);
  }

  @override
  Future<int> markRead(String id) {
    return _postUnreadCount(ApiConstants.notificationRead(id));
  }

  Future<int> _postUnreadCount(String path) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(path);
      return apiInt(apiPayload(response.data)['unreadCount']);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  AppException _unwrap(DioException error) {
    if (error.error is AppException) {
      return error.error as AppException;
    }
    return ServerException(error.message ?? 'Server error');
  }
}
