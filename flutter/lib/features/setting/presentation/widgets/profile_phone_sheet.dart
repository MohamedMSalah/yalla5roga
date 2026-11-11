import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/edit_profile_phone_otp_section.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_edit_sheet.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_text_sheet.dart';

class ProfilePhoneSheet extends StatefulWidget {
  const ProfilePhoneSheet._({required this.phone, required this.canEdit});

  final String phone;
  final bool canEdit;

  static Future<void> open(
    BuildContext context, {
    required String phone,
    bool canEdit = false,
  }) async {
    final auth = context.read<AuthProvider>();
    auth.resetOtp();
    final success = await ProfileEditSheet.show<bool>(
      context,
      (_) => ProfilePhoneSheet._(phone: phone, canEdit: canEdit),
    );
    auth.resetOtp();
    if (success == true && context.mounted) {
      await context.read<GroupsProvider>().refresh(forceRefresh: true);
      if (!context.mounted) return;
      await AppAlert.success(context, message: context.l10n.phoneVerified);
    }
  }

  @override
  State<ProfilePhoneSheet> createState() => _ProfilePhoneSheetState();
}

class _ProfilePhoneSheetState extends State<ProfilePhoneSheet> {
  final _phoneForm = GlobalKey<FormState>();
  final _otpForm = GlobalKey<FormState>();
  late final _phone = TextEditingController(
    text: Validators.localPhoneDigits(widget.phone),
  );
  final _code = TextEditingController();
  bool _busy = false;
  bool _verified = false;
  String? _authorizedNumber;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phone.removeListener(_onPhoneChanged);
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _number =>
      Validators.normalizePhone(widget.canEdit ? _phone.text : widget.phone);

  void _onPhoneChanged() {
    final auth = context.read<AuthProvider>();
    if (auth.pendingPhone != null && auth.pendingPhone != _number) {
      _code.clear();
      auth.resetOtp();
    }
  }

  Future<void> _send() async {
    if (_busy || !(_phoneForm.currentState?.validate() ?? true)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final number = _number;
    if (widget.canEdit &&
        auth.hasPassword &&
        number != Validators.normalizePhone(widget.phone) &&
        number != _authorizedNumber) {
      final password = await ProfileEditSheet.show<String>(
        context,
        (_) => const ProfileTextSheet.password(),
      );
      if (!mounted) return;
      if (password == null || !await auth.confirmPassword(password)) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      _authorizedNumber = number;
    }
    _code.clear();
    final sent = await auth.sendOtp(number, updateCurrentUser: true);
    if (!mounted) return;
    if (sent && auth.phoneAutoVerified) {
      _verified = true;
      await _sync();
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || (!_verified && !_otpForm.currentState!.validate())) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    if (!_verified) {
      _verified = await auth.changePhoneNumber(
        phone: _number,
        smsCode: Validators.normalizeOtp(_code.text),
      );
    }
    if (!mounted) return;
    if (_verified) {
      await _sync();
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    final success = await context.read<AuthProvider>().syncProfileToBackend(
      phone: _number,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final otpSent = auth.otpSent && auth.pendingPhone == _number;
    return PopScope(
      canPop: !_busy,
      child: ProfileEditSheet(
        title: l10n.verifyPhoneNumber,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.canEdit)
              Form(
                key: _phoneForm,
                child: IgnorePointer(
                  ignoring: _busy || _verified,
                  child: PhoneTextField(controller: _phone),
                ),
              )
            else
              Text(l10n.digits(widget.phone), style: context.texts.titleMedium),
            if (!_verified)
              Form(
                key: _otpForm,
                child: EditProfilePhoneOtpSection(
                  phoneChanged: true,
                  otpSent: otpSent,
                  phoneAutoVerified: false,
                  isLoading: _busy,
                  otpController: _code,
                  onSendOtp: _send,
                  hint: l10n.phoneVerificationSmsHint,
                ),
              ),
            if (otpSent || _verified) ...[
              Responsive.spaceMd.gapH,
              CustomButton(
                label: _verified ? l10n.tryAgain : l10n.verifyPhoneNumber,
                isLoading: _busy,
                onPressed: _busy ? null : _verify,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
