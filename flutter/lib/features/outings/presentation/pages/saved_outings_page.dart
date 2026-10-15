import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/segmented_tabs.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_list_tile.dart';

class SavedOutingsPage extends StatelessWidget {
  const SavedOutingsPage({super.key});

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
            Padding(
              padding: Responsive.padding(horizontal: 20, top: 8),
              child: SegmentedTabs(
                labels: [l10n.mySaved, l10n.drafts],
                index: store.tab,
                onChanged: store.setTab,
                badges: {
                  0: l10n.n(store.totalCount),
                  1: l10n.n(store.drafts.length),
                },
              ),
            ),
            Expanded(
              child: items.isEmpty
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
                              Get.to(
                                () => CreateOutingPage(saved: item.outing),
                              );
                            },
                            trailing: AppIconButton(
                              icon: Icons.delete_outline,
                              size: 32,
                              foreground: AppColors.rose500,
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
