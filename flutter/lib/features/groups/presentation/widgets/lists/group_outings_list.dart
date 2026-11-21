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
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_upcoming_outing_card.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/active_vote_card.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_list_tile.dart';

enum GroupOutingsSection { activeVotes, upcoming, history }

/// Reads the same scoped lifecycle projections for previews and full lists.
class GroupOutingsList extends StatelessWidget {
  const GroupOutingsList({
    super.key,
    required this.group,
    this.section = GroupOutingsSection.upcoming,
    this.onSeeAll,
    this.onCreate,
    this.preview = false,
  });

  final Group group;
  final GroupOutingsSection section;
  final VoidCallback? onSeeAll, onCreate;
  final bool preview;

  static const _previewSize = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = GroupPageColors(context);
    final isVoting = section == GroupOutingsSection.activeVotes;
    final outings = context.select((OutingsProvider provider) {
      final source = switch (section) {
        GroupOutingsSection.activeVotes => provider.activeVotes,
        GroupOutingsSection.upcoming => provider.upcoming,
        GroupOutingsSection.history => provider.history,
      };
      return source.where((outing) => outing.groupId == group.id).toList();
    }).toList();
    final (loaded, error) = context.select(
      (OutingsProvider provider) => (provider.hasLoaded, provider.errorMessage),
    );
    if (section == GroupOutingsSection.upcoming) {
      outings.sort((a, b) {
        final first = a.scheduledAt;
        final second = b.scheduledAt;
        if (first == null) return second == null ? 0 : 1;
        return second == null ? -1 : first.compareTo(second);
      });
    }
    final title = switch (section) {
      GroupOutingsSection.activeVotes => l10n.activeVotes,
      GroupOutingsSection.upcoming => l10n.upcoming,
      GroupOutingsSection.history => l10n.outingHistory,
    };
    if (!loaded && error == null) {
      if (preview && !isVoting) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: preview ? 24 : 0),
        child: const AppShimmer(
          child: ShimmerBone(width: double.infinity, height: 80, radius: 19),
        ),
      );
    }
    if (error != null && outings.isEmpty) {
      if (preview && !isVoting) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: preview ? 24 : 0),
        child: AppErrorState(
          message: error,
          onRetry: () =>
              context.read<OutingsProvider>().load(forceRefresh: true),
        ),
      );
    }
    if (preview && !isVoting && outings.isEmpty) return const SizedBox.shrink();
    final visible = preview ? outings.take(_previewSize).toList() : outings;

    return Padding(
      padding: EdgeInsets.only(top: preview ? 24 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: title,
            icon: preview
                ? null
                : (isVoting
                      ? Icons.bolt_outlined
                      : Icons.calendar_month_outlined),
            titleStyle: preview
                ? context.texts.titleLarge?.copyWith(
                    color: style.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  )
                : null,
            trailing:
                preview && outings.length > _previewSize && onSeeAll != null
                ? TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: style.accent,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(l10n.seeAll)),
                        Icon(context.chevronForward, size: 19),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            if (preview && isVoting)
              _EmptyActiveVotesCard(onCreate: onCreate)
            else
              AppEmptyState(
                icon: Icons.event_busy_outlined,
                message: switch (section) {
                  GroupOutingsSection.activeVotes => l10n.groupNoActiveVotes,
                  GroupOutingsSection.upcoming => l10n.noGroupOutings,
                  GroupOutingsSection.history => l10n.noOutingHistory,
                },
                compact: true,
              )
          else
            for (final (index, outing) in visible.indexed)
              Padding(
                key: ValueKey(outing.id),
                padding: EdgeInsets.only(top: index == 0 ? 0 : 9),
                child: isVoting
                    ? ActiveVoteCard(outing: outing)
                    : section == GroupOutingsSection.upcoming
                    ? GroupUpcomingOutingCard(outing: outing)
                    : OutingListTile(
                        title: outing.title,
                        statusLabel: outing.statusLabel(l10n),
                        subtitle: [
                          outing.localizedWhen(l10n),
                          outing.localizedPlace,
                        ].where((part) => part.trim().isNotEmpty).join(' · '),
                        image: outing.image,
                        occasion: outing.occasion,
                        heroTag: HeroTags.outingCover(
                          'group-history',
                          outing.id,
                        ),
                        onTap: () => Get.to(
                          () => EventPage(
                            event: outing,
                            coverHeroTag: HeroTags.outingCover(
                              'group-history',
                              outing.id,
                            ),
                          ),
                        ),
                      ),
              ),
        ],
      ),
    );
  }
}

class _EmptyActiveVotesCard extends StatelessWidget {
  const _EmptyActiveVotesCard({this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = GroupPageColors(context);
    return GroupSurface(
      onTap: onCreate,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6023A6), Color(0xFF45177C)],
              ),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.groupNoActiveVotes,
                  style: context.texts.titleMedium?.copyWith(
                    color: style.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  onCreate == null
                      ? l10n.noActiveVotesHint
                      : l10n.groupStartVote,
                  style: context.texts.bodyMedium?.copyWith(
                    color: style.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (onCreate != null) ...[
            const SizedBox(width: 8),
            Icon(context.chevronForward, color: style.accent, size: 21),
          ],
        ],
      ),
    );
  }
}
