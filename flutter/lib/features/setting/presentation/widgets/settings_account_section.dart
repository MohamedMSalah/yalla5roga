import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';

import '../pages/edit_profile_page.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import 'phone_verification_chip.dart';
import 'profile_phone_sheet.dart';

class SettingsAccountSection extends StatelessWidget {
  const SettingsAccountSection({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().user;
    return SettingsSection(
      icon: Icons.person_outline,
      title: l10n.accountSettings,
      children: [
        SettingsTile(
          icon: Icons.edit_outlined,
          title: l10n.editProfile,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(() => const EditProfilePage()),
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
          background: context.palette.warningSoft,
          foreground: context.palette.warning,
        ),
      ],
    );
  }
}
