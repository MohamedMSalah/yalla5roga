import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';

/// Settings section list: title + tile children.
class SettingsList extends StatelessWidget {
  const SettingsList({
    super.key,
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontBody,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          12.gapH,
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 20.h, color: context.palette.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Backward-compatible alias.
typedef SettingsGroup = SettingsList;
