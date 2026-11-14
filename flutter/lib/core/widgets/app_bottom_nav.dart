import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

/// Floating capsule-shaped bottom navigation bar.
///
/// The entire bar uses a [StadiumBorder] with a continuous pill background.
/// Selection uses a filled primary-colored icon without a background indicator.
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

/// The inner capsule bar with backdrop blur and an outer drop shadow.
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
        color: highContrast ? palette.textSecondary : Colors.transparent,
        width: 1.0,
      ),
    );

    final barColor = palette.navBackground.withValues(
      alpha: highContrast ? 1.0 : 0.88,
    );

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
        shadows: highContrast ? const [] : AppShadows.floating(palette.shadow),
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
    return Path()..addRRect(
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

/// Equal-width items with a shared label height, including scaled/wrapped text.
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
        final labelStyle =
            context.texts.labelSmall ??
            const TextStyle(fontSize: AppTypography.caption);
        final labelWidth = constraints.maxWidth / items.length - AppSpacing.sm;
        var labelHeight = 0.0;
        for (final item in items) {
          final painter = TextPainter(
            text: TextSpan(text: item.label, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
            textAlign: TextAlign.center,
          )..layout(maxWidth: labelWidth.clamp(1.0, double.infinity));
          if (painter.height > labelHeight) labelHeight = painter.height;
          painter.dispose();
        }

        return Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  item: items[i],
                  selected: i == currentIndex,
                  labelStyle: labelStyle,
                  labelHeight: labelHeight.ceilToDouble(),
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Individual navigation tab item with animated icon and label colors.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.labelStyle,
    required this.labelHeight,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final TextStyle labelStyle;
  final double labelHeight;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.12,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.12,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 1,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant _NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    if (widget.selected && !AppMotion.reduce(context)) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduce(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.standard);
    final color = widget.selected
        ? context.colors.primary
        : context.palette.textSecondary;

    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.item.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: InkWell(
        onTap: widget.onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.navItem),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<Color?>(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  tween: ColorTween(begin: color, end: color),
                  builder: (context, value, child) => IconTheme.merge(
                    data: IconThemeData(color: value),
                    child: child!,
                  ),
                  child: SizedBox.square(
                    // Reserve the pulse's full size so it never shifts layout.
                    dimension: Responsive.iconMd * 1.12,
                    child: Center(
                      child: ScaleTransition(
                        scale: _scale,
                        child: AnimatedSwitcher(
                          duration: duration,
                          switchInCurve: Curves.easeInOutCubic,
                          switchOutCurve: Curves.easeInOutCubic,
                          child: Icon(
                            widget.selected
                                ? widget.item.selectedIcon ?? widget.item.icon
                                : widget.item.icon,
                            key: ValueKey(widget.selected),
                            size: Responsive.iconMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Responsive.spaceXs.gapH,
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  style: widget.labelStyle.copyWith(color: color),
                  child: SizedBox(
                    height: widget.labelHeight,
                    width: double.infinity,
                    child: Text(widget.item.label, textAlign: TextAlign.center),
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
