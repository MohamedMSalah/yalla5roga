class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'http://10.0.2.2:3000',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Auth — identity from Firebase ID token (Bearer); no passwords in PostgreSQL.
  // POST register creates/upserts the `users` row using the verified token UID.
  static const String register = '/auth/register';

  /// Unused by the app: login is Firebase-only; APIs use Bearer ID tokens.
  static const String login = '/auth/login';

  // User
  static const String profile = '/user/profile';
  static const String unreadCounts = '/user/unread-counts';
  static const String savedOutings = '/user/saved-outings';
  static const String fcmToken = '/user/fcm-token';

  static String savedOuting(String id) => '/user/saved-outings/$id';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsRead = '/notifications/read';

  static String notificationRead(String id) => '/notifications/$id/read';

  // Groups (placeholders until Node.js backend)
  static const String groups = '/groups';

  static String group(String groupId) => '/groups/$groupId';

  static String groupMembers(String groupId) => '/groups/$groupId/members';

  static String groupLeave(String groupId) => '/groups/$groupId/leave';

  // Outings (placeholders until Node.js backend)
  static const String outings = '/outings';

  static String outing(String outingId) => '/outings/$outingId';

  static String outingVotes(String outingId) => '/outings/$outingId/votes';

  static String outingAttendance(String outingId) =>
      '/outings/$outingId/attendance';

  static String outingChatMessages(String outingId) =>
      '/outings/$outingId/chat/messages';

  static String outingChatRead(String outingId) =>
      '/outings/$outingId/chat/read';

  // Discover / places (placeholders)
  static const String places = '/places';

  static String place(String placeId) => '/places/$placeId';
}
