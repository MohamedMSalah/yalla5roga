import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_list_tile.dart';

/// Outings list: optional title + outing cards / empty state.
class OutingsList extends StatelessWidget {
  const OutingsList({
    super.key,
    this.title,
    this.limit,
    this.items,
    this.emptyMessage,
    this.heroSurface = 'outings',
  });

  final String? title;
  final int? limit;
  final List<Outing>? items;
  final String? emptyMessage;

  /// Keeps Hero tags unique when this list and another list showing the same
  /// outings live on one route (Home and Outings tabs share an IndexedStack).
  final String heroSurface;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outings = this.items ?? context.watch<OutingsProvider>().outings;
    final items = limit == null ? outings : outings.take(limit!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: context.texts.titleMedium),
          Responsive.spaceSm.gapH,
        ],
        if (items.isEmpty)
          AppEmptyState(
            icon: Icons.explore_outlined,
            message: emptyMessage ?? l10n.noOutings,
            subtitle: emptyMessage == null ? l10n.noOutingsHint : null,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final outing = items[index];
              final heroTag = HeroTags.outingCover(heroSurface, outing.id);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 8.h,
                ),
                child: OutingListTile(
                  title: outing.title,
                  subtitle: [
                    outing.localizedWhen(l10n),
                    if (outing.status == OutingStatus.past)
                      l10n.completedOuting
                    else if (outing.status == OutingStatus.cancelled)
                      l10n.cancelledOuting
                    else
                      l10n.goingCount(outing.going),
                  ].where((part) => part.trim().isNotEmpty).join(' · '),
                  image: outing.image,
                  occasion: outing.occasion,
                  heroTag: heroTag,
                  onTap: () => Get.to(
                    () => EventPage(event: outing, coverHeroTag: heroTag),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
