import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';

class LocationUsageConsentSheet extends StatelessWidget {
  const LocationUsageConsentSheet({super.key});

  static Future<bool?> show(BuildContext context) => AppBottomSheet.show<bool>(
    context: context,
    builder: (_) => const LocationUsageConsentSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.locationConsentTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Responsive.spaceMd.gapH,
        Text(l10n.automaticMeetupLocationHint),
        Responsive.spaceSm.gapH,
        Text(l10n.locationRoutingDisclosure),
        Responsive.spaceSm.gapH,
        Text(l10n.locationConsentControlsHint),
        Responsive.spaceLg.gapH,
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.allow),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

@Preview(name: 'Smart Meetup location consent', size: Size(390, 580))
Widget locationUsageConsentPreview() => const MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: LocationUsageConsentSheet(),
    ),
  ),
);
