import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';

class EditProfilePasswordSection extends StatelessWidget {
  const EditProfilePasswordSection({
    super.key,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.obscureCurrent,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.editingPassword,
    required this.isLoading,
    required this.hasAnyChange,
    required this.onToggleObscureCurrent,
    required this.onToggleObscureNew,
    required this.onToggleObscureConfirm,
    required this.onToggleEditPassword,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool obscureCurrent;
  final bool obscureNew;
  final bool obscureConfirm;
  final bool editingPassword;
  final bool isLoading;
  final bool hasAnyChange;
  final VoidCallback onToggleObscureCurrent;
  final VoidCallback onToggleObscureNew;
  final VoidCallback onToggleObscureConfirm;
  final VoidCallback onToggleEditPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Responsive.spaceLg.gapH,
        Text(
          l10n.confirmWithPassword,
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: Responsive.fontSm,
            height: 1.35,
          ),
        ),
        Responsive.spaceMd.gapH,
        CustomTextField(
          controller: currentPasswordController,
          label: l10n.currentPassword,
          obscureText: obscureCurrent,
          prefixIcon: Icons.lock_outline,
          textInputAction: TextInputAction.next,
          onToggleObscure: onToggleObscureCurrent,
          validator: (value) {
            if (!hasAnyChange) return null;
            return Validators.required(value, l10n);
          },
        ),
        Responsive.spaceMd.gapH,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: isLoading ? null : onToggleEditPassword,
            icon: Icon(
              editingPassword ? Icons.close : Icons.lock_reset_outlined,
              size: 18.w,
              color: AppColors.brand600,
            ),
            label: Text(
              editingPassword ? l10n.cancelEditPassword : l10n.editPassword,
              style: TextStyle(
                color: AppColors.brand600,
                fontWeight: FontWeight.w800,
                fontSize: Responsive.fontSm,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: editingPassword
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Responsive.spaceMd.gapH,
                    CustomTextField(
                      controller: newPasswordController,
                      label: l10n.newPassword,
                      hint: l10n.passwordHint,
                      obscureText: obscureNew,
                      prefixIcon: Icons.lock_outline,
                      textInputAction: TextInputAction.next,
                      onToggleObscure: onToggleObscureNew,
                      validator: (value) {
                        if (!editingPassword) return null;
                        if ((value ?? '').isEmpty &&
                            confirmPasswordController.text.isEmpty) {
                          return null;
                        }
                        return Validators.password(value, l10n);
                      },
                    ),
                    Responsive.spaceMd.gapH,
                    CustomTextField(
                      controller: confirmPasswordController,
                      label: l10n.confirmNewPassword,
                      obscureText: obscureConfirm,
                      prefixIcon: Icons.lock_outline,
                      textInputAction: TextInputAction.done,
                      onToggleObscure: onToggleObscureConfirm,
                      validator: (value) {
                        if (!editingPassword) return null;
                        if ((value ?? '').isEmpty &&
                            newPasswordController.text.isEmpty) {
                          return null;
                        }
                        if (value != newPasswordController.text) {
                          return l10n.passwordsDoNotMatch;
                        }
                        return Validators.password(value, l10n);
                      },
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
