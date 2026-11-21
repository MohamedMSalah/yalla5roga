import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_style.dart';

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.showArrow = true,
  });

  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final style = HomeStyle(context);
    return LayoutBuilder(
      builder: (context, constraints) => SectionHeader(
        title: title,
        icon: icon,
        iconColor: style.accent,
        iconSize: HomeStyle.sectionIcon,
        iconGap: 8,
        titleStyle: context.texts.titleLarge?.copyWith(
          fontSize: HomeStyle.sectionTitle,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          color: style.text,
        ),
        trailingMaxWidth: constraints.maxWidth * .35,
        trailing: onAction != null && actionLabel != null
            ? TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: style.muted,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontSize: HomeStyle.sectionAction,
                        ),
                      ),
                    ),
                    if (showArrow) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward_rounded, size: 15),
                    ],
                  ],
                ),
              )
            : null,
      ),
    );
  }
}
