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

class PlaceBranchList extends StatelessWidget {
  const PlaceBranchList({
    super.key,
    required this.current,
    required this.onSelected,
  });
  final Place current;
  final ValueChanged<SuggestedPlace> onSelected;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        PlaceCatalogProvider(context.read<DiscoverProvider>().repository)
          ..update(PlaceFilters(brandId: current.brandId)),
    child: _BranchList(
      current: current,
      embedded: true,
      onSelected: onSelected,
    ),
  );
}

class _BranchList extends StatelessWidget {
  const _BranchList({
    required this.current,
    this.embedded = false,
    this.onSelected,
  });
  final bool embedded;
  final ValueChanged<SuggestedPlace>? onSelected;
  final Place current;
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<PlaceCatalogProvider>();
    final l10n = context.l10n;
    return SizedBox(
      height: embedded ? null : MediaQuery.sizeOf(context).height * .65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!embedded) ...[
            Text(l10n.chooseBranch, style: context.texts.titleLarge),
            Text(current.brandName, style: context.texts.titleMedium),
          ],
          Expanded(
            child: ListView.builder(
              padding: embedded
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
                  : null,
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
                  minVerticalPadding: embedded ? 20 : 8,
                  title: Text(
                    embedded
                        ? (branch.branchName.isEmpty
                              ? branch.localizedName(l10n)
                              : branch.branchName)
                        : (branch.branchLabel.isEmpty
                              ? branch.localizedName(l10n)
                              : branch.branchLabel),
                    style: embedded
                        ? context.texts.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )
                        : null,
                  ),
                  subtitle: embedded
                      ? Text(
                          [
                            branch.address.isEmpty
                                ? branch.localizedArea(l10n)
                                : branch.address,
                            if (branch.distanceKm != null)
                              l10n.catalogDistanceLabel(branch.distanceKm!),
                          ].where((value) => value.isNotEmpty).join(' · '),
                        )
                      : branch.distanceKm == null
                      ? null
                      : Text(l10n.catalogDistanceLabel(branch.distanceKm!)),
                  trailing: branch.id == current.id
                      ? const Icon(Icons.check)
                      : Icon(
                          embedded ? Icons.chevron_right : Icons.place_outlined,
                        ),
                  onTap: branch.latitude == null || branch.longitude == null
                      ? null
                      : () {
                          if (onSelected != null) {
                            onSelected!(branch);
                          } else {
                            Navigator.of(context).pop(branch);
                          }
                        },
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
