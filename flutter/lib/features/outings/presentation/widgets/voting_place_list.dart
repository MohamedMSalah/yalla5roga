import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/place_card.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';

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
    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) Responsive.spaceSm.gapH,
          PlaceCard.option(
            title: options[i].label,
            subtitle: options[i].address.isEmpty
                ? options[i].area
                : options[i].address,
            leading:
                options[i].imageUrl.isEmpty && options[i].categoryId.isNotEmpty
                ? PlaceCoverImage(
                    url: '',
                    categoryId: options[i].categoryId,
                    vibe: OutingVibe.food,
                    width: 48,
                    height: 48,
                    radius: 8,
                  )
                : PlanningCover(
                    url: options[i].imageUrl,
                    art: PlanningCoverArt.outing,
                    width: 48,
                    height: 48,
                    radius: 8,
                  ),
            selected: selectedIndexes.contains(i),
            progress: options[i].percent / 100,
            trailing: Text(
              l10n.votesPercent(options[i].votes, options[i].percent),
            ),
            onTap: enabled ? () => onSelected(i) : null,
          ),
        ],
      ],
    );
  }
}
