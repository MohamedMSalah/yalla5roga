import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';

class OutingListTile extends StatelessWidget {
  const OutingListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    this.occasion = OutingOccasion.none,
    this.onTap,
    this.trailing,
    this.heroTag,
  });

  final String title;
  final String subtitle;
  final String image;
  final OutingOccasion occasion;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Shared-element tag for the thumbnail; pass the same tag to the details
  /// page. Null when the tile does not open outing details.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final details = Row(
      children: [
        AppHero(
          tag: heroTag,
          url: image,
          radius: 12.r,
          child: PlanningCover(
            url: image,
            art: occasion.coverArt,
            width: 48.w,
            height: 48.w,
          ),
        ),
        12.gapW,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return AppCard(
      onTap: trailing == null ? onTap : null,
      radius: 20,
      child: Row(
        children: [
          Expanded(
            child: trailing == null || onTap == null
                ? details
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: details,
                  ),
          ),
          if (trailing != null) ...[
            8.gapW,
            trailing!,
          ] else
            Icon(
              context.chevronForward,
              color: context.palette.border,
              size: 20.w,
            ),
        ],
      ),
    );
  }
}
