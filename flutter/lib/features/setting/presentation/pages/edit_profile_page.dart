import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/image_source_sheet.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/edit_profile_avatar_section.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/edit_profile_fields_section.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/edit_profile_password_section.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/edit_profile_phone_otp_section.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/edit_profile_section_card.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  String? _imagePath;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _editingPassword = false;
  late final String _initialEmail;
  late final String _initialPhone;
  late final String _initialName;
  late final String? _initialImage;
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    final user = _auth.user;
    _initialName = user?.name ?? '';
    _initialEmail = user?.email?.trim() ?? '';
    _initialPhone = user?.phone ?? '';
    _initialImage = user?.imageUrl;
    _nameController.text = _initialName;
    _emailController.text = _initialEmail;
    _phoneController.text = _displayPhone(_initialPhone);
    _imagePath = _initialImage;
    _phoneController.addListener(_onPhoneChanged);
  }

  String _displayPhone(String phone) {
    final local = Validators.localPhoneDigits(phone);
    if (local.length <= Validators.localPhoneLength) return local;
    return local.substring(local.length - Validators.localPhoneLength);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    if (_auth.otpSent || _auth.phoneAutoVerified) {
      _auth.resetOtp();
    }
    super.dispose();
  }

  void _onPhoneChanged() {
    if (_auth.otpSent || _auth.phoneAutoVerified) {
      final pending = _auth.pendingPhone;
      if (pending == null ||
          Validators.localPhoneDigits(pending) != _newLocalPhone) {
        _otpController.clear();
        _auth.resetOtp();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    final path = await ImageSourceSheet.pick(
      title: context.l10n.changeProfileImage,
    );
    if (path == null || !mounted) return;
    setState(() => _imagePath = path);
  }

  String _authError(AuthProvider auth) {
    return context.l10n.authError(
      auth.errorCode,
      fallback: auth.errorMessage ?? context.l10n.unexpectedError,
    );
  }

  String get _lastLocalPhone => Validators.localPhoneDigits(_initialPhone);

  String get _newLocalPhone =>
      Validators.localPhoneDigits(_phoneController.text);

  bool get _phoneChanged => _newLocalPhone != _lastLocalPhone;

  bool get _needsPhoneOtp =>
      _newLocalPhone.length == Validators.localPhoneLength &&
      _phoneChanged &&
      Validators.isValidEgyptianPhone(_phoneController.text);

  bool get _emailChanged =>
      _emailController.text.trim().toLowerCase() != _initialEmail.toLowerCase();

  bool get _nameChanged => _nameController.text.trim() != _initialName.trim();

  bool get _imageChanged => (_imagePath ?? '') != (_initialImage ?? '');

  bool get _wantsPasswordChange =>
      _editingPassword &&
      (_newPasswordController.text.isNotEmpty ||
          _confirmPasswordController.text.isNotEmpty);

  bool get _hasAnyChange =>
      _nameChanged ||
      _emailChanged ||
      _phoneChanged ||
      _imageChanged ||
      _wantsPasswordChange;

  void _toggleEditPassword() {
    setState(() {
      _editingPassword = !_editingPassword;
      if (!_editingPassword) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    });
  }

  Future<void> _sendPhoneOtp() async {
    final l10n = context.l10n;
    final phoneError = Validators.phone(_phoneController.text, l10n);
    if (phoneError != null) {
      AppSnackBar.showError(phoneError);
      return;
    }
    final auth = context.read<AuthProvider>();
    final phone = Validators.normalizePhone(_phoneController.text);
    _otpController.clear();
    final ok = await auth.sendOtp(phone, updateCurrentUser: true);
    if (!mounted) return;
    if (!ok) {
      AppSnackBar.showError(_authError(auth));
      return;
    }
    AppSnackBar.show(
      auth.phoneAutoVerified
          ? l10n.phoneVerified
          : l10n.otpSent(l10n.digits(phone)),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final auth = context.read<AuthProvider>();
    final hasPassword = auth.hasPasswordProvider;

    if (!_hasAnyChange) {
      Get.back();
      return;
    }

    if (_phoneChanged) {
      final phone = Validators.normalizePhone(_phoneController.text);
      final otpReady =
          (auth.otpSent || auth.phoneAutoVerified) &&
          auth.pendingPhone == phone;
      if (!otpReady) {
        AppSnackBar.showError(l10n.verifyNewPhoneFirst);
        return;
      }
    }

    if (hasPassword) {
      if (_currentPasswordController.text.isEmpty) {
        AppSnackBar.showError(l10n.confirmWithPassword);
        return;
      }
      final confirmed = await auth.confirmPassword(
        _currentPasswordController.text,
      );
      if (!mounted) return;
      if (!confirmed) {
        AppSnackBar.showError(_authError(auth));
        return;
      }
    }

    if (_wantsPasswordChange && hasPassword) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        AppSnackBar.showError(l10n.passwordsDoNotMatch);
        return;
      }
    }

    var changedSomething = false;
    String? syncedName;
    String? syncedEmail;
    String? syncedPhone;
    String? syncedImage;

    if (_nameChanged || _imageChanged) {
      final ok = await auth.updateProfile(
        name: _nameChanged ? _nameController.text.trim() : null,
        imageUrl: _imageChanged ? _imagePath : null,
      );
      if (!mounted) return;
      if (!ok) {
        AppSnackBar.showError(_authError(auth));
        return;
      }
      if (_nameChanged) syncedName = _nameController.text.trim();
      if (_imageChanged) syncedImage = _imagePath;
      changedSomething = true;
    }

    if (_emailChanged && hasPassword) {
      final ok = await auth.requestEmailChange(
        newEmail: _emailController.text.trim(),
        currentPassword: _currentPasswordController.text,
      );
      if (!mounted) return;
      if (!ok) {
        AppSnackBar.showError(_authError(auth));
        return;
      }
      syncedEmail = _emailController.text.trim();
      AppSnackBar.show(l10n.emailChangeSent);
      changedSomething = true;
    }

    if (_wantsPasswordChange && hasPassword) {
      final ok = await auth.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      if (!ok) {
        AppSnackBar.showError(_authError(auth));
        return;
      }
      AppSnackBar.show(l10n.passwordUpdated);
      changedSomething = true;
    }

    if (_phoneChanged && auth.phoneAutoVerified) {
      syncedPhone = Validators.normalizePhone(_phoneController.text);
      changedSomething = true;
    } else if (_phoneChanged && auth.otpSent) {
      final phone = Validators.normalizePhone(_phoneController.text);
      final ok = await auth.changePhoneNumber(
        phone: phone,
        smsCode: Validators.normalizeOtp(_otpController.text),
      );
      if (!mounted) return;
      if (!ok) {
        AppSnackBar.showError(_authError(auth));
        return;
      }
      syncedPhone = phone;
      AppSnackBar.show(l10n.phoneUpdated);
      changedSomething = true;
    }

    if (changedSomething &&
        (syncedName != null ||
            syncedEmail != null ||
            syncedPhone != null ||
            syncedImage != null)) {
      await auth.syncProfileToBackend(
        name: syncedName,
        email: syncedEmail,
        phone: syncedPhone,
        imageUrl: syncedImage,
      );
    }

    if (!mounted) return;
    if (!changedSomething) {
      Get.back();
      return;
    }
    if (!_emailChanged && !_wantsPasswordChange && !_phoneChanged) {
      AppSnackBar.show(l10n.profileUpdated);
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final hasPassword = auth.hasPasswordProvider;

    return Scaffold(
      appBar: AppPageBar(
        title: l10n.editProfile,
        subtitle: l10n.profileSettings,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: Responsive.pagePadding(),
                children: [
                  EditProfileAvatarSection(
                    imagePath: _imagePath,
                    onPickImage: _pickImage,
                    pickEnabled: !auth.isLoading,
                  ),
                  Responsive.spaceLg.gapH,
                  EditProfileSectionCard(
                    title: l10n.personalDetails,
                    child: EditProfileFieldsSection(
                      nameController: _nameController,
                      emailController: _emailController,
                      phoneController: _phoneController,
                      hasPassword: hasPassword,
                      showContact: false,
                    ),
                  ),
                  Responsive.spaceMd.gapH,
                  EditProfileSectionCard(
                    title: l10n.contactDetails,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EditProfileFieldsSection(
                          nameController: _nameController,
                          emailController: _emailController,
                          phoneController: _phoneController,
                          hasPassword: hasPassword,
                          showName: false,
                          phoneAutovalidateMode:
                              AutovalidateMode.onUserInteraction,
                        ),
                        EditProfilePhoneOtpSection(
                          phoneChanged: _needsPhoneOtp,
                          otpSent: auth.otpSent,
                          phoneAutoVerified: auth.phoneAutoVerified,
                          isLoading: auth.isLoading,
                          otpController: _otpController,
                          onSendOtp: _sendPhoneOtp,
                        ),
                      ],
                    ),
                  ),
                  if (hasPassword) ...[
                    Responsive.spaceMd.gapH,
                    EditProfileSectionCard(
                      title: l10n.securityDetails,
                      subtitle: l10n.confirmWithPassword,
                      child: EditProfilePasswordSection(
                        currentPasswordController: _currentPasswordController,
                        newPasswordController: _newPasswordController,
                        confirmPasswordController: _confirmPasswordController,
                        obscureCurrent: _obscureCurrent,
                        obscureNew: _obscureNew,
                        obscureConfirm: _obscureConfirm,
                        editingPassword: _editingPassword,
                        isLoading: auth.isLoading,
                        hasAnyChange: _hasAnyChange,
                        onToggleObscureCurrent: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                        onToggleObscureNew: () =>
                            setState(() => _obscureNew = !_obscureNew),
                        onToggleObscureConfirm: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        onToggleEditPassword: _toggleEditPassword,
                      ),
                    ),
                  ],
                  Responsive.spaceXl.gapH,
                ],
              ),
            ),
            Material(
              color: context.palette.background,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: Responsive.pagePadding().copyWith(top: 8.h),
                  child: CustomButton(
                    label: l10n.saveChanges,
                    icon: Icons.check,
                    isLoading: auth.isLoading,
                    onPressed: _save,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
