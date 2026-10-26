import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';

/// Tap target with a subtle scale-down while pressed.
///
/// Used by cards and tiles that previously relied on a bare
/// [GestureDetector] and gave no feedback. Scale is tiny ([AppMotion.pressScale])
/// and snaps back on release/cancel so scrolling lists never feel sticky.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;
  final bool enabled;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  var _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_interactive) return widget.child;

    final reduce = AppMotion.reduce(context);
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !reduce ? AppMotion.pressScale : 1,
        // Instant restore so a Hero flight does not measure a 0.98
        // transform from the still-running press tween.
        duration: _pressed && !reduce ? AppMotion.press : Duration.zero,
        curve: AppMotion.settle,
        child: widget.child,
      ),
    );
  }
}
