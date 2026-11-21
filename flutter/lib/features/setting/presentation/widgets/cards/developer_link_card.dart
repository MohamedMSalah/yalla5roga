import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/support_email.dart';

enum DeveloperPlatform { portfolio, linkedIn, github, email }

class DeveloperLinkCard extends StatelessWidget {
  const DeveloperLinkCard({
    super.key,
    required this.platform,
    required this.title,
    required this.subtitle,
    required this.destination,
  });

  final DeveloperPlatform platform;
  final String title;
  final String subtitle;
  final String destination;

  Future<void> _open(BuildContext context) async {
    final l10n = context.l10n;
    if (platform != DeveloperPlatform.email) {
      final opened = await AppLauncher.open(destination);
      if (!opened && context.mounted) {
        AppSnackBar.show(l10n.couldNotOpenLink);
      }
      return;
    }

    final opened = await openSupportEmail(subject: l10n.appName);
    if (opened || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.email),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.noEmailApp),
            Responsive.spaceSm.gapH,
            const SupportEmailAddress(),
            const CopySupportEmail(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => _open(context),
      showBorder: true,
      padding: EdgeInsets.all(AppSpacing.compact.w),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.brandSoft,
              borderRadius: BorderRadius.circular(Responsive.radiusSm),
            ),
            child: _platformIcon(palette.brandStrong),
          ),
          Responsive.spaceMd.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(
                  subtitle,
                  style: text.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Responsive.spaceSm.gapW,
          Icon(Icons.open_in_new, size: 16.w, color: palette.textMuted),
        ],
      ),
    );
  }

  Widget _platformIcon(Color color) => switch (platform) {
    DeveloperPlatform.portfolio => Icon(
      Icons.language,
      color: color,
      size: 20.w,
    ),
    DeveloperPlatform.email => Icon(
      Icons.mail_outline,
      color: color,
      size: 20.w,
    ),
    DeveloperPlatform.linkedIn => _brandIcon(_linkedInPath, color),
    DeveloperPlatform.github => _brandIcon(_githubPath, color),
  };

  Widget _brandIcon(String path, Color color) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="$path"/></svg>',
    width: 18.w,
    height: 18.w,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    excludeFromSemantics: true,
  );

  static const _linkedInPath =
      'M4.98 3.5a2.48 2.48 0 1 1-4.96 0 2.48 2.48 0 0 1 4.96 0zM.5 8h4v15h-4z'
      'M8 8h4v2.05C12.75 8.75 14.1 7.5 16.6 7.5 21 7.5 23 10 23 14.1V23h-4v-8.1'
      'c0-2-.65-3.65-2.65-3.65C14 11.25 12 12.8 12 15v8H8z';
  static const _githubPath =
      'M12 .75a11.25 11.25 0 0 0-3.56 21.92c.56.1.77-.24.77-.54v-2.1'
      'c-3.13.68-3.79-1.33-3.79-1.33-.51-1.3-1.25-1.64-1.25-1.64'
      '-1.02-.7.08-.69.08-.69 1.13.08 1.72 1.16 1.72 1.16 1 1.72 2.63 1.22 3.27.93'
      '.1-.73.39-1.22.71-1.5-2.5-.29-5.13-1.25-5.13-5.56 0-1.23.44-2.23 1.16-3.02'
      '-.12-.28-.5-1.43.11-2.98 0 0 .95-.3 3.1 1.15a10.8 10.8 0 0 1 5.62 0'
      'c2.15-1.46 3.1-1.15 3.1-1.15.61 1.55.23 2.7.11 2.98.72.79 1.16 1.79 1.16 3.02'
      ' 0 4.32-2.63 5.27-5.14 5.55.4.35.76 1.03.76 2.08v3.1c0 .3.2.65.77.54'
      'A11.25 11.25 0 0 0 12 .75z';
}
