import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';

class AddMemberPhoneSheet {
  const AddMemberPhoneSheet._();

  static Future<String?> show() {
    final phoneController = TextEditingController();
    return Get.bottomSheet<String>(
      SafeArea(child: _AddMemberPhoneSheetBody(controller: phoneController)),
    ).whenComplete(phoneController.dispose);
  }
}

class _AddMemberPhoneSheetBody extends StatelessWidget {
  const _AddMemberPhoneSheetBody({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Container(
      padding: Responsive.padding(all: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.addByPhone,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: Responsive.fontMd,
            ),
          ),
          Responsive.spaceMd.gapH,
          PhoneTextField(controller: controller, validate: false),
          Responsive.spaceMd.gapH,
          CustomButton(
            label: l10n.addPhone,
            onPressed: () {
              final error = Validators.phone(controller.text, l10n);
              if (error != null) {
                AppSnackBar.show(error);
                return;
              }
              Get.back(result: Validators.normalizePhone(controller.text));
            },
          ),
        ],
      ),
    );
  }
}
