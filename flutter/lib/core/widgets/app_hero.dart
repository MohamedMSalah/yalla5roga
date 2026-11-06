import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';

/// Shared-element wrapper for cover images and avatars.
///
/// - Skips the [Hero] entirely when [tag] is null so callers can pass an
///   optional tag straight through (deep links, notifications, etc.).
/// - Skips it when motion is reduced; the route still fades.
/// - Owns the corner clip: pass the *unclipped* image as [child] and the
///   surface [radius] here. At rest the child is clipped to [radius]; during
///   the flight the radius is interpolated between the two surfaces so a 12r
///   thumbnail does not snap to a 24r cover mid-air.
/// - The flight shows the artwork that was already on screen (source on
///   push, destination-of-pop on pop), so nothing has to decode mid-flight.
class AppHero extends StatelessWidget {
  const AppHero({
    super.key,
    required this.tag,
    required this.child,
    this.radius,
    this.url,
  });

  final String? tag;
  final Widget child;

  /// Corner radius of [child] on this surface.
  final double? radius;

  /// Artwork URL on this surface. Empty/missing URLs skip the Hero so a
  /// placeholder cannot fly into a photo that the API later hydrates
  /// (or the reverse).
  final String? url;

  @override
  Widget build(BuildContext context) {
    final heroTag = tag;
    final clipped = _HeroSurface(radius: radius, child: child);
    final hasArt = url == null || url!.trim().isNotEmpty;
    if (heroTag == null ||
        heroTag.isEmpty ||
        !hasArt ||
        AppMotion.reduce(context)) {
      return clipped;
    }
    return Hero(tag: heroTag, flightShuttleBuilder: _shuttle, child: clipped);
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final fromSurface = _HeroSurface.from(fromContext);
    final toSurface = _HeroSurface.from(toContext);
    final isPush = direction == HeroFlightDirection.push;

    // Artwork that was visible before the flight began is already decoded.
    final visibleHero = (isPush ? fromContext : toContext).widget as Hero;
    final visibleSurface = isPush ? fromSurface : toSurface;
    final artwork = visibleSurface?.child ?? visibleHero.child;

    final startRadius = fromSurface?.radius ?? toSurface?.radius;
    final endRadius = toSurface?.radius ?? fromSurface?.radius;
    if (startRadius == null || endRadius == null) return artwork;

    final curve = isPush ? AppMotion.enter : AppMotion.exit;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = curve.transform(animation.value);
        return ClipRRect(
          borderRadius: BorderRadius.circular(
            startRadius + (endRadius - startRadius) * t,
          ),
          child: child,
        );
      },
      child: artwork,
    );
  }
}

/// Clips [child] to [radius] and lets the flight shuttle read the surface
/// radius and the raw artwork from the Hero's direct child.
class _HeroSurface extends StatelessWidget {
  const _HeroSurface({required this.radius, required this.child});

  final double? radius;
  final Widget child;

  static _HeroSurface? from(BuildContext heroContext) {
    final hero = heroContext.widget;
    if (hero is Hero && hero.child is _HeroSurface) {
      return hero.child as _HeroSurface;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final r = radius;
    if (r == null) return child;
    return ClipRRect(borderRadius: BorderRadius.circular(r), child: child);
  }
}
