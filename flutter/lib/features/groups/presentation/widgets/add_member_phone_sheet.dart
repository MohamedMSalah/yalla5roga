import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/pick_device_contacts_page.dart';

class AddMemberPhoneSheet {
  const AddMemberPhoneSheet._();

  static Future<({List<String> phones, bool whatsappOptIn})?> show() {
    return Get.bottomSheet<({List<String> phones, bool whatsappOptIn})>(
      const SafeArea(child: _AddMemberPhoneSheetBody()),
      isScrollControlled: true,
      enterBottomSheetDuration: AppMotion.sheetEnter,
      exitBottomSheetDuration: AppMotion.sheetExit,
    );
  }
}

class _AddMemberPhoneSheetBody extends StatefulWidget {
  const _AddMemberPhoneSheetBody();

  @override
  State<_AddMemberPhoneSheetBody> createState() =>
      _AddMemberPhoneSheetBodyState();
}

class _AddMemberPhoneSheetBodyState extends State<_AddMemberPhoneSheetBody> {
  var _whatsappOptIn = false;
  var _callingCode = '+20';
  var _contactPhones = <String>[];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickContacts() async {
    final selected = await Get.to<List<String>>(
      () => PickDeviceContactsPage(
        initialSelectedPhones: _contactPhones.toSet(),
        allowInternational: true,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _contactPhones = selected;
      _whatsappOptIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        maxWidth: Responsive.contentMaxWidth,
      ),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        child: SingleChildScrollView(
          padding: Responsive.padding(all: 20).add(
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.addPeople,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.fontMd,
                ),
              ),
              Responsive.spaceMd.gapH,
              CustomButton(
                label: l10n.selectFromContacts,
                icon: Icons.contacts_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: _pickContacts,
              ),
              if (_contactPhones.isNotEmpty) ...[
                Responsive.spaceSm.gapH,
                Wrap(
                  spacing: Responsive.spaceSm,
                  children: [
                    for (final phone in _contactPhones)
                      Chip(
                        label: Text(
                          l10n.digits(phone),
                          textDirection: TextDirection.ltr,
                        ),
                        onDeleted: () => setState(() {
                          _contactPhones.remove(phone);
                          _whatsappOptIn = false;
                        }),
                      ),
                  ],
                ),
              ],
              Responsive.spaceMd.gapH,
              PhoneTextField(
                controller: _controller,
                validate: false,
                allowInternational: true,
                callingCode: _callingCode,
                onCallingCodeChanged: (code) => setState(() {
                  _callingCode = code;
                  _whatsappOptIn = false;
                }),
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
                label: _contactPhones.isEmpty
                    ? l10n.addPhone
                    : l10n.addSelectedContacts(_contactPhones.length),
                onPressed: !_whatsappOptIn
                    ? null
                    : () {
                        final phones = _contactPhones.toSet();
                        if (_controller.text.trim().isNotEmpty ||
                            phones.isEmpty) {
                          final phone = Validators.normalizeGroupPhone(
                            _controller.text,
                            callingCode: _callingCode,
                          );
                          if (phone == null) {
                            AppSnackBar.show(l10n.invalidPhone);
                            return;
                          }
                          phones.add(phone);
                        }
                        Get.back(
                          result: (
                            phones: phones.toList(),
                            whatsappOptIn: _whatsappOptIn,
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
