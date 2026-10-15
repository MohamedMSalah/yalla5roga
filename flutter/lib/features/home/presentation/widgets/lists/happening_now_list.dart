import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/lists/outings_list.dart';

/// Home “Happening now” list: title + outing cards.
class HappeningNowList extends StatelessWidget {
  const HappeningNowList({super.key, this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.happeningNow,
          actionLabel: l10n.seeAll,
          onAction: onSeeAll,
        ),
        12.gapH,
        const OutingsList(limit: 3),
      ],
    );
  }
}
