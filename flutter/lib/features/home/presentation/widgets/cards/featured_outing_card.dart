import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';

/// Select only a dated, non-terminal future plan; never label an old plan next.
Outing? nextHomeOuting(Iterable<Outing> outings, DateTime now) {
  Outing? next;
  for (final outing in outings) {
    final date = outing.scheduledAt;
    if (date == null ||
        !date.isAfter(now) ||
        outing.status == OutingStatus.past ||
        outing.status == OutingStatus.cancelled) {
      continue;
    }
    if (next == null || date.isBefore(next.scheduledAt!)) next = outing;
  }
  return next;
}

class FeaturedOutingCard extends StatelessWidget {
  const FeaturedOutingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OutingsProvider>();
    final l10n = context.l10n;
    final outing = nextHomeOuting(provider.outings, DateTime.now());
    if (outing == null) {
      if (provider.errorMessage != null && provider.outings.isEmpty) {
        return Column(
          children: [
            Text(l10n.errorUnexpected, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => provider.load(forceRefresh: true),
              child: Text(l10n.tryAgain),
            ),
          ],
        );
      }
      return AppEmptyState(
        icon: Icons.event_outlined,
        message: l10n.noUpcomingOutings,
        subtitle: l10n.noOutingsHint,
        compact: true,
      );
    }
    final heroTag = HeroTags.outingCover('home-next', outing.id);
    final when = outing.localizedWhen(l10n);
    final place = outing.isLocationHidden ? '' : outing.localizedPlace;
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Get.to(() => EventPage(event: outing, coverHeroTag: heroTag)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHero(
                tag: heroTag,
                url: outing.image,
                radius: 12,
                child: PlanningCover(
                  url: outing.image,
                  art: outing.occasion.coverArt,
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outing.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (when.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(when, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        place,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: context.palette.textSecondary),
                      ),
                    ],
                    if (outing.status == OutingStatus.voting) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.voting,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: context.palette.brandStrong),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(context.chevronForward),
            ],
          ),
        ),
      ),
    );
  }
}
