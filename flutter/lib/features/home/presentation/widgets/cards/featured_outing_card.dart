import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
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
    return Semantics(
      value: status,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () =>
            Get.to(() => EventPage(event: outing, coverHeroTag: heroTag)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card.r),
          child: Stack(
            children: [
              Positioned.fill(
                child: AppHero(
                  tag: heroTag,
                  url: outing.image,
                  radius: AppRadii.card,
                  child: PlanningCover(
                    url: outing.image,
                    art: outing.occasion.coverArt,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.82),
                        Colors.black.withValues(alpha: 0.94),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 210.h),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: AppBadge(
                          label: l10n.nextUp,
                          color: context.colors.primary,
                          textColor: context.colors.onPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              outing.title,
                              style: context.texts.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            if (groupName != null) ...[
                              AppSpacing.xs.gapH,
                              _CoverDetail(
                                icon: Icons.groups_outlined,
                                text: groupName,
                              ),
                            ],
                            AppSpacing.xs.gapH,
                            _CoverDetail(
                              icon: Icons.calendar_today_outlined,
                              text: outing.localizedWhen(l10n),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverDetail extends StatelessWidget {
  const _CoverDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: AppSizes.icon),
        AppSpacing.sm.gapW,
        Expanded(
          child: Text(
            text,
            style: context.texts.bodySmall?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
