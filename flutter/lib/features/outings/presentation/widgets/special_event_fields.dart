import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/vibe_picker.dart';

/// Occasion and audience controls; common image/schedule fields stay in the wizard.
class SpecialEventFields extends StatelessWidget {
  const SpecialEventFields({
    super.key,
    required this.form,
    required this.onPickGroup,
    required this.onInviteGuests,
  });
  final CreateOutingProvider form;
  final VoidCallback onPickGroup, onInviteGuests;
  static const occasions = [
    OutingOccasion.birthday,
    OutingOccasion.wedding,
    OutingOccasion.celebration,
    OutingOccasion.other,
  ];
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.specialEvent, style: context.texts.titleSmall),
        Responsive.spaceSm.gapH,
        VibePicker(
          options: [
            VibeOption(Icons.cake_outlined, l10n.birthday),
            VibeOption(Icons.favorite_border, l10n.wedding),
            VibeOption(Icons.celebration_outlined, l10n.celebration),
            VibeOption(Icons.event_outlined, l10n.otherOccasion),
          ],
          index: occasions.indexOf(form.occasion),
          onChanged: (index) => form.setOccasion(occasions[index]),
        ),
        Responsive.spaceMd.gapH,
        Text(l10n.eventGroupOptional, style: context.texts.titleSmall),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.groups_outlined),
            title: Text(form.group?.name ?? l10n.independentEvent),
            subtitle: Text(
              form.group == null
                  ? l10n.chooseGroup
                  : l10n.membersWillBeInvited(form.group!.memberCount),
            ),
            onTap: form.groupLocked ? null : onPickGroup,
            trailing: form.group == null || form.groupLocked
                ? null
                : IconButton(
                    tooltip: l10n.independentEvent,
                    icon: const Icon(Icons.close),
                    onPressed: () => form.setGroup(null),
                  ),
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
            form.occasion.label(l10n),
          ),
          style: context.texts.bodySmall,
        ),
      ],
    );
  }
}
