import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
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
        AppNetworkImage(
          url: form.resolvedImage,
          width: double.infinity,
          height: 160.h,
          radius: 22.r,
          placeholderIcon: Icons.explore_outlined,
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
                  form.occasion == OutingOccasion.birthday
                      ? l10n.birthday
                      : l10n.wedding,
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
              if (form.multiPlaceMode) ...[
                Responsive.spaceXs.gapH,
                Text(
                  l10n.voteClosesInHours(form.voteDeadlineHours),
                  style: TextStyle(
                    color: AppColors.amber700,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.sp,
                  ),
                ),
              ],
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
                    ? l10n.guestsInvited(form.guestIds.length)
                    : form.group == null
                    ? l10n.chooseGroup
                    : l10n.membersWillBeInvited(form.group!.memberCount),
                style: TextStyle(
                  color: AppColors.brand600,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (form.specialEvent)
                Text(
                  form.guestNames.join(', '),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                )
              else if (form.group != null)
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
