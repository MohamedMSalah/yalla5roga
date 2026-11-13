import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';

class GroupInviteePicker extends StatelessWidget {
  const GroupInviteePicker({
    super.key,
    required this.phoneController,
    required this.phones,
    required this.isCreating,
    required this.onPickContacts,
    required this.onAddPhone,
    required this.onRemovePhone,
  });
  final TextEditingController phoneController;
  final List<String> phones;
  final bool isCreating;
  final VoidCallback onPickContacts, onAddPhone;
  final ValueChanged<String> onRemovePhone;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.invitePeople,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontSm,
            color: palette.textSecondary,
          ),
        ),
        Responsive.spaceSm.gapH,
        CustomButton(
          label: l10n.selectFromContacts,
          icon: Icons.contacts_outlined,
          size: AppButtonSize.medium,
          variant: AppButtonVariant.outlined,
          onPressed: isCreating ? null : onPickContacts,
        ),
        Responsive.spaceMd.gapH,
        Text(
          l10n.addByPhone,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontSm,
            color: palette.textSecondary,
          ),
        ),
        Responsive.spaceSm.gapH,
        PhoneTextField(
          controller: phoneController,
          validate: false,
          allowInternational: true,
        ),
        Responsive.spaceSm.gapH,
        CustomButton(
          label: l10n.addPhone,
          icon: Icons.person_add_alt_1_outlined,
          size: AppButtonSize.medium,
          variant: AppButtonVariant.outlined,
          onPressed: isCreating ? null : onAddPhone,
        ),
        if (phones.isNotEmpty) ...[
          Responsive.spaceMd.gapH,
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final phone in phones)
                Chip(
                  label: Text(
                    l10n.digits(MemberDisplayName.resolvePhone(phone)),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.sp,
                    ),
                  ),
                  onDeleted: isCreating ? null : () => onRemovePhone(phone),
                  backgroundColor: palette.surfaceMuted,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
