import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Attendance + place voting for an outing (independent domains).
class OutingVoteWidget extends StatefulWidget {
  const OutingVoteWidget({
    super.key,
    required this.outing,
    this.showHeader = true,
    this.compact = false,
  });

  final Outing outing;
  final bool showHeader;
  final bool compact;

  @override
  State<OutingVoteWidget> createState() => _OutingVoteWidgetState();
}

class _OutingVoteWidgetState extends State<OutingVoteWidget> {
  var _saving = false;
  var _breakingTie = false;

  Future<void> _selectAttendance(AttendanceStatus status) async {
    if (_saving || status == AttendanceStatus.unset) return;
    final outings = context.read<OutingsProvider>();
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || userId.isEmpty) return;
    if (widget.outing.createdById == userId) return;
    if (!outings.canChangeAttendance(widget.outing.id, userId: userId)) {
      AppSnackBar.show(context.l10n.attendanceClosed);
      return;
    }

    setState(() => _saving = true);
    final ok = await outings.setAttendance(widget.outing.id, userId, status);
    if (!mounted) return;
    setState(() => _saving = false);
    AppSnackBar.show(
      ok ? context.l10n.attendanceUpdated : context.l10n.attendanceClosed,
    );
  }

  Future<void> _togglePlace(int index) async {
    final outings = context.read<OutingsProvider>();
    final l10n = context.l10n;

    if (outings.isVoteFinalized(widget.outing.id)) {
      AppSnackBar.show(l10n.voteLocked);
      return;
    }

    final ok = await outings.selectVoteFor(widget.outing.id, index);
    if (!mounted) return;
    if (ok) AppSnackBar.show(l10n.voteUpdated);
  }

  Future<void> _runTieBreak() async {
    if (_breakingTie) return;
    final outings = context.read<OutingsProvider>();
    final userId = context.read<AuthProvider>().user?.id;
    final isOwner =
        widget.outing.createdById != null &&
        widget.outing.createdById == userId;
    if (!isOwner) return;

    setState(() => _breakingTie = true);
    final winnerId = await outings.breakTieFor(widget.outing.id);
    if (!mounted) return;

    if (winnerId == null || winnerId.isEmpty) {
      setState(() => _breakingTie = false);
      AppSnackBar.show(context.l10n.voteUpdated);
      return;
    }

    final options = outings.optionsFor(widget.outing.id);
    final labels = [for (final option in options) option.label];
    final matched = options.where((o) => o.placeId == winnerId);
    final winnerLabel = matched.isNotEmpty
        ? matched.first.label
        : (labels.isNotEmpty ? labels.first : 'Winner');

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'tie-break',
      pageBuilder: (context, animation, secondary) {
        return TieBreakRevealDialog(
          candidates: labels,
          winnerLabel: winnerLabel,
        );
      },
    );

    if (mounted) setState(() => _breakingTie = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final outings = context.watch<OutingsProvider>();
    final userId = context.watch<AuthProvider>().user?.id;
    final outing = outings.findById(widget.outing.id) ?? widget.outing;
    final options = outings.optionsFor(outing.id);
    final showPlaces =
        outing.status == OutingStatus.voting && options.isNotEmpty;
    final selectedIndexes = outings.voteIndexesFor(outing.id);
    final mine = outings.cuserAttendance(outing.id, userId);
    final isCreator =
        outing.createdById != null && outing.createdById == userId;
    final locked = outings.isVoteFinalized(outing.id);
    final attendanceOpen =
        outings.canChangeAttendance(outing.id, userId: userId) && !_saving;
    final placesEnabled = !locked && showPlaces;
    final totalMembers = math.max(outing.going, 1);
    final voted = outings.votedCountFor(outing.id).clamp(0, totalMembers);
    final showTieBreak = isCreator && outings.isTied(outing.id);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                const IconCircle(
                  icon: Icons.how_to_vote_outlined,
                  background: AppColors.amber100,
                  foreground: AppColors.amber700,
                ),
                12.gapW,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outing.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        showPlaces
                            ? l10n.pickFavoritePlace
                            : l10n.attendanceTitle,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showPlaces)
                  AppBadge(
                    label: l10n.votedCount(voted, totalMembers),
                    color: AppColors.brand50,
                    textColor: AppColors.brand600,
                  ),
              ],
            ),
            12.gapH,
          ],
          Text(
            l10n.attendanceTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: Responsive.fontSm,
            ),
          ),
          8.gapH,
          if (isCreator) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: const Color(0xFF059669),
                  size: 20.w,
                ),
                8.gapW,
                Text(
                  l10n.imIn,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
            4.gapH,
            Text(
              l10n.youreIn,
              style: TextStyle(color: palette.textMuted, fontSize: 11.sp),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _AttendanceButton(
                    label: l10n.imIn,
                    icon: Icons.check,
                    selected: mine == AttendanceStatus.going,
                    loading: _saving && mine != AttendanceStatus.going,
                    enabled: attendanceOpen,
                    color: const Color(0xFF059669),
                    onTap: () => _selectAttendance(AttendanceStatus.going),
                  ),
                ),
                8.gapW,
                Expanded(
                  child: _AttendanceButton(
                    label: l10n.maybe,
                    icon: Icons.help_outline,
                    selected: mine == AttendanceStatus.maybe,
                    loading: _saving && mine != AttendanceStatus.maybe,
                    enabled: attendanceOpen,
                    color: AppColors.amber700,
                    onTap: () => _selectAttendance(AttendanceStatus.maybe),
                  ),
                ),
                8.gapW,
                Expanded(
                  child: _AttendanceButton(
                    label: l10n.notIn,
                    icon: Icons.close,
                    selected: mine == AttendanceStatus.notGoing,
                    loading: _saving && mine != AttendanceStatus.notGoing,
                    enabled: attendanceOpen,
                    color: AppColors.rose600,
                    onTap: () => _selectAttendance(AttendanceStatus.notGoing),
                  ),
                ),
              ],
            ),
          ],
          if (locked) ...[
            8.gapH,
            Text(
              l10n.voteLocked,
              style: TextStyle(
                color: AppColors.brand600,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (showPlaces) ...[
            14.gapH,
            Text(
              l10n.pickFavoritePlace,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: Responsive.fontSm,
              ),
            ),
            8.gapH,
            OutingVoteOptions(
              options: options,
              selectedIndexes: selectedIndexes,
              compact: widget.compact,
              enabled: placesEnabled,
              onSelected: _togglePlace,
            ),
            if (outings.voteEndsAt(outing.id) != null) ...[
              12.gapH,
              VoteCountdownText(endsAt: outings.voteEndsAt(outing.id)!),
            ],
          ],
          if (showTieBreak) ...[
            14.gapH,
            CustomButton(
              label: l10n.letYallaDecide,
              icon: Icons.casino_outlined,
              size: AppButtonSize.small,
              onPressed: _breakingTie ? null : _runTieBreak,
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  const _AttendanceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.loading,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool loading;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = AppMotion.of(context, AppMotion.standard);
    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.settle,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 16.w,
                    color: selected ? color : palette.textMuted,
                  ),
                4.gapW,
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.sp,
                      color: selected ? color : palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable place rows used by [OutingVoteWidget].
class OutingVoteOptions extends StatelessWidget {
  const OutingVoteOptions({
    super.key,
    required this.options,
    required this.selectedIndexes,
    required this.onSelected,
    this.compact = false,
    this.enabled = true,
  });

  final List<VoteOption> options;
  final Set<int> selectedIndexes;
  final ValueChanged<int> onSelected;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) Responsive.spaceSm.gapH,
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => onSelected(i) : null,
              borderRadius: BorderRadius.circular(12.r),
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.standard),
                padding: EdgeInsets.all(compact ? 10.w : 12.w),
                decoration: BoxDecoration(
                  color: selectedIndexes.contains(i)
                      ? palette.brandSoft
                      : palette.surface,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedIndexes.contains(i)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: selectedIndexes.contains(i)
                          ? AppColors.brand600
                          : palette.border,
                    ),
                    Responsive.spaceSm.gapW,
                    Expanded(
                      child: Text(
                        options[i].label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontSm,
                        ),
                      ),
                    ),
                    Text(
                      l10n.votesPercent(options[i].votes, options[i].percent),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brand600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Live countdown for vote deadlines.
class VoteCountdownText extends StatefulWidget {
  const VoteCountdownText({super.key, required this.endsAt, this.style});

  final DateTime endsAt;
  final TextStyle? style;

  @override
  State<VoteCountdownText> createState() => _VoteCountdownTextState();
}

class _VoteCountdownTextState extends State<VoteCountdownText> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 30)),
      builder: (context, _) {
        final remaining = widget.endsAt.difference(DateTime.now());
        final l10n = context.l10n;
        final label = remaining.isNegative || remaining == Duration.zero
            ? l10n.voteEnded
            : l10n.endsInDuration(
                remaining.inHours,
                remaining.inMinutes.remainder(60),
              );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 14.w, color: AppColors.amber700),
            6.gapW,
            Text(
              label,
              style:
                  widget.style ??
                  TextStyle(
                    color: AppColors.amber700,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        );
      },
    );
  }
}

/// Polished reveal for the server-selected tie-break winner.
class TieBreakRevealDialog extends StatefulWidget {
  const TieBreakRevealDialog({
    super.key,
    required this.candidates,
    required this.winnerLabel,
  });

  final List<String> candidates;
  final String winnerLabel;

  @override
  State<TieBreakRevealDialog> createState() => _TieBreakRevealDialogState();
}

class _TieBreakRevealDialogState extends State<TieBreakRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final candidates = widget.candidates.isEmpty
        ? [widget.winnerLabel]
        : widget.candidates;

    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_controller.value);
            final index = (_controller.value * 12).floor() % candidates.length;
            final revealing = _controller.value > 0.72;
            final label = revealing ? widget.winnerLabel : candidates[index];

            return Container(
              width: 300.w,
              padding: EdgeInsets.all(22.w),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.letYallaDecide,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18.sp,
                    ),
                  ),
                  16.gapH,
                  Transform.rotate(
                    angle: (1 - t) * math.pi * 4,
                    child: Container(
                      width: 120.w,
                      height: 120.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brand200,
                            AppColors.brand600.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                  18.gapH,
                  if (revealing)
                    Text(
                      l10n.winnerIs(widget.winnerLabel),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.sp,
                        color: AppColors.brand600,
                      ),
                    )
                  else
                    Text(
                      l10n.pickingWinner,
                      style: TextStyle(color: palette.textMuted),
                    ),
                  16.gapH,
                  if (_controller.isCompleted)
                    CustomButton(
                      label: l10n.done,
                      size: AppButtonSize.small,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
