import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class CreateOutingLocationStep extends StatelessWidget {
  const CreateOutingLocationStep({
    super.key,
    required this.form,
    required this.onPickCustomLocation,
    required this.onAddVotePlace,
  });

  final CreateOutingProvider form;
  final VoidCallback onPickCustomLocation;
  final VoidCallback onAddVotePlace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final multi = form.multiPlaceMode;
    if (multi) {
      return _MultiPlaceSection(form: form, onAddVotePlace: onAddVotePlace);
    }
    return Column(
      children: [
        if (!form.specialEvent) ...[
          CustomButton(
            label: l10n.addPlacesForVoting,
            icon: Icons.how_to_vote_outlined,
            variant: AppButtonVariant.outlined,
            onPressed: () => form.setLetVote(true),
          ),
          Responsive.spaceMd.gapH,
        ],
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
        if (!form.specialEvent) ...[
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
        if (form.suggestedPlaces.isEmpty)
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
            itemCount: form.suggestedPlaces.length,
            itemBuilder: (context, index) {
              final place = form.suggestedPlaces[index];
              final selected = form.place == place;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == form.suggestedPlaces.length - 1 ? 0 : 8.h,
                ),
                child: AppCard(
                  onTap: () => form.togglePlace(place),
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
                      if (selected)
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

class _MultiPlaceSection extends StatelessWidget {
  const _MultiPlaceSection({required this.form, required this.onAddVotePlace});

  final CreateOutingProvider form;
  final VoidCallback onAddVotePlace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = form.selectedPlaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => form.setLetVote(false),
          icon: const Icon(Icons.place_outlined),
          label: Text(l10n.useSingleLocation),
        ),
        Responsive.spaceSm.gapH,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.voteDeadlineHours, style: context.texts.titleSmall),
              Text(l10n.voteDeadlineHint, style: context.texts.bodySmall),
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.decreaseVoteHours,
                    onPressed: form.voteDeadlineHours <= 1
                        ? null
                        : () => form.setVoteDeadlineHours(
                            form.voteDeadlineHours - 1,
                          ),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(l10n.hoursCount(form.voteDeadlineHours)),
                  IconButton(
                    tooltip: l10n.increaseVoteHours,
                    onPressed: form.voteDeadlineHours >= 72
                        ? null
                        : () => form.setVoteDeadlineHours(
                            form.voteDeadlineHours + 1,
                          ),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
        Responsive.spaceMd.gapH,
        Text(
          l10n.placesSelectedMax(
            selected.length,
            OutingsProvider.maxVotePlaces,
          ),
          style: TextStyle(
            color: AppColors.brand600,
            fontWeight: FontWeight.w800,
            fontSize: 10.sp,
          ),
        ),
        Responsive.spaceMd.gapH,
        if (selected.isEmpty)
          AppEmptyState(
            icon: Icons.add_location_alt_outlined,
            message: l10n.noPlacesAddedYet,
            subtitle: l10n.addPlacesForVotingHint,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selected.length,
            itemBuilder: (context, index) {
              final place = selected[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == selected.length - 1 ? 0 : 8.h,
                ),
                child: AppCard(
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
                      IconButton(
                        onPressed: () => form.removeSelectedPlace(place),
                        icon: Icon(
                          Icons.close,
                          color: context.palette.textMuted,
                          size: 20.w,
                        ),
                        tooltip: l10n.removePlace,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Responsive.spaceMd.gapH,
        CustomButton(
          label: selected.isEmpty ? l10n.addPlace : l10n.addAnotherPlace,
          icon: Icons.add_location_alt_outlined,
          variant: AppButtonVariant.outlined,
          onPressed: form.canAddMorePlaces ? onAddVotePlace : null,
        ),
      ],
    );
  }
}
