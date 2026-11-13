import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Floating capsule-shaped bottom navigation bar.
///
/// The entire bar uses a [StadiumBorder] with a continuous pill background.
/// The selected tab receives a separate, larger rounded pill highlight that
/// animates smoothly between tabs. Unselected tabs remain transparent.
/// All existing palette colors, semantics, accessibility, high-contrast
/// handling, and theme responsiveness are preserved.
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
    final highContrast = MediaQuery.highContrastOf(context);

    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: Padding(
            // Bottom margin lifts the capsule bar off the bottom edge for the
            // floating effect; horizontal padding keeps it off screen edges.
            padding: Responsive.padding(horizontal: 16, bottom: 10),
            child: _PillBar(
              items: items,
              currentIndex: currentIndex,
              onChanged: onChanged,
              highContrast: highContrast,
            ),
          ),
        ),
      ),
    );
  }
}

/// The inner capsule bar with backdrop blur, outer drop shadow, and an
/// animated selection indicator.
class _PillBar extends StatelessWidget {
  const _PillBar({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.highContrast,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = StadiumBorder(
      side: BorderSide(
        color: palette.border.withValues(alpha: highContrast ? 1.0 : 0.6),
        width: 1.0,
      ),
    );

    final barColor =
        palette.navBackground.withValues(alpha: highContrast ? 1.0 : 0.88);

    Widget barContent = Material(
      color: barColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: Responsive.padding(horizontal: 6, vertical: 6),
        child: _NavRow(
          items: items,
          currentIndex: currentIndex,
          onChanged: onChanged,
        ),
      ),
    );

    if (!highContrast) {
      barContent = ClipPath(
        clipper: const StadiumBorderClipper(),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: barContent,
        ),
      );
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: highContrast
            ? const []
            : [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
              ],
      ),
      child: barContent,
    );
  }
}

/// Custom clipper that clips child pixels to a stadium (fully rounded capsule).
class StadiumBorderClipper extends CustomClipper<Path> {
  const StadiumBorderClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..addRRect(
        RRect.fromLTRBR(
          0,
          0,
          size.width,
          size.height,
          Radius.circular(size.height / 2),
        ),
      );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Row of navigation items with an animated selection pill sliding behind
/// the active tab.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / items.length;
        final reduceMotion = AppMotion.reduce(context);
        final palette = context.palette;

        return Stack(
          children: [
            // Animated larger rounded pill-shaped highlight for selected tab
            AnimatedPositionedDirectional(
              duration: reduceMotion ? Duration.zero : AppMotion.standard,
              curve: AppMotion.settle,
              start: currentIndex * itemWidth,
              top: 0,
              bottom: 0,
              width: itemWidth,
              child: Padding(
                padding: Responsive.padding(horizontal: 4, vertical: 3),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: palette.brandSoft,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
            // Navigation tab items on top
            Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Individual navigation tab item with animated icon and label colors.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = AppMotion.reduce(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.standard;
    final iconColor = selected ? palette.brandStrong : palette.textSecondary;
    final labelColor = selected ? palette.brandStrong : palette.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: duration,
                  style: TextStyle(color: iconColor),
                  child: Icon(
                    item.icon,
                    size: Responsive.iconMd,
                    color: iconColor,
                  ),
                ),
                Responsive.spaceXs.gapH,
                AnimatedDefaultTextStyle(
                  duration: duration,
                  style: context.texts.labelSmall?.copyWith(
                        color: labelColor,
                      ) ??
                      TextStyle(color: labelColor),
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
