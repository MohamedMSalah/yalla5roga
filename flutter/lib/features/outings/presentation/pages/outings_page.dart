import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/gradient_action_button.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/outing_history_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/cards/outing_preview_card.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/lists/active_votes_list.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outings_header.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outings_style.dart';

enum _OutingsSection { votes, upcoming }

class OutingsPage extends StatelessWidget {
  const OutingsPage({super.key});

  @override
  Widget build(BuildContext context) => const _OutingsFeed();
}

class _OutingsFeed extends StatefulWidget {
  const _OutingsFeed({this.section});

  final _OutingsSection? section;

  @override
  State<_OutingsFeed> createState() => _OutingsFeedState();
}

class _OutingsFeedState extends State<_OutingsFeed>
    with WidgetsBindingObserver {
  static const _previewLimit = 2;
  late final AppSyncProvider _sync = context.read<AppSyncProvider>();
  late final OutingsProvider _outings = context.read<OutingsProvider>();
  bool _visible = false;
  bool _foreground = true;
  bool _retained = false;
  bool _feedOpen = false;
  bool _offline = false;
  bool _openingRoute = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateVisibility();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateVisibility();
  }

  void _updateVisibility() {
    final visible = _visible && _foreground;
    if (visible != _retained) {
      _retained = visible;
      if (visible) {
        _sync.retainRealtime(this, revalidate: false);
      } else {
        _sync.releaseRealtime(this);
      }
    }
    final feedOpen = visible && !_offline;
    if (feedOpen != _feedOpen) {
      _feedOpen = feedOpen;
      if (feedOpen) {
        _outings.openFeed(this);
      } else {
        _outings.closeFeed(this);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_feedOpen) _outings.closeFeed(this);
    if (_retained) _sync.releaseRealtime(this);
    super.dispose();
  }

  Future<void> _open(Widget Function() route) async {
    if (_openingRoute) return;
    _openingRoute = true;
    try {
      await Get.to<void>(route);
    } finally {
      _openingRoute = false;
    }
  }

  void _seeAll(_OutingsSection section) =>
      unawaited(_open(() => Scaffold(body: _OutingsFeed(section: section))));

  void _openVote(Outing outing) => unawaited(
    _open(
      () => EventPage(
        event: outing,
        initialSection: OutingDetailsSection.placeVoting,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final section = widget.section;
    final isPreview = section == null;
    final votes = section == _OutingsSection.upcoming
        ? const <Outing>[]
        : context.select((OutingsProvider p) => p.activeVotes);
    final upcoming = section == _OutingsSection.votes
        ? const <Outing>[]
        : context.select((OutingsProvider p) => p.upcoming);
    final status = context.select(
      (OutingsProvider p) => (loaded: p.hasLoaded, error: p.errorMessage),
    );
    final offline = context.select(
      (AppSyncProvider p) => p.status == SyncStatus.offline,
    );
    if (_offline != offline) {
      _offline = offline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateVisibility();
      });
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return OutingsBackground(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OutingsStyle.gutter,
              ),
              child: CustomScrollView(
                key: PageStorageKey(section ?? 'outings-feed'),
                slivers: [
                  if (isPreview)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),
                          const OutingsHeader(),
                          const SizedBox(height: 7),
                          _OutingActions(
                            onCreate: () =>
                                _open(() => const CreateOutingPage()),
                            onHistory: () =>
                                _open(() => const OutingHistoryPage()),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: AppPageBar(
                        title: section == _OutingsSection.votes
                            ? l10n.activeVotes
                            : l10n.upcoming,
                      ),
                    ),
                  if (offline)
                    const SliverPadding(
                      padding: EdgeInsets.only(bottom: 10),
                      sliver: SliverToBoxAdapter(
                        child: AppOfflineIndicator(isOffline: true),
                      ),
                    ),
                  if (status.error case final error?)
                    SliverToBoxAdapter(
                      child: AppErrorState(
                        message: error,
                        onRetry: () => _outings.load(forceRefresh: true),
                      ),
                    ),
                  if (votes.isEmpty && upcoming.isEmpty)
                    SliverToBoxAdapter(
                      child: status.error != null
                          ? const SizedBox.shrink()
                          : !status.loaded
                          ? _OutingsSkeleton(section: section)
                          : AppEmptyState(
                              icon: Icons.event_outlined,
                              message: switch (section) {
                                _OutingsSection.votes => l10n.noActiveVotes,
                                _OutingsSection.upcoming =>
                                  l10n.noUpcomingOutings,
                                null => l10n.noActiveOrUpcomingOutings,
                              },
                              compact: true,
                            ),
                    ),
                  if (votes.isNotEmpty) ...[
                    if (isPreview)
                      _sectionHeader(
                        title: l10n.activeVotes,
                        icon: Icons.bolt_outlined,
                        label: l10n.seeAllOutings(votes.length),
                        onAction: () => _seeAll(_OutingsSection.votes),
                      ),
                    ActiveVotesList(
                      items: votes,
                      onOpen: _openVote,
                      limit: isPreview ? _previewLimit : null,
                    ),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    if (isPreview) ...[
                      if (votes.isNotEmpty)
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      _sectionHeader(
                        title: l10n.upcoming,
                        icon: Icons.calendar_month_outlined,
                        label: l10n.seeAllOutings(upcoming.length),
                        onAction: () => _seeAll(_OutingsSection.upcoming),
                      ),
                    ],
                    SliverList.builder(
                      itemCount: isPreview
                          ? upcoming.length.clamp(0, _previewLimit)
                          : upcoming.length,
                      itemBuilder: (context, index) {
                        final outing = upcoming[index];
                        return Padding(
                          key: ValueKey(outing.id),
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                          child: UpcomingOutingPreviewCard(
                            outing: outing,
                            heroTag: HeroTags.outingCover(
                              isPreview ? 'outings' : 'outings-upcoming',
                              outing.id,
                            ),
                            onTap: (tag) => _open(
                              () => EventPage(event: outing, coverHeroTag: tag),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  SliverToBoxAdapter(child: SizedBox(height: bottomInset + 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required String label,
    required VoidCallback onAction,
  }) {
    final style = OutingsStyle(context);
    return SliverPadding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 2, 4),
      sliver: SliverToBoxAdapter(
        child: SectionHeader(
          title: title,
          icon: icon,
          iconColor: style.accent,
          iconSize: 25,
          titleStyle: style.label(context, 20, weight: FontWeight.w700),
          trailing: TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: style.text,
              minimumSize: const Size(0, 29),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              tapTargetSize: MaterialTapTargetSize.padded,
              backgroundColor: style.dark
                  ? const Color(0xFF241F30)
                  : const Color(0xFFF3EAF9),
              side: BorderSide(color: style.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label, style: style.label(context, 12))),
                const SizedBox(width: 4),
                Icon(context.chevronForward, size: 16, color: style.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutingActions extends StatelessWidget {
  const _OutingActions({required this.onCreate, required this.onHistory});

  final VoidCallback onCreate, onHistory;

  @override
  Widget build(BuildContext context) {
    final style = OutingsStyle(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientActionButton(
            label: context.l10n.createOuting,
            icon: Icons.add_rounded,
            onTap: onCreate,
            gradient: OutingsStyle.primaryGradient,
            highlight: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x32E1AFFF), Color(0x00E1AFFF)],
              stops: [0, .24],
            ),
            glow: const BoxShadow(
              color: Color(0x357A3AD2),
              blurRadius: 10,
              spreadRadius: -4,
            ),
            borderColor: const Color(0xFFBD83F4),
            textStyle: style.label(
              context,
              17.5,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          AppPressable(
            onTap: onHistory,
            child: Container(
              decoration: style.panel(radius: 14, raised: true),
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 23, color: style.muted),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      context.l10n.outingHistory,
                      style: style.label(
                        context,
                        14.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(context.chevronForward, size: 18, color: style.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutingsSkeleton extends StatelessWidget {
  const _OutingsSkeleton({this.section});

  final _OutingsSection? section;

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section != _OutingsSection.upcoming) ...[
          const ShimmerBone(width: double.infinity, height: 162, radius: 18),
          if (section == null) const SizedBox(height: 24),
        ],
        if (section != _OutingsSection.votes) ...[
          const ShimmerBone(width: double.infinity, height: 94, radius: 18),
          const SizedBox(height: 8),
          const ShimmerBone(width: double.infinity, height: 94, radius: 18),
        ],
      ],
    ),
  );
}
