import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/app_search_field.dart';
import 'package:yalla_5roga/core/widgets/filter_chip_row.dart';

/// Map chrome accepts presentation values; routes own search and selection.
class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onChanged,
    this.leading,
    this.trailing,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final Widget? leading, trailing;
  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    elevation: 3,
    borderRadius: BorderRadius.circular(Responsive.radiusMd),
    child: Row(
      children: [
        ?leading,
        Expanded(
          child: AppSearchField(
            controller: controller,
            focusNode: focusNode,
            hint: context.l10n.mapSearchHint,
            onChanged: onChanged,
            onClear: () {
              controller.clear();
              onChanged('');
            },
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class MapCurrentLocationButton extends StatelessWidget {
  const MapCurrentLocationButton({
    super.key,
    required this.onPressed,
    this.busy = false,
  });
  final VoidCallback onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: context.l10n.yourLocation,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.my_location),
  );
}

class MapPlaceMarker extends StatelessWidget {
  const MapPlaceMarker({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.number,
  });
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final String? number;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: IconButton.filledTonal(
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onPressed,
      isSelected: selected,
      icon: number == null ? const Icon(Icons.place_outlined) : Text(number!),
      selectedIcon: number == null
          ? const Icon(Icons.location_on)
          : Text(number!),
    ),
  );
}

class MapVibeFilters extends StatelessWidget {
  const MapVibeFilters({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => FilterChipRow(
    labels: [context.l10n.allVibes, ...labels],
    index: index + 1,
    onChanged: (value) => onChanged(value - 1),
  );
}

class MapSelectedLocationCard extends StatelessWidget {
  const MapSelectedLocationCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl = '',
    this.onTap,
    this.trailing,
    this.selected = false,
  });
  final String title, subtitle, imageUrl;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Card(
      color: selected ? context.palette.brandSoft : context.palette.surface,
      child: ListTile(
        contentPadding: Responsive.padding(all: 12),
        leading: AppNetworkImage(
          url: imageUrl,
          width: 56,
          height: 56,
          radius: Responsive.radiusMd,
          placeholderIcon: Icons.place_outlined,
        ),
        title: Text(title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        onTap: onTap,
        trailing: trailing,
      ),
    ),
  );
}

class MapPlacePreview extends StatelessWidget {
  const MapPlacePreview({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl = '',
    required this.actionLabel,
    required this.onAction,
    this.onDetails,
    this.onClose,
  });
  final String title, subtitle, imageUrl, actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onDetails, onClose;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MapSelectedLocationCard(
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        selected: true,
        onTap: onDetails,
        trailing: onClose == null
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
      ),
      FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
    ],
  );
}
