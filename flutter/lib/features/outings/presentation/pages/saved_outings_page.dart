import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/saved_places_list.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/segmented_tabs.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_list_tile.dart';

class SavedOutingsPage extends StatefulWidget {
  const SavedOutingsPage({super.key});
  @override
  State<SavedOutingsPage> createState() => _SavedOutingsPageState();
}

class _SavedOutingsPageState extends State<SavedOutingsPage> {
  @override
  void initState() {
    super.initState();
    _filter = context.read<SavedOutingsProvider>().tab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SavedOutingsProvider>().load();
        context.read<DiscoverProvider>().loadSavedPlaces(force: true);
      }
    });
  }

  int _filter = 0;
  String? _opening;
  Future<void> _open(SavedItem item) async {
    if (_opening != null) return;
    final outings = context.read<OutingsProvider>();
    setState(() => _opening = item.id);
    await outings.refreshLifecycle(outingId: item.id, forceRefresh: true);
    if (!mounted) return;
    setState(() => _opening = null);
    final outing = outings.findById(item.id);
    if (outing == null || outings.errorMessage != null) {
      AppSnackBar.showError(context.l10n.dataLoadFailed);
      return;
    }
    Get.to(() => EventPage(event: outing));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final store = context.watch<SavedOutingsProvider>();
    final items = store.visible;
    final showingDrafts = store.showingDrafts;

    return Scaffold(
      // AppPageBar — My saved
      appBar: AppPageBar(title: l10n.mySaved, subtitle: l10n.mySavedSubtitle),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (store.hasDraftConflicts)
              Padding(
                padding: Responsive.pagePadding(),
                child: Text(l10n.draftSyncConflict),
              ),
            if (store.hasPendingDrafts && !store.hasDraftConflicts)
              Padding(
                padding: Responsive.pagePadding(),
                child: Text(l10n.draftPending),
              ),
            Padding(
              padding: Responsive.padding(horizontal: 20, top: 8),
              child: SegmentedTabs(
                labels: [l10n.mySaved, l10n.drafts, l10n.savedPlacesFilter],
                index: _filter,
                onChanged: (index) {
                  setState(() => _filter = index);
                  if (index < 2) store.setTab(index);
                },
                badges: {
                  0: l10n.n(store.totalCount),
                  1: l10n.n(store.drafts.length),
                },
              ),
            ),
            if (_filter != 2 && store.loadFailed && items.isNotEmpty)
              TextButton(
                onPressed: store.isLoading ? null : store.load,
                child: Text(l10n.savedLoadFailed),
              ),
            Expanded(
              child: _filter == 2
                  ? const SavedPlacesList()
                  : !store.hasLoaded && store.isLoading
                  ? const AppShimmer(child: ShimmerOutingList(count: 3))
                  : store.loadFailed && items.isEmpty
                  ? AppErrorState(
                      message: l10n.savedLoadFailed,
                      onRetry: store.load,
                    )
                  : items.isEmpty
                  ? AppEmptyState(
                      icon: showingDrafts
                          ? Icons.edit_note_outlined
                          : Icons.bookmark_border,
                      message: showingDrafts
                          ? l10n.noDrafts
                          : l10n.noSavedOutings,
                    )
                  : ListView.builder(
                      padding: Responsive.pagePadding(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == items.length - 1 ? 0 : 8.h,
                          ),
                          child: OutingListTile(
                            title: item.title,
                            subtitle: item.location.label,
                            image: item.image,
                            occasion: item.occasion,
                            onTap: () {
                              final draft = item.draft;
                              if (draft != null) {
                                Get.to(
                                  () => CreateOutingPage(
                                    draft: draft,
                                    specialEvent: draft.specialEvent,
                                  ),
                                );
                                return;
                              }
                              _open(item);
                            },
                            statusLabel: _opening == item.id
                                ? l10n.openingDetails
                                : null,
                            trailing: AppIconButton(
                              icon: Icons.delete_outline,
                              size: 48,
                              tooltip: MaterialLocalizations.of(context)
                                  .deleteButtonTooltip,
                              foreground: context.palette.danger,
                              onTap: () async {
                                await store.remove(item);
                                AppSnackBar.show(
                                  item.isDraft
                                      ? l10n.draftRemoved
                                      : l10n.outingRemoved,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
