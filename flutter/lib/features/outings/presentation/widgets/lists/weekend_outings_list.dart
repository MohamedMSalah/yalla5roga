import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/lists/outings_list.dart';

/// Outings-tab filtered list with “this weekend” section title.
class WeekendOutingsList extends StatelessWidget {
  const WeekendOutingsList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return OutingsList(
      filtered: true,
      title: l10n.thisWeekend.toUpperCase(),
      titleStyle: TextStyle(
        color: palette.textMuted,
        fontSize: Responsive.fontCaption,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}
