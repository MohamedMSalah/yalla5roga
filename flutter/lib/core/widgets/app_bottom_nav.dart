import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final highContrast = MediaQuery.highContrastOf(context);
    final bar = Material(
      color: palette.navBackground.withValues(alpha: highContrast ? 1 : 0.82),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: Responsive.padding(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == currentIndex,
                      button: true,
                      child: InkWell(
                        onTap: () => onChanged(i),
                        borderRadius: BorderRadius.circular(
                          Responsive.radiusMd,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: AppMotion.of(
                                    context,
                                    AppMotion.standard,
                                  ),
                                  padding: Responsive.padding(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == currentIndex
                                        ? palette.brandSoft
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      Responsive.radiusMd,
                                    ),
                                  ),
                                  child: Icon(
                                    items[i].icon,
                                    size: Responsive.iconMd,
                                    color: i == currentIndex
                                        ? palette.brandStrong
                                        : palette.textSecondary,
                                  ),
                                ),
                                Responsive.spaceXs.gapH,
                                Text(
                                  items[i].label,
                                  textAlign: TextAlign.center,
                                  style: context.texts.labelSmall?.copyWith(
                                    color: i == currentIndex
                                        ? palette.brandStrong
                                        : palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (highContrast) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: bar,
      ),
    );
  }
}
