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
    this.meetupSessionId,
    this.expiresAt,
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
  final String? meetupSessionId;
  final String? expiresAt;

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
      meetupSessionId: meetupSessionId,
      expiresAt: expiresAt,
    );
  }
}

class NotificationsFeed {
  const NotificationsFeed({
    required this.unreadCount,
    required this.items,
    this.preferences = const {},
  });

  final int unreadCount;
  final List<NotificationItem> items;
  final Map<String, bool> preferences;
}
