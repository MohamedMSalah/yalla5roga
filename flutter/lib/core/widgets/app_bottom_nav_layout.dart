import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_nav.dart';

class AppBottomNavLayout extends StatelessWidget {
  const AppBottomNavLayout({
    super.key,
    required this.pages,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<Widget> pages;
  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  /// Higher-index tabs enter from the end side (right in LTR, left in RTL),
  /// matching where that item sits in the nav row.
  @visibleForTesting
  static double swapDirection({
    required int from,
    required int to,
    required TextDirection textDirection,
  }) {
    if (from == to) return 0;
    final forward = to > from ? 1.0 : -1.0;
    return textDirection == TextDirection.rtl ? -forward : forward;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: _TabSwap(index: currentIndex, pages: pages),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: items,
        currentIndex: currentIndex,
        onChanged: onChanged,
      ),
    );
  }
}

/// Horizontal swap between shell tabs. Translation only — no [Opacity]
/// saveLayer — so image-heavy feeds stay at 60fps.
class _TabSwap extends StatefulWidget {
  const _TabSwap({required this.index, required this.pages});

  final int index;
  final List<Widget> pages;

  @override
  State<_TabSwap> createState() => _TabSwapState();
}

class _TabSwapState extends State<_TabSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );

  int? _from;
  var _dir = 1.0;

  @override
  void didUpdateWidget(covariant _TabSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (AppMotion.reduce(context)) {
      _from = null;
      _controller.value = 1;
      return;
    }
    if (_controller.isAnimating) _controller.stop();
    _from = oldWidget.index;
    _dir = AppBottomNavLayout.swapDirection(
      from: oldWidget.index,
      to: widget.index,
      textDirection: Directionality.of(context),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final swapping = _from != null && _controller.value < 1;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < widget.pages.length; i++)
                _slot(i, swapping: swapping),
            ],
          );
        },
      ),
    );
  }

  Widget _slot(int i, {required bool swapping}) {
    final incoming = i == widget.index;
    final outgoing = swapping && i == _from;
    final show = incoming || outgoing;

    Widget child = RepaintBoundary(child: widget.pages[i]);
    child = TickerMode(enabled: show, child: child);

    if (swapping && show) {
      final t = _curve.value;
      final dx = incoming ? _dir * (1 - t) : -_dir * t;
      child = FractionalTranslation(translation: Offset(dx, 0), child: child);
    }

    return Offstage(offstage: !show, child: child);
  }
}
