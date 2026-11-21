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
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: context.palette.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon ?? Icons.settings_outlined,
                  size: 18,
                  color: context.palette.brandStrong,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: context.texts.titleMedium)),
              ?action,
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 3, 12, 3),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(indent: 0, endIndent: 0, height: 1),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Backward-compatible alias.
typedef SettingsGroup = SettingsList;
typedef SettingsSection = SettingsList;
