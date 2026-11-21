import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';

class GroupInfoSectionCard extends StatelessWidget {
  const GroupInfoSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.trailing,
    this.onTap,
    this.inlineBody = false,
  });

  final String title;
  final IconData icon;
  final Widget body;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool inlineBody;

  @override
  Widget build(BuildContext context) {
    final style = GroupPageColors(context);
    final titleStyle = context.texts.titleMedium?.copyWith(
      color: style.text,
      fontSize: 17,
      fontWeight: FontWeight.w700,
    );
    return GroupSurface(
      onTap: onTap,
      child: inlineBody
          ? Row(
              children: [
                Icon(icon, color: style.accent, size: 25),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: titleStyle),
                      ),
                      const SizedBox(height: 6),
                      body,
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(context.chevronForward, color: style.accent, size: 20),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: title,
                  icon: icon,
                  iconColor: style.accent,
                  titleStyle: titleStyle,
                  trailing: trailing,
                ),
                const SizedBox(height: 8),
                body,
              ],
            ),
    );
  }
}

class GroupInfoNavigationRow extends StatelessWidget {
  const GroupInfoNavigationRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = GroupPageColors(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 22, color: style.accent),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: context.texts.bodyLarge?.copyWith(
                    color: style.text,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(context.chevronForward, color: style.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
