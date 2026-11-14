import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';

import '../pages/profile_info_page.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import 'cards/about_developer_card.dart';

class SettingsSupportSection extends StatelessWidget {
  const SettingsSupportSection({super.key});
  Future<void> _openLink(BuildContext context, String url) async {
    final opened = await AppLauncher.open(url);
    if (!opened && context.mounted) {
      AppSnackBar.show(context.l10n.couldNotOpenLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.support,
      children: [
        SettingsTile(
          icon: Icons.help_outline,
          title: l10n.helpAndFaq,
          background: AppColors.amber100,
          foreground: AppColors.amber700,
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
          subtitle: l10n.getInTouch,
          background: context.palette.surfaceMuted,
          foreground: context.palette.textPrimary,
          trailing: Icon(
            Icons.arrow_outward,
            size: 16.w,
            color: context.palette.textMuted,
          ),
          onTap: () => _openLink(
            context,
            'mailto:${AboutDeveloperCard.contactEmail}?subject=Yalla%205roga',
          ),
        ),
      ],
    );
  }
}
