import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';

class SavePlaceButton extends StatefulWidget {
  const SavePlaceButton({super.key, required this.place});
  final SuggestedPlace place;
  @override
  State<SavePlaceButton> createState() => _SavePlaceButtonState();
}

class _SavePlaceButtonState extends State<SavePlaceButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DiscoverProvider>().loadSavedPlaces();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DiscoverProvider>();
    final saved = store.isPlaceSaved(widget.place.id);
    return IconButton(
      tooltip: saved ? context.l10n.unsavePlace : context.l10n.savePlace,
      isSelected: saved,
      icon: store.savingPlaceId == widget.place.id
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.bookmark_border),
      selectedIcon: const Icon(Icons.bookmark),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: store.savingPlaceId != null || store.savedLoading
          ? null
          : () async {
              final error = context.l10n.savedPlaceFailed;
              if (!store.savedLoaded || store.savedFailed) {
                await store.loadSavedPlaces(force: true);
                if (!mounted) return;
              }
              if (!await store.toggleSavedPlace(widget.place) && mounted) {
                AppSnackBar.showError(error);
              }
            },
    );
  }
}
