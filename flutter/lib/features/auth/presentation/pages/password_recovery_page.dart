import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/core/widgets/otp_input.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/password_recovery_provider.dart';

class PasswordRecoveryPage extends StatelessWidget {
  const PasswordRecoveryPage({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        PasswordRecoveryProvider(context.read<AuthProvider>().repository),
    child: const _RecoveryForm(),
  );
}

class _RecoveryForm extends StatefulWidget {
  const _RecoveryForm();
  @override
  State<_RecoveryForm> createState() => _RecoveryFormState();
}

class _RecoveryFormState extends State<_RecoveryForm> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _visible = [false, false];

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _error(PasswordRecoveryProvider recovery, {bool starting = false}) {
    final failure = recovery.failure;
    if (failure == null) return;
    final l10n = context.l10n;
    final message = failure.statusCode == 429
        ? l10n.recoveryRateLimited
        : starting && failure.statusCode == 400
        ? l10n.recoveryUnavailable
        : failure.statusCode == 401
        ? l10n.recoveryExpired
        : FailureMessageMapper.localize(failure, l10n);
    AppSnackBar.showError(message);
  }

  Future<void> _send({bool resend = false}) async {
    if (!resend && !_form.currentState!.validate()) return;
    final recovery = context.read<PasswordRecoveryProvider>();
    _code.clear();
    final phone = resend
        ? recovery.phone
        : Validators.normalizePhone(_phone.text);
    final ok = await recovery.send(phone);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.show(context.l10n.otpSent(context.l10n.digits(phone)));
    } else {
      _error(recovery, starting: true);
    }
  }

  Future<void> _submit() async {
    final recovery = context.read<PasswordRecoveryProvider>();
    if (recovery.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (recovery.verified) {
      final ok = await recovery.reset(_password.text, _confirm.text);
      if (!mounted) return;
      if (ok) {
        context.read<AuthProvider>().resetAuthForm();
        final message = context.l10n.recoverySuccess;
        Navigator.of(context).pop();
        AppSnackBar.show(message);
      } else {
        _error(recovery);
      }
    } else if (recovery.codeSent) {
      final ok = await recovery.verify(Validators.normalizeOtp(_code.text));
      if (!mounted) return;
      if (!ok) {
        _error(recovery);
      } else {
        _code.clear();
      }
    } else {
      await _send();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovery = context.watch<PasswordRecoveryProvider>();
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.palette.surface,
      appBar: AppPageBar(title: l10n.recoverPassword),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: Form(
              key: _form,
              child: ListView(
                padding: Responsive.pagePadding(),
                children: [
                  Text(
                    recovery.verified
                        ? l10n.recoveryPasswordHelp
                        : recovery.codeSent
                        ? l10n.recoveryCodeHelp
                        : l10n.recoveryPhoneHelp,
                    style: context.texts.bodyLarge,
                  ),
                  Responsive.spaceLg.gapH,
                  if (recovery.verified) ...[
                    CustomTextField(
                      controller: _password,
                      label: l10n.newPassword,
                      prefixIcon: Icons.lock_outline,
                      obscureText: !_visible[0],
                      onToggleObscure: () =>
                          setState(() => _visible[0] = !_visible[0]),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          Validators.password(value, l10n) ??
                          (utf8.encode(value ?? '').length > 72
                              ? l10n.recoveryPasswordLimit
                              : null),
                    ),
                    Responsive.spaceMd.gapH,
                    CustomTextField(
                      controller: _confirm,
                      label: l10n.confirmNewPassword,
                      prefixIcon: Icons.lock_outline,
                      obscureText: !_visible[1],
                      onToggleObscure: () =>
                          setState(() => _visible[1] = !_visible[1]),
                      textInputAction: TextInputAction.done,
                      validator: (value) =>
                          Validators.required(value, l10n) ??
                          (value == _password.text
                              ? null
                              : l10n.passwordsDoNotMatch),
                    ),
                  ] else if (recovery.codeSent) ...[
                    Text(
                      l10n.digits(recovery.phone),
                      textDirection: TextDirection.ltr,
                    ),
                    Responsive.spaceMd.gapH,
                    OtpInput(
                      controller: _code,
                      label: l10n.otp,
                      length: Validators.otpLength,
                      validator: (value) => Validators.otp(value, l10n),
                      onCompleted: (_) {
                        if (!recovery.busy) _submit();
                      },
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: recovery.busy || recovery.resendSeconds > 0
                          ? null
                          : () => _send(resend: true),
                      child: Text(
                        recovery.resendSeconds > 0
                            ? l10n.recoveryResendIn(recovery.resendSeconds)
                            : l10n.resendOtp,
                      ),
                    ),
                  ] else
                    PhoneTextField(controller: _phone),
                  Responsive.spaceLg.gapH,
                  CustomButton(
                    label: recovery.verified
                        ? l10n.resetPassword
                        : recovery.codeSent
                        ? l10n.verifyPhoneNumber
                        : l10n.sendOtp,
                    isLoading: recovery.busy,
                    onPressed:
                        recovery.busy ||
                            (!recovery.verified &&
                                !recovery.codeSent &&
                                recovery.resendSeconds > 0)
                        ? null
                        : _submit,
                  ),
                  if (!recovery.codeSent &&
                      !recovery.verified &&
                      recovery.resendSeconds > 0)
                    Padding(
                      padding: EdgeInsets.only(top: Responsive.spaceMd),
                      child: Text(
                        l10n.recoveryResendIn(recovery.resendSeconds),
                      ),
                    ),
                  if (recovery.codeSent || recovery.verified)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: recovery.busy
                          ? null
                          : () {
                              _code.clear();
                              _password.clear();
                              _confirm.clear();
                              recovery.restart();
                            },
                      child: Text(l10n.recoveryStartAgain),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
