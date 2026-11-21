import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/outings/domain/entities/vote_countdown.dart';

class VoteCountdownText extends StatefulWidget {
  const VoteCountdownText({
    super.key,
    required this.endsAt,
    this.style,
    this.isClosed = false,
    this.compact = false,
    this.clock = DateTime.now,
  });
  final DateTime endsAt;
  final TextStyle? style;
  final bool isClosed;
  final bool compact;
  final DateTime Function() clock;
  @override
  State<VoteCountdownText> createState() => _VoteCountdownTextState();
}

class _VoteCountdownTextState extends State<VoteCountdownText>
    with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _now = widget.clock();
  bool _visible = false;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _restart();
  }

  @override
  void didUpdateWidget(covariant VoteCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt ||
        oldWidget.isClosed != widget.isClosed) {
      _restart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) setState(_restart);
  }

  void _restart() {
    _timer?.cancel();
    _now = widget.clock();
    if (!_visible ||
        !_foreground ||
        widget.isClosed ||
        !widget.endsAt.isAfter(_now)) {
      return;
    }
    final remaining = widget.endsAt.difference(_now);
    final untilNext = widget.compact
        ? Duration(
            microseconds:
                ((remaining.inMicroseconds - 1) %
                    Duration.microsecondsPerMinute) +
                1,
          )
        : const Duration(seconds: 1);
    _timer = Timer(untilNext, () {
      if (mounted) setState(_restart);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = VoteCountdown(
      endsAt: widget.endsAt,
      now: _now,
      isClosed: widget.isClosed,
    );
    final minutes =
        (value.totalSeconds + Duration.secondsPerMinute - 1) ~/
        Duration.secondsPerMinute;
    final label = value.ended
        ? context.l10n.voteEnded
        : widget.compact
        ? context.l10n.outingVoteTimeLeft(minutes)
        : context.l10n.voteCountdown(
            value.days,
            value.hours,
            value.minutes,
            value.seconds,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          widget.compact ? Icons.schedule_outlined : Icons.timer_outlined,
          size: widget.compact ? 14 : 18,
          color: widget.style?.color ?? context.palette.warning,
        ),
        SizedBox(width: widget.compact ? 4 : Responsive.spaceXs),
        Flexible(
          child: Text(
            label,
            style:
                widget.style ??
                context.texts.labelLarge?.copyWith(
                  color: context.palette.warning,
                ),
          ),
        ),
      ],
    );
  }
}
