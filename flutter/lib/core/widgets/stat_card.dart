import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Padding(
      padding: EdgeInsets.all(Responsive.spaceSm),
      child: Column(
        children: [
          Text(value, style: context.texts.titleLarge),
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
