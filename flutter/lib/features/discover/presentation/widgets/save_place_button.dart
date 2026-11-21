import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';

class SavePlaceButton extends StatefulWidget {
  const SavePlaceButton({
    super.key,
    required this.place,
    this.showLabel = false,
    this.photoOverlay = false,
    this.heart = false,
  });

  final SuggestedPlace place;
  final bool showLabel, heart;

  /// In a photo carousel, the section loads saved places once for all cards.
  final bool photoOverlay;

  @override
  State<SavePlaceButton> createState() => _SavePlaceButtonState();
}

class _SavePlaceButtonState extends State<SavePlaceButton> {
  @override
  void initState() {
    super.initState();
    if (widget.photoOverlay) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DiscoverProvider>().loadSavedPlaces();
    });
  }

  Future<void> _toggle() async {
    final store = context.read<DiscoverProvider>();
    final error = context.l10n.savedPlaceFailed;
    if (!store.savedLoaded || store.savedFailed) {
      await store.loadSavedPlaces(force: true);
      if (!mounted) return;
    }
    if (!await store.toggleSavedPlace(widget.place) && mounted) {
      AppSnackBar.showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (saved, saving, busy) = context.select(
      (DiscoverProvider store) => (
        store.isPlaceSaved(widget.place.id),
        store.savingPlaceId == widget.place.id,
        store.savingPlaceId != null || store.savedLoading,
      ),
    );
    final label = saved ? context.l10n.unsavePlace : context.l10n.savePlace;
    final icon = saving
        ? SizedBox.square(
            dimension: widget.photoOverlay ? 15 : 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.photoOverlay ? Colors.white : null,
            ),
          )
        : Icon(
            widget.heart
                ? (saved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded)
                : (saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded),
            size: widget.photoOverlay ? 19 : null,
          );
    final onPressed = busy ? null : _toggle;

    if (widget.showLabel) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
      );
    }

    final button = IconButton(
      tooltip: label,
      isSelected: saved,
      icon: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.standard),
        child: KeyedSubtree(key: ValueKey((saving, saved)), child: icon),
      ),
      color: widget.photoOverlay ? Colors.white : null,
      disabledColor: widget.photoOverlay ? Colors.white70 : null,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      onPressed: onPressed,
    );

    if (!widget.photoOverlay) return button;
    return Stack(
      alignment: Alignment.center,
      children: [
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xC21B1726),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 31),
          ),
        ),
        button,
      ],
    );
  }
}
