import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';

enum DiscoverBasemap { automatic, day, night }

class DiscoverMapControls extends StatelessWidget {
  const DiscoverMapControls({
    super.key,
    required this.basemap,
    required this.onBasemapChanged,
    required this.onResetNorth,
    this.compact = false,
  });

  final DiscoverBasemap basemap;
  final ValueChanged<DiscoverBasemap> onBasemapChanged;
  final VoidCallback onResetNorth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    return Material(
      color: palette.surface,
      shape: StadiumBorder(side: BorderSide(color: palette.border)),
      clipBehavior: Clip.antiAlias,
      child: Flex(
        direction: compact ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<DiscoverBasemap>(
            tooltip: l10n.mapAppearance,
            initialValue: basemap,
            onSelected: onBasemapChanged,
            icon: Icon(Icons.layers_outlined, color: palette.textSecondary),
            itemBuilder: (_) => [
              for (final (value, label) in [
                (DiscoverBasemap.automatic, l10n.mapFollowTheme),
                (DiscoverBasemap.day, l10n.mapDay),
                (DiscoverBasemap.night, l10n.mapNight),
              ])
                CheckedPopupMenuItem(
                  value: value,
                  checked: value == basemap,
                  child: Text(label),
                ),
            ],
          ),
          IconButton(
            tooltip: l10n.mapResetNorth,
            onPressed: onResetNorth,
            color: palette.textSecondary,
            icon: const Icon(Icons.near_me_outlined),
          ),
        ],
      ),
    );
  }
}

class DiscoverMyLocationButton extends StatelessWidget {
  const DiscoverMyLocationButton({
    super.key,
    required this.onLocate,
    required this.busy,
  });

  final VoidCallback onLocate;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MapCurrentLocationButton(
      onPressed: onLocate,
      busy: busy,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: palette.surface,
        foregroundColor: palette.groupAction,
        disabledBackgroundColor: palette.surfaceMuted,
        side: BorderSide(color: palette.groupAction.withValues(alpha: .65)),
      ),
    );
  }
}
