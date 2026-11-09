import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';

class AnimatedCheckmark extends StatelessWidget {
  const AnimatedCheckmark({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primaryContainer,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: AppMotion.reduce(context) ? 1.0 : 0.0, end: 1.0),
          duration: AppMotion.of(context, const Duration(milliseconds: 450)),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CustomPaint(
            size: const Size.square(56),
            painter: _CheckPainter(progress, colors.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * .28, size.height * .52);
    final corner = Offset(size.width * .43, size.height * .67);
    final end = Offset(size.width * .73, size.height * .36);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(end.dx, end.dy);
    final measure = path.computeMetrics().single;
    canvas.drawPath(
      measure.extractPath(0, lerpDouble(0, measure.length, progress)!),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
