import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/utils/app_permissions.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/featured_places_list.dart';

class HomeNearbySection extends StatefulWidget {
  const HomeNearbySection({super.key, this.onSeeAll});
  final VoidCallback? onSeeAll;
  @override
  State<HomeNearbySection> createState() => _HomeNearbySectionState();
}

class _HomeNearbySectionState extends State<HomeNearbySection> {
  List<SuggestedPlace>? _nearby;
  bool _loading = true;
  List<String> _sampleIds = [];
  String? _error;
  Future<void>? _request;

  @override
  void initState() {
    super.initState();
    AppPermissions.locationChanges.addListener(_locationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(requestPermission: false);
    });
  }

  void _locationChanged() {
    if (mounted) _load(requestPermission: false);
  }

  @override
  void dispose() {
    AppPermissions.locationChanges.removeListener(_locationChanged);
    super.dispose();
  }

  Future<void> _load({bool requestPermission = false}) =>
      _request ??= _loadNearby(requestPermission: requestPermission)
          .whenComplete(() => _request = null);

  Future<void> _loadNearby({required bool requestPermission}) async {
    final discover = context.read<DiscoverProvider>();
    final l10n = context.l10n;
    setState(() {
      _loading = true;
      _error = null;
    });
    final location = await const MapLocation().locate(
      requestPermission: requestPermission,
    );
    if (!mounted) return;
    if (location.point case final point?) {
      final result = await discover.getNearbyPlaces(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) return;
      result.fold(
        (failure) => _error = FailureMessageMapper.localize(failure, l10n),
        (items) => _nearby = List<SuggestedPlace>.of(items),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final discover = context.watch<DiscoverProvider>();
    final l10n = context.l10n;
    final pool = <String, SuggestedPlace>{
      for (final place
          in _nearby ?? [...discover.places, ...discover.featuredPlaces])
        if (place.status == 'active') place.id: place,
    };
    // Keep the random sample stable across ordinary theme/provider rebuilds.
    if (_sampleIds.length != pool.length ||
        !_sampleIds.every(pool.containsKey)) {
      _sampleIds = pool.keys.toList()..shuffle();
    }
    final places = _sampleIds.take(6).map((id) => pool[id]!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: _nearby == null ? l10n.placesToExplore : l10n.nearbyPlaces,
          actionLabel: l10n.seeAll,
          onAction: widget.onSeeAll,
        ),
        Responsive.spaceSm.gapH,
        if ((_loading || !discover.hasLoaded) && places.isEmpty)
          AppShimmer(child: ShimmerBone(height: 168.h, radius: 16))
        else if (places.isEmpty &&
            (_error != null || discover.errorMessage != null))
          AppErrorState(
            message: _error ?? discover.errorMessage!,
            onRetry: () async {
              await Future.wait([_load(), discover.load(forceRefresh: true)]);
            },
          )
        else if (places.isEmpty)
          AppEmptyState(
            icon: Icons.travel_explore,
            message: l10n.noPlaces,
            subtitle: l10n.noPlacesHint,
            compact: true,
          )
        else
          FeaturedPlacesList(
            places: places,
            compact: true,
            showPriceLevel: false,
            heroSurface: 'home-nearby',
          ),
      ],
    );
  }
}
