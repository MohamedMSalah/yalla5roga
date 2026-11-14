import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../pages/about_developer_page.dart';
import '../pages/profile_info_page.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

class SettingsAboutSection extends StatelessWidget {
  const SettingsAboutSection({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.about,
      children: [
        SettingsTile(
          icon: Icons.info_outline,
          title: l10n.aboutYalla5roga,
          background: AppColors.brand50,
          foreground: AppColors.brand600,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(
            () => ProfileInfoPage(
              title: l10n.aboutYalla5roga,
              children: [
                ProfileInfoBlock(title: l10n.appName, body: l10n.aboutAppBody),
              ],
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.lock_outline,
          title: l10n.privacyPolicy,
          background: context.palette.brandSoft,
          foreground: context.palette.brandStrong,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(
            () => ProfileInfoPage(
              title: l10n.privacyPolicy,
              children: [
                ProfileInfoBlock(
                  title: l10n.privacyPolicy,
                  body: l10n.privacyPolicyBody,
                ),
              ],
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.description_outlined,
          title: l10n.termsAndConditions,
          background: context.palette.surfaceMuted,
          foreground: context.palette.textPrimary,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(
            () => ProfileInfoPage(
              title: l10n.termsAndConditions,
              children: [
                ProfileInfoBlock(
                  title: l10n.termsAndConditions,
                  body: l10n.termsBody,
                ),
              ],
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.computer_outlined,
          title: l10n.aboutDeveloper,
          //subtitle: l10n.developerName,
          background: AppColors.brand50,
          foreground: AppColors.brand600,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(() => const AboutDeveloperPage()),
        ),
      ],
    );
  }
}
