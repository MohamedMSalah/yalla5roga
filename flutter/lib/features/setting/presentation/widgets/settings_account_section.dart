import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';

import '../pages/edit_profile_page.dart';
import '../pages/profile_info_page.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import 'delete_account_action.dart';
import 'phone_verification_chip.dart';
import 'profile_phone_sheet.dart';

class SettingsAccountSection extends StatelessWidget {
  const SettingsAccountSection({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().user;
    return SettingsSection(
      title: l10n.accountSettings,
      children: [
        SettingsTile(
          icon: Icons.edit_outlined,
          title: l10n.editProfile,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(() => const EditProfilePage()),
        ),
        SettingsTile(
          icon: Icons.camera_alt_outlined,
          title: l10n.changePhoto,
          trailing: const SettingsChevron(),
          onTap: () =>
              Get.to(() => const EditProfilePage(pickPhotoOnOpen: true)),
        ),
        SettingsTile(
          icon: Icons.phone_outlined,
          title: l10n.phone,
          subtitle: l10n.digits(user?.phone ?? ''),
          background: context.palette.brandSoft,
          foreground: context.palette.brandStrong,
          trailing: PhoneVerificationChip(
            verified: user?.phoneVerified ?? false,
            onVerify:
                user != null &&
                    user.phone.trim().isNotEmpty &&
                    !user.phoneVerified
                ? () => ProfilePhoneSheet.open(context, phone: user.phone)
                : null,
          ),
        ),
        SettingsTile(
          icon: Icons.calendar_today_outlined,
          title: l10n.memberSince,
          subtitle: user?.createdAt != null
              ? l10n.formatMemberSince(user!.createdAt!)
              : null,
          background: AppColors.amber100,
          foreground: AppColors.amber700,
        ),
        SettingsTile(
          icon: Icons.info_outline,
          title: l10n.accountInformation,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(
            () => ProfileInfoPage(
              title: l10n.accountInformation,
              children: [
                ProfileInfoBlock(title: l10n.name, body: user?.name ?? ''),
                ProfileInfoBlock(
                  title: l10n.phone,
                  body: l10n.digits(user?.phone ?? ''),
                ),
                ProfileInfoBlock(
                  title: l10n.memberSince,
                  body: user?.createdAt == null
                      ? '—'
                      : l10n.formatMemberSince(user!.createdAt!),
                ),
              ],
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.delete_outline,
          title: l10n.deleteAccount,
          foreground: context.colors.error,
          onTap: context.watch<AuthProvider>().isLoading
              ? null
              : () => confirmDeleteAccount(context),
        ),
      ],
    );
  }
}
