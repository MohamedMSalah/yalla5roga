import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AboutDeveloperCard extends StatelessWidget {
  const AboutDeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    const foreground = AppPalette.gradientText;
    final contour = Border.all(color: foreground.withValues(alpha: 0.14));

    return ClipRRect(
      borderRadius: BorderRadius.circular(Responsive.radiusLg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: context.palette.isDark
              ? AppPalette.darkSelectedGradient
              : AppPalette.selectedGradient,
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -46.w,
              top: -42.h,
              child: ExcludeSemantics(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final diameter in [176, 138, 98])
                      Container(
                        width: diameter.w,
                        height: diameter.w,
                        decoration: BoxDecoration(
                          border: contour,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Icon(
                      Icons.location_on_outlined,
                      size: 38.w,
                      color: foreground.withValues(alpha: 0.12),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(24.w, 28.h, 24.w, 26.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.developerRole,
                    style: text.labelMedium?.copyWith(
                      color: foreground,
                      letterSpacing:
                          Directionality.of(context) == TextDirection.ltr
                          ? 1.25
                          : 0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Responsive.spaceMd.gapH,
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.developerName,
                      style: text.headlineMedium?.copyWith(
                        fontSize: Responsive.fontXl,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                        height: 1.15,
                      ),
                    ),
                  ),
                  Responsive.spaceSm.gapH,
                  Text(
                    l10n.developerTitle,
                    style: text.titleMedium?.copyWith(color: foreground),
                  ),
                  Responsive.spaceLg.gapH,
                  Text(
                    l10n.developerLocation,
                    style: text.bodyMedium?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
