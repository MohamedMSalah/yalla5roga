import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
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
  bool _settings = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(requestPermission: false);
    });
  }

  Future<void> _load({bool requestPermission = true}) async {
    final discover = context.read<DiscoverProvider>();
    final l10n = context.l10n;
    setState(() {
      _loading = true;
      _error = null;
      _settings = false;
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
        (items) => _nearby = items,
      );
    } else if (requestPermission) {
      _error = switch (location.issue) {
        MapLocationIssue.disabled => l10n.locationDisabled,
        MapLocationIssue.denied ||
        MapLocationIssue.deniedForever => l10n.locationPermissionDenied,
        _ => l10n.couldNotGetLocation,
      };
      _settings = location.issue == MapLocationIssue.deniedForever;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final discover = context.watch<DiscoverProvider>();
    final l10n = context.l10n;
    final places = (_nearby ?? discover.featuredPlaces).take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.nearbyPlaces,
          subtitle: _nearby == null ? l10n.nearbyLocationHint : null,
          actionLabel: l10n.seeAll,
          onAction: widget.onSeeAll,
        ),
        Responsive.spaceSm.gapH,
        if (_nearby == null)
          CustomButton(
            label: _settings ? l10n.openAppSettings : l10n.findNearbyPlaces,
            icon: Icons.my_location,
            variant: AppButtonVariant.light,
            onPressed: _loading
                ? null
                : _settings
                ? () {
                    Geolocator.openAppSettings();
                  }
                : () => _load(),
          ),
        if (_error case final error?)
          Padding(
            padding: EdgeInsets.symmetric(vertical: Responsive.spaceSm),
            child: Semantics(
              liveRegion: true,
              child: Text(error, style: context.texts.bodyMedium),
            ),
          ),
        Responsive.spaceSm.gapH,
        if ((_loading || !discover.hasLoaded) && places.isEmpty)
          AppShimmer(child: ShimmerBone(height: 168.h, radius: 16))
        else if (places.isEmpty &&
            discover.errorMessage != null &&
            _nearby == null)
          AppErrorState(
            message: discover.errorMessage!,
            onRetry: () => discover.load(forceRefresh: true),
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
        if (_nearby != null && _error != null)
          TextButton(
            onPressed: _loading ? null : () => _load(),
            child: Text(l10n.retry),
          ),
      ],
    );
  }
}
