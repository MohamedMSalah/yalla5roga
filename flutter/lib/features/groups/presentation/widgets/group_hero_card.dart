import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';

class GroupHeroCard extends StatelessWidget {
  const GroupHeroCard({
    super.key,
    required this.group,
    this.memberCount,
    this.outingCount,
    this.role,
    this.compact = false,
  });

  final Group group;
  final int? memberCount, outingCount;
  final String? role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = [
      if (memberCount case final count?) l10n.groupMemberCount(count),
      if (outingCount case final count?) l10n.groupOutingCount(count),
    ];
    final size = compact ? 90.0 : 94.0;
    final radius = BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: const Color(0x447C48BC)),
        ),
        child: CustomPaint(
          painter: const _GroupArtwork(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: compact ? 177 : 206,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                compact ? 12 : 20,
                16,
                compact ? 12 : 16,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x457832E0), blurRadius: 12),
                      ],
                    ),
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF873ED5),
                          width: 1.5,
                        ),
                      ),
                      child: AppHero(
                        tag: HeroTags.groupCover(group.id),
                        url: group.image,
                        radius: size / 2,
                        child: AppNetworkImage(
                          url: group.image,
                          width: size,
                          height: size,
                          fade: false,
                          placeholder: CustomPaint(
                            size: Size.square(size),
                            painter: const _GroupEmblem(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 19),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 5,
                    children: [
                      Text(
                        group.name,
                        style: context.texts.headlineSmall?.copyWith(
                          color: const Color(0xFFFAF7FF),
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 24 : 26,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (role case final label?)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF512080),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 15,
                                  color: Color(0xFFDBC2F7),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    label,
                                    style: context.texts.labelMedium?.copyWith(
                                      color: const Color(0xFFF3E4FF),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 19,
                          color: Color(0xFFCCABF8),
                        ),
                        Text(
                          stats.join(' · '),
                          textAlign: TextAlign.center,
                          style: context.texts.bodyMedium?.copyWith(
                            color: const Color(0xFFD1BAEE),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupArtwork extends CustomPainter {
  const _GroupArtwork();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final paint = Paint();
    canvas.drawRect(
      bounds,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6924B7),
            Color(0xFF39186F),
            Color(0xFF211333),
            Color(0xFF191225),
          ],
          stops: [0, .40, .77, 1],
        ).createShader(bounds),
    );

    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(w, h * .10)
        ..cubicTo(w * .83, h * .07, w * .83, h * .51, w * .61, h * .64)
        ..lineTo(w, h)
        ..close(),
      paint
        ..shader = null
        ..color = const Color(0x66190D38),
    );

    final streak = Path()
      ..moveTo(w * .63, h * .29)
      ..lineTo(w * .80, 0)
      ..lineTo(w * .79, 0)
      ..close();
    canvas.drawPath(
      streak,
      paint
        ..shader = const LinearGradient(
          colors: [Colors.transparent, Color(0x668F40ED), Colors.transparent],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(streak.getBounds()),
    );

    final unit = (w / 360).clamp(.74, 1.22);
    void silhouette(double x, double y, double radius, Color color) {
      final center = Offset(w * x, h * y);
      final r = radius * unit;
      canvas.drawCircle(
        center,
        r,
        paint
          ..shader = null
          ..color = color,
      );
      final shoulders = Rect.fromCenter(
        center: center.translate(0, r * 2.75),
        width: r * 5.3,
        height: r * 3.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(shoulders, Radius.circular(r * 1.7)),
        paint
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, const Color(0xFF271646)],
          ).createShader(shoulders),
      );
    }

    silhouette(.28, .40, 9, const Color(0xFF522987));
    silhouette(.11, .36, 10, const Color(0xFF622EA3));
    silhouette(.20, .34, 12, const Color(0xFF7136BA));
    silhouette(.79, .40, 10, const Color(0xFF592D94));
    silhouette(.95, .40, 9, const Color(0xFF512886));
    silhouette(.89, .36, 12, const Color(0xFF6A34AF));

    canvas.drawPath(
      Path()
        ..moveTo(0, h * .82)
        ..cubicTo(w * .27, h * .49, w * .65, h * .46, w, h * .77)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF201339), Color(0xFF191225)],
        ).createShader(Rect.fromLTRB(0, h * .50, w, h)),
    );
  }

  @override
  bool shouldRepaint(_GroupArtwork oldDelegate) => false;
}

class _GroupEmblem extends CustomPainter {
  const _GroupEmblem();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7631C5), Color(0xFF482099), Color(0xFF33206D)],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.scale(size.width / 96, size.height / 96);
    paint
      ..shader = null
      ..color = const Color(0xFFFAF7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(48, 36), 8.5, paint);
    canvas.drawCircle(const Offset(27, 43), 6, paint);
    canvas.drawCircle(const Offset(69, 43), 6, paint);
    canvas.drawPath(
      Path()
        ..moveTo(15, 70)
        ..lineTo(15, 64)
        ..cubicTo(15, 52, 26, 49, 35, 54)
        ..moveTo(81, 70)
        ..lineTo(81, 64)
        ..cubicTo(81, 52, 70, 49, 61, 54)
        ..moveTo(31, 70)
        ..lineTo(31, 62)
        ..cubicTo(31, 44, 65, 44, 65, 62)
        ..lineTo(65, 70),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GroupEmblem oldDelegate) => false;
}
