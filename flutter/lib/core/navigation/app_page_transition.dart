import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';

/// Default push/pop transition for every `Get.to` / `Get.off` / `Get.offAll`.
///
/// Incoming page: fade in while sliding a few percent from the *end* side
/// (right in LTR, left in RTL). Outgoing page: eases slightly toward the start
/// side and dims so the stack reads as layered. Reverse plays the same motion
/// backwards, so back navigation mirrors forward navigation.
///
/// Only used where GetX falls through to `Get.customTransition`; iOS keeps
/// `Transition.cupertino` so the native edge-swipe back gesture survives.
///
/// GetX calls [buildTransition] on every tick, so the curved animations live
/// in a [State] and are disposed with the route — allocating them here would
/// leak tickers and skip frames on Android back / EventPage pops.
class AppPageTransition extends CustomTransition {
  AppPageTransition();

  /// Horizontal travel as a fraction of width.
  static const double _enterOffset = 0.04;
  static const double _exitOffset = 0.015;

  /// GetX hands over `Transition.cupertino` on iOS, our fade-slide elsewhere.
  static Transition? defaultTransition() =>
      GetPlatform.isIOS ? Transition.cupertino : null;

  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduce(context)) return child;
    return _AppPageTransitionBody(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _AppPageTransitionBody extends StatefulWidget {
  const _AppPageTransitionBody({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_AppPageTransitionBody> createState() => _AppPageTransitionBodyState();
}

class _AppPageTransitionBodyState extends State<_AppPageTransitionBody> {
  CurvedAnimation? _primary;
  CurvedAnimation? _secondary;
  Animation<Offset>? _enterSlide;
  Animation<Offset>? _exitSlide;
  Animation<double>? _exitFade;
  TextDirection? _direction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final direction = Directionality.of(context);
    if (_direction != direction) {
      _direction = direction;
      _rebuildTweens();
    }
  }

  @override
  void didUpdateWidget(covariant _AppPageTransitionBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _rebuildTweens();
    }
  }

  void _rebuildTweens() {
    _primary?.dispose();
    _secondary?.dispose();
    final dir = _direction == TextDirection.rtl ? -1.0 : 1.0;
    _primary = CurvedAnimation(
      parent: widget.animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    _secondary = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    _enterSlide = Tween<Offset>(
      begin: Offset(AppPageTransition._enterOffset * dir, 0),
      end: Offset.zero,
    ).animate(_primary!);
    _exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-AppPageTransition._exitOffset * dir, 0),
    ).animate(_secondary!);
    _exitFade = Tween<double>(begin: 1, end: 0.92).animate(_secondary!);
  }

  @override
  void dispose() {
    _primary?.dispose();
    _secondary?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _exitSlide!,
      child: FadeTransition(
        opacity: _exitFade!,
        child: FadeTransition(
          opacity: _primary!,
          child: SlideTransition(position: _enterSlide!, child: widget.child),
        ),
      ),
    );
  }
}
