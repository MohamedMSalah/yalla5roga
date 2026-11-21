import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';

import 'outing_schedule_field.dart';
import 'voting_place_list.dart';

class RevoteBottomSheet extends StatefulWidget {
  const RevoteBottomSheet({
    super.key,
    required this.options,
    required this.scheduledAt,
    required this.onSubmit,
  });
  final List<VoteOption> options;
  final DateTime? scheduledAt;
  final Future<bool> Function(DateTime) onSubmit;
  @override
  State<RevoteBottomSheet> createState() => _RevoteBottomSheetState();
}

class _RevoteBottomSheetState extends State<RevoteBottomSheet> {
  DateTime? _deadline;
  bool _busy = false;
  String? _error;
  Future<void> _pick() async {
    final now = DateTime.now();
    var last = now.add(const Duration(days: 7));
    final scheduledAt = widget.scheduledAt?.toLocal();
    if (scheduledAt != null && scheduledAt.isBefore(last)) {
      last = scheduledAt;
    }
    if (!last.isAfter(now)) {
      setState(() => _error = context.l10n.votingDeadlineBeforeOuting);
      return;
    }
    var initial = _deadline ?? now;
    if (initial.isBefore(now)) initial = now;
    if (initial.isAfter(last)) initial = last;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateUtils.dateOnly(last),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _deadline ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (!mounted || time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _deadline = value;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _deadline == null) return;
    final now = DateTime.now();
    if (!_deadline!.isAfter(now) ||
        _deadline!.isAfter(now.add(const Duration(days: 7))) ||
        (widget.scheduledAt != null &&
            !_deadline!.isBefore(widget.scheduledAt!))) {
      setState(() => _error = context.l10n.votingDeadlineBeforeOuting);
      return;
    }
    setState(() => _busy = true);
    final ok = await widget.onSubmit(_deadline!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AppSnackBar.show(context.l10n.revoteStarted);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: !_busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.revote, style: context.texts.titleLarge),
          Responsive.spaceSm.gapH,
          Text(l.revoteExplanation),
          Responsive.spaceMd.gapH,
          OutingVoteOptions(
            options: widget.options,
            selectedIndexes: const {},
            onSelected: (_) {},
            enabled: false,
          ),
          Responsive.spaceMd.gapH,
          OutingScheduleField(
            label: l.votingDeadlineTitle,
            value: _deadline == null
                ? l.outingSchedule
                : '${l.formatDate(_deadline!)} · ${l.formatTime(_deadline!)}',
            icon: Icons.event_outlined,
            onTap: _busy ? () {} : _pick,
          ),
          if (_error != null)
            Padding(
              padding: Responsive.padding(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Responsive.spaceMd.gapH,
          CustomButton(
            label: l.startRevote,
            isLoading: _busy,
            onPressed: _busy || _deadline == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}
