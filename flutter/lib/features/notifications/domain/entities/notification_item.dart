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
    this.eventType,
    this.messageId,
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
  final String? eventType;
  final String? messageId;

  /// Legacy alias used by older UI / JSON payloads.
  String? get eventId => outingId;

  bool get isEarlier {
    final at = createdAt;
    if (at != null) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      return at.isBefore(startOfToday);
    }
    final stamp = time.toLowerCase();
    return stamp.contains('yesterday') || stamp.contains('أمس');
  }

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
      eventType: eventType,
      messageId: messageId,
    );
  }
}

class NotificationsFeed {
  const NotificationsFeed({required this.unreadCount, required this.items});

  final int unreadCount;
  final List<NotificationItem> items;
}
