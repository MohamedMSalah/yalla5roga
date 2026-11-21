import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_branch_picker.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_map_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_place_card.dart';

class DiscoverPlaceCarousel extends StatefulWidget {
  const DiscoverPlaceCarousel({
    super.key,
    required this.catalog,
    required this.onDetails,
    required this.onCreate,
  });
  final DiscoverMapProvider catalog;
  final ValueChanged<SuggestedPlace> onDetails, onCreate;
  @override
  State<DiscoverPlaceCarousel> createState() => _DiscoverPlaceCarouselState();
}

class _DiscoverPlaceCarouselState extends State<DiscoverPlaceCarousel> {
  final _pages = PageController(viewportFraction: .92);
  String? _scrollTarget;
  String? _centeredId;
  int _scrollRevision = 0;

  @override
  void initState() {
    super.initState();
    _syncSelection();
  }

  @override
  void didUpdateWidget(covariant DiscoverPlaceCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelection();
  }

  void _syncSelection() {
    final selected = widget.catalog.selectedPlaceId;
    final index = widget.catalog.places.indexWhere((p) => p.id == selected);
    if (index < 0) return;
    // A swipe already owns snapping. Do not start another scroll animation
    // while its final scroll notification updates the shared selection.
    if (selected == _centeredId &&
        _pages.hasClients &&
        _pages.page?.round() == index) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focus(index, selected!),
    );
  }

  Future<void> _focus(int index, String id) async {
    if (!mounted ||
        !_pages.hasClients ||
        _scrollTarget == id ||
        widget.catalog.selectedPlaceId != id ||
        _pages.page?.round() == index) {
      return;
    }
    final revision = ++_scrollRevision;
    _scrollTarget = id;
    try {
      if (AppMotion.reduce(context)) {
        _pages.jumpToPage(index);
      } else {
        await _pages.animateToPage(
          index,
          duration: AppMotion.standard,
          curve: AppMotion.enter,
        );
      }
    } finally {
      if (mounted && revision == _scrollRevision) _scrollTarget = null;
    }
  }

  @override
  void dispose() {
    _scrollRevision++;
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    final places = catalog.places;
    return NotificationListener<ScrollNotification>(
      onNotification: (event) {
        if (event.depth != 0 || event.metrics.axis != Axis.horizontal) {
          return false;
        }
        if (event is ScrollUpdateNotification &&
            event.dragDetails != null &&
            _scrollTarget != null) {
          _scrollRevision++;
          _scrollTarget = null;
        }
        if (event is ScrollEndNotification && _scrollTarget == null) {
          final index = _pages.page?.round();
          if (index != null && index >= 0 && index < places.length) {
            _centeredId = places[index].id;
            catalog.select(places[index]);
          }
        }
        return false;
      },
      child: PageView.builder(
        controller: _pages,
        padEnds: false,
        itemCount: places.length + (catalog.hasMore ? 1 : 0),
        onPageChanged: (index) {
          if (index >= places.length - 4 &&
              catalog.hasMore &&
              !catalog.loading &&
              catalog.error == null) {
            catalog.load(more: true);
          }
        },
        itemBuilder: (context, index) {
          if (index == places.length) {
            return Center(
              child: catalog.loading
                  ? const CircularProgressIndicator()
                  : FilledButton.tonal(
                      onPressed: () => catalog.load(more: true),
                      child: Text(
                        catalog.error != null
                            ? context.l10n.catalogRetry
                            : context.l10n.catalogMore,
                      ),
                    ),
            );
          }
          final place = places[index];
          final language = context.l10n.locale.languageCode;
          final category = catalog.categories
              .where((c) => c.id == place.categoryId)
              .firstOrNull;
          final vibes = catalog.vibes
              .where((v) => place.vibeIds.contains(v.id))
              .map((v) => v.label(language))
              .join(' · ');
          return Padding(
            key: ValueKey(place.id),
            padding: const EdgeInsetsDirectional.only(start: 14, bottom: 3),
            child: DiscoverPlaceCard(
              place: place,
              category: category,
              vibes: vibes,
              distanceKm: catalog.distanceKm(place),
              selected: catalog.selectedPlaceId == place.id,
              onBranches: () async {
                final branch = await pickPlaceBranch(
                  context,
                  place.toOutingPlace(),
                  latitude: catalog.userLocation?.latitude,
                  longitude: catalog.userLocation?.longitude,
                );
                if (context.mounted && branch != null) {
                  catalog.revealBranch(branch);
                }
              },
              onSelect: () => catalog.select(place),
              onDetails: () => widget.onDetails(place),
              onCreate: () => widget.onCreate(place),
            ),
          );
        },
      ),
    );
  }
}
