import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/localization/locale_provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/theme_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/app_switch.dart';
import 'package:yalla_5roga/core/widgets/language_choice.dart';
import 'package:yalla_5roga/features/invitations/presentation/pages/invitations_page.dart';
import 'package:yalla_5roga/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/outing_history_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/saved_outings_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';

import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';

import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

class SettingsPreferencesSection extends StatelessWidget {
  const SettingsPreferencesSection({super.key});
  Widget _buildInvitationsBadge(BuildContext context) {
    final invitations = context.watch<InvitationsProvider>();
    final count = invitations.pendingCount;
    if (count == 0) return const SettingsChevron();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.rose500,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        context.l10n.n(count),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.watch<LocaleProvider>();
    final theme = context.watch<ThemeProvider>();
    final savedOutings = context.watch<SavedOutingsProvider>();
    return SettingsSection(
      title: l10n.preferences,
      children: [
        SettingsTile(
          icon: Icons.bookmark_outline,
          title: l10n.mySaved,
          subtitle: savedOutings.totalCount == 0
              ? l10n.mySavedSubtitle
              : l10n.savedCount(savedOutings.totalCount),
          background: AppColors.brand50,
          foreground: AppColors.brand600,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(() => const SavedOutingsPage()),
        ),
        SettingsTile(
          icon: Icons.history,
          title: l10n.outingHistory,
          subtitle: l10n.outingHistoryHint,
          trailing: const SettingsChevron(),
          onTap: () => Get.to(() => const OutingHistoryPage()),
        ),
        SettingsTile(
          icon: theme.isDark
              ? Icons.wb_sunny_outlined
              : Icons.dark_mode_outlined,
          title: l10n.darkTheme,
          subtitle: l10n.useDarkColors,
          background: context.palette.brandSoft,
          foreground: context.palette.brandStrong,
          trailing: AppSwitch(
            value: theme.isDark,
            onChanged: (value) async {
              await theme.setDark(value);
              AppSnackBar.show(l10n.themeChanged);
            },
          ),
        ),

        SettingsTile(
          icon: Icons.notifications_active_outlined,
          title: l10n.notifications,
          subtitle: l10n.votesPlansReminders,
          background: AppColors.rose50,
          foreground: AppColors.rose500,
          trailing: AppSwitch(
            value: context.watch<NotificationsProvider>().pushEnabled,
            onChanged: context.read<NotificationsProvider>().setPushEnabled,
          ),
        ),
        SettingsTile(
          icon: Icons.mail_outline,
          title: l10n.invitations,
          subtitle: l10n.invitedBy(context.l10n.appName),
          background: AppColors.brand50,
          foreground: AppColors.brand500,
          trailing: _buildInvitationsBadge(context),
          onTap: () => Get.to(() => const InvitationsPage()),
        ),
        SettingsTile(
          icon: Icons.language,
          title: l10n.appLanguage,
          subtitle: locale.isRtl ? l10n.arabic : l10n.english,
          background: context.palette.surfaceMuted,
          foreground: context.palette.textPrimary,
          trailing: const LanguageChoice(),
        ),
      ],
    );
  }
}
