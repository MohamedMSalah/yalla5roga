/// Shared TTL policies for repository-level API caches.
///
/// Keep TTLs short for feeds that change often; longer for catalogs.
class CachePolicy {
  const CachePolicy._();

  /// Discover places catalog — relatively stable.
  static const Duration discover = Duration(minutes: 10);

  /// Groups list — medium; unread is refreshed separately.
  static const Duration groups = Duration(minutes: 2);

  /// Outings snapshot — votes/attendance change often; mutations invalidate.
  static const Duration outings = Duration(minutes: 2);

  /// Notifications feed — short window to avoid stale unread UI.
  static const Duration notifications = Duration(seconds: 45);
}
