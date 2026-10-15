import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/core/widgets/otp_input.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/auth/presentation/widgets/auth_social_buttons.dart';
import 'package:yalla_5roga/features/shell/presentation/pages/main_shell.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({super.key});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final auth = context.read<AuthProvider>();
    if (!auth.otpSent) return;
    if (Validators.isValidEgyptianPhone(_phoneController.text)) return;
    _otpController.clear();
    auth.resetOtp();
  }

  String _authError(AuthProvider auth) {
    final l10n = context.l10n;
    return l10n.authError(
      auth.errorCode,
      fallback:
          auth.errorMessage ??
          (auth.isLogin ? l10n.loginFailed : l10n.registerFailed),
    );
  }

  Future<void> _resendOtp() async {
    final auth = context.read<AuthProvider>();
    final phone = Validators.normalizePhone(_phoneController.text);
    final ok = await auth.resendOtp(phone);
    if (!mounted) return;
    if (!ok) {
      AppSnackBar.showError(_authError(auth));
      return;
    }
    AppSnackBar.show(context.l10n.otpSent(context.l10n.digits(phone)));
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (!AppConfig.useMockData && !auth.agreeTerms) {
      AppSnackBar.showError(context.l10n.termsRequired);
      return;
    }
    final phone = Validators.normalizePhone(_phoneController.text);
    _otpController.clear();
    final ok = await auth.sendOtp(phone);
    if (!mounted) return;
    if (!ok) {
      AppSnackBar.showError(_authError(auth));
      return;
    }
    AppSnackBar.show(context.l10n.otpSent(context.l10n.digits(phone)));
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (!ok) {
      AppSnackBar.showError(_authError(auth));
      return;
    }
    Get.offAll(() => const MainShell());
  }

  Future<void> _submitRegister() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    if (!AppConfig.useMockData && !auth.agreeTerms) {
      AppSnackBar.showError(l10n.termsRequired);
      return;
    }
    if (!AppConfig.useMockData && !auth.otpSent) {
      AppSnackBar.showError(l10n.verifyPhoneFirst);
      return;
    }

    FocusScope.of(context).unfocus();
    final ok = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: Validators.normalizePhone(_phoneController.text),
      smsCode: AppConfig.useMockData
          ? '123456'
          : Validators.normalizeOtp(_otpController.text),
    );

    if (!mounted) return;
    if (!ok) {
      AppSnackBar.showError(_authError(auth));
      return;
    }
    Get.offAll(() => const MainShell());
  }

  void _onOtpCompleted(String code) {
    if (code.length != Validators.otpLength) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoading || !auth.otpSent) return;
    _submitRegister();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final isLogin = auth.isLogin;
    final otpSent = auth.otpSent;

    if (!otpSent && _otpController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpController.clear();
      });
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isLogin) ...[
            CustomTextField(
              controller: _nameController,
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
          ],
          CustomTextField(
            controller: _emailController,
            label: l10n.email,
            hint: l10n.emailHint,
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            inputFormatters: [InputFormatters.noSpaces, InputFormatters.email],
            validator: (value) => Validators.email(value, l10n),
          ),
          Responsive.spaceMd.gapH,
          CustomTextField(
            controller: _passwordController,
            label: l10n.password,
            hint: l10n.passwordHint,
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            textInputAction: isLogin
                ? TextInputAction.done
                : TextInputAction.next,
            onToggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            validator: (value) => isLogin
                ? Validators.required(value, l10n)
                : Validators.password(value, l10n),
          ),
          if (!isLogin) ...[
            Responsive.spaceMd.gapH,
            PhoneTextField(controller: _phoneController),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: otpSent
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Responsive.spaceMd.gapH,
                        OtpInput(
                          controller: _otpController,
                          label: l10n.otp,
                          length: Validators.otpLength,
                          validator: (value) => Validators.otp(value, l10n),
                          onCompleted: _onOtpCompleted,
                          action: TextButton(
                            onPressed: auth.isLoading ? null : _resendOtp,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.resendOtp,
                              style: TextStyle(
                                color: AppColors.brand600,
                                fontSize: Responsive.fontSm,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Responsive.spaceSm.gapH,
            Row(
              children: [
                Checkbox(
                  value: auth.agreeTerms,
                  activeColor: AppColors.brand600,
                  onChanged: (value) => auth.setAgreeTerms(value ?? false),
                ),
                Expanded(
                  child: Text(
                    l10n.agreeTerms,
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: Responsive.fontSm,
                    ),
                  ),
                ),
              ],
            ),
          ],
          Responsive.spaceMd.gapH,
          if (isLogin)
            CustomButton(
              label: l10n.login,
              icon: Icons.arrow_forward,
              isLoading: auth.isLoading,
              onPressed: _submitLogin,
            )
          else
            CustomButton(
              label: AppConfig.useMockData || otpSent
                  ? l10n.register
                  : l10n.sendOtp,
              icon: AppConfig.useMockData || otpSent
                  ? Icons.person_add_alt_1
                  : Icons.sms_outlined,
              isLoading: auth.isLoading,
              onPressed: AppConfig.useMockData || otpSent
                  ? _submitRegister
                  : _sendOtp,
            ),
          Responsive.spaceLg.gapH,
          const AuthSocialButtons(),
        ],
      ),
    );
  }
}
