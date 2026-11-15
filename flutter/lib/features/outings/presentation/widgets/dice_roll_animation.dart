import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/place_card.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';

class TieBreakRevealDialog extends StatefulWidget {
  const TieBreakRevealDialog({
    super.key,
    required this.candidates,
    required this.winningOptionId,
  });
  final List<VoteOption> candidates;
  final String winningOptionId;
  @override
  State<TieBreakRevealDialog> createState() => _TieBreakRevealDialogState();
}

class _TieBreakRevealDialogState extends State<TieBreakRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduce(context)) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final reveal = _controller.value >= .9;
      final index =
          (Curves.easeOutCubic.transform(_controller.value) * 18).floor() %
          widget.candidates.length;
      return AlertDialog(
        scrollable: true,
        title: Text(
          reveal ? context.l10n.locationSelected : context.l10n.pickingWinner,
        ),
        content: SizedBox(
          width: Responsive.contentMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.candidates.length; i++) ...[
                if (i > 0) Responsive.spaceSm.gapH,
                AnimatedScale(
                  scale:
                      reveal &&
                          widget.candidates[i].placeId == widget.winningOptionId
                      ? 1.02
                      : 1,
                  duration: AppMotion.of(context, AppMotion.standard),
                  child: PlaceCard.option(
                    title: widget.candidates[i].label,
                    subtitle: widget.candidates[i].area,
                    leading: PlanningCover(
                      url: widget.candidates[i].imageUrl,
                      art: PlanningCoverArt.outing,
                      width: 48,
                      height: 48,
                      radius: 8,
                    ),
                    selected: reveal
                        ? widget.candidates[i].placeId == widget.winningOptionId
                        : i == index,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_controller.isCompleted)
            CustomButton(
              label: context.l10n.done,
              onPressed: () => Navigator.pop(context),
            ),
        ],
      );
    },
  );
}
