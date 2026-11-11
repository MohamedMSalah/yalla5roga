import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class CreateOutingLocationStep extends StatelessWidget {
  const CreateOutingLocationStep({
    super.key,
    required this.form,
    required this.onPickCustomLocation,
  });

  final CreateOutingProvider form;
  final VoidCallback onPickCustomLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final multi = form.multiPlaceMode;
    final suggestions = form.suggestedPlaces;
    final places = <Place>[
      if (multi)
        for (final place in form.selectedPlaces)
          if (!suggestions.any(place.matchesSelection)) place,
      if (!multi)
        if (form.place case final place?)
          if (!suggestions.any(place.matchesSelection)) place,
      ...suggestions,
    ];
    return Column(
      children: [
        if (!form.specialEvent) ...[
          CustomButton(
            label: multi ? l10n.useSingleLocation : l10n.addPlacesForVoting,
            icon: multi ? Icons.place_outlined : Icons.how_to_vote_outlined,
            variant: AppButtonVariant.outlined,
            onPressed: () => form.setLetVote(!multi),
          ),
          Responsive.spaceMd.gapH,
        ],
        if (multi) ...[
          SectionHeader(
            title: l10n.placesSelectedMax(
              form.selectedPlaces.length,
              OutingsProvider.maxVotePlaces,
            ),
            subtitle: l10n.addPlacesForVotingHint,
          ),
          Responsive.spaceSm.gapH,
          CustomButton(
            label: l10n.mapManagePlaces,
            icon: Icons.add_location_alt_outlined,
            variant: AppButtonVariant.light,
            onPressed: onPickCustomLocation,
          ),
        ] else
          AppCard(
            onTap: onPickCustomLocation,
            color: form.customPlacePinned ? context.palette.brandSoft : null,
            child: Row(
              children: [
                IconCircle(
                  icon: form.customPlacePinned
                      ? Icons.check_circle
                      : Icons.add_location_alt_outlined,
                  background: form.customPlacePinned
                      ? AppColors.brand600
                      : AppColors.brand50,
                  foreground: form.customPlacePinned
                      ? Colors.white
                      : AppColors.brand600,
                ),
                12.gapW,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.isCustomPlace
                            ? form.customPlaceController.text.trim()
                            : l10n.pickOnMap,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        form.customPlacePinned
                            ? l10n.changeMapLocation
                            : l10n.locationHint,
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.map_outlined, color: AppColors.brand600, size: 20.w),
              ],
            ),
          ),
        Responsive.spaceMd.gapH,
        if (!form.specialEvent && !multi) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.suggestedForVibe(
                l10n.vibeLabel(
                  OutingVibe
                      .values[form.vibe.clamp(0, OutingVibe.values.length - 1)]
                      .name,
                ),
              ),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: Responsive.fontSm,
              ),
            ),
          ),
          Responsive.spaceSm.gapH,
        ],
        if (places.isEmpty)
          AppEmptyState(
            icon: Icons.place_outlined,
            message: l10n.noPlaces,
            subtitle: l10n.noPlacesHint,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              final selected = multi
                  ? form.isPlaceSelected(place)
                  : form.place == place;
              final canSelect = !multi || selected || form.canAddMorePlaces;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == places.length - 1 ? 0 : 8.h,
                ),
                child: AppCard(
                  onTap: canSelect ? () => form.togglePlace(place) : null,
                  color: selected ? context.palette.brandSoft : null,
                  child: Row(
                    children: [
                      PlaceCoverImage.fromOutingPlace(
                        place: place,
                        width: 44.w,
                        height: 44.w,
                        radius: 12.r,
                      ),
                      12.gapW,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              place.area,
                              style: TextStyle(
                                color: context.palette.textMuted,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (multi)
                        Checkbox(
                          value: selected,
                          semanticLabel: place.name,
                          onChanged: canSelect
                              ? (_) => form.togglePlace(place)
                              : null,
                        )
                      else if (selected)
                        Icon(
                          Icons.check_circle,
                          color: AppColors.brand600,
                          size: 20.w,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
