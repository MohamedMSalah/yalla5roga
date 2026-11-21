import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/loading_indicator.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_info_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

import 'outing_info_style.dart';

class OutingAttendanceWidget extends StatelessWidget {
  const OutingAttendanceWidget({
    super.key,
    required this.outing,
    required this.userId,
    this.onRetry,
  });
  final Outing outing;
  final String userId;
  final VoidCallback? onRetry;

  static const _options = [
    AttendanceStatus.going,
    AttendanceStatus.maybe,
    AttendanceStatus.notGoing,
  ];

  @override
  Widget build(BuildContext context) {
    final id = outing.id;
    final state = context.select((OutingsProvider store) {
      final votes = store.attendanceMapFor(id);
      return (
        eligible: store.isAttendanceParticipant(id, userId),
        busy: store.isSavingAttendance(id),
        changeable: store.canChangeAttendance(id, userId: userId),
        choice: votes[userId],
        going: votes.values
            .where((value) => value == AttendanceStatus.going)
            .length,
        maybe: votes.values
            .where((value) => value == AttendanceStatus.maybe)
            .length,
        notGoing: votes.values
            .where((value) => value == AttendanceStatus.notGoing)
            .length,
        unset: votes.values
            .where((value) => value == AttendanceStatus.unset)
            .length,
      );
    });
    final l10n = context.l10n;
    final style = OutingInfoStyle(context);
    final total = state.going + state.maybe + state.notGoing;
    final creator = userId == outing.createdById;
    final prompt = !state.eligible
        ? (onRetry == null
              ? l10n.outingRsvpPreview
              : l10n.outingRosterUnavailable)
        : creator
        ? l10n.youreIn
        : !state.changeable
        ? l10n.attendanceClosed
        : outing.groupId == null
        ? l10n.outingGuestPrompt
        : l10n.attendancePrompt;
    return OutingInfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 5,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.attendanceTitle,
                  style: style.type(19, weight: FontWeight.w700),
                ),
              ),
              if (state.eligible)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: style.dark ? const Color(0xFF433B4D) : style.control,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Text(
                      l10n.outingResponses(total),
                      style: style.type(11),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(prompt, style: style.type(13, color: style.secondary)),
          if (onRetry != null && !state.eligible)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
            ),
          if (state.eligible) ...[
            const SizedBox(height: 11),
            LayoutBuilder(
              builder: (context, limits) {
                final vertical =
                    limits.maxWidth < 245 ||
                    MediaQuery.textScalerOf(context).scale(13) > 19;
                final items = [
                  for (final status in _options)
                    _RsvpOption(
                      icon: AttendanceDisplay.icon(status),
                      label: switch (status) {
                        AttendanceStatus.going => l10n.imIn,
                        AttendanceStatus.maybe => l10n.maybe,
                        _ => l10n.notIn,
                      },
                      selected: state.choice == status,
                      loading: state.busy && state.choice == status,
                      onTap:
                          !state.changeable ||
                              state.busy ||
                              state.choice == status
                          ? null
                          : () => context.read<OutingsProvider>().setAttendance(
                              id,
                              userId,
                              status,
                            ),
                    ),
                ];
                if (vertical) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 4),
                        items[i],
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(child: items[i]),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Statistic(
                    Icons.people_outline,
                    state.going,
                    l10n.votedGoing,
                    style.success,
                  ),
                ),
                _divider(style),
                Expanded(
                  child: _Statistic(
                    Icons.help_outline,
                    state.maybe,
                    l10n.maybe,
                    style.warning,
                  ),
                ),
                _divider(style),
                Expanded(
                  child: _Statistic(
                    Icons.cancel_outlined,
                    state.notGoing,
                    l10n.notIn,
                    style.danger,
                  ),
                ),
                _divider(style),
                Expanded(
                  child: _Statistic(
                    Icons.more_horiz,
                    state.unset,
                    l10n.noResponse,
                    style.icon,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider(OutingInfoStyle style) =>
      Container(width: 1, height: 34, color: style.border);
}

class _RsvpOption extends StatelessWidget {
  const _RsvpOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.loading,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected, loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    final corners = BorderRadius.circular(14);
    final foreground = selected ? Colors.white : style.text;
    return Semantics(
      selected: selected,
      enabled: onTap != null,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: corners,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.press),
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 39),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  gradient: selected ? OutingInfoStyle.purple : null,
                  borderRadius: corners,
                  border: Border.all(
                    color: selected ? style.accent : style.border,
                    width: 1.25,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      LoadingIndicator(
                        size: 16,
                        strokeWidth: 2,
                        color: foreground,
                      )
                    else
                      Icon(
                        icon,
                        size: 17,
                        color: selected ? Colors.white : style.icon,
                      ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: style.type(
                          13,
                          color: foreground,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Statistic extends StatelessWidget {
  const _Statistic(this.icon, this.total, this.label, this.color);
  final IconData icon;
  final int total;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 3),
        Text(
          context.l10n.n(total),
          style: style.type(16, color: color, weight: FontWeight.w600),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: style.type(10.5, color: style.secondary),
        ),
      ],
    );
  }
}

/// Icon + label helpers for attendance lists.
class AttendanceDisplay {
  const AttendanceDisplay._();

  static IconData icon(AttendanceStatus status) {
    return switch (status) {
      AttendanceStatus.going => Icons.check,
      AttendanceStatus.notGoing => Icons.close,
      AttendanceStatus.maybe => Icons.help_outline,
      AttendanceStatus.unset => Icons.help_outline,
    };
  }

  static Color color(AttendanceStatus status, Color muted) {
    return switch (status) {
      AttendanceStatus.going => const Color(0xFF059669),
      AttendanceStatus.notGoing => AppColors.rose600,
      AttendanceStatus.maybe => AppColors.amber700,
      AttendanceStatus.unset => muted,
    };
  }

  static String label(AttendanceStatus status, L10n l10n) {
    return switch (status) {
      AttendanceStatus.going => '✓ ${l10n.imIn}',
      AttendanceStatus.notGoing => '✕ ${l10n.notIn}',
      AttendanceStatus.maybe => '? ${l10n.maybe}',
      AttendanceStatus.unset => l10n.noResponse,
    };
  }
}
