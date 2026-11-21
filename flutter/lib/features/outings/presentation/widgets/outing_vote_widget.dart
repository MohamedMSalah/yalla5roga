import 'package:yalla_5roga/features/outings/presentation/widgets/vote_countdown_text.dart';
export 'package:yalla_5roga/features/outings/presentation/widgets/vote_countdown_text.dart';

import 'voting_place_list.dart';
import 'tie_results_section.dart';
import 'dice_roll_animation.dart';
import 'revote_bottom_sheet.dart';

import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';

export 'voting_place_list.dart';
export 'dice_roll_animation.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';

import 'outing_info_style.dart';

import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Place voting only. RSVP and GPS arrival have separate widgets.
class OutingVoteWidget extends StatefulWidget {
  const OutingVoteWidget({
    super.key,
    required this.outing,
    this.showHeader = true,
    required this.canParticipate,
    this.compact = false,
    this.placeVotingKey,
    this.attendanceKey,
  });

  final Outing outing;
  final bool showHeader, canParticipate;
  final bool compact;
  final Key? placeVotingKey;
  final Key? attendanceKey;

  @override
  State<OutingVoteWidget> createState() => _OutingVoteWidgetState();
}

class _OutingVoteWidgetState extends State<OutingVoteWidget> {
  Set<int>? _draftIndexes;
  String? _optionSet;
  var _breakingTie = false;
  var _voting = false;

  String _optionsKey(OutingsProvider store, String id) {
    final optionIds = store.optionsFor(id).map((option) => option.placeId);
    return '${store.roundNumberFor(id)}:${optionIds.join(',')}';
  }

  Future<void> _submitBallot() async {
    if (_voting || _draftIndexes == null || !widget.canParticipate) return;
    final outings = context.read<OutingsProvider>();
    final id = widget.outing.id;
    if (_optionSet != _optionsKey(outings, id)) return;
    if (outings.isVoteExpired(id)) {
      AppSnackBar.show(context.l10n.voteEnded);
      return;
    }
    setState(() => _voting = true);
    final ok = await outings.setBallotFor(widget.outing.id, _draftIndexes!);
    if (!mounted) return;
    setState(() {
      _voting = false;
      if (ok) _draftIndexes = null;
    });
    if (ok) AppSnackBar.show(context.l10n.voteUpdated);
  }

  Future<void> _chooseVenue(List<VoteOption> options) async {
    final l10n = context.l10n;
    final choice = options.length == 1
        ? options.single
        : await showDialog<VoteOption>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(l10n.confirmVenue),
              children: [
                for (final option in options)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, option),
                    child: ListTile(
                      title: Text(option.label),
                      subtitle: Text(
                        l10n.votesPercent(option.votes, option.percent),
                      ),
                    ),
                  ),
              ],
            ),
          );
    if (!mounted || choice == null) return;
    final confirmed = await AppAlert.confirm(
      title: l10n.confirmVenue,
      message: l10n.confirmVenuePrompt(choice.label),
      confirmText: l10n.confirmVenue,
      cancelText: l10n.cancel,
    );
    if (!mounted || !confirmed) return;
    final store = context.read<OutingsProvider>();
    final current = store.findById(widget.outing.id);
    if (current?.status != OutingStatus.voting ||
        current?.createdById != context.read<AuthProvider>().user?.id ||
        store.isTied(widget.outing.id) ||
        store.roundNumberFor(widget.outing.id) != 1) {
      return;
    }
    setState(() => _voting = true);
    await context.read<OutingsProvider>().confirmVenue(
      widget.outing.id,
      choice.placeId,
    );
    if (mounted) setState(() => _voting = false);
  }

  bool _canResolve(OutingsProvider outings, int round, String? creator) {
    final id = widget.outing.id;
    final current = outings.findById(id);
    return mounted &&
        creator != null &&
        context.read<AuthProvider>().user?.id == creator &&
        current?.createdById == creator &&
        current?.status == OutingStatus.voting &&
        outings.canResolveTie(id) &&
        !outings.isManaging(id) &&
        outings.roundNumberFor(id) == round;
  }

  Future<void> _runTieBreak() async {
    if (_breakingTie) return;
    final outings = context.read<OutingsProvider>();
    final id = widget.outing.id;
    final round = outings.roundNumberFor(id);
    final creator = context.read<AuthProvider>().user?.id;
    if (!_canResolve(outings, round, creator)) return;
    final candidates = outings.tiedOptionsFor(id);
    if (candidates.length < 2) return;

    setState(() => _breakingTie = true);
    try {
      final confirmed = await AppAlert.confirm(
        title: context.l10n.rollTheDice,
        message: context.l10n.randomLocationPrompt,
        confirmText: context.l10n.rollTheDice,
        cancelText: context.l10n.cancel,
      );
      if (!mounted || !confirmed || !_canResolve(outings, round, creator)) {
        return;
      }

      final result = outings.breakTieFor(id, round);
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: context.l10n.rollTheDice,
        transitionDuration: AppMotion.of(context, AppMotion.standard),
        pageBuilder: (context, animation, secondary) => TieBreakRevealDialog(
          outingId: id,
          creatorId: creator!,
          candidates: candidates,
          result: result,
        ),
      );
    } finally {
      if (mounted) setState(() => _breakingTie = false);
    }
  }

  Future<void> _startRevote() async {
    if (_breakingTie) return;
    final outings = context.read<OutingsProvider>();
    final id = widget.outing.id;
    final round = outings.roundNumberFor(id);
    final creator = context.read<AuthProvider>().user?.id;
    final options = outings.tiedOptionsFor(id);
    if (!_canResolve(outings, round, creator) || options.length < 2) return;

    setState(() => _breakingTie = true);
    try {
      await AppBottomSheet.show<void>(
        context: context,
        builder: (_) => RevoteBottomSheet(
          options: options,
          scheduledAt: widget.outing.scheduledAt,
          onSubmit: (deadline) async {
            if (!_canResolve(outings, round, creator)) return false;
            return outings.startRevoteFor(id, deadline, round);
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _breakingTie = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final outings = context.watch<OutingsProvider>();
    final userId = context.watch<AuthProvider>().user?.id;
    final outing = outings.findById(widget.outing.id) ?? widget.outing;
    final options = outings.optionsFor(outing.id);
    final optionSet = _optionsKey(outings, outing.id);
    if (_optionSet != optionSet) {
      _draftIndexes = null;
      _optionSet = optionSet;
    }
    final showPlaces = options.isNotEmpty;
    final canConfirm =
        (userId != null && outing.createdById == userId) &&
        outing.status == OutingStatus.voting &&
        showPlaces &&
        !outings.isTied(outing.id) &&
        (options.length == 1 || !outings.isVoteExpired(outing.id)) &&
        outings.roundNumberFor(outing.id) == 1;
    final selectedIndexes = outings.voteIndexesFor(outing.id);
    final canResolve =
        outings.canResolveTie(outing.id) &&
        outing.createdById != null &&
        outing.createdById == userId;
    final locked =
        outings.isVoteFinalized(outing.id) ||
        outing.status != OutingStatus.voting;
    final endsAt = outings.voteEndsAt(outing.id) ?? outing.voteEndsAt;
    final placesEnabled =
        widget.canParticipate &&
        !locked &&
        !_voting &&
        outings.canSelectPlaces(outing.id, userId);
    final totalMembers = math.max(
      outings.eligibleVoterCountFor(outing.id),
      outings.votedCountFor(outing.id),
    );
    final voted = outings.votedCountFor(outing.id).clamp(0, totalMembers);
    final confirmVenueButton = CustomButton(
      label: l10n.confirmVenue,
      icon: Icons.place_outlined,
      size: AppButtonSize.small,
      onPressed: _voting || _breakingTie ? null : () => _chooseVenue(options),
    );

    if (outing.status == OutingStatus.voting && outings.isTied(outing.id)) {
      return TieResultsSection(
        key: widget.placeVotingKey,
        options: outings.tiedOptionsFor(outing.id),
        round: outings.roundNumberFor(outing.id),
        canResolve: canResolve,
        busy: _breakingTie || outings.isManaging(outing.id),
        onRandom: _runTieBreak,
        onRevote: _startRevote,
      );
    }
    if (options.length < 2 || outing.status != OutingStatus.voting) {
      return canConfirm ? confirmVenueButton : const SizedBox.shrink();
    }
    return OutingInfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.votingRound(outings.roundNumberFor(outing.id)),
            style: context.texts.titleSmall,
          ),
          Responsive.spaceSm.gapH,
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
                        l10n.suggestPlaces,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.sp,
                        ),
                      ),
                      Text(
                        showPlaces
                            ? l10n.selectPreferredPlaces
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
          if (locked && showPlaces) ...[
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
          if (!showPlaces && widget.placeVotingKey != null) ...[
            14.gapH,
            Text(l10n.noPlacesAddedYet, key: widget.placeVotingKey),
          ],
          if (showPlaces) ...[
            14.gapH,
            Text(
              l10n.selectPreferredPlaces,
              key: widget.placeVotingKey,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: Responsive.fontSm,
              ),
            ),
            8.gapH,
            LinearProgressIndicator(
              value: totalMembers == 0 ? 0 : voted / totalMembers,
            ),
            Responsive.spaceSm.gapH,
            OutingVoteOptions(
              options: options,
              selectedIndexes: locked
                  ? selectedIndexes
                  : (_draftIndexes ?? selectedIndexes),
              compact: widget.compact,
              enabled: placesEnabled,
              onSelected: (index) => setState(() {
                final next = Set<int>.of(_draftIndexes ?? selectedIndexes);
                if (!next.add(index)) next.remove(index);
                _draftIndexes = next;
              }),
            ),
            if (!locked) ...[
              Responsive.spaceSm.gapH,
              CustomButton(
                label: l10n.confirmVote,
                icon: Icons.how_to_vote_outlined,
                isLoading: _voting,
                onPressed: _draftIndexes == null || _voting
                    ? null
                    : _submitBallot,
              ),
            ],
            if (canConfirm) ...[12.gapH, confirmVenueButton],
            if (endsAt != null) ...[
              12.gapH,
              VoteCountdownText(endsAt: endsAt, isClosed: locked),
            ],
          ],
        ],
      ),
    );
  }
}
