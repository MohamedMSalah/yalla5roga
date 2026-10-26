import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';

/// Direction of the small translate that accompanies the fade.
enum AppRevealAxis { none, vertical, horizontal }

/// Fade + short translate between content states (skeleton -> list, tab
/// bodies, wizard steps).
///
/// Give [child] a stable [Key] that only changes when the *state* changes
/// (e.g. `ValueKey(hasLoaded)` or `ValueKey(step)`), never on every rebuild,
/// so lists do not replay their entrance when data refreshes.
///
/// Horizontal travel uses the reading direction: `forward = true` slides in
/// from the end side, which is the right in LTR and the left in RTL.
class AppFadeSwitcher extends StatelessWidget {
  const AppFadeSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.standard,
    this.axis = AppRevealAxis.vertical,
    this.forward = true,
    this.alignment = Alignment.topCenter,
    this.sizeCurve = AppMotion.settle,
  });

  final Widget child;
  final Duration duration;
  final AppRevealAxis axis;

  /// Travel direction for [AppRevealAxis.horizontal].
  final bool forward;
  final AlignmentGeometry alignment;
  final Curve sizeCurve;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduce(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Fixed logical-pixel travel (not a fraction of the child) so tall list
    // bodies and small badges move the same short distance.
    Offset begin;
    switch (axis) {
      case AppRevealAxis.none:
        begin = Offset.zero;
      case AppRevealAxis.vertical:
        begin = const Offset(0, AppMotion.revealOffset);
      case AppRevealAxis.horizontal:
        final sign = (forward ? 1 : -1) * (isRtl ? -1 : 1);
        begin = Offset(AppMotion.revealOffset * 3 * sign, 0);
    }

    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : duration,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        if (reduce) return child;
        return FadeTransition(
          opacity: animation,
          child: begin == Offset.zero
              ? child
              : AnimatedBuilder(
                  animation: animation,
                  child: child,
                  builder: (context, child) => Transform.translate(
                    offset: begin * (1 - animation.value),
                    child: child,
                  ),
                ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: alignment,
          // Pass constraints through untouched so wrapped content lays out
          // exactly as it did without the switcher.
          fit: StackFit.passthrough,
          children: [
            // Outgoing children are rendered first so the incoming state sits
            // on top and never flashes underneath.
            ...previousChildren.map(
              (child) => TickerMode(
                enabled: false,
                child: IgnorePointer(child: child),
              ),
            ),
            ?currentChild,
          ],
        );
      },
      child: child,
    );
  }
}
