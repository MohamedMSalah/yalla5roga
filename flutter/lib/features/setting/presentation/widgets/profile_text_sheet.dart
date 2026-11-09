import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_edit_sheet.dart';

class ProfileTextSheet extends StatefulWidget {
  const ProfileTextSheet.name(this.initialName, {super.key}) : password = false;
  const ProfileTextSheet.password({super.key})
    : initialName = '',
      password = true;

  final String initialName;
  final bool password;

  @override
  State<ProfileTextSheet> createState() => _ProfileTextSheetState();
}

class _ProfileTextSheetState extends State<ProfileTextSheet> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialName);
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context)
        .pop(widget.password ? _controller.text : _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = widget.password ? l10n.currentPassword : l10n.name;
    return ProfileEditSheet(
      title: widget.password ? l10n.confirmWithPassword : label,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _controller,
              label: label,
              obscureText: widget.password && _obscured,
              onToggleObscure: widget.password
                  ? () => setState(() => _obscured = !_obscured)
                  : null,
              textInputAction: TextInputAction.done,
              inputFormatters: widget.password
                  ? null
                  : [InputFormatters.maxLength(AppConstants.maxNameLength)],
              validator: (value) => widget.password
                  ? Validators.required(value, l10n)
                  : Validators.name(value, l10n),
            ),
            Responsive.spaceMd.gapH,
            CustomButton(label: l10n.saveChanges, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
