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
      child: ListView(
        padding: Responsive.pagePadding().add(
          EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.outingsTitle,
                  style: context.texts.headlineSmall,
                ),
              ),
              const NotificationButton(),
            ],
          ),
          Responsive.spaceMd.gapH,
          FilledButton.icon(
            label: Text(l10n.createOuting),
            icon: const Icon(Icons.add),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Get.to(() => const CreateOutingPage()),
          ),
          Responsive.spaceXl.gapH,
          if (!outings.hasLoaded)
            const AppShimmer(child: ShimmerOutingList(count: 3))
          else if (outings.errorMessage != null && outings.outings.isEmpty)
            TextButton(
              onPressed: () => outings.load(forceRefresh: true),
              child: Text(l10n.tryAgain),
            )
          else ...[
            const ActiveVotesList(),
            Responsive.spaceXl.gapH,
            OutingsList(title: l10n.upcoming, items: outings.upcoming),
          ],
        ],
      ),
    );
  }
}
