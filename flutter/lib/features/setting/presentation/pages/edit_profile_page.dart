import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';
import 'package:yalla_5roga/core/media/media_upload_service.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/image_source_sheet.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/pages/change_password_page.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/edit_profile_avatar_section.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_edit_sheet.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_phone_sheet.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_text_sheet.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/sign_out_to_login.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  String? _name;
  String? _imagePath;
  bool _saving = false;

  Future<void> _editName(String name) async {
    final value = await ProfileEditSheet.show<String>(
      context,
      (_) => ProfileTextSheet.name(name),
    );
    if (mounted && value != null) setState(() => _name = value);
  }

  Future<void> _pickImage() async {
    final path = await ImageSourceSheet.pick(
      title: context.l10n.changeProfileImage,
    );
    if (mounted && path != null) setState(() => _imagePath = path);
  }

  Future<void> _save() async {
    if (_saving) return;
    final auth = context.read<AuthProvider>();
    final l10n = context.l10n;
    setState(() => _saving = true);

    if (auth.hasPassword) {
      final password = await ProfileEditSheet.show<String>(
        context,
        (_) => const ProfileTextSheet.password(),
      );
      if (!mounted) return;
      if (password == null || !await auth.confirmPassword(password)) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }

    if (!mounted) return;
    final previousImage = auth.user?.imageUrl;
    final wantsNewImage =
        _imagePath != null && _imagePath != auth.user?.imageUrl;
    String? imageRef;
    if (wantsNewImage) {
      try {
        if (isLocalFilePath(_imagePath)) {
          final uploaded = await context.read<MediaUploadService>().uploadLocalImage(
            path: _imagePath!,
            purpose: MediaPurpose.profile,
          );
          imageRef = uploaded.reference;
        } else {
          imageRef = _imagePath;
        }
      } catch (_) {
        if (mounted) {
          setState(() => _saving = false);
          AppSnackBar.show(l10n.imageUploadFailed);
        }
        return;
      }
    }

    if (!mounted) return;
    final success = await auth.syncProfileToBackend(
      name: _name == auth.user?.name ? null : _name,
      imageUrl: imageRef,
    );
    if (!mounted) return;
    if (success) {
      final uploads = context.read<MediaUploadService>();
      if (wantsNewImage &&
          isMediaReference(previousImage) &&
          previousImage != imageRef) {
        unawaited(uploads.deleteMediaReference(previousImage));
      }
      setState(() {
        _name = null;
        _imagePath = null;
      });
      await AppAlert.success(context, message: l10n.profileUpdated);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _deleteAccount() async {
    final l10n = context.l10n;
    final confirmed = await AppAlert.confirm(
      title: l10n.deleteAccountTitle,
      message: l10n.deleteAccountBody,
      confirmText: l10n.deleteAccount,
      cancelText: l10n.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    // Account deletion still requires a backend endpoint.
    await signOutToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final name = _name ?? user?.name ?? '';
    final phone = user?.phone ?? '';
    final image = _imagePath ?? user?.imageUrl;
    final dirty =
        (_name != null && _name != user?.name) ||
        (_imagePath != null && _imagePath != user?.imageUrl);
    final busy = _saving || auth.isLoading;

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppPageBar(title: l10n.editProfile),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: Responsive.pagePadding(),
            children: [
              EditProfileAvatarSection(
                imagePath: image,
                onPickImage: _pickImage,
                pickEnabled: !busy,
              ),
              Responsive.spaceLg.gapH,
              _ProfileValueButton(
                label: l10n.name,
                value: name,
                icon: Icons.edit_outlined,
                onPressed: busy ? null : () => _editName(name),
              ),
              _ProfileValueButton(
                label: l10n.phone,
                value: l10n.digits(phone),
                icon: Icons.edit_outlined,
                onPressed: busy
                    ? null
                    : () => ProfilePhoneSheet.open(
                        context,
                        phone: phone,
                        canEdit: true,
                      ),
              ),
              if (auth.hasPassword)
                _ProfileValueButton(
                  label: l10n.editPassword,
                  icon: context.chevronForward,
                  onPressed: busy
                      ? null
                      : () => Get.to(() => const ChangePasswordPage()),
                ),
              Responsive.spaceXl.gapH,
              CustomButton(
                label: l10n.saveChanges,
                icon: Icons.check,
                isLoading: _saving,
                onPressed: dirty && !busy ? _save : null,
              ),
              Responsive.spaceXl.gapH,
              CustomButton(
                label: l10n.deleteAccount,
                icon: Icons.delete_outline,
                variant: AppButtonVariant.danger,
                onPressed: busy ? null : _deleteAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileValueButton extends StatelessWidget {
  const _ProfileValueButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.value = '',
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.texts.labelLarge),
                if (value.isNotEmpty)
                  Text(value, style: context.texts.bodyLarge),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 20),
        ],
      ),
    );
  }
}
