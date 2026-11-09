import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/featured_places_list.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/nearby_places_list.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _vibes = <OutingVibe?>[
    null,
    OutingVibe.food,
    OutingVibe.activity,
    OutingVibe.outdoor,
    OutingVibe.movie,
  ];

  Position? _position;
  List<SuggestedPlace> _nearby = [];
  String? _error;
  bool _busy = false;
  bool _offerSettings = false;
  int _filter = 0;

  Future<void> _findNearby({bool refreshLocation = false}) async {
    if (_busy) return;
    final l10n = context.l10n;
    final discover = context.read<DiscoverProvider>();
    setState(() {
      _busy = true;
      _error = null;
      _offerSettings = false;
    });

    String? error;
    bool offerSettings = false;
    List<SuggestedPlace> results = [];
    try {
      if (refreshLocation || _position == null) {
        _position = null;
        if (!await Geolocator.isLocationServiceEnabled()) {
          error = l10n.locationDisabled;
        } else {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            _position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 15),
              ),
            );
          } else {
            error = l10n.locationPermissionDenied;
            offerSettings = permission == LocationPermission.deniedForever;
          }
        }
      }

      final position = _position;
      if (!mounted) return;
      if (position != null) {
        final result = await discover.getNearbyPlaces(
          latitude: position.latitude,
          longitude: position.longitude,
          vibe: _vibes[_filter],
        );
        result.fold(
          (failure) => error = FailureMessageMapper.localize(failure, l10n),
          (items) => results = items,
        );
      }
    } catch (_) {
      error = l10n.couldNotGetLocation;
    }

    if (!mounted) return;
    setState(() {
      _nearby = results;
      _error = error;
      _offerSettings = offerSettings;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final discover = context.watch<DiscoverProvider>();
    final labels = [
      l10n.allVibes,
      l10n.food,
      l10n.activity,
      l10n.outdoor,
      l10n.movie,
    ];
    final vibe = _vibes[_filter];

    return Scaffold(
      appBar: AppPageBar(title: l10n.discover),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Responsive.pagePadding(),
          children: [
            SectionHeader(
              title: l10n.nearbyPlaces,
              subtitle: l10n.nearbyLocationHint,
            ),
            Responsive.spaceMd.gapH,
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _findNearby(refreshLocation: true),
              icon: const Icon(Icons.my_location),
              label: Text(l10n.findNearbyPlaces),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
            if (_error case final error?) ...[
              Responsive.spaceSm.gapH,
              Semantics(liveRegion: true, child: Text(error)),
              if (_offerSettings)
                TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: Text(l10n.openAppSettings),
                ),
            ],
            Responsive.spaceMd.gapH,
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < labels.length; i++)
                  ChoiceChip(
                    label: Text(labels[i]),
                    selected: _filter == i,
                    onSelected: _busy
                        ? null
                        : (selected) {
                            if (!selected) return;
                            setState(() => _filter = i);
                            if (_position != null) _findNearby();
                          },
                  ),
              ],
            ),
            Responsive.spaceLg.gapH,
            if (_busy)
              const LinearProgressIndicator()
            else if (_position != null && _error == null) ...[
              NearbyPlacesList(
                places: _nearby,
                emptyMessage: l10n.noNearbyPlaces,
              ),
              TextButton(
                onPressed: () => setState(() => _position = null),
                child: Text(l10n.allPlaces),
              ),
            ],
            if (!_busy && (_position == null || _error != null)) ...[
              if (discover.featured.any(
                (place) => vibe == null || place.vibe == vibe,
              )) ...[
                FeaturedPlacesList(
                  title: l10n.featuredPlaces,
                  places: [
                    for (final place in discover.featured)
                      if (vibe == null || place.vibe == vibe) place,
                  ],
                ),
                Responsive.spaceLg.gapH,
              ],
              NearbyPlacesList(
                title: l10n.allPlaces,
                heroSurface: 'discover-catalog',
                places: [
                  for (final place in discover.places)
                    if (vibe == null || place.vibe == vibe) place,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
