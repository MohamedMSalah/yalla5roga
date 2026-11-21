import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';

Future<bool> openSupportEmail({required String subject, String? body}) {
  // mailto clients expect percent-encoded spaces and CRLF line breaks.
  final query = [
    'subject=${Uri.encodeComponent(subject)}',
    if (body != null)
      'body=${Uri.encodeComponent(body.replaceAll(RegExp(r'\r?\n|\r'), '\r\n'))}',
  ].join('&');
  final uri = Uri(scheme: 'mailto', path: AppConfig.contactEmail, query: query);
  return AppLauncher.open(uri.toString());
}

class CopySupportEmail extends StatelessWidget {
  const CopySupportEmail({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextButton.icon(
      onPressed: () async {
        await Clipboard.setData(
          const ClipboardData(text: AppConfig.contactEmail),
        );
        if (!context.mounted) return;
        AppSnackBar.show(l10n.emailAddressCopied);
      },
      icon: const Icon(Icons.copy_outlined),
      label: Text(l10n.copyEmailAddress),
    );
  }
}

class SupportEmailAddress extends StatelessWidget {
  const SupportEmailAddress({super.key});

  @override
  Widget build(BuildContext context) => const SelectableText(
    AppConfig.contactEmail,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.start,
  );
}
