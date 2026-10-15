import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Merged attendance + place voting card for an outing.
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

  Future<void> _selectAttendance(AttendanceStatus status) async {
    if (_saving) return;
    final outings = context.read<OutingsProvider>();
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || userId.isEmpty) return;

    if (widget.outing.createdById == userId) return;
    if (outings.isVoteFinalized(widget.outing.id)) {
      AppSnackBar.show(context.l10n.voteLocked);
      return;
    }
    if (!outings.canChangeAttendance(widget.outing.id)) {
      AppSnackBar.show(context.l10n.attendanceClosed);
      return;
    }

    setState(() => _saving = true);
    final ok = await outings.setAttendance(widget.outing.id, userId, status);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      AppSnackBar.show(context.l10n.attendanceClosed);
      return;
    }
    AppSnackBar.show(context.l10n.attendanceUpdated);

    // Lock when I'm In is chosen after place(s) were already selected.
    if (status == AttendanceStatus.going &&
        outings.hasVoted(widget.outing.id) &&
        !outings.isVoteFinalized(widget.outing.id)) {
      await outings.finalizeVoteFor(widget.outing.id);
      if (mounted) AppSnackBar.show(context.l10n.voteLocked);
    }
  }

  Future<void> _togglePlace(int index) async {
    final outings = context.read<OutingsProvider>();
    final userId = context.read<AuthProvider>().user?.id;
    final l10n = context.l10n;

    if (outings.isVoteFinalized(widget.outing.id)) {
      AppSnackBar.show(l10n.voteLocked);
      return;
    }

    final attendance = outings.cuserAttendance(widget.outing.id, userId);
    if (attendance == AttendanceStatus.notGoing) {
      AppSnackBar.show(l10n.notInCannotVotePlaces);
      return;
    }

    final ok = await outings.selectVoteFor(widget.outing.id, index);
    if (!mounted) return;
    if (ok) AppSnackBar.show(l10n.voteUpdated);
  }

  Future<void> _confirmVote() async {
    final outings = context.read<OutingsProvider>();
    final userId = context.read<AuthProvider>().user?.id;
    final l10n = context.l10n;

    final isCreator =
        widget.outing.createdById != null &&
        widget.outing.createdById == userId;
    if (!isCreator &&
        outings.cuserAttendance(widget.outing.id, userId) !=
            AttendanceStatus.going) {
      AppSnackBar.show(l10n.pickImInToVote);
      return;
    }
    if (!outings.hasVoted(widget.outing.id)) {
      AppSnackBar.show(l10n.pickFavoritePlace);
      return;
    }

    final ok = await outings.finalizeVoteFor(widget.outing.id);
    if (!mounted) return;
    AppSnackBar.show(ok ? l10n.voteLocked : l10n.voteUpdated);
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
        outings.canChangeAttendance(outing.id) && !locked && !_saving;
    final placesEnabled =
        !locked &&
        showPlaces &&
        (isCreator || outings.canSelectPlaces(outing.id, userId));
    final totalMembers = outing.going;
    final voted = outings.votedCountFor(outing.id).clamp(0, totalMembers);
    final canConfirm =
        showPlaces &&
        !locked &&
        outings.hasVoted(outing.id) &&
        (isCreator || mine == AttendanceStatus.going);

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
          ] else if (mine == AttendanceStatus.notGoing && showPlaces) ...[
            8.gapH,
            Text(
              l10n.notInCannotVotePlaces,
              style: TextStyle(color: palette.textMuted, fontSize: 11.sp),
            ),
          ] else if (showPlaces &&
              outings.hasVoted(outing.id) &&
              mine != AttendanceStatus.going &&
              !isCreator) ...[
            8.gapH,
            Text(
              l10n.pickImInToVote,
              style: TextStyle(color: palette.textMuted, fontSize: 11.sp),
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
            if (canConfirm) ...[
              12.gapH,
              CustomButton(
                label: l10n.confirmVote,
                icon: Icons.lock_outline,
                size: AppButtonSize.small,
                onPressed: _confirmVote,
              ),
            ],
            if (outings.voteEndsAt(outing.id) != null) ...[
              12.gapH,
              VoteCountdownText(endsAt: outings.voteEndsAt(outing.id)!),
            ],
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
    return Material(
      color: selected
          ? color.withValues(alpha: 0.12)
          : context.palette.surfaceMuted,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18.w,
                  color: selected ? color : context.palette.textMuted,
                ),
              6.gapW,
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.sp,
                    color: selected ? color : context.palette.textPrimary,
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
          _VoteOptionTile(
            label: options[i].label,
            votesLabel: l10n.votesPercent(options[i].votes, options[i].percent),
            percent: options[i].percent,
            selected: selectedIndexes.contains(i),
            compact: compact,
            enabled: enabled,
            onTap: () => onSelected(i),
            muted: palette.textMuted,
            surface: palette.surface,
            border: palette.border,
            brandSoft: palette.brandSoft,
          ),
        ],
      ],
    );
  }
}

class _VoteOptionTile extends StatelessWidget {
  const _VoteOptionTile({
    required this.label,
    required this.votesLabel,
    required this.percent,
    required this.selected,
    required this.compact,
    required this.enabled,
    required this.onTap,
    required this.muted,
    required this.surface,
    required this.border,
    required this.brandSoft,
  });

  final String label;
  final String votesLabel;
  final int percent;
  final bool selected;
  final bool compact;
  final bool enabled;
  final VoidCallback onTap;
  final Color muted;
  final Color surface;
  final Color border;
  final Color brandSoft;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.45;
    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(compact ? 10.w : 12.w),
            decoration: BoxDecoration(
              color: selected ? brandSoft : surface,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.brand600.withValues(alpha: 0.12),
                        blurRadius: 12.w,
                        offset: Offset(0, 4.h),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: context.palette.shadow,
                        blurRadius: 10.w,
                        offset: Offset(0, 4.h),
                      ),
                    ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6.r),
                        color: selected
                            ? AppColors.brand600
                            : Colors.transparent,
                        border: Border.all(
                          color: selected ? AppColors.brand600 : border,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Icon(Icons.check, size: 12.w, color: Colors.white)
                          : null,
                    ),
                    Responsive.spaceSm.gapW,
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontSm,
                          color: selected ? context.palette.brandStrong : null,
                        ),
                      ),
                    ),
                    Text(
                      votesLabel,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: selected ? AppColors.brand600 : muted,
                      ),
                    ),
                  ],
                ),
                if (!compact) ...[
                  Responsive.spaceSm.gapH,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999.r),
                    child: LinearProgressIndicator(
                      value: (percent.clamp(0, 100)) / 100,
                      minHeight: 6.h,
                      backgroundColor: border.withValues(alpha: 0.45),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        selected ? AppColors.brand600 : AppColors.brand200,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
