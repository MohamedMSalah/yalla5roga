import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/app_permissions.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/cards/explore_place_card.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_section_header.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_style.dart';

class HomeNearbySection extends StatefulWidget {
  const HomeNearbySection({super.key, this.onSeeAll});
  final VoidCallback? onSeeAll;

  @override
  State<HomeNearbySection> createState() => _HomeNearbySectionState();
}

class _HomeNearbySectionState extends State<HomeNearbySection>
    with AutomaticKeepAliveClientMixin<HomeNearbySection> {
  @override
  bool get wantKeepAlive => true;

  late final DiscoverRepository _repository;
  List<SuggestedPlace>? _places;
  Map<String, CatalogDefinition> _categories = const {};
  List<SuggestedPlace> _nearby = const [];
  LatLng? _location;
  String? _error;
  Timer? _refresh;
  Future<void>? _request;
  Future<void>? _locationRequest;
  Future<void>? _nearbyRequest;

  @override
  void initState() {
    super.initState();
    _repository = context.read<DiscoverProvider>().repository;
    _places = _repository.cachedRecommendations();
    AppPermissions.locationChanges.addListener(_locationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_load());
      _locationChanged();
      unawaited(_loadCategories());
      unawaited(context.read<DiscoverProvider>().loadSavedPlaces());
    });
    _refresh = Timer.periodic(CachePolicy.placeRecommendations, (_) {
      if (!mounted) return;
      if (_nearby.isEmpty) unawaited(_load());
      if (_location case final location?) unawaited(_loadNearby(location));
    });
  }

  Future<void> _loadCategories() async {
    final result = await _repository.getDefinitions('categories');
    if (!mounted) return;
    result.fold((_) {}, (categories) {
      if (categories.isEmpty) return;
      setState(() {
        _categories = {
          for (final category in categories) category.id: category,
        };
      });
    });
  }

  void _locationChanged() {
    if (!mounted || _locationRequest != null) return;
    _locationRequest = _locate().whenComplete(() => _locationRequest = null);
  }

  Future<void> _locate() async {
    final result = await const MapLocation().locate(requestPermission: false);
    if (!mounted || result.point == null) return;
    _location = result.point;
    await _loadNearby(result.point!);
  }

  Future<void> _loadNearby(LatLng location) =>
      _nearbyRequest ??= _fetchNearby(location)
          .whenComplete(() => _nearbyRequest = null);

  Future<void> _fetchNearby(LatLng location) async {
    final permitted = await AppPermissions.isLocationGranted.catchError(
      (Object _) => false,
    );
    if (!mounted) return;
    if (!permitted) {
      _location = null;
      if (_nearby.isNotEmpty) setState(() => _nearby = const []);
      return;
    }
    final result = await _repository.getNearbyRecommendations(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    if (!mounted) return;
    result.fold((_) {}, (places) {
      if (identical(places, _nearby) || (places.isEmpty && _nearby.isEmpty)) {
        return;
      }
      setState(() {
        _nearby = places;
        if (places.isNotEmpty) _error = null;
      });
    });
  }

  Future<void> _load({bool force = false}) =>
      _request ??= _fetch(force).whenComplete(() => _request = null);

  Future<void> _fetch(bool force) async {
    if (_places == null) {
      final cached = await _repository.restoreRecommendations();
      if (!mounted) return;
      if (cached != null) setState(() => _places = cached);
    }
    final result = await _repository.getRecommendations(forceRefresh: force);
    if (!mounted) return;
    result.fold(
      (failure) {
        if (_places == null && _nearby.isEmpty) {
          setState(() {
            _error = FailureMessageMapper.localize(failure, context.l10n);
          });
        }
      },
      (places) {
        if (identical(places, _places) && _error == null) return;
        setState(() {
          _places = places;
          _error = null;
        });
      },
    );
  }

  @override
  void dispose() {
    AppPermissions.locationChanges.removeListener(_locationChanged);
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final places = _nearby.isEmpty ? _places : _nearby;
    const inset = EdgeInsets.symmetric(horizontal: HomeStyle.gutter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: inset,
          child: HomeSectionHeader(
            title: l10n.placesToExplore,
            icon: Icons.explore_outlined,
            actionLabel: l10n.seeAll,
            onAction: widget.onSeeAll,
          ),
        ),
        const SizedBox(height: 4),
        if (_error case final error?)
          Padding(
            padding: inset,
            child: AppErrorState(
              message: error,
              onRetry: () => _load(force: true),
            ),
          )
        else if (places != null && places.isEmpty)
          Padding(
            padding: inset,
            child: AppEmptyState(
              icon: Icons.travel_explore,
              message: l10n.noPlaces,
              subtitle: l10n.noPlacesHint,
              compact: true,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth * .36).clamp(100.0, 192.0);
              final scaler = MediaQuery.textScalerOf(context);
              final extraHeight =
                  (scaler.scale(15) - 15).clamp(0.0, double.infinity) * 3;
              final height = width / .80 + extraHeight;
              final list = SizedBox(
                height: height,
                child: ListView.separated(
                  key: const PageStorageKey('home-explore'),
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  physics: places == null
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  addAutomaticKeepAlives: false,
                  padding: inset,
                  itemCount: places?.length ?? 3,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final place = places?[index];
                    return SizedBox(
                      key: place == null ? null : ValueKey(place.id),
                      width: width,
                      child: place == null
                          ? const ShimmerBone(radius: 18)
                          : ExplorePlaceCard(
                              place: place,
                              category: _categories[place.categoryId],
                            ),
                    );
                  },
                ),
              );
              return places == null ? AppShimmer(child: list) : list;
            },
          ),
      ],
    );
  }
}
