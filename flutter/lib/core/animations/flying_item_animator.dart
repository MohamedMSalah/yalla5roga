import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';

/// Flies a temporary copy of a source widget (typically an image) along a
/// curved path toward a target widget using an [OverlayEntry].
///
/// Keep business logic (save/unsave, cart, etc.) outside this helper — call
/// [fly] only after the operation succeeds.
class FlyingItemAnimator {
  FlyingItemAnimator._();

  static OverlayEntry? _active;
  static Completer<void>? _activeCompleter;

  /// Whether a flight is currently in progress.
  static bool get isFlying => _active != null;

  /// Animate [imageUrl] from [sourceKey] to [targetKey].
  ///
  /// Returns immediately (without flying) when:
  /// - a flight is already running
  /// - either key has no attached [RenderBox]
  /// - reduce-motion is enabled (still invokes [onArrived])
  static Future<void> fly({
    required BuildContext context,
    required GlobalKey sourceKey,
    required GlobalKey targetKey,
    required String imageUrl,
    double borderRadius = 24,
    Duration duration = const Duration(milliseconds: 700),
    VoidCallback? onArrived,
  }) async {
    if (_active != null) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      onArrived?.call();
      return;
    }

    if (AppMotion.reduce(context)) {
      onArrived?.call();
      return;
    }

    final sourceBox =
        sourceKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (sourceBox == null ||
        !sourceBox.hasSize ||
        !sourceBox.attached ||
        targetBox == null ||
        !targetBox.hasSize ||
        !targetBox.attached) {
      onArrived?.call();
      return;
    }

    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize) {
      onArrived?.call();
      return;
    }

    final sourceOrigin = sourceBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final targetOrigin = targetBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final sourceSize = sourceBox.size;
    final targetSize = targetBox.size;

    final startRect = sourceOrigin & sourceSize;
    final endCenter =
        targetOrigin + Offset(targetSize.width / 2, targetSize.height / 2);
    // Land as a small thumbnail centered on the bookmark icon.
    final endSize = Size(
      math.min(28.0, targetSize.width * 0.85),
      math.min(28.0, targetSize.height * 0.85),
    );
    final endRect = Rect.fromCenter(
      center: endCenter,
      width: endSize.width,
      height: endSize.height,
    );

    final completer = Completer<void>();
    _activeCompleter = completer;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyingItemOverlay(
        startRect: startRect,
        endRect: endRect,
        imageUrl: imageUrl,
        borderRadius: borderRadius,
        duration: duration,
        onArrived: onArrived,
        onFinished: () {
          entry.remove();
          if (identical(_active, entry)) {
            _active = null;
            _activeCompleter = null;
          }
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    _active = entry;
    overlay.insert(entry);
    return completer.future;
  }

  /// Cancel any in-flight animation and free resources.
  static void cancel() {
    final entry = _active;
    final completer = _activeCompleter;
    _active = null;
    _activeCompleter = null;
    entry?.remove();
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

class _FlyingItemOverlay extends StatefulWidget {
  const _FlyingItemOverlay({
    required this.startRect,
    required this.endRect,
    required this.imageUrl,
    required this.borderRadius,
    required this.duration,
    required this.onFinished,
    this.onArrived,
  });

  final Rect startRect;
  final Rect endRect;
  final String imageUrl;
  final double borderRadius;
  final Duration duration;
  final VoidCallback onFinished;
  final VoidCallback? onArrived;

  @override
  State<_FlyingItemOverlay> createState() => _FlyingItemOverlayState();
}

class _FlyingItemOverlayState extends State<_FlyingItemOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  late final Animation<double> _opacity;
  late final Animation<double> _rotation;
  var _arrivedNotified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 70),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);
    _rotation = Tween<double>(
      begin: -0.08,
      end: 0.28,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_arrivedNotified) {
          _arrivedNotified = true;
          widget.onArrived?.call();
        }
        widget.onFinished();
      }
    });
    _controller.addListener(() {
      // Fire bounce slightly before the end so it feels connected.
      if (!_arrivedNotified && _controller.value >= 0.92) {
        _arrivedNotified = true;
        widget.onArrived?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Quadratic Bezier: start → control → end.
  Offset _pointAt(double t) {
    final start = widget.startRect.center;
    final end = widget.endRect.center;
    final mid = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - 80,
    );
    final u = 1 - t;
    return Offset(
      u * u * start.dx + 2 * u * t * mid.dx + t * t * end.dx,
      u * u * start.dy + 2 * u * t * mid.dy + t * t * end.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _curved.value;
          final center = _pointAt(t);
          final width = lerpDouble(
            widget.startRect.width,
            widget.endRect.width,
            t,
          )!;
          final height = lerpDouble(
            widget.startRect.height,
            widget.endRect.height,
            t,
          )!;
          final radius = lerpDouble(
            widget.borderRadius,
            widget.borderRadius * 0.35,
            t,
          )!;

          return Stack(
            children: [
              Positioned(
                left: center.dx - width / 2,
                top: center.dy - height / 2,
                width: width,
                height: height,
                child: Opacity(
                  opacity: _opacity.value.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: _rotation.value,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: AppNetworkImage(
          url: widget.imageUrl,
          width: widget.startRect.width,
          height: widget.startRect.height,
          placeholderIcon: Icons.explore_outlined,
          fade: false,
        ),
      ),
    );
  }
}
