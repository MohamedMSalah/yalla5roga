import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

/// Same branch query/cache/provider as Discover; choosing returns a physical ID.
Future<SuggestedPlace?> pickPlaceBranch(
  BuildContext context,
  Place current, {
  double? latitude,
  double? longitude,
}) {
  final repository = context.read<DiscoverProvider>().repository;
  return AppBottomSheet.show<SuggestedPlace>(
    context: context,
    builder: (context) => ChangeNotifierProvider(
      create: (_) => PlaceCatalogProvider(repository)
        ..update(
          PlaceFilters(
            brandId: current.brandId,
            latitude: latitude,
            longitude: longitude,
          ),
        ),
      child: _BranchList(current: current),
    ),
  );
}

class _BranchList extends StatelessWidget {
  const _BranchList({required this.current});
  final Place current;
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<PlaceCatalogProvider>();
    final l10n = context.l10n;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.chooseBranch, style: context.texts.titleLarge),
          Text(current.brandName, style: context.texts.titleMedium),
          Expanded(
            child: ListView.builder(
              itemCount: catalog.places.length + 1,
              itemBuilder: (context, index) {
                if (index == catalog.places.length) {
                  if (catalog.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (catalog.error != null) {
                    return TextButton(
                      onPressed: () => catalog.load(force: true),
                      child: Text(l10n.catalogRetry),
                    );
                  }
                  if (catalog.hasMore) {
                    return TextButton(
                      onPressed: () => catalog.load(more: true),
                      child: Text(l10n.catalogMore),
                    );
                  }
                  if (catalog.places.isEmpty) return Text(l10n.noPlaces);
                  return const SizedBox.shrink();
                }
                final branch = catalog.places[index];
                return ListTile(
                  selected: branch.id == current.id,
                  title: Text(
                    branch.branchLabel.isEmpty
                        ? branch.localizedName(l10n)
                        : branch.branchLabel,
                  ),
                  subtitle: branch.distanceKm == null
                      ? null
                      : Text(l10n.catalogDistanceLabel(branch.distanceKm!)),
                  trailing: branch.id == current.id
                      ? const Icon(Icons.check)
                      : const Icon(Icons.place_outlined),
                  onTap: branch.latitude == null || branch.longitude == null
                      ? null
                      : () => Navigator.of(context).pop(branch),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Data and callbacks only; reusable in Discover, details and outing creation.
class PlaceBranchesButton extends StatelessWidget {
  const PlaceBranchesButton({
    super.key,
    required this.count,
    required this.onPressed,
  });
  final int count;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: onPressed,
    icon: const Icon(Icons.storefront_outlined),
    label: Text(
      '${context.l10n.multipleBranches} · ${context.l10n.viewOtherBranches(count - 1)}',
    ),
  );
}
