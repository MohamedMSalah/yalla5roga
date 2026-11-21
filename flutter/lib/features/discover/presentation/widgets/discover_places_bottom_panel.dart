import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// An overlay with a dedicated drag target, so swiping cards and panning the
/// exposed map use their own gestures.
class DiscoverPlacesBottomPanel extends StatefulWidget {
  const DiscoverPlacesBottomPanel({
    super.key,
    required this.expanded,
    required this.expandable,
    required this.onExpanded,
    required this.child,
  });

  final bool expanded, expandable;
  final ValueChanged<bool> onExpanded;
  final Widget child;

  @override
  State<DiscoverPlacesBottomPanel> createState() =>
      _DiscoverPlacesBottomPanelState();
}

class _DiscoverPlacesBottomPanelState extends State<DiscoverPlacesBottomPanel> {
  double _dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    final canExpand = widget.expandable;
    final expanded = widget.expanded;
    void toggle() => widget.onExpanded(!expanded);
    final palette = context.palette;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.surfaceMuted, palette.background],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 24,
            // The handle shares its hit region with the space above the cards.
            child: Semantics(
              button: canExpand,
              label: expanded
                  ? l10n.discoverCollapsePlaces
                  : l10n.discoverExpandPlaces,
              onTap: canExpand ? toggle : null,
              child: GestureDetector(
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTap: canExpand ? toggle : null,
                onVerticalDragStart: canExpand ? (_) => _dragDelta = 0 : null,
                onVerticalDragUpdate: canExpand
                    ? (details) => _dragDelta += details.primaryDelta ?? 0
                    : null,
                onVerticalDragEnd: canExpand
                    ? (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (_dragDelta.abs() >= 16) {
                          widget.onExpanded(_dragDelta < 0);
                        } else if (velocity.abs() > 250) {
                          widget.onExpanded(velocity < 0);
                        }
                      }
                    : null,
                child: SizedBox(
                  width: 96,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withValues(alpha: .58),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
