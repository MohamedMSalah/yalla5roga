import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';

class NotificationModel extends NotificationItem {
  const NotificationModel({
    required super.id,
    required super.body,
    required super.time,
    required super.unread,
    super.image,
    super.outingId,
    super.groupId,
    super.action,
    super.createdAt,
    super.type,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: apiString(json['id']) ?? '',
      body: apiString(json['body']) ?? '',
      time: apiString(json['time']) ?? '',
      unread: apiBool(json['unread']),
      image: apiString(json['image']),
      outingId: apiString(json['outingId']) ?? apiString(json['eventId']),
      groupId: apiString(json['groupId']),
      action: apiBool(json['action']),
      type: apiString(json['type']),
      createdAt: DateTime.tryParse(apiString(json['createdAt']) ?? ''),
    );
  }
}

class NotificationsFeedModel extends NotificationsFeed {
  const NotificationsFeedModel({
    required super.unreadCount,
    required super.items,
  });

  factory NotificationsFeedModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return NotificationsFeedModel(
      unreadCount: apiInt(json['unreadCount']),
      items: [
        if (rawItems is List)
          for (final item in rawItems)
            if (item is Map)
              NotificationModel.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}
