import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';

class EditProfileFieldsSection extends StatelessWidget {
  const EditProfileFieldsSection({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.hasPassword,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final bool hasPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: nameController,
          label: l10n.name,
          hint: l10n.nameHint,
          prefixIcon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            InputFormatters.maxLength(AppConstants.maxNameLength),
          ],
          validator: (value) => Validators.name(value, l10n),
        ),
        Responsive.spaceMd.gapH,
        CustomTextField(
          controller: emailController,
          label: l10n.email,
          hint: l10n.emailHint,
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          inputFormatters: [InputFormatters.noSpaces, InputFormatters.email],
          validator: (value) => Validators.email(value, l10n),
        ),
        if (!hasPassword) ...[
          Responsive.spaceSm.gapH,
          Text(
            l10n.socialAccountHint,
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: Responsive.fontSm,
              height: 1.35,
            ),
          ),
        ],
        Responsive.spaceMd.gapH,
        PhoneTextField(
          controller: phoneController,
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }
}
