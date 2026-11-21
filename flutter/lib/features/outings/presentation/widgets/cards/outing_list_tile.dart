import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/outing_card.dart';
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
    this.statusLabel,
    this.heroTag,
    this.detailsFooter,
    this.dateLabel,
  });

  final String title;
  final String subtitle;
  final String image;
  final OutingOccasion occasion;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? statusLabel, dateLabel;
  final Widget? detailsFooter;

  /// Shared-element tag for the thumbnail; pass the same tag to the details
  /// page. Null when the tile does not open outing details.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return OutingCard(
      title: title,
      statusLabel: statusLabel,
      detailsFooter: detailsFooter,
      subtitle: subtitle,
      onTap: onTap,
      trailing: trailing,
      cover: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dateLabel != null &&
              MediaQuery.sizeOf(context).width >= 350 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3) ...[
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
              decoration: BoxDecoration(
                color: context.palette.brandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dateLabel!,
                textAlign: TextAlign.center,
                style: context.texts.labelMedium,
              ),
            ),
            const SizedBox(width: 8),
          ],
          AppHero(
            tag: heroTag,
            url: image,
            radius: 12.r,
            child: PlanningCover(
              url: image,
              art: occasion.coverArt,
              width: 68.w,
              height: 70.w,
            ),
          ),
        ],
      ),
    );
  }
}
