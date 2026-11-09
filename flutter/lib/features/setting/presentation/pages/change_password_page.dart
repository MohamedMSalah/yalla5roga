import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  final _visible = List.filled(3, false);
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final l10n = context.l10n;
    final success = await auth.changePassword(
      currentPassword: _current.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    if (success) {
      await AppAlert.success(context, message: l10n.passwordUpdated);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    } else {
      setState(() => _saving = false);
    }
  }

  Widget _field(
    int index,
    String label,
    TextEditingController controller,
    FormFieldValidator<String> validator,
  ) {
    return CustomTextField(
      controller: controller,
      label: label,
      prefixIcon: Icons.lock_outline,
      obscureText: !_visible[index],
      onToggleObscure: () => setState(() => _visible[index] = !_visible[index]),
      textInputAction: index == 2 ? TextInputAction.done : TextInputAction.next,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppPageBar(title: l10n.editPassword),
        body: SafeArea(
          top: false,
          child: Form(
            key: _form,
            child: ListView(
              padding: Responsive.pagePadding(),
              children: [
                _field(
                  0,
                  l10n.currentPassword,
                  _current,
                  (value) => Validators.required(value, l10n),
                ),
                Responsive.spaceMd.gapH,
                _field(
                  1,
                  l10n.newPassword,
                  _newPassword,
                  (value) => Validators.password(value, l10n),
                ),
                Responsive.spaceMd.gapH,
                _field(2, l10n.confirmNewPassword, _confirm, (value) {
                  return Validators.required(value, l10n) ??
                      (value == _newPassword.text
                          ? null
                          : l10n.passwordsDoNotMatch);
                }),
                Responsive.spaceXl.gapH,
                CustomButton(
                  label: l10n.saveChanges,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
