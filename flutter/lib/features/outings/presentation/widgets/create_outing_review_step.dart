import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';

class CreateOutingReviewStep extends StatelessWidget {
  const CreateOutingReviewStep({super.key, required this.form});

  final CreateOutingProvider form;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        PlanningCover(
          url: form.resolvedImage,
          art: form.occasion.coverArt,
          width: double.infinity,
          height: 160.h,
          radius: 22.r,
        ),
        Responsive.spaceMd.gapH,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                form.nameController.text.trim(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.fontMd,
                ),
              ),
              if (form.occasion != OutingOccasion.none) ...[
                Responsive.spaceXs.gapH,
                Text(
                  form.occasion.label(l10n),
                  style: TextStyle(
                    color: AppColors.brand600,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.sp,
                  ),
                ),
              ],
              Responsive.spaceSm.gapH,
              Text(
                form.locationLabel,
                style: TextStyle(color: context.palette.textMuted),
              ),
              if (!form.specialEvent)
                Text(l10n.votingDeadlineSummary(form.previewVotingDeadline)),
              if (form.votingDeadlineError(l10n) case final error?)
                Text(
                  error,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              Responsive.spaceSm.gapH,
              if (!form.specialEvent)
                Text(l10n.vibeLabel(OutingVibe.values[form.vibe].name)),
              Wrap(
                spacing: Responsive.spaceSm,
                children: [
                  TextButton.icon(
                    onPressed: () => form.editStep(0),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.whatAreWeDoing),
                  ),
                  TextButton.icon(
                    onPressed: () => form.editStep(1),
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: Text(l10n.pickAPlace),
                  ),
                ],
              ),
              if (form.selectedLocation?.hasCoordinates ?? false) ...[
                Responsive.spaceXs.gapH,
                Text(
                  l10n.locationPinned,
                  style: TextStyle(
                    color: AppColors.brand600,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.sp,
                  ),
                ),
              ],
              Responsive.spaceSm.gapH,
              Text(
                '${form.formattedDate} · ${form.formattedTime}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Responsive.spaceSm.gapH,
              Text(
                form.specialEvent
                    ? l10n.guestsInvited(
                        form.guestIds.length + form.guestPhones.length,
                      )
                    : form.group == null
                    ? l10n.chooseGroup
                    : l10n.membersWillBeInvited(form.group!.memberCount),
                style: TextStyle(
                  color: AppColors.brand600,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (form.guestPhones.isNotEmpty)
                Text(l10n.whatsappGuestCount(form.guestPhones.length)),
              if (form.specialEvent && form.guestIds.isNotEmpty)
                Text(
                  form.guestNames.join(', '),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              if (form.group != null)
                Text(
                  form.group!.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
