import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

enum HeaderIllustration { cairo, people, calendar }

/// A decorative illustration behind live header content.
class IllustratedHeader extends StatelessWidget {
  const IllustratedHeader({
    super.key,
    required this.illustration,
    required this.child,
    this.height = 104,
  });

  final HeaderIllustration illustration;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          PositionedDirectional(
            end: 0,
            bottom: 0,
            width: 192,
            height: height,
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _HeaderArt(
                    illustration,
                    palette.brandStrong,
                    palette.brandSoft,
                    palette.background,
                    palette.isDark,
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
        ],
      ),
    );
  }
}

class _HeaderArt extends CustomPainter {
  const _HeaderArt(this.kind, this.accent, this.tint, this.base, this.dark);
  final HeaderIllustration kind;
  final Color accent, tint, base;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 192, size.height / 104);
    final bounds = const Rect.fromLTWH(0, 0, 192, 104);
    final opacity = dark ? 1.0 : .66;
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(.4, .35),
        radius: .64,
        colors: [
          accent.withValues(alpha: .26 * opacity),
          tint.withValues(alpha: 0),
        ],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
    paint.shader = null;

    void shape(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, paint..color = color);
    }

    final hill = Color.lerp(base, accent, dark ? .18 : .13)!;
    final violet = accent.withValues(alpha: .68 * opacity);
    switch (kind) {
      case HeaderIllustration.cairo:
        canvas.drawCircle(const Offset(109, 30), 9, paint..color = violet);
        shape(const [
          Offset(58, 89),
          Offset(99, 49),
          Offset(136, 89),
        ], Color.lerp(tint, const Color(0xFFB7669B), .52)!);
        shape(const [
          Offset(102, 89),
          Offset(130, 61),
          Offset(159, 89),
        ], Color.lerp(tint, accent, .45)!);
        for (var i = 0; i < 13; i++) {
          final h = (9 + i * 7 % 17).toDouble();
          final x = 33 + i * 11.0;
          canvas.drawRect(Rect.fromLTWH(x, 92 - h, 9, h), paint..color = hill);
          for (var j = 1; j * 5 < h; j++) {
            canvas.drawRect(
              Rect.fromLTWH(x + 2.5, 92 - j * 5.0, 2, 1.5),
              paint..color = violet,
            );
          }
        }
        final tower = Path()
          ..moveTo(151, 88)
          ..lineTo(154, 31)
          ..lineTo(157, 31)
          ..lineTo(160, 88)
          ..close();
        canvas.drawPath(tower, paint..color = violet);
        canvas.drawLine(
          const Offset(155.5, 31),
          const Offset(155.5, 13),
          paint..strokeWidth = 1,
        );
        canvas.drawOval(const Rect.fromLTWH(151, 25, 9, 8), paint);
        for (var y = 38.0; y < 85; y += 6) {
          canvas.drawLine(
            Offset(154, y),
            Offset(158, y + 4),
            paint..color = tint,
          );
        }
        canvas.drawOval(
          const Rect.fromLTWH(0, 88, 214, 52),
          paint..color = hill,
        );
      case HeaderIllustration.people:
        for (final (x, y, r) in [
          (93.0, 53.0, 9.0),
          (121.0, 43.0, 12.0),
          (149.0, 53.0, 9.0),
        ]) {
          canvas.drawCircle(Offset(x, y), r, paint..color = violet);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(x, y + 2 * r + 8),
                width: r * 3.7,
                height: r * 2.4,
              ),
              Radius.circular(r),
            ),
            paint,
          );
        }
        canvas.drawOval(
          const Rect.fromLTWH(32, 83, 171, 50),
          paint..color = hill,
        );
      case HeaderIllustration.calendar:
        canvas.drawOval(
          const Rect.fromLTWH(37, 71, 165, 52),
          paint..color = hill,
        );
        canvas.save();
        canvas.translate(123, 62);
        canvas.rotate(math.pi / 16);
        final card = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-38, -28, 76, 58),
          const Radius.circular(10),
        );
        canvas.drawRRect(card.shift(const Offset(0, 4)), paint..color = tint);
        canvas.drawRRect(
          card,
          paint..color = Color.lerp(accent, Colors.white, .62)!,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-38, -28, 76, 16),
            const Radius.circular(8),
          ),
          paint..color = accent,
        );
        for (var i = 0; i < 4; i++) {
          final x = -27 + i * 17.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, -34, 5, 16),
              const Radius.circular(3),
            ),
            paint..color = tint,
          );
          for (var j = 0; j < 2; j++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, -6 + j * 15.0, 10, 10),
                const Radius.circular(2),
              ),
              paint..color = violet,
            );
          }
        }
        final pin = Path()
          ..moveTo(25, 28)
          ..quadraticBezierTo(4, 9, 15, 0)
          ..arcToPoint(const Offset(35, 0), radius: const Radius.circular(13))
          ..quadraticBezierTo(46, 9, 25, 28)
          ..close();
        canvas.drawPath(pin, paint..color = const Color(0xFF6930C4));
        canvas.drawCircle(const Offset(25, 6), 5, paint..color = Colors.white);
        canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeaderArt oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.accent != accent ||
      oldDelegate.tint != tint ||
      oldDelegate.base != base ||
      oldDelegate.dark != dark;
}
