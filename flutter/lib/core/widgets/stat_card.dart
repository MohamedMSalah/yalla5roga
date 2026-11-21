import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });
  final String value;
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Padding(
      padding: EdgeInsets.all(Responsive.spaceSm),
      child: Column(
        children: [
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (icon case final glyph?)
                Icon(glyph, size: 17, color: context.palette.brandStrong),
              Text(value, style: context.texts.titleMedium),
            ],
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}
