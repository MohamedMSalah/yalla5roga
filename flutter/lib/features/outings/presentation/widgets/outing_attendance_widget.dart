import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Attendance RSVP (I'm In / Not In) — separate from place voting.
class OutingAttendanceWidget extends StatefulWidget {
  const OutingAttendanceWidget({super.key, required this.outing});

  final Outing outing;

  @override
  State<OutingAttendanceWidget> createState() => _OutingAttendanceWidgetState();
}

class _OutingAttendanceWidgetState extends State<OutingAttendanceWidget> {
  var _saving = false;

  Future<void> _select(AttendanceStatus status) async {
    if (_saving) return;
    final outings = context.read<OutingsProvider>();
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || userId.isEmpty) return;

    if (widget.outing.createdById == userId) {
      // Creator is always I'm In — already persisted.
      return;
    }
    if (!outings.canChangeAttendance(widget.outing.id)) {
      AppSnackBar.show(context.l10n.attendanceClosed);
      return;
    }

    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final ok = await outings.setAttendance(widget.outing.id, userId, status);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      AppSnackBar.show(context.l10n.attendanceClosed);
      return;
    }
    AppSnackBar.show(context.l10n.attendanceUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final outings = context.watch<OutingsProvider>();
    final userId = context.watch<AuthProvider>().user?.id;
    final outing = outings.findById(widget.outing.id) ?? widget.outing;
    final mine = outings.cuserAttendance(outing.id, userId);
    final isCreator =
        outing.createdById != null && outing.createdById == userId;
    final open = outings.canChangeAttendance(outing.id);

    return AppCard(
      radius: 18,
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.attendanceTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: Responsive.fontSm,
            ),
          ),
          8.gapH,
          if (isCreator) ...[
            _StatusChip(
              icon: Icons.check_circle,
              label: l10n.imIn,
              selected: true,
              color: const Color(0xFF059669),
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
                    enabled: open && !_saving,
                    color: const Color(0xFF059669),
                    onTap: () => _select(AttendanceStatus.going),
                  ),
                ),
                8.gapW,
                Expanded(
                  child: _AttendanceButton(
                    label: l10n.notIn,
                    icon: Icons.close,
                    selected: mine == AttendanceStatus.notGoing,
                    loading: _saving && mine != AttendanceStatus.notGoing,
                    enabled: open && !_saving,
                    color: AppColors.rose600,
                    onTap: () => _select(AttendanceStatus.notGoing),
                  ),
                ),
              ],
            ),
            if (mine == AttendanceStatus.notVoted) ...[
              8.gapH,
              Text(
                '؟ ${l10n.stillNotVoted}',
                style: TextStyle(color: palette.textMuted, fontSize: 11.sp),
              ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20.w),
        8.gapW,
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 13.sp,
          ),
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
      AttendanceStatus.notVoted => Icons.help_outline,
    };
  }

  static Color color(AttendanceStatus status, Color muted) {
    return switch (status) {
      AttendanceStatus.going => const Color(0xFF059669),
      AttendanceStatus.notGoing => AppColors.rose600,
      AttendanceStatus.notVoted => muted,
    };
  }

  static String label(AttendanceStatus status, L10n l10n) {
    return switch (status) {
      AttendanceStatus.going => '✓ ${l10n.imIn}',
      AttendanceStatus.notGoing => '✕ ${l10n.notIn}',
      AttendanceStatus.notVoted => '? ${l10n.stillNotVoted}',
    };
  }
}
