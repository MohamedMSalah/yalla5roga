import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';

class SuggestedPlaceTile extends StatelessWidget {
  const SuggestedPlaceTile({
    super.key,
    required this.place,
    required this.onTap,
  });

  final SuggestedPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final thumb = Responsive.avatarLg * 0.62;

    return AppCard(
      onTap: onTap,
      radius: 18,
      child: Row(
        children: [
          PlaceCoverImage.fromSuggested(
            place: place,
            width: thumb,
            height: thumb,
            radius: 14.r,
          ),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.localizedName(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSm,
                  ),
                ),
                Responsive.spaceXs.gapH,
                Text(
                  '${place.localizedArea(l10n)} · ${l10n.priceLevelLabel(place.priceLevel.name)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: Responsive.fontCaption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Responsive.spaceSm.gapW,
          AppBadge(
            label: l10n.vibeLabel(place.vibe.name),
            color: palette.brandSoft,
            textColor: palette.brandStrong,
          ),
          6.gapW,
          Icon(
            context.isRtl ? Icons.chevron_left : Icons.chevron_right,
            color: palette.textMuted,
            size: Responsive.iconMd,
          ),
        ],
      ),
    );
  }
}
