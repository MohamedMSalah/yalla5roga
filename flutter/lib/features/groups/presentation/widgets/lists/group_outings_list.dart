import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_list_tile.dart';

enum GroupOutingsSection { activeVotes, upcoming, history }

/// Composes the existing outing snapshots without changing lifecycle rules.
class GroupOutingsList extends StatelessWidget {
  const GroupOutingsList({
    super.key,
    required this.group,
    this.section = GroupOutingsSection.upcoming,
  });

  final Group group;
  final GroupOutingsSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<OutingsProvider>();
    final source = switch (section) {
      GroupOutingsSection.activeVotes => provider.activeVotes,
      GroupOutingsSection.upcoming => provider.upcoming,
      GroupOutingsSection.history => provider.history,
    };
    final outings = source.where((o) => o.groupId == group.id).toList();
    if (section == GroupOutingsSection.upcoming) {
      outings.sort(
        (a, b) => (a.scheduledAt ?? DateTime(9999)).compareTo(
          b.scheduledAt ?? DateTime(9999),
        ),
      );
    }
    final title = switch (section) {
      GroupOutingsSection.activeVotes => l10n.activeVotes,
      GroupOutingsSection.upcoming => l10n.upcoming,
      GroupOutingsSection.history => l10n.outingHistory,
    };
    if (!provider.hasLoaded) {
      return AppShimmer(child: ShimmerBone(height: 120.h, radius: 16));
    }
    if (provider.errorMessage != null && outings.isEmpty) {
      return AppErrorState(
        message: provider.errorMessage!,
        onRetry: () => provider.load(forceRefresh: true),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        Responsive.spaceSm.gapH,
        if (outings.isEmpty)
          AppEmptyState(
            icon: Icons.event_busy_outlined,
            message: section == GroupOutingsSection.activeVotes
                ? l10n.noActiveVotes
                : section == GroupOutingsSection.history
                ? l10n.noOutingHistory
                : l10n.noGroupOutings,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: outings.length,
            itemBuilder: (context, index) {
              final outing = outings[index];
              final heroTag = HeroTags.outingCover(
                'group-${section.name}',
                outing.id,
              );
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == outings.length - 1 ? 0 : 8.h,
                ),
                child: OutingListTile(
                  title: outing.title,
                  subtitle: [
                    outing.localizedWhen(l10n),
                    if (section == GroupOutingsSection.activeVotes) l10n.voting,
                    outing.localizedPlace,
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
