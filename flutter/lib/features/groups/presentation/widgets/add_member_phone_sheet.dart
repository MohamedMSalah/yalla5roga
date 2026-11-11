import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';

class AddMemberPhoneSheet {
  const AddMemberPhoneSheet._();

  static Future<({String phone, bool whatsappOptIn})?> show() {
    final phoneController = TextEditingController();
    return Get.bottomSheet<({String phone, bool whatsappOptIn})>(
      SafeArea(child: _AddMemberPhoneSheetBody(controller: phoneController)),
      enterBottomSheetDuration: AppMotion.sheetEnter,
      exitBottomSheetDuration: AppMotion.sheetExit,
    ).whenComplete(phoneController.dispose);
  }
}

class _AddMemberPhoneSheetBody extends StatefulWidget {
  const _AddMemberPhoneSheetBody({required this.controller});

  final TextEditingController controller;

  @override
  State<_AddMemberPhoneSheetBody> createState() =>
      _AddMemberPhoneSheetBodyState();
}

class _AddMemberPhoneSheetBodyState extends State<_AddMemberPhoneSheetBody> {
  var _whatsappOptIn = false;

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
          PhoneTextField(
            controller: widget.controller,
            validate: false,
            allowInternational: true,
            onChanged: (_) {
              if (_whatsappOptIn) setState(() => _whatsappOptIn = false);
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _whatsappOptIn,
            title: Text(l10n.groupWhatsAppConsent),
            onChanged: (value) =>
                setState(() => _whatsappOptIn = value ?? false),
          ),
          Responsive.spaceMd.gapH,
          CustomButton(
            label: l10n.addPhone,
            onPressed: () {
              final phone = Validators.normalizeGroupPhone(
                widget.controller.text,
              );
              if (phone == null) {
                AppSnackBar.show(l10n.invalidPhone);
                return;
              }
              Get.back(result: (phone: phone, whatsappOptIn: _whatsappOptIn));
            },
          ),
        ],
      ),
    );
  }
}
