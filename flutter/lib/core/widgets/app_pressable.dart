import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
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
  var _focused = false;

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
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: _focused
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: GestureDetector(
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
          ),
        ),
      ),
    );
  }
}
