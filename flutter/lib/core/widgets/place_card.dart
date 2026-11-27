import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';

/// Horizontal featured place card used in Discover carousels.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onTap,
    this.compact = false,
    this.trailing,
    this.metadata,
  }) : leading = null,
       inline = false,
       selected = false,
       progress = null;

  const PlaceCard.option({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.leading,
    this.selected = false,
    this.progress,
    this.trailing,
    this.metadata,
  }) : inline = true,
       compact = true,
       cover = const Icon(Icons.place_outlined);

  final Widget? leading;
  final String title;
  final String subtitle;
  final Widget cover;
  final VoidCallback? onTap;
  final bool inline;
  final bool selected;
  final double? progress;
  final Widget? trailing, metadata;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (inline) {
      return Semantics(
        selected: selected,
        child: Material(
          color: selected
              ? context.palette.brandSoft
              : context.palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.control.r),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.control.r),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: Responsive.padding(all: AppSpacing.compact),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: Responsive.spaceSm,
                      runSpacing: Responsive.spaceSm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ?leading,
                        if (onTap != null)
                          Icon(
                            selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                          ),
                        Text(title, style: context.texts.titleSmall),
                        if (subtitle.isNotEmpty)
                          Text(subtitle, style: context.texts.bodySmall),
                        ?metadata,
                        ?trailing,
                      ],
                    ),
                    if (progress != null) ...[
                      Responsive.spaceSm.gapH,
                      LinearProgressIndicator(value: progress!.clamp(0, 1)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final width = compact ? 200.w : 220.w;
    final height =
        168.h +
        (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 2.0) * 40;

    return AppPressable(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card.r),
          boxShadow: AppShadows.card(context.palette.shadow),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              cover,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              if (trailing != null)
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: Material(
                    color: context.palette.surface,
                    shape: const CircleBorder(),
                    child: trailing!,
                  ),
                ),
              Positioned(
                left: AppSpacing.compact.w,
                right: AppSpacing.compact.w,
                bottom: AppSpacing.compact.h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: AppTypography.body,
                      ),
                    ),
                    ?metadata,
                    2.gapH,
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppTypography.caption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
