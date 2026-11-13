import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/outing_card.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
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
        return AppErrorState(
          message: provider.errorMessage!,
          onRetry: () => provider.load(forceRefresh: true),
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
    final groupName = context
        .watch<GroupsProvider>()
        .findById(outing.groupId ?? '')
        ?.name;
    final status = switch (outing.status) {
      OutingStatus.voting => l10n.voting,
      OutingStatus.confirmed => l10n.confirmed,
      OutingStatus.draft => l10n.draftOuting,
      OutingStatus.cancelled => l10n.cancelledOuting,
      OutingStatus.past => l10n.outingHistory,
    };
    return OutingCard(
      title: outing.title,
      subtitle: [?groupName, outing.localizedWhen(l10n)].join(' · '),
      statusLabel: status,
      onTap: () =>
          Get.to(() => EventPage(event: outing, coverHeroTag: heroTag)),
      cover: AppHero(
        tag: heroTag,
        url: outing.image,
        radius: 16,
        child: PlanningCover(
          url: outing.image,
          art: outing.occasion.coverArt,
          width: 72,
          height: 88,
        ),
      ),
    );
  }
}
