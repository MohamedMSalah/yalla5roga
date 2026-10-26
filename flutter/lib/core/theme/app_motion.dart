import 'package:flutter/widgets.dart';

/// Motion tokens shared by every presentation-layer animation.
///
/// The app already settled on ~180ms implicit tweens for chips, cards and
/// the nav pill. These tokens keep new motion on the same scale so frequent
/// actions never feel slow.
class AppMotion {
  const AppMotion._();

  /// Press feedback, icon swaps, tiny state changes.
  static const Duration press = Duration(milliseconds: 140);

  /// Standard UI transitions: content reveals, tab bodies, selection.
  static const Duration standard = Duration(milliseconds: 200);

  /// Expressive transitions: page pushes and shared-element flights.
  static const Duration emphasis = Duration(milliseconds: 320);

  /// Bottom sheets rise a touch slower than they dismiss.
  static const Duration sheetEnter = Duration(milliseconds: 280);
  static const Duration sheetExit = Duration(milliseconds: 200);

  /// Entering elements decelerate into place.
  static const Curve enter = Curves.easeOutCubic;

  /// Leaving elements accelerate away.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric curve for in-place state changes (fill, scale, colour).
  static const Curve settle = Curves.easeInOut;

  /// Press scale for cards and tiles. Small on purpose; the goal is tactile
  /// acknowledgement, not a bounce.
  static const double pressScale = 0.98;

  /// Reveal offset (logical px) for fade + translate content transitions.
  static const double revealOffset = 8;

  /// Honour the platform "reduce motion" / "disable animations" setting.
  static bool reduce(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Duration that collapses to zero when motion is reduced.
  static Duration of(BuildContext context, Duration duration) =>
      reduce(context) ? Duration.zero : duration;
}

/// Stable, surface-scoped Hero tags.
///
/// Home, Outings and Discover sections can show the same outing or place on
/// one Navigator route (the shell is an `IndexedStack`), so each list passes
/// its own `surface` to keep tags unique and the details page receives the
/// exact tag of the card that was tapped.
class HeroTags {
  const HeroTags._();

  /// Null when the id is missing so live API stubs never share one empty tag.
  static String? outingCover(String surface, String outingId) =>
      _cover('outing-cover', surface, outingId);

  static String? placeCover(String surface, String placeId) =>
      _cover('place-cover', surface, placeId);

  static String? groupCover(String groupId) {
    final id = groupId.trim();
    if (id.isEmpty) return null;
    return 'group-cover-$id';
  }

  static const String profileAvatar = 'profile-avatar';

  static String? _cover(String prefix, String surface, String id) {
    final trimmedId = id.trim();
    final trimmedSurface = surface.trim();
    if (trimmedId.isEmpty || trimmedSurface.isEmpty) return null;
    return '$prefix-$trimmedSurface-$trimmedId';
  }
}
