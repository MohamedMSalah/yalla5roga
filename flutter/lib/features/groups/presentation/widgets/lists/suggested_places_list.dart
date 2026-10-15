import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/suggested_place_card.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Group details list: place suggestions + create multi-place vote sheet.
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
              onPressed: () => _openSuggestSheet(context),
              icon: Icon(Icons.add_location_alt_outlined, size: 18.w),
              label: Text(
                l10n.suggest,
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

  Future<void> _openSuggestSheet(BuildContext context) async {
    final titleController = TextEditingController();
    final selected = <Place>{};
    var hours = 3;
    var publishing = false;

    try {
      final createdOuting = await Get.bottomSheet<Outing>(
        SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final l10n = context.l10n;
              final palette = context.palette;
              return Container(
                height: Responsive.height * 0.78,
                padding: Responsive.padding(all: 20),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24.r),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.suggestPlaces,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: Responsive.fontMd,
                      ),
                    ),
                    Text(
                      l10n.suggestPlacesSheetHint,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                    Responsive.spaceMd.gapH,
                    CustomTextField(
                      controller: titleController,
                      label: l10n.outingName,
                      hint: l10n.defaultOutingName,
                    ),
                    Responsive.spaceMd.gapH,
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.voteDeadlineHours,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: hours <= 1
                              ? null
                              : () => setModalState(() => hours -= 1),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: AppColors.brand600,
                        ),
                        Text(
                          l10n.hoursCount(hours),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.brand700,
                          ),
                        ),
                        IconButton(
                          onPressed: hours >= 72
                              ? null
                              : () => setModalState(() => hours += 1),
                          icon: const Icon(Icons.add_circle_outline),
                          color: AppColors.brand600,
                        ),
                      ],
                    ),
                    Responsive.spaceSm.gapH,
                    Text(
                      l10n.placesSelected(selected.length),
                      style: TextStyle(
                        color: AppColors.brand600,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.sp,
                      ),
                    ),
                    Responsive.spaceSm.gapH,
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final places = context
                              .read<DiscoverProvider>()
                              .catalogPlaces();
                          return ListView.builder(
                            itemCount: places.length,
                            itemBuilder: (context, index) {
                              final place = places[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: 8.h),
                                child: AppCard(
                                  onTap: () => setModalState(() {
                                    if (selected.contains(place)) {
                                      selected.remove(place);
                                    } else if (selected.length <
                                        OutingsProvider.maxVotePlaces) {
                                      selected.add(place);
                                    } else {
                                      AppSnackBar.show(
                                        l10n.pickAtMostFivePlaces,
                                      );
                                    }
                                  }),
                                  color: selected.contains(place)
                                      ? palette.brandSoft
                                      : null,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                color: palette.textMuted,
                                                fontSize: 10.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        selected.contains(place)
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        color: selected.contains(place)
                                            ? AppColors.brand600
                                            : palette.border,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    CustomButton(
                      label: l10n.publishSuggestion,
                      isLoading: publishing,
                      onPressed: () async {
                        if (publishing) return;
                        if (titleController.text.trim().isEmpty) {
                          AppSnackBar.show(l10n.nameRequired);
                          return;
                        }
                        if (selected.length < 2) {
                          AppSnackBar.show(l10n.pickAtLeastTwoPlaces);
                          return;
                        }
                        if (selected.length > OutingsProvider.maxVotePlaces) {
                          AppSnackBar.show(l10n.pickAtMostFivePlaces);
                          return;
                        }
                        setModalState(() => publishing = true);
                        final auth = context.read<AuthProvider>();
                        final outing = await context
                            .read<OutingsProvider>()
                            .suggestPlaces(
                              groupId: group.id,
                              title: titleController.text.trim(),
                              places: selected.toList(),
                              deadlineHours: hours,
                              createdBy: auth.user?.name ?? 'You',
                              createdById: auth.user?.id,
                            );
                        if (outing == null) {
                          if (context.mounted) {
                            setModalState(() => publishing = false);
                          }
                          return;
                        }
                        Get.back(result: outing);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        isScrollControlled: true,
      );

      if (createdOuting == null || !context.mounted) return;
      AppSnackBar.show(context.l10n.placesSuggested);
      Get.to(() => EventPage(event: createdOuting));
    } finally {
      titleController.dispose();
    }
  }
}
