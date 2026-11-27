import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

import '../../domain/entities/default_starting_location.dart';
import '../../domain/entities/saved_location.dart';
import '../providers/saved_locations_provider.dart';
import '../widgets/default_starting_location_tile.dart';
import '../widgets/saved_location_card.dart';
import 'add_edit_location_page.dart';
import 'select_starting_location_page.dart';

class MyLocationsPage extends StatefulWidget {
  const MyLocationsPage({super.key});

  @override
  State<MyLocationsPage> createState() => _MyLocationsPageState();
}

class _MyLocationsPageState extends State<MyLocationsPage>
    with WidgetsBindingObserver {
  late final int _session = context.read<SavedLocationsProvider>().session;
  bool _openingEditor = false;

  @override
  void initState() {
    super.initState();
    // Capture on entry so an old route cannot write to a replacement account.
    final session = _session;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(session);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refresh(int session) {
    final provider = context.read<SavedLocationsProvider>();
    if (provider.matchesSession(session)) unawaited(provider.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(_session);
  }

  Future<void> _remove(SavedLocation location) async {
    final l = context.l10n;
    final confirmed = await AppAlert.confirm(
      title: l.savedLocationDelete,
      message: l.savedLocationDeletePrompt,
      confirmText: l.savedLocationDelete,
      cancelText: l.cancel,
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    final provider = context.read<SavedLocationsProvider>();
    if (provider.matchesSession(_session)) await provider.delete(location.id);
  }

  Future<void> _edit(SavedLocation location) async {
    if (_openingEditor) return;
    final provider = context.read<SavedLocationsProvider>();
    setState(() => _openingEditor = true);
    try {
      final result = await provider.get(location.id);
      if (!mounted || !provider.matchesSession(_session)) return;
      await result.fold<Future<void>>(
        (failure) async {
          if (failure.statusCode == 404) _refresh(_session);
          AppErrorFeedback.report(failure, kind: AppErrorKind.load);
        },
        (saved) async {
          await Get.to(() => AddEditLocationPage(existing: saved));
        },
      );
    } finally {
      if (mounted) setState(() => _openingEditor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = context.watch<SavedLocationsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l.myLocations)),
      body: SafeArea(
        child: provider.matchesSession(_session)
            ? _body(provider)
            : AppEmptyState(message: l.dataLoadFailed),
      ),
    );
  }

  Widget _body(SavedLocationsProvider provider) {
    final l = context.l10n;
    final failure = provider.readFailure;
    final offline = failure is NetworkFailure;
    if (!provider.hasLoaded && failure == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!provider.hasLoaded && failure != null && !offline) {
      return AppErrorState(
        message: FailureMessageMapper.localize(failure, l),
        onRetry: provider.refresh,
      );
    }
    final writable = !provider.isSaving && !_openingEditor && !offline;
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.pagePadding(),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (offline) ...[
                    const AppOfflineIndicator(isOffline: true),
                    TextButton(
                      onPressed: provider.refresh,
                      child: Text(l.retry),
                    ),
                  ] else if (failure != null) ...[
                    Text(FailureMessageMapper.localize(failure, l)),
                    TextButton(
                      onPressed: provider.refresh,
                      child: Text(l.retry),
                    ),
                  ],
                  if (provider.writeFailure case final failure?)
                    Semantics(
                      liveRegion: true,
                      child: Text(FailureMessageMapper.localize(failure, l)),
                    ),
                  if (_openingEditor || provider.isSaving)
                    const Center(child: CircularProgressIndicator()),
                  if (provider.hasLoaded) ...[
                    DefaultStartingLocationTile(
                      location: provider.defaultLocation,
                      onSelect: writable
                          ? () =>
                                Get.to(() => const SelectStartingLocationPage())
                          : null,
                      onClear: writable ? provider.clearDefault : null,
                      onTransportationChanged: writable
                          ? provider.updateDefaultBookmarkTransportation
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: l.savedLocationAdd,
                      onPressed: writable
                          ? () => Get.to(() => const AddEditLocationPage())
                          : null,
                    ),
                    const SizedBox(height: 16),
                    if (provider.locations.isEmpty)
                      AppEmptyState(
                        message: l.savedLocationsEmpty,
                        icon: Icons.location_on_outlined,
                        compact: true,
                      ),
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
                          onTap: writable ? () => _edit(location) : null,
                          onRemove: writable ? () => _remove(location) : null,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
