import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/pick_location_page.dart';

import '../providers/smart_meetup_provider.dart';

class ParticipantLocationPicker extends StatefulWidget {
  const ParticipantLocationPicker({super.key, this.initial});

  final Place? initial;

  static Future<Place?> show(
    BuildContext context, {
    required SmartMeetupProvider meetup,
    Place? initial,
  }) async {
    final selection = await Navigator.of(context).push<List<Place>>(
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: meetup,
          builder: (context, _) {
            final session = meetup.session;
            if (session != null &&
                session.canManage &&
                session.expiresAt.isAfter(DateTime.now())) {
              return ParticipantLocationPicker(initial: initial);
            }
            final l10n = context.l10n;
            return Scaffold(
              appBar: AppBar(title: Text(l10n.quickMeetup)),
              body: Center(
                child: Text(
                  session == null
                      ? l10n.errorSessionExpired
                      : l10n.meetupExpired,
                ),
              ),
            );
          },
        ),
      ),
    );
    return selection?.firstOrNull;
  }

  @override
  State<ParticipantLocationPicker> createState() =>
      _ParticipantLocationPickerState();
}

class _ParticipantLocationPickerState extends State<ParticipantLocationPicker> {
  late final PlaceCatalogProvider _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = PlaceCatalogProvider(
      context.read<DiscoverProvider>().repository,
      searchAcrossBounds: true,
      maxPlaces: 100,
    );
    unawaited(_catalog.loadDefinitions());
  }

  @override
  void dispose() {
    _catalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PickLocationPage(
    catalog: const [],
    initial: widget.initial,
    placeCatalog: _catalog,
    includePersonalLocations: false,
    includeGeocodingSearch: true,
  );
}
