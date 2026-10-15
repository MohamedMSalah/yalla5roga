import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/lists/settings_list.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/settings_tile.dart';

class AboutDeveloperCard extends StatelessWidget {
  const AboutDeveloperCard({super.key});

  static const githubUrl = 'https://github.com/MohamedMSalah';
  static const portfolioUrl = 'https://mmsalahresume26.lovable.app/';
  static const contactEmail = 'mohamedmsalah26@gmail.com';

  /// Set this to `assets/branding/developer.png` after adding the file to pubspec assets.
  static const String? avatarAsset = null;

  Future<void> _open(BuildContext context, String url) async {
    final opened = await AppLauncher.open(url);
    if (!opened && context.mounted) {
      AppSnackBar.show(context.l10n.couldNotOpenLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return SettingsGroup(
      title: l10n.developerName,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.developerTitle,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            Responsive.spaceXs.gapH,
            Text(
              l10n.developerTagline,
              style: TextStyle(color: palette.textMuted, fontSize: 10.sp),
            ),

            12.gapH,
            Text(
              l10n.developerDescription,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: Responsive.fontSm,
                height: 1.45,
              ),
            ),
            Responsive.spaceSm.gapH,
            Text(
              l10n.developerShortDescription,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: Responsive.fontSm,
                height: 1.45,
              ),
            ),
          ],
        ),
        SettingsTile(
          icon: Icons.code,
          title: l10n.github,
          subtitle: l10n.viewMyProjects,
          background: context.palette.surfaceMuted,
          foreground: context.palette.textPrimary,
          trailing: Icon(
            Icons.open_in_new,
            size: 16.w,
            color: palette.textMuted,
          ),
          onTap: () => _open(context, githubUrl),
        ),
        SettingsTile(
          icon: Icons.language,
          title: l10n.portfolio,
          subtitle: l10n.viewMyPortfolio,
          background: AppColors.brand50,
          foreground: AppColors.brand600,
          trailing: Icon(
            Icons.open_in_new,
            size: 16.w,
            color: palette.textMuted,
          ),
          onTap: () => _open(context, portfolioUrl),
        ),
        SettingsTile(
          icon: Icons.mail_outline,
          title: l10n.contactDeveloper,
          subtitle: l10n.getInTouch,
          background: const Color(0xFFE0F2FE),
          foreground: const Color(0xFF0284C7),
          trailing: Icon(
            Icons.arrow_outward,
            size: 16.w,
            color: palette.textMuted,
          ),
          onTap: () =>
              _open(context, 'mailto:$contactEmail?subject=Yalla%205roga'),
        ),
      ],
    );
  }
}
