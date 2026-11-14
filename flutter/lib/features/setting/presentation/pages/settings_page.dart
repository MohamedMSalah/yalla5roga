import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';

import '../pages/edit_profile_page.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';
import '../widgets/sign_out_to_login.dart';
import '../widgets/settings_account_section.dart';
import '../widgets/settings_preferences_section.dart';
import '../widgets/settings_support_section.dart';
import '../widgets/settings_about_section.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

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
            onEditProfile: () => Get.to(() => const EditProfilePage()),
          ),
          Responsive.spaceMd.gapH,
          const ProfileStats(),
          Responsive.spaceXl.gapH,
          const SettingsAccountSection(),
          12.gapH,
          // SettingsGroup — notifications + LanguageChoice
          const SettingsPreferencesSection(),
          12.gapH,
          // SettingsGroup — help, contact
          const SettingsSupportSection(),
          12.gapH,
          // SettingsGroup — about, privacy, terms
          const SettingsAboutSection(),
        ],
      ),
    );
  }
}
