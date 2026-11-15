import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/voting_deadline_selector.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_schedule_field.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/special_event_fields.dart';
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
          SpecialEventFields(
            form: form,
            onPickGroup: onPickGroup,
            onInviteGuests: onInviteGuests,
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
                      ? context.palette.brandSoft
                      : context.palette.chipActive,
                  foreground: form.group == null
                      ? context.palette.brandStrong
                      : context.palette.chipActiveText,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OutingScheduleField(
                label: l10n.date,
                value: form.shortDate,
                icon: Icons.calendar_today,
                onTap: onPickDate,
              ),
            ),
            10.gapW,
            Expanded(
              child: OutingScheduleField(
                label: l10n.time,
                value: form.formattedTime,
                icon: Icons.schedule,
                onTap: onPickTime,
              ),
            ),
          ],
        ),
        Responsive.spaceMd.gapH,
        if (!form.specialEvent) VotingDeadlineSelector(form: form),
      ],
    );
  }
}
