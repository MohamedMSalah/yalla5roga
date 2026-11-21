import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/maps/yalla_map_markers.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';
import 'package:yalla_5roga/core/widgets/participant_avatar_stack.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outings_style.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/vote_countdown_text.dart';

String? _groupLabel(BuildContext context, Outing outing) {
  final groupId = outing.groupId;
  if (groupId == null) {
    return outing.type == OutingType.specialEvent
        ? context.l10n.specialEvent
        : null;
  }
  return context.select((GroupsProvider p) => p.findById(groupId)?.name);
}

class ActiveVotePreviewCard extends StatelessWidget {
  const ActiveVotePreviewCard({
    super.key,
    required this.outing,
    required this.onTap,
  });

  final Outing outing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = OutingsStyle(context);
    final l10n = context.l10n;
    final id = outing.id;
    final group = _groupLabel(context, outing);
    final options = context.select((OutingsProvider p) => p.optionsFor(id));
    final selected = context.select(
      (OutingsProvider p) => p.voteIndexesFor(id),
    );
    final summary = context.select(
      (OutingsProvider p) => (
        deadline: p.voteDeadlineFor(outing),
        closed: p.isVoteFinalized(id) || p.isVoteExpired(id),
        progress: p.voteParticipationFor(id),
      ),
    );
    final clock = context.read<OutingsProvider>().currentTime;
    final image = [
      outing.image,
      ...options.map((option) => option.imageUrl),
      ...outing.votePlaces.map((place) => place.imageUrl),
    ].firstWhere((url) => url.trim().isNotEmpty, orElse: () => '');
    final titleStyle = style.label(context, 17, weight: FontWeight.w700);
    final captionStyle = style.label(context, 12, color: style.muted);
    final badgeStyle = style.label(context, 11.5, color: style.muted);
    final caption = summary.closed
        ? l10n.voteEnded
        : selected.isNotEmpty
        ? l10n.youVoted
        : l10n.voteForOutingPlace;
    return AppPressable(
      onTap: onTap,
      child: Container(
        decoration: style.panel(),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 158),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final imageWidth = (width * .272).clamp(65.0, 99.0);
            final groupBadge = group == null
                ? null
                : _Pill(
                    color: style.pill,
                    child: _Metadata(
                      icon: Icons.groups_outlined,
                      text: group,
                      style: badgeStyle,
                    ),
                  );
            final deadline = summary.deadline;
            final countdown = deadline == null
                ? null
                : _Pill(
                    color: style.deadlineFill,
                    child: VoteCountdownText(
                      endsAt: deadline,
                      isClosed: summary.closed,
                      compact: true,
                      clock: clock,
                      style: style.label(
                        context,
                        11.5,
                        color: style.deadlineText,
                      ),
                    ),
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    PlanningCover(
                      url: image,
                      art: outing.occasion.coverArt,
                      width: imageWidth,
                      height: imageWidth * 1.12,
                      radius: 13,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              alignment: groupBadge == null
                                  ? WrapAlignment.end
                                  : WrapAlignment.spaceBetween,
                              children: [?groupBadge, ?countdown],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            outing.title,
                            style: titleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(caption, style: captionStyle),
                          if (options.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            _BallotOptions(
                              options: options,
                              selected: selected,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (summary.progress case final progress?
                    when progress.eligible > 0) ...[
                  const SizedBox(height: 12),
                  _VotingProgress(
                    voted: progress.voted,
                    eligible: progress.eligible,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BallotOptions extends StatelessWidget {
  const _BallotOptions({required this.options, required this.selected});

  final List<VoteOption> options;
  final Set<int> selected;

  @override
  Widget build(BuildContext context) {
    final style = OutingsStyle(context);
    final count = options.length.clamp(0, 3);
    return LayoutBuilder(
      builder: (context, constraints) {
        final chipWidth = ((constraints.maxWidth - (count - 1) * 5) / count)
            .clamp(67.0, 135.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < count; i++)
                Padding(
                  key: ValueKey(options[i].placeId),
                  padding: EdgeInsetsDirectional.only(
                    end: i == count - 1 ? 0 : 5,
                  ),
                  child: Tooltip(
                    message: options[i].label,
                    child: Semantics(
                      selected: selected.contains(i),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 36),
                        width: chipWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        decoration: style
                            .panel(radius: 10, raised: true)
                            .copyWith(
                              border: Border.all(
                                color: selected.contains(i)
                                    ? style.accent
                                    : style.border,
                              ),
                              color: selected.contains(i) ? style.pill : null,
                              gradient: selected.contains(i)
                                  ? null
                                  : style.panel(raised: true).gradient,
                            ),
                        child: Row(
                          children: [
                            if (options[i].categoryId.isNotEmpty)
                              Image.asset(
                                '${YallaMapMarkers.assetPath}/${YallaMapMarkers.assetId(options[i].categoryId)}.png',
                                width: 17,
                                height: 20,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              )
                            else
                              Icon(
                                Icons.place_outlined,
                                size: 17,
                                color: style.muted,
                              ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                options[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style.label(context, 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (options.length > count)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 7),
                  child: Text(
                    '+${context.l10n.n(options.length - count)}',
                    style: style.label(context, 12, color: style.muted),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VotingProgress extends StatelessWidget {
  const _VotingProgress({required this.voted, required this.eligible});

  final int voted, eligible;

  @override
  Widget build(BuildContext context) {
    final style = OutingsStyle(context);
    final amount = (voted / eligible).clamp(0.0, 1.0);
    final label = context.l10n.votedCount(voted, eligible);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: style.pill,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: amount, end: amount),
                  duration: AppMotion.reduce(context)
                      ? Duration.zero
                      : AppMotion.standard,
                  builder: (context, value, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      child: const SizedBox(
                        height: 9,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: OutingsStyle.progressGradient,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(label, style: style.label(context, 12))),
      ],
    );
  }
}

class UpcomingOutingPreviewCard extends StatelessWidget {
  const UpcomingOutingPreviewCard({
    super.key,
    required this.outing,
    required this.onTap,
    required this.heroTag,
  });

  final Outing outing;
  final void Function(String? coverHeroTag) onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final style = OutingsStyle(context);
    final l10n = context.l10n;
    final group = _groupLabel(context, outing);
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
    final cover = [winnerImage, placeImage, outing.image]
        .whereType<String>()
        .firstWhere((url) => url.trim().isNotEmpty, orElse: () => '');
    final sourceHero = cover == outing.image ? heroTag : null;
    final date = outing.scheduledAt?.toLocal();
    final time = outing.localizedTime(l10n);
    final statusColor = switch (outing.status) {
      OutingStatus.voting => context.palette.warning,
      OutingStatus.cancelled => context.palette.danger,
      OutingStatus.past => style.muted,
      _ => style.accent,
    };
    final status = _Pill(
      color: style.pill,
      child: Text(
        outing.statusLabel(l10n),
        textAlign: TextAlign.center,
        style: style.label(
          context,
          10.5,
          color: statusColor,
          weight: FontWeight.w600,
        ),
      ),
    );
    final title = Text(
      outing.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style.label(context, 15.5, weight: FontWeight.w700),
    );
    return AppPressable(
      onTap: () => onTap(sourceHero),
      child: Container(
        decoration: style.panel(),
        padding: const EdgeInsets.all(11),
        constraints: const BoxConstraints(minHeight: 92),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 302;
            final photoSize = compact ? 49.0 : 67.0;
            return Row(
              children: [
                if (date != null) ...[
                  _OutingDateTile(date: date, width: compact ? 43 : 55),
                  SizedBox(width: compact ? 7 : 10),
                ],
                AppHero(
                  tag: sourceHero,
                  url: cover,
                  radius: 12,
                  child: PlanningCover(
                    url: cover,
                    art: outing.occasion.coverArt,
                    width: photoSize,
                    height: photoSize + 1,
                    radius: 12,
                  ),
                ),
                SizedBox(width: compact ? 8 : 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!compact &&
                          width >= 328 &&
                          MediaQuery.textScalerOf(context).scale(15.5) <= 19)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: width * .24,
                              ),
                              child: status,
                            ),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [title, status],
                        ),
                      if (group != null) ...[
                        const SizedBox(height: 4),
                        _Metadata(
                          icon: Icons.groups_outlined,
                          text: group,
                          style: style.label(context, 12, color: style.muted),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        alignment: avatars.isEmpty
                            ? WrapAlignment.end
                            : WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (avatars.isNotEmpty)
                            ParticipantAvatarStack(
                              urls: avatars,
                              extra: (going - avatars.length).clamp(0, going),
                              ring: style.dark
                                  ? const Color(0xFFF0E8F5)
                                  : style.border,
                              counterFill: style.pill,
                              counterText: style.text,
                            ),
                          if (time.isNotEmpty)
                            _Metadata(
                              icon: Icons.schedule_outlined,
                              text: time,
                              style: style.label(context, 12),
                              iconColor: style.muted,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutingDateTile extends StatelessWidget {
  const _OutingDateTile({required this.date, required this.width});

  final DateTime date;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = l10n.locale.languageCode;
    final style = OutingsStyle(context);
    final small = style.label(context, 11.5, color: style.muted);
    return Semantics(
      label: DateFormat.yMMMMEEEEd(language).format(date),
      excludeSemantics: true,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 68),
        decoration: style.panel(radius: 12, date: true),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat.E(language).format(date),
              textAlign: TextAlign.center,
              style: small,
            ),
            Text(
              l10n.n(date.day),
              textAlign: TextAlign.center,
              style: style.label(context, 23, weight: FontWeight.w800),
            ),
            Text(
              DateFormat.MMM(language).format(date),
              textAlign: TextAlign.center,
              style: small,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({
    required this.icon,
    required this.text,
    required this.style,
    this.iconColor,
  });

  final IconData icon;
  final String text;
  final TextStyle style;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: iconColor ?? style.color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          style: style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: child,
    ),
  );
}
