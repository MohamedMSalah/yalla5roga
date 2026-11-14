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
  });
  final DateTime endsAt;
  final TextStyle? style;
  final bool isClosed;
  @override
  State<VoteCountdownText> createState() => _VoteCountdownTextState();
}

class _VoteCountdownTextState extends State<VoteCountdownText>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();
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
    _visible = TickerMode.valuesOf(context).enabled;
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
    _now = DateTime.now();
    if (!_visible ||
        !_foreground ||
        widget.isClosed ||
        !widget.endsAt.isAfter(_now)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _now = DateTime.now());
      if (!widget.endsAt.isAfter(_now)) timer.cancel();
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
    final label = value.ended
        ? context.l10n.voteEnded
        : context.l10n.voteCountdown(
            value.days,
            value.hours,
            value.minutes,
            value.seconds,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 18, color: context.palette.warning),
        Responsive.spaceXs.gapW,
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
