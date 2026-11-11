import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/lists/outings_list.dart';

class OutingHistoryPage extends StatefulWidget {
  const OutingHistoryPage({super.key});

  @override
  State<OutingHistoryPage> createState() => _OutingHistoryPageState();
}

class _OutingHistoryPageState extends State<OutingHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OutingsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outings = context.watch<OutingsProvider>();
    final history = outings.history;
    return Scaffold(
      appBar: AppPageBar(title: l10n.outingHistory),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Responsive.pagePadding(),
          children: [
            Text(l10n.outingHistoryHint, style: context.texts.titleMedium),
            Responsive.spaceMd.gapH,
            if (!outings.hasLoaded)
              const AppShimmer(child: ShimmerOutingList(count: 3))
            else if (outings.errorMessage != null && history.isEmpty)
              TextButton(
                onPressed: () => outings.load(forceRefresh: true),
                child: Text(l10n.tryAgain),
              )
            else
              OutingsList(
                items: history,
                emptyMessage: l10n.noOutingHistory,
                heroSurface: 'outing-history',
              ),
          ],
        ),
      ),
    );
  }
}
