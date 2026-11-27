import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';

import '../../domain/entities/default_starting_location.dart';
import '../providers/saved_locations_provider.dart';
import '../widgets/location_source_selector.dart';
import '../widgets/saved_location_card.dart';
import 'add_edit_location_page.dart';

class SelectStartingLocationPage extends StatefulWidget {
  const SelectStartingLocationPage({super.key});

  @override
  State<SelectStartingLocationPage> createState() =>
      _SelectStartingLocationPageState();
}

class _SelectStartingLocationPageState
    extends State<SelectStartingLocationPage> {
  late final int _session;
  LocationSelectionMethod? _selection;
  bool _loadingBookmarks = false;
  bool _openingForm = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SavedLocationsProvider>();
    _session = provider.session;
  }

  Future<void> _choose(LocationSelectionMethod method) async {
    if (method == LocationSelectionMethod.gps ||
        method == LocationSelectionMethod.map) {
      if (_openingForm) return;
      setState(() => _openingForm = true);
      final selected = await Get.to<bool>(
        () => AddEditLocationPage(makeDefault: true, initialMethod: method),
      );
      if (!mounted) return;
      setState(() => _openingForm = false);
      if (selected == true &&
          context.read<SavedLocationsProvider>().matchesSession(_session)) {
        Get.back();
      }
      return;
    }
    setState(() => _selection = method);
    if (method == LocationSelectionMethod.bookmark) await _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _loadingBookmarks = true);
    await context.read<DiscoverProvider>().loadSavedPlaces(force: true);
    if (mounted) setState(() => _loadingBookmarks = false);
  }

  Future<void> _setDefault(StartingLocationSource source, String id) async {
    final provider = context.read<SavedLocationsProvider>();
    if (!provider.matchesSession(_session)) return;
    final saved = await provider.setDefault(source, id);
    if (mounted && saved && provider.matchesSession(_session)) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = context.watch<SavedLocationsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l.defaultStartingLocation)),
      body: SafeArea(
        child: provider.matchesSession(_session)
            ? ListView(
                padding: Responsive.pagePadding(),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: Responsive.contentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_selection == null)
                            LocationSourceSelector(
                              enabled: !provider.isSaving && !_openingForm,
                              onSelect: _choose,
                            )
                          else ...[
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: provider.isSaving
                                    ? null
                                    : () => setState(() => _selection = null),
                                child: Text(l.startingChangeSource),
                              ),
                            ),
                            if (_selection == LocationSelectionMethod.personal)
                              ..._personal(provider)
                            else
                              ..._bookmarks(provider),
                          ],
                          if (provider.isSaving)
                            const Center(child: CircularProgressIndicator()),
                          if (provider.writeFailure case final failure?)
                            Semantics(
                              liveRegion: true,
                              child: failure is NetworkFailure
                                  ? const AppOfflineIndicator(isOffline: true)
                                  : Text(
                                      FailureMessageMapper.localize(failure, l),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : AppEmptyState(message: l.dataLoadFailed),
      ),
    );
  }

  List<Widget> _personal(SavedLocationsProvider provider) {
    final l = context.l10n;
    return [
      if (provider.locations.isEmpty)
        AppEmptyState(message: l.savedLocationsEmpty, compact: true),
      for (final location in provider.locations)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SavedLocationCard(
            location: location,
            isDefault:
                provider.defaultLocation?.matches(
                  StartingLocationSource.savedLocation,
                  location.id,
                ) ??
                false,
            onTap: provider.isSaving
                ? null
                : () => _setDefault(
                    StartingLocationSource.savedLocation,
                    location.id,
                  ),
          ),
        ),
    ];
  }

  List<Widget> _bookmarks(SavedLocationsProvider provider) {
    final l = context.l10n;
    final bookmarks = context.watch<DiscoverProvider>();
    if (_loadingBookmarks || bookmarks.savedLoading) {
      return [const Center(child: CircularProgressIndicator())];
    }
    if (bookmarks.savedFailed) {
      return [
        AppErrorState(message: l.savedLoadFailed, onRetry: _loadBookmarks),
      ];
    }
    return [
      if (bookmarks.savedPlaces.isEmpty)
        AppEmptyState(message: l.startingBookmarksEmpty, compact: true),
      for (final place in bookmarks.savedPlaces)
        ListTile(
          leading: const Icon(Icons.bookmark_outline),
          title: Text(place.localizedName(l)),
          subtitle: Text(
            [
              if (place.area.isNotEmpty) place.area,
              if (!place.toOutingPlace().hasCoordinates)
                l.startingCoordinatesUnavailable,
              if (provider.defaultLocation?.matches(
                    StartingLocationSource.savedPlace,
                    place.id,
                  ) ??
                  false)
                l.startingDefaultIndicator,
            ].join(' · '),
          ),
          enabled: !provider.isSaving && place.toOutingPlace().hasCoordinates,
          onTap: () => _setDefault(StartingLocationSource.savedPlace, place.id),
        ),
    ];
  }
}
