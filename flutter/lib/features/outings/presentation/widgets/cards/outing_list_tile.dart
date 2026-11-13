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
    return OutingCard(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: trailing,
      cover: AppHero(
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
    );
  }
}
