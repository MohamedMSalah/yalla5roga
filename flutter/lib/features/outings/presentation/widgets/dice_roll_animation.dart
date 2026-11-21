import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/loading_indicator.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_info_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

import 'outing_info_style.dart';
import 'tie_results_section.dart';

class TieBreakRevealDialog extends StatefulWidget {
  const TieBreakRevealDialog({
    super.key,
    required this.outingId,
    required this.creatorId,
    required this.candidates,
    required this.result,
  });

  final String outingId, creatorId;
  final List<VoteOption> candidates;
  final Future<String?> result;

  @override
  State<TieBreakRevealDialog> createState() => _TieBreakRevealDialogState();
}

class _TieBreakRevealDialogState extends State<TieBreakRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduce(context)) {
      _roll.value = 1;
    } else if (!_started) {
      _roll.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final viewer = context.select((AuthProvider auth) => auth.user?.id);
    final available =
        viewer == widget.creatorId &&
        context.select(
          (OutingsProvider store) =>
              !store.isUnavailable(widget.outingId) &&
              store.findById(widget.outingId)?.status != OutingStatus.cancelled,
        );
    return FutureBuilder<String?>(
      future: widget.result,
      builder: (context, snapshot) => AnimatedBuilder(
        animation: _roll,
        builder: (context, _) {
          final finished = snapshot.connectionState == ConnectionState.done;
          final winner = available && finished
              ? widget.candidates
                    .where((candidate) => candidate.placeId == snapshot.data)
                    .firstOrNull
              : null;
          final pending =
              available &&
              (!finished || (!_roll.isCompleted && winner != null));
          final revealed = winner != null && !pending;
          final placeId = winner?.catalogPlaceId;
          final title = !available
              ? l.dataLoadFailed
              : pending
              ? l.outingDiceChoosing
              : revealed
              ? l.outingWinnerTitle
              : l.outingWinnerLoadFailed;
          return PopScope(
            canPop: !pending,
            child: AlertDialog(
              scrollable: true,
              title: Semantics(liveRegion: true, child: Text(title)),
              content: pending
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DiceRollAnimation(progress: _roll.value),
                        if (_roll.isCompleted) ...[
                          const SizedBox(height: 12),
                          LoadingIndicator(
                            size: 20,
                            strokeWidth: 2,
                            color: OutingInfoStyle(context).accent,
                          ),
                        ],
                      ],
                    )
                  : revealed
                  ? _TieWinnerReveal(option: winner)
                  : null,
              actions: [
                if (revealed && placeId != null && placeId.isNotEmpty)
                  TextButton(
                    onPressed: () => Get.to(
                      () => DiscoverPlaceDetailsPage(placeId: placeId),
                    ),
                    child: Text(l.outingViewPlace),
                  ),
                if (!pending)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.done),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DiceRollAnimation extends StatelessWidget {
  const DiceRollAnimation({super.key, required this.progress});
  final double progress;

  static const _faces = [
    [4],
    [0, 8],
    [0, 4, 8],
    [0, 2, 6, 8],
    [0, 2, 4, 6, 8],
    [0, 2, 3, 5, 6, 8],
  ];

  @override
  Widget build(BuildContext context) {
    final settled = Curves.easeOutCubic.transform(progress);
    final pips = _faces[(settled * 20).floor() % _faces.length];
    final height = -math.sin(math.pi * settled) * 11;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Transform.translate(
          offset: Offset(0, height),
          child: Transform.rotate(
            angle: settled * math.pi * 4,
            child: Container(
              width: 63,
              height: 63,
              decoration: BoxDecoration(
                gradient: OutingInfoStyle.purple,
                border: Border.all(color: const Color(0xFFB767EA)),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Stack(
                children: [
                  for (final pip in pips)
                    Positioned(
                      left: 14.0 + (pip % 3) * 14,
                      top: 14.0 + (pip ~/ 3) * 14,
                      child: const CircleAvatar(
                        radius: 3.5,
                        backgroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TieWinnerReveal extends StatelessWidget {
  const _TieWinnerReveal({required this.option});
  final VoteOption option;

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    return TiePlaceCategories(
      builder: (context, categories) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .82, end: 1),
            duration: AppMotion.of(context, AppMotion.standard),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Icon(
              Icons.celebration_outlined,
              color: style.accent,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          TiePlacePhoto(option: option, width: 240, height: 106),
          const SizedBox(height: 10),
          Text(
            option.label,
            textAlign: TextAlign.center,
            style: style.type(16, weight: FontWeight.w700),
          ),
          if (categories[option.categoryId] case final category?
              when category.isNotEmpty)
            Text(category, style: style.type(12, color: style.secondary)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, color: style.success, size: 17),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  context.l10n.confirmed,
                  style: style.type(12, color: style.success),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
