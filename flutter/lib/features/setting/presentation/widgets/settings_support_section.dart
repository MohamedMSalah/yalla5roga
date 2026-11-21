import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../pages/contact_us_page.dart';
import '../pages/profile_info_page.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

class SettingsSupportSection extends StatelessWidget {
  const SettingsSupportSection({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      icon: Icons.headset_mic_outlined,
      title: l10n.support,
      children: [
        SettingsTile(
          icon: Icons.help_outline,
          title: l10n.helpAndFaq,
          background: context.palette.warningSoft,
          foreground: context.palette.warning,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(
            () => ProfileInfoPage(
              title: l10n.helpAndFaq,
              children: [
                ProfileInfoBlock(
                  title: l10n.faqCreateOuting,
                  body: l10n.faqCreateOutingAnswer,
                ),
                ProfileInfoBlock(
                  title: l10n.faqGroups,
                  body: l10n.faqGroupsAnswer,
                ),
                ProfileInfoBlock(
                  title: l10n.faqInvite,
                  body: l10n.faqInviteAnswer,
                ),
              ],
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.mail_outline,
          title: l10n.contactUs,
          background: context.palette.surfaceMuted,
          foreground: context.palette.textPrimary,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(() => const ContactUsPage()),
        ),
      ],
    );
  }
}
