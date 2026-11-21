import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_style.dart';

class HomeHeroBanner extends StatelessWidget {
  const HomeHeroBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = HomeStyle(context);
    final radius = BorderRadius.circular(20);
    final title = l10n.homePlanTitle;
    final accent = l10n.homePlanAccent;
    final start = title.indexOf(accent);
    return AppPressable(
      onTap: onTap,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: style.heroBorder),
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: style.hero),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const AlignmentDirectional(-.88, 1.28),
                        radius: .95,
                        colors: [
                          style.heroGlow,
                          style.heroGlow.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  end: 18,
                  bottom: -31,
                  width: 180,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: style.heroCurve,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.elliptical(150, 50),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(17, 11, 13, 11),
                  child: LayoutBuilder(
                    builder: (context, constraints) => ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 78),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: title.substring(0, start)),
                                      TextSpan(
                                        text: accent,
                                        style: TextStyle(color: style.accent),
                                      ),
                                      TextSpan(
                                        text: title.substring(
                                          start + accent.length,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: context.texts.titleLarge?.copyWith(
                                    fontSize: HomeStyle.heroTitle,
                                    fontWeight: FontWeight.w700,
                                    height: 1.16,
                                    color: style.text,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.homePlanBody,
                                  style: context.texts.bodySmall?.copyWith(
                                    fontSize: HomeStyle.heroBody,
                                    height: 1.35,
                                    color: style.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: (constraints.maxWidth * .25).clamp(
                              54.0,
                              105.0,
                            ),
                            height: 82,
                            child: Image.asset(
                              'assets/home/outing_calendar.webp',
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
