import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/save_place_button.dart';

class SavedPlacesList extends StatelessWidget {
  const SavedPlacesList({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<DiscoverProvider>();
    if (store.savedLoading && !store.savedLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (store.savedFailed && store.savedPlaces.isEmpty) {
      return AppErrorState(
        message: context.l10n.savedPlaceFailed,
        onRetry: () => store.loadSavedPlaces(force: true),
      );
    }
    if (store.savedPlaces.isEmpty) {
      return AppEmptyState(
        icon: Icons.bookmark_border,
        message: context.l10n.noSavedPlaces,
      );
    }
    return ListView(
      padding: Responsive.pagePadding(),
      children: [
        if (store.savedFailed)
          TextButton(
            onPressed: () => store.loadSavedPlaces(force: true),
            child: Text(context.l10n.savedPlaceFailed),
          ),
        for (final place in store.savedPlaces)
          MapSelectedLocationCard(
            title: place.localizedName(context.l10n),
            subtitle: place.status == 'active'
                ? place.localizedSummary(context.l10n)
                : context.l10n.catalogStatus(place.status),
            imageUrl: place.coverImageUrl,
            trailing: SavePlaceButton(place: place),
            onTap: () => Get.to(
              () => DiscoverPlaceDetailsPage(
                placeId: place.id,
                initialPlace: place,
              ),
            ),
          ),
      ],
    );
  }
}
