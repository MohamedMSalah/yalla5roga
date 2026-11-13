import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_page_header.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/outing_history_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/lists/active_votes_list.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/lists/outings_list.dart';

class OutingsPage extends StatefulWidget {
  const OutingsPage({super.key});

  @override
  State<OutingsPage> createState() => _OutingsPageState();
}

class _OutingsPageState extends State<OutingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Respect snapshot TTL — avoid unconditional N+1 fan-out on tab open.
      context.read<OutingsProvider>().refreshLifecycle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final outings = context.watch<OutingsProvider>();
    final l10n = context.l10n;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: ListView(
            padding: Responsive.pagePadding().add(
              EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
            ),
            children: [
              AppPageHeader(
                title: l10n.outingsTitle,
                trailing: const NotificationButton(),
              ),
              AppOfflineIndicator(
                isOffline: context.select<AppSyncProvider, bool>(
                  (sync) => sync.status == SyncStatus.offline,
                ),
              ),
              Responsive.spaceMd.gapH,
              CustomButton(
                label: l10n.createOuting,
                icon: Icons.add,
                onPressed: () => Get.to(() => const CreateOutingPage()),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => Get.to(() => const OutingHistoryPage()),
                  icon: const Icon(Icons.history),
                  label: Text(l10n.outingHistory),
                ),
              ),
              Responsive.spaceXl.gapH,
              if (!outings.hasLoaded && outings.errorMessage == null)
                const AppShimmer(child: ShimmerOutingList(count: 3))
              else if (outings.errorMessage != null && outings.outings.isEmpty)
                AppErrorState(
                  message: outings.errorMessage!,
                  onRetry: () => outings.load(forceRefresh: true),
                )
              else ...[
                if (outings.errorMessage != null)
                  AppErrorState(
                    message: outings.errorMessage!,
                    onRetry: () => outings.load(forceRefresh: true),
                  ),
                const ActiveVotesList(),
                Responsive.spaceXl.gapH,
                OutingsList(title: l10n.upcoming, items: outings.upcoming),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
