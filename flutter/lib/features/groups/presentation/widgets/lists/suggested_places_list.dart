import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/suggested_place_card.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Group details list of active multi-place votes.
///
/// Creating suggestions uses the shared [CreateOutingPage] with `letVote: true`
/// (same form as create outing + Add places).
class SuggestedPlacesList extends StatelessWidget {
  const SuggestedPlacesList({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outings = context.watch<OutingsProvider>();
    final suggestions = outings.suggestionsForGroup(group.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.suggestPlaces,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.fontMd,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  Get.to(() => CreateOutingPage(group: group, letVote: true)),
              icon: Icon(Icons.add_location_alt_outlined, size: 18.w),
              label: Text(
                l10n.addPlacesForVoting,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp),
              ),
            ),
          ],
        ),
        Text(
          l10n.suggestPlacesHint,
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: Responsive.fontSm,
          ),
        ),
        Responsive.spaceSm.gapH,
        if (suggestions.isEmpty)
          AppEmptyState(
            icon: Icons.add_location_alt_outlined,
            message: l10n.noPlaceSuggestions,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == suggestions.length - 1 ? 0 : 8.h,
                ),
                child: SuggestedPlaceCard(suggestion: suggestions[index]),
              );
            },
          ),
      ],
    );
  }
}
