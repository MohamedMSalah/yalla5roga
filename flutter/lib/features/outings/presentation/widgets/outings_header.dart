import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outings_style.dart';

class OutingsBackground extends StatelessWidget {
  const OutingsBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = OutingsStyle(context);
    if (style.highContrast) {
      return ColoredBox(color: style.scheme.surface, child: child);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.dark
              ? const [Color(0xFF171321), Color(0xFF100F18)]
              : const [Color(0xFFF6EEFC), Color(0xFFFCF9FF)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const AlignmentDirectional(.54, -.88),
            radius: .62,
            colors: style.dark
                ? const [Color(0xFF35204E), Color(0x0035204E)]
                : const [Color(0xFFEADAF8), Color(0x00EADAF8)],
          ),
        ),
        child: child,
      ),
    );
  }
}

class OutingsHeader extends StatelessWidget {
  const OutingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = OutingsStyle(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 320;
        final showCalendar =
            width >= 250 && MediaQuery.textScalerOf(context).scale(14) <= 22;
        final artSize = (width * .24).clamp(62.0, 104.0);
        return Stack(
          children: [
            if (!style.highContrast)
              PositionedDirectional(
                top: 0,
                bottom: 0,
                end: -6,
                width: (width * .49).clamp(124.0, 248.0),
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _OutingHills(
                        dark: style.dark,
                        rtl: Directionality.of(context) == TextDirection.rtl,
                      ),
                    ),
                  ),
                ),
              ),
            if (showCalendar)
              PositionedDirectional(
                end: compact ? 11 : 45,
                bottom: 0,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/outings/calendar_pin.webp',
                    width: artSize,
                    height: artSize * .94,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: 8,
                end: showCalendar ? artSize + (compact ? 18 : 52) : 57,
                top: 29,
                bottom: 13,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        context.l10n.outingsTitle,
                        style: style.label(
                          context,
                          30,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.outingsHeaderBody,
                      style: style.label(context, 14, color: style.muted),
                    ),
                  ],
                ),
              ),
            ),
            const PositionedDirectional(
              top: 0,
              end: 0,
              child: NotificationButton(showUnreadDot: true),
            ),
          ],
        );
      },
    );
  }
}

class _OutingHills extends CustomPainter {
  const _OutingHills({required this.dark, required this.rtl});

  final bool dark;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 110);
    if (rtl) {
      canvas.translate(200, 0);
      canvas.scale(-1, 1);
    }
    final ridge = Path()
      ..moveTo(10, 101)
      ..cubicTo(45, 78, 57, 7, 88, 7)
      ..cubicTo(116, 5, 142, 60, 190, 102)
      ..close();
    final foreground = Path()
      ..moveTo(0, 108)
      ..cubicTo(18, 89, 37, 63, 52, 72)
      ..cubicTo(70, 76, 84, 96, 104, 96)
      ..cubicTo(145, 91, 132, 22, 200, 97)
      ..lineTo(200, 110)
      ..close();
    Color tint(int darkColor, int lightColor) =>
        Color(dark ? darkColor : lightColor);
    canvas.drawPath(
      ridge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint(0xAA7846AE, 0x66AC78DE), const Color(0x00683CA3)],
          stops: const [0, .95],
        ).createShader(const Rect.fromLTWH(0, 7, 200, 102)),
    );
    canvas.drawPath(
      foreground,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint(0x907043AA, 0x72B487DC), const Color(0x00683CA3)],
        ).createShader(const Rect.fromLTWH(0, 55, 200, 55)),
    );
    final cloud = Path()
      ..moveTo(15, 34)
      ..quadraticBezierTo(22, 25, 29, 28)
      ..cubicTo(36, 23, 46, 23, 52, 34)
      ..close();
    canvas.drawPath(cloud, Paint()..color = tint(0x986F439F, 0x77B384D8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OutingHills oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.rtl != rtl;
}
