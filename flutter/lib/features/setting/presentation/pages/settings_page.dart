import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/localization/locale_provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/theme_provider.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/app_switch.dart';
import 'package:yalla_5roga/core/widgets/language_choice.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/pages/about_developer_page.dart';
import 'package:yalla_5roga/features/setting/presentation/providers/settings_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/pages/edit_profile_page.dart';
import 'package:yalla_5roga/features/setting/presentation/pages/profile_info_page.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/cards/about_developer_card.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_header.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_stats.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/outing_history_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/saved_outings_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/lists/settings_list.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/phone_verification_chip.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/profile_phone_sheet.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/sign_out_to_login.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/settings_tile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loggingOut = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshProfile();
    });
  }

  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    _loggingOut = true;
    final l10n = context.l10n;
    final confirmed = await AppAlert.confirm(
      title: l10n.logoutConfirmTitle,
      message: l10n.logoutConfirmBody,
      confirmText: l10n.logOut,
      cancelText: l10n.cancel,
    );
    if (!confirmed || !context.mounted) {
      _loggingOut = false;
      return;
    }
    await signOutToLogin(context);
  }

  void _openEditProfile(BuildContext context) {
    Get.to(() => const EditProfilePage());
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final opened = await AppLauncher.open(url);
    if (!opened && context.mounted) {
      AppSnackBar.show(context.l10n.couldNotOpenLink);
    }
  }

  Widget _chevron(BuildContext context) {
    return Icon(
      context.chevronForward,
      color: context.palette.border,
      size: 20.w,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().user;
    final locale = context.watch<LocaleProvider>();
    final theme = context.watch<ThemeProvider>();
    final savedOutings = context.watch<SavedOutingsProvider>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: Responsive.pagePadding().add(
          EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        ),
        children: [
          ProfileHeader(
            user: user,
            onLogout: () => _logout(context),
            onEditProfile: () => _openEditProfile(context),
          ),
          Responsive.spaceMd.gapH,
          const ProfileStats(),
          Responsive.spaceXl.gapH,
          SettingsGroup(
            title: l10n.accountSettings,
            children: [
              SettingsTile(
                icon: Icons.phone_outlined,
                title: l10n.phone,
                subtitle: l10n.digits(user?.phone ?? ''),
                background: const Color(0xFFEDE9FE),
                foreground: const Color(0xFF7C3AED),
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
                icon: Icons.bookmark_outline,
                title: l10n.mySaved,
                subtitle: savedOutings.totalCount == 0
                    ? l10n.mySavedSubtitle
                    : l10n.savedCount(savedOutings.totalCount),
                background: AppColors.brand50,
                foreground: AppColors.brand600,
                trailing: _chevron(context),
                onTap: () => Get.to(() => const SavedOutingsPage()),
              ),
              SettingsTile(
                icon: Icons.history,
                title: l10n.outingHistory,
                subtitle: l10n.outingHistoryHint,
                trailing: _chevron(context),
                onTap: () => Get.to(() => const OutingHistoryPage()),
              ),
              SettingsTile(
                icon: theme.isDark
                    ? Icons.wb_sunny_outlined
                    : Icons.dark_mode_outlined,
                title: l10n.darkTheme,
                subtitle: l10n.useDarkColors,
                background: const Color(0xFFEDE9FE),
                foreground: const Color(0xFF7C3AED),
                trailing: AppSwitch(
                  value: theme.isDark,
                  onChanged: (value) async {
                    await theme.setDark(value);
                    AppSnackBar.show(l10n.themeChanged);
                  },
                ),
              ),
            ],
          ),
          12.gapH,
          // SettingsGroup — notifications + LanguageChoice
          SettingsGroup(
            title: l10n.preferences,
            children: [
              SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: l10n.notifications,
                subtitle: l10n.votesPlansReminders,
                background: AppColors.rose50,
                foreground: AppColors.rose500,
                trailing: AppSwitch(
                  value: context.watch<SettingsProvider>().pushEnabled,
                  onChanged: context.read<SettingsProvider>().setPushEnabled,
                ),
              ),
              SettingsTile(
                icon: Icons.language,
                title: l10n.appLanguage,
                subtitle: locale.isRtl ? l10n.arabic : l10n.english,
                background: const Color(0xFFD1FAE5),
                foreground: const Color(0xFF059669),
                trailing: const LanguageChoice(),
              ),
            ],
          ),
          12.gapH,
          // SettingsGroup — help, contact
          SettingsGroup(
            title: l10n.support,
            children: [
              SettingsTile(
                icon: Icons.help_outline,
                title: l10n.helpAndFaq,
                background: AppColors.amber100,
                foreground: AppColors.amber700,
                trailing: _chevron(context),
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
                background: const Color(0xFFE0F2FE),
                foreground: const Color(0xFF0284C7),
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
          ),
          12.gapH,
          // SettingsGroup — about, privacy, terms
          SettingsGroup(
            title: l10n.about,
            children: [
              SettingsTile(
                icon: Icons.info_outline,
                title: l10n.aboutYalla5roga,
                background: AppColors.brand50,
                foreground: AppColors.brand600,
                trailing: _chevron(context),
                onTap: () => Get.to(
                  () => ProfileInfoPage(
                    title: l10n.aboutYalla5roga,
                    children: [
                      ProfileInfoBlock(
                        title: l10n.appName,
                        body: l10n.aboutAppBody,
                      ),
                    ],
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.lock_outline,
                title: l10n.privacyPolicy,
                background: const Color(0xFFEDE9FE),
                foreground: const Color(0xFF7C3AED),
                trailing: _chevron(context),
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
                trailing: _chevron(context),
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
            ],
          ),
          12.gapH,
          // SettingsGroup — AboutDeveloperPage
          SettingsGroup(
            title: l10n.developer,
            children: [
              SettingsTile(
                icon: Icons.computer_outlined,
                title: l10n.aboutDeveloper,
                //subtitle: l10n.developerName,
                background: AppColors.brand50,
                foreground: AppColors.brand600,
                trailing: _chevron(context),
                onTap: () => Get.to(() => const AboutDeveloperPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
