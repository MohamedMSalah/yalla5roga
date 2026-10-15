class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.body,
    required this.time,
    required this.unread,
    this.image,
    this.outingId,
    this.groupId,
    this.action = false,
    this.createdAt,
    this.type,
  });

  final String id;
  final String body;

  /// Relative display time (or format [createdAt] in presentation).
  final String time;
  final bool unread;
  final String? image;

  /// Canonical outing deep-link id. [eventId] is a legacy alias.
  final String? outingId;
  final String? groupId;
  final bool action;
  final DateTime? createdAt;
  final String? type;

  /// Legacy alias used by older UI / JSON payloads.
  String? get eventId => outingId;

  bool get isEarlier => time.toLowerCase().contains('yesterday');

  NotificationItem copyWith({bool? unread}) {
    return NotificationItem(
      id: id,
      body: body,
      time: time,
      unread: unread ?? this.unread,
      image: image,
      outingId: outingId,
      groupId: groupId,
      action: action,
      createdAt: createdAt,
      type: type,
    );
  }
}

class NotificationsFeed {
  const NotificationsFeed({required this.unreadCount, required this.items});

  final int unreadCount;
  final List<NotificationItem> items;
}
