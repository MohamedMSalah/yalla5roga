import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/vibe_picker.dart';

class CreateOutingBasicsStep extends StatelessWidget {
  const CreateOutingBasicsStep({
    super.key,
    required this.form,
    required this.onUploadPhoto,
    required this.onInviteGuests,
    required this.onPickGroup,
    required this.onPickDate,
    required this.onPickTime,
  });

  final CreateOutingProvider form;
  final Future<void> Function() onUploadPhoto;
  final VoidCallback onInviteGuests;
  final VoidCallback onPickGroup;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlanningCoverPicker(
          url: form.image ?? '',
          art: form.occasion.coverArt,
          optionalLabel: l10n.outingPhotoOptional,
          onTap: onUploadPhoto,
        ),
        Responsive.spaceMd.gapH,
        CustomTextField(
          controller: form.nameController,
          label: form.specialEvent ? l10n.eventName : l10n.outingName,
          prefixIcon: Icons.auto_awesome,
          inputFormatters: [
            InputFormatters.maxLength(AppConstants.maxOutingNameLength),
          ],
          validator: (value) => Validators.outingName(value, l10n),
        ),
        Responsive.spaceMd.gapH,
        if (form.specialEvent) ...[
          Text(
            l10n.specialEvent,
            style: TextStyle(
              fontSize: Responsive.fontSm,
              fontWeight: FontWeight.w800,
              color: context.palette.textSecondary,
            ),
          ),
          Responsive.spaceXs.gapH,
          Text(
            l10n.specialEventHint,
            style: TextStyle(color: context.palette.textMuted, fontSize: 10.sp),
          ),
          Responsive.spaceSm.gapH,
          VibePicker(
            options: [
              VibeOption(Icons.cake_outlined, l10n.birthday),
              VibeOption(Icons.favorite_border, l10n.wedding),
            ],
            index: form.occasion == OutingOccasion.wedding ? 1 : 0,
            onChanged: (index) => form.setOccasion(
              index == 1 ? OutingOccasion.wedding : OutingOccasion.birthday,
            ),
          ),
          Responsive.spaceMd.gapH,
          CustomButton(
            label: l10n.invitePeople,
            icon: Icons.person_add_alt_1_outlined,
            variant: AppButtonVariant.outlined,
            onPressed: onInviteGuests,
          ),
          Responsive.spaceSm.gapH,
          Text(
            l10n.youInvitedPeopleToEvent(
              form.guestIds.length + form.guestPhones.length,
              form.occasion == OutingOccasion.wedding
                  ? l10n.wedding
                  : l10n.birthday,
            ),
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: Responsive.fontSm,
              height: 1.35,
            ),
          ),
        ] else ...[
          Text(
            l10n.pickAVibe,
            style: TextStyle(
              fontSize: Responsive.fontSm,
              fontWeight: FontWeight.w800,
              color: context.palette.textSecondary,
            ),
          ),
          Responsive.spaceSm.gapH,
          VibePicker(
            options: VibeOption.outingVibes(l10n),
            index: form.vibe,
            onChanged: form.setVibe,
          ),
          Responsive.spaceMd.gapH,
          Text(
            l10n.inviteAGroup,
            style: TextStyle(
              fontSize: Responsive.fontSm,
              fontWeight: FontWeight.w800,
              color: context.palette.textSecondary,
            ),
          ),
          Responsive.spaceSm.gapH,
          AppCard(
            onTap: form.groupLocked ? null : onPickGroup,
            color: form.group == null ? context.palette.brandSoft : null,
            child: Row(
              children: [
                IconCircle(
                  icon: Icons.groups_2_outlined,
                  background: form.group == null
                      ? AppColors.brand50
                      : AppColors.brand600,
                  foreground: form.group == null
                      ? AppColors.brand600
                      : Colors.white,
                ),
                12.gapW,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.group?.name ?? l10n.chooseGroup,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        form.group == null
                            ? l10n.inviteAGroup
                            : l10n.membersWillBeInvited(
                                form.group!.memberCount,
                              ),
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!form.groupLocked)
                  Icon(Icons.unfold_more, color: context.palette.textMuted),
              ],
            ),
          ),
        ],
        Responsive.spaceMd.gapH,
        Row(
          children: [
            Expanded(
              child: AppCard(
                onTap: onPickDate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.date,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    Responsive.spaceSm.gapH,
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppColors.brand600,
                        ),
                        Responsive.spaceSm.gapW,
                        Expanded(
                          child: Text(
                            form.shortDate,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            10.gapW,
            Expanded(
              child: AppCard(
                onTap: onPickTime,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.time,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    Responsive.spaceSm.gapH,
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: AppColors.brand600,
                        ),
                        Responsive.spaceSm.gapW,
                        Expanded(
                          child: Text(
                            form.formattedTime,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Responsive.spaceMd.gapH,
        Text(l10n.voteDeadlineHours, style: context.texts.titleSmall),
        Text(l10n.voteDeadlineHint, style: context.texts.bodySmall),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: l10n.decreaseVoteHours,
              onPressed: form.voteDeadlineHours <= 1
                  ? null
                  : () => form.setVoteDeadlineHours(form.voteDeadlineHours - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(l10n.hoursCount(form.voteDeadlineHours)),
            IconButton(
              tooltip: l10n.increaseVoteHours,
              onPressed: form.voteDeadlineHours >= 72
                  ? null
                  : () => form.setVoteDeadlineHours(form.voteDeadlineHours + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}
