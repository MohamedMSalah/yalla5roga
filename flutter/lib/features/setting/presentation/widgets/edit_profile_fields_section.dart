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
    required this.phoneController,
    this.showName = true,
    this.showContact = true,
    this.phoneAutovalidateMode,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool showName;
  final bool showContact;
  final AutovalidateMode? phoneAutovalidateMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final children = <Widget>[
      if (showName)
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
      if (showContact) ...[
        PhoneTextField(
          controller: phoneController,
          textInputAction: TextInputAction.next,
          autovalidateMode: phoneAutovalidateMode,
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Responsive.spaceMd.gapH,
          children[i],
        ],
      ],
    );
  }
}
