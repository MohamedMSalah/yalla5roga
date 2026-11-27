class ApiConstants {
  const ApiConstants._();

  static String groupSmartMeetup(String groupId) =>
      '/api/groups/$groupId/smart-meetup';
  static String meetupStartingLocation(String id) =>
      '${smartMeetup(id)}/my-starting-location';
  static String outingStartingLocation(String id) =>
      '${outing(id)}/my-starting-location';
  static String smartMeetup(String id) => '/api/smart-meetups/$id';
  static String meetupLocationRequests(String id) =>
      '${smartMeetup(id)}/location-requests';
  static const departureReminderPreferences =
      '/api/users/me/departure-reminder-preferences';
  static String myDepartureReminder(String id) =>
      '${outing(id)}/my-departure-reminder';
  static String myMeetupRoute(String id, String placeId) =>
      '${smartMeetup(id)}/recommendations/$placeId/my-route';
  static String myOutingRoute(String id) => '${outing(id)}/my-route';
  static String meetupResults(String id) => '${smartMeetup(id)}/results';
  static String calculateMeetup(String id) => '${smartMeetup(id)}/calculate';
  static String meetupCalculation(String id, String calculationId) =>
      '${smartMeetup(id)}/calculations/$calculationId';
  static const standaloneMeetup = '/api/smart-meetups/standalone';
  static const meetupFilterOptions = '/api/smart-meetups/filter-options';
  static String meetupPreferences(String id) =>
      '${smartMeetup(id)}/preferences';
  static String resetMeetupPreferences(String id) =>
      '${meetupPreferences(id)}/reset';
  static String meetupParticipants(String id) =>
      '${smartMeetup(id)}/participants';
  static String meetupParticipant(String id, String participantId) =>
      '${meetupParticipants(id)}/$participantId';

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

  /// Change Neon `password_hash` (authenticated).
  static const String changePassword = '/api/auth/change-password';

  /// Confirm Neon password without changing it (authenticated).
  static const String verifyPassword = '/api/auth/verify-password';

  static const recoveryStart = '/api/auth/recovery/start';
  static const recoveryVerify = '/api/auth/recovery/verify';
  static const recoveryReset = '/api/auth/recovery/reset';

  // User
  static const String profile = '/api/users/cuser';
  static const String transportationPreferences =
      '/api/users/me/transportation-preferences';
  static const String routingCapabilities = '/api/routing/capabilities';
  static const String savedLocations = '/api/users/me/saved-locations';
  static String savedLocation(String id) => '$savedLocations/$id';
  static const String defaultStartingLocation =
      '/api/users/me/default-starting-location';
  static const String locationPrivacy = '/api/users/me/location-privacy';
  static const String locationConsent = '/api/users/me/location-consent';
  static const String locationExcludedGroups =
      '$locationConsent/excluded-groups';
  static String locationExcludedGroup(String groupId) =>
      '$locationExcludedGroups/${Uri.encodeComponent(groupId)}';
  static const String savedOutings = '/api/outings/saved';
  static const String fcmToken = '/api/users/cuser/fcm-token';

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

  static String pendingGroupMember(String groupId, String invitationId) =>
      '/api/groups/$groupId/pending-memberships/$invitationId';

  static String groupInvitations(String groupId) =>
      '/api/groups/$groupId/invitations';

  // Invitations (user-scoped)
  static const String invitations = '/api/invitations';

  static String invitationAccept(String invitationId) =>
      '/api/invitations/$invitationId/accept';

  static String invitationDecline(String invitationId) =>
      '/api/invitations/$invitationId/decline';

  // Outings
  static const String outings = '/api/outings';
  static const String outingDrafts = '/api/outings/drafts';
  static String outingDraft(String id) => '$outingDrafts/$id';
  static String outingGuest(String id, String userId) =>
      '${outingGuests(id)}/${Uri.encodeComponent(userId)}';

  static const String outingsCuser = '/api/outings/cuser';

  static String outing(String outingId) => '/api/outings/$outingId';

  static String outingVotes(String outingId) => '/api/outings/$outingId/votes';

  static String outingVoteOptions(String outingId) =>
      '/api/outings/$outingId/vote-options';

  static String outingVoteOption(String outingId, String optionId) =>
      '/api/outings/$outingId/vote-options/$optionId';

  static String outingVotingState(String outingId) =>
      '/api/outings/$outingId/voting-state';

  static String outingConfirmedVenue(String outingId) =>
      '/api/outings/$outingId/confirmed-venue';

  static String outingRevote(String outingId) =>
      '/api/outings/$outingId/voting/revote';
  static String outingTieBreak(String outingId) =>
      '/api/outings/$outingId/tie-break';

  static String outingCancel(String outingId) =>
      '/api/outings/$outingId/cancel';

  static String outingArrivals(String id) => '${outing(id)}/arrivals';

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

  // Chat (outing sub-resource)
  static String outingChatMessages(String outingId) =>
      '/api/outings/$outingId/messages';

  static String outingChatRead(String outingId) =>
      '/api/outings/$outingId/read';

  // Discover / places
  static const String places = '/api/places';
  static const String nearbyPlaces = '/api/places/nearby';
  static const String placeGeocoding = '/api/places/geocoding';

  static String place(String placeId) => '/api/places/$placeId';

  static String placeRatings(String id) => '${place(id)}/ratings';
  static String placeReviews(String id) => '${place(id)}/reviews';
  static String myPlaceRating(String id) => '${place(id)}/my-rating';
  static String placeReview(String id, String reviewId) =>
      '${placeReviews(id)}/$reviewId';
  static const String placeReviewBlocks = '/api/places/review-blocks';

  // Media — direct-to-R2 uploads and access-checked delivery URLs.
  static const String mediaUploadUrl = '/api/media/upload-url';
  static const String mediaSignedUrls = '/api/media/signed-urls';

  static String mediaConfirm(String mediaId) => '/api/media/$mediaId/confirm';

  static String mediaAssetUrl(String mediaId) => '/api/media/$mediaId/url';

  static String mediaDelete(String mediaId) => '/api/media/$mediaId';
}
