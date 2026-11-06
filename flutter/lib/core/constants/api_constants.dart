class ApiConstants {
  const ApiConstants._();

  // Relative paths under the API host. Include `/api` so API_BASE_URL stays
  // host-only (e.g. http://10.0.2.2:3000). Contract: docs/system-design/openapi-contract-freeze.md

  // Auth — email/password via backend (Neon); Google/Apple/OTP via Firebase,
  // then Bearer Firebase ID token on all other APIs.
  /// Canonical provisioning after Google / Apple / phone Firebase sign-in.
  static const String syncUser = '/api/users/sync';

  /// Canonical email/password login (Neon hash → Firebase custom/ID token).
  static const String login = '/api/auth/login';

  /// Canonical email/password signup (Neon hash + Firebase identity, no Firebase password).
  static const String signup = '/api/auth/signup';

  // User
  static const String profile = '/api/users/cuser';
  static const String unreadCounts = '/api/user/unread-counts';
  static const String savedOutings = '/api/outings/saved';
  static const String fcmToken = '/api/user/fcm-token';

  static String savedOuting(String id) => '/api/outings/$id/save';

  // Notifications
  static const String notifications = '/api/notifications';
  static const String notificationsReadAll = '/api/notifications/read';

  static String notificationRead(String id) => '/api/notifications/$id/read';

  // Groups
  static const String groups = '/api/groups';
  static const String groupsCuser = '/api/groups/cuser';

  static String group(String groupId) => '/api/groups/$groupId';

  static String groupMembers(String groupId) => '/api/groups/$groupId/members';

  static String groupMember(String groupId, String userId) =>
      '/api/groups/$groupId/members/$userId';

  static String groupInvitations(String groupId) =>
      '/api/groups/$groupId/invitations';

  // Outings
  static const String outings = '/api/outings';
  static const String outingsCuser = '/api/outings/cuser';

  static String outing(String outingId) => '/api/outings/$outingId';

  static String outingVotes(String outingId) => '/api/outings/$outingId/votes';

  static String outingVoteOptions(String outingId) =>
      '/api/outings/$outingId/vote-options';

  static String outingVoteOption(String outingId, String optionId) =>
      '/api/outings/$outingId/vote-options/$optionId';

  static String outingVotingState(String outingId) =>
      '/api/outings/$outingId/voting-state';

  static String outingTieBreak(String outingId) =>
      '/api/outings/$outingId/tie-break';

  static String outingCancel(String outingId) =>
      '/api/outings/$outingId/cancel';

  static String outingAttendance(String outingId) =>
      '/api/outings/$outingId/attendance';

  static String outingGuests(String outingId) =>
      '/api/outings/$outingId/guests';

  static String outingInvitationAccept(String outingId) =>
      '/api/outings/$outingId/invitations/accept';

  static String outingInvitationDecline(String outingId) =>
      '/api/outings/$outingId/invitations/decline';

  static const String savedPlaces = '/api/places/saved';

  static String savedPlace(String id) => '/api/places/$id/save';

  // Chat
  static String outingChatMessages(String outingId) =>
      '/api/chat/outings/$outingId/messages';

  static String outingChatRead(String outingId) =>
      '/api/chat/outings/$outingId/read';

  // Discover / places
  static const String places = '/api/places';

  static String place(String placeId) => '/api/places/$placeId';
}
