import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/participant_avatar_stack.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_section_header.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_style.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

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

class NextUpSection extends StatelessWidget {
  const NextUpSection({super.key, this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (outing, loaded, error) = context.select(
      (OutingsProvider p) => (
        nextHomeOuting(p.outings, DateTime.now()),
        p.hasLoaded,
        p.outings.isEmpty ? p.errorMessage : null,
      ),
    );
    Widget content;
    if (outing != null) {
      content = _NextOuting(outing: outing);
    } else if (error != null) {
      content = AppErrorState(
        message: error,
        onRetry: () => context.read<OutingsProvider>().load(forceRefresh: true),
      );
    } else if (!loaded) {
      content = const AppShimmer(
        child: ShimmerBone(width: double.infinity, height: 108, radius: 18),
      );
    } else {
      content = AppEmptyState(
        icon: Icons.event_outlined,
        message: l10n.noUpcomingOutings,
        subtitle: l10n.noOutingsHint,
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: l10n.nextUp,
          icon: Icons.calendar_month_outlined,
          actionLabel: l10n.seeAll,
          onAction: onSeeAll,
        ),
        const SizedBox(height: 4),
        content,
      ],
    );
  }
}

class _NextOuting extends StatelessWidget {
  const _NextOuting({required this.outing});

  final Outing outing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupName = context.select(
      (GroupsProvider p) => p.findById(outing.groupId ?? '')?.name,
    );
    final avatars = context.select(
      (OutingsProvider p) => p
          .membersForOuting(outing)
          .where(
            (member) =>
                p.attendanceFor(outing.id, member.id) == AttendanceStatus.going,
          )
          .take(3)
          .map((member) => member.avatar)
          .toList(growable: false),
    );
    final going = context.select(
      (OutingsProvider p) => p.goingCountFor(outing.id),
    );
    final winnerImage = context.select(
      (OutingsProvider p) => p.winningOptionFor(outing.id)?.imageUrl,
    );
    final placeId = outing.location?.placeId;
    final placeImage = placeId == null
        ? null
        : context.select(
            (DiscoverProvider p) => p.findById(placeId)?.coverImageUrl,
          );
    final coverUrl = [winnerImage, placeImage, outing.image]
        .whereType<String>()
        .map((url) => url.trim())
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');
    // Details uses the original outing cover for shared-element flights.
    final heroTag =
        outing.image.trim().isEmpty || outing.image.trim() == coverUrl
        ? HeroTags.outingCover('home-next', outing.id)
        : null;

    return UpcomingOutingCard(
      title: outing.title,
      status: outing.statusLabel(l10n),
      group: groupName,
      date: l10n.formatHomeOutingDate(outing.scheduledAt!.toLocal()),
      time: l10n.formatTime(outing.scheduledAt!.toLocal()),
      avatars: avatars,
      extra: (going - avatars.length).clamp(0, going),
      onTap: () =>
          Get.to(() => EventPage(event: outing, coverHeroTag: heroTag)),
      cover: AppHero(
        tag: heroTag,
        url: coverUrl,
        radius: 13,
        child: PlanningCover(
          url: coverUrl,
          art: outing.occasion.coverArt,
          width: 88,
          height: 88,
        ),
      ),
    );
  }
}

class UpcomingOutingCard extends StatelessWidget {
  const UpcomingOutingCard({
    super.key,
    required this.title,
    required this.status,
    required this.group,
    required this.date,
    required this.time,
    required this.avatars,
    required this.extra,
    required this.cover,
    required this.onTap,
  });

  final String title, status, date, time;
  final String? group;
  final List<String> avatars;
  final int extra;
  final Widget cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = HomeStyle(context);
    final metadataStyle = context.texts.bodySmall?.copyWith(
      color: style.muted,
      fontSize: 12,
      height: 1.2,
    );
    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.texts.titleMedium?.copyWith(
        color: style.text,
        fontWeight: FontWeight.w700,
        height: 1.18,
        fontSize: 17,
      ),
    );
    final statusPill = DecoratedBox(
      decoration: BoxDecoration(
        color: style.statusFill,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: metadataStyle?.copyWith(
            color: style.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minHeight: 108),
        decoration: BoxDecoration(
          gradient: style.panel,
          border: Border.all(color: style.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            cover,
            const SizedBox(width: 11),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final inlineStatus =
                      constraints.maxWidth >= 188 &&
                      MediaQuery.textScalerOf(context).scale(17) <= 21;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (inlineStatus)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: titleText),
                            const SizedBox(width: 7),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * .44,
                              ),
                              child: statusPill,
                            ),
                          ],
                        )
                      else ...[
                        Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: statusPill,
                        ),
                        const SizedBox(height: 4),
                        titleText,
                      ],
                      if (group case final name? when name.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _OutingMeta(
                          icon: Icons.groups_outlined,
                          value: name,
                          style: metadataStyle,
                          singleLine: true,
                        ),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _OutingMeta(
                            icon: Icons.calendar_month_outlined,
                            value: date,
                            style: metadataStyle,
                          ),
                          _OutingMeta(
                            icon: Icons.schedule_rounded,
                            value: time,
                            style: metadataStyle,
                          ),
                          if (avatars.isNotEmpty || extra > 0)
                            ParticipantAvatarStack(
                              urls: avatars,
                              extra: extra,
                              ring: style.dark
                                  ? const Color(0xFFF0E8F5)
                                  : style.avatarRing,
                              counterFill: style.statusFill,
                              counterText: style.text,
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutingMeta extends StatelessWidget {
  const _OutingMeta({
    required this.icon,
    required this.value,
    this.style,
    this.singleLine = false,
  });

  final IconData icon;
  final String value;
  final TextStyle? style;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: style?.color, size: 15),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: style,
            maxLines: singleLine ? 1 : null,
            overflow: singleLine ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }
}
