class AppConstants {
  const AppConstants._();

  static const String appName = 'Yalla 5roga';
  static const String downloadUrl = 'https://yalla5roga.com';
  static const String tokenKey = 'auth_token';
  static const String userCacheKey = 'cached_user';
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'locale';
  static const String savedOutingsKey = 'saved_outings';
  static const String outingDraftsKey = 'outing_drafts';
  static const String locationPromptShownKey = 'location_prompt_shown';
  static const String fcmTokenKey = 'fcm_device_token';

  /// Android FCM / local-notification channel (must match AndroidManifest meta-data).
  static const String fcmAndroidChannelId = 'yalla_5roga_high_importance';
  static const String fcmAndroidChannelName = 'Yalla 5roga';
  static const String fcmAndroidChannelDescription =
      'Outing, group, and chat updates';

  static const String nominatimUserAgent = 'Yalla5roga/1.0';

  static const Duration splashDuration = Duration(seconds: 2);
  static const int minPasswordLength = 8;
  static const int minNameLength = 3;
  static const int maxNameLength = 30;
  static const int maxOutingNameLength = 20;
}
