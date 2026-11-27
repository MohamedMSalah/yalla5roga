import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/animations/flying_item_animator.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/route_preview/presentation/route_preview_page.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/starting_location/presentation/widgets/starting_location_editor.dart';
import 'package:yalla_5roga/features/notifications/presentation/widgets/departure_reminder_card.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/core/widgets/realtime_route.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/chat/presentation/pages/outing_chat_page.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_info_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/edit_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_arrivals_section.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_attendance_widget.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_going_sheet.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_info_style.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_location_section.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_management_actions.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_overview.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_place_gallery.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_vote_widget.dart';

enum OutingDetailsSection { placeVoting, attendance }

class EventPage extends StatefulWidget {
  const EventPage({
    super.key,
    required this.event,
    this.coverHeroTag,
    this.createdVotingDeadline,
    this.initialSection,
    this.manualWhatsAppUrls = const [],
  });

  final Outing event;
  final DateTime? createdVotingDeadline;
  final OutingDetailsSection? initialSection;
  final List<String> manualWhatsAppUrls;

  /// Hero tag of the card thumbnail that opened this page; null for deep
  /// links, notifications and post-create navigation (no source image).
  final String? coverHeroTag;

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage>
    with SingleTickerProviderStateMixin, RealtimeRoute<EventPage> {
  @override
  String get realtimeOutingId => widget.event.id;

  final _coverKey = GlobalKey();
  final _initialSectionKey = GlobalKey();
  final _bookmarkKey = GlobalKey();

  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeListener;
  late final AnimationController _bookmarkBounce;
  var _saving = false;
  var _deleting = false;
  var _loadingDetails = true;
  var _initialScrollQueued = false;
  late final String? _accountId;

  bool get _sameAccount =>
      _accountId != null && context.read<AuthProvider>().user?.id == _accountId;
  OutingsProvider? _openOutingProvider;

  @override
  void initState() {
    super.initState();
    _accountId = context.read<AuthProvider>().user?.id;
    _openOutingProvider = context.read<OutingsProvider>()
      ..openOuting(widget.event.id);
    _bookmarkBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshAfterPush();
    });
  }

  @override
  void dispose() {
    _openOutingProvider?.closeOuting(widget.event.id);
    FlyingItemAnimator.cancel();
    _bookmarkBounce.dispose();
    _stopRouteListener();
    super.dispose();
  }

  void _stopRouteListener() {
    final animation = _routeAnimation;
    final listener = _routeListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _routeAnimation = null;
    _routeListener = null;
  }

  /// Wait until the GetX / Hero push has landed. Refreshing on the first
  /// frame rebuilds IndexedStack source Heroes mid-flight and skips frames.
  void _refreshAfterPush() {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      unawaited(_refreshLifecycle());
      return;
    }
    _routeAnimation = animation;
    _routeListener = (status) {
      if (status != AnimationStatus.completed) return;
      _stopRouteListener();
      unawaited(_refreshLifecycle());
    };
    animation.addStatusListener(_routeListener!);
  }

  Future<void> _refreshLifecycle() async {
    if (!mounted || !_sameAccount) return;
    if (!_loadingDetails) setState(() => _loadingDetails = true);
    final outings = context.read<OutingsProvider>();
    final changed = await OfflineSnapshots.preview(
      () => outings.refreshLifecycle(outingId: widget.event.id),
    );
    if (!mounted || !_sameAccount) return;
    if (changed) setState(() => _loadingDetails = false);
    await outings.refreshLifecycle(
      outingId: widget.event.id,
      forceRefresh: true,
    );
    if (!mounted || !_sameAccount || outings.isUnavailable(widget.event.id)) {
      return;
    }
    await outings.loadGuests(widget.event.id);
    if (mounted && _loadingDetails) setState(() => _loadingDetails = false);
  }

  Future<void> _delete(Outing outing) async {
    if (_deleting || !_ownsOuting(outing.id)) return;
    final l10n = context.l10n;
    final confirmed = await AppAlert.confirm(
      title: l10n.deleteOutingTitle,
      message: l10n.deleteOutingBody,
      confirmText: l10n.deleteOuting,
      cancelText: l10n.cancel,
      destructive: true,
    );
    if (!mounted || !confirmed || _deleting || !_ownsOuting(outing.id)) return;
    final saved = context.read<SavedOutingsProvider>();
    setState(() => _deleting = true);
    final deleted = await context.read<OutingsProvider>().delete(outing.id);
    if (mounted && _sameAccount && deleted) {
      saved.removeDeletedOuting(outing.id);
    }
    if (!mounted) return;
    setState(() => _deleting = false);
    if (deleted && _sameAccount) {
      Navigator.of(context).pop();
      AppSnackBar.show(l10n.outingDeleted);
    }
  }

  bool _ownsOuting(String id) {
    if (!_sameAccount) return false;
    return context.read<OutingsProvider>().findById(id)?.createdById ==
        _accountId;
  }

  Future<void> _cancel(Outing outing) async {
    final l10n = context.l10n;
    if (!await AppAlert.confirm(
      title: l10n.cancelOuting,
      message: l10n.cancelOutingPrompt,
      confirmText: l10n.cancelOuting,
      cancelText: l10n.cancel,
      destructive: true,
    )) {
      return;
    }
    if (!mounted || !_ownsOuting(outing.id)) return;
    final store = context.read<OutingsProvider>();
    if (!_editable(store.findById(outing.id)!) || store.isManaging(outing.id)) {
      return;
    }
    final ok = await store.cancel(outing.id);
    if (mounted && _sameAccount) {
      AppSnackBar.show(
        ok ? l10n.changesSaved : store.errorMessage ?? l10n.tryAgain,
      );
    }
  }

  bool _editable(Outing outing) =>
      outing.status != OutingStatus.past &&
      outing.status != OutingStatus.cancelled;

  void _scheduleInitialScroll() {
    if (_initialScrollQueued || widget.initialSection == null) return;
    _initialScrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _initialSectionKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = widget.event.id;
    final userId = context.select((AuthProvider auth) => auth.user?.id);
    final style = OutingInfoStyle(context);
    final details = context.select(
      (OutingsProvider store) => (
        outing: store.findById(id),
        unavailable: store.isUnavailable(id),
        tied: store.isTied(id),
        round: store.roundNumberFor(id),
        eligible: store.isAttendanceParticipant(id, userId),
        participantCount: store.attendanceParticipantCount(id),
        invitation: userId == null ? null : store.invitationStatus(id, userId),
        busy: store.isManaging(id),
      ),
    );

    final available =
        userId != null && userId == _accountId && !details.unavailable;
    final live = available ? details.outing : null;
    final owner = live != null && live.createdById == userId;
    final eligible = live != null && details.eligible;
    final canOpenGroup =
        live != null &&
        userId != null &&
        context.select((GroupsProvider groups) {
          final group = groups.findById(live.groupId ?? '');
          return group?.isOwner == true ||
              group?.memberById(userId)?.isPending == false;
        });
    final invited = details.invitation == 'pending';
    final participant =
        live != null &&
        (eligible || owner || canOpenGroup || details.invitation == 'accepted');
    final bookmarked = context.select(
      (SavedOutingsProvider saved) => saved.isSaved(id),
    );

    // The route argument can be a shallow notification placeholder. Wait for
    // account-scoped details before exposing actions or showing its title.
    final loading = available && live == null && _loadingDetails;
    final showCoverDuringPush =
        loading && widget.coverHeroTag != null && widget.event.image.isNotEmpty;
    final title =
        live?.title ??
        (showCoverDuringPush ? widget.event.title : l10n.wizardDetails);
    final tied = live?.status == OutingStatus.voting && details.tied;
    bool canViewDetails(BuildContext routeContext) {
      final uid = routeContext.select((AuthProvider auth) => auth.user?.id);
      final authorized = routeContext.select(
        (OutingsProvider store) =>
            store.findById(id) != null && !store.isUnavailable(id),
      );
      return uid == userId && authorized;
    }

    final location =
        live != null &&
            !tied &&
            live.status != OutingStatus.voting &&
            live.status != OutingStatus.draft
        ? live.location
        : null;
    final placeId = location?.placeId;
    final actionsDisabled = _deleting || _saving || details.busy;
    final canEdit = owner && _editable(live);
    if (live != null) _scheduleInitialScroll();

    final page = Scaffold(
      backgroundColor: style.dark
          ? const Color(0xFF16121C)
          : context.palette.brandSoft,
      appBar: AppBar(
        toolbarHeight: (MediaQuery.textScalerOf(context).scale(20) + 12).clamp(
          54,
          76,
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back,
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    background: style.control,
                    visualSize: 38,
                    borderColor: style.border,
                    foreground: style.icon,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.type(20, weight: FontWeight.w700),
                    ),
                  ),
                  if (participant) ...[
                    const SizedBox(width: 6),
                    ScaleTransition(
                      scale: TweenSequence<double>([
                        TweenSequenceItem(
                          tween: Tween(begin: 1.0, end: 1.22),
                          weight: 45,
                        ),
                        TweenSequenceItem(
                          tween: Tween(begin: 1.22, end: 1.0),
                          weight: 55,
                        ),
                      ]).animate(_bookmarkBounce),
                      child: KeyedSubtree(
                        key: _bookmarkKey,
                        child: AppIconButton(
                          icon: bookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          tooltip: bookmarked
                              ? l10n.unsaveOutingAction
                              : l10n.saveOutingAction,
                          foreground: bookmarked ? style.accent : style.icon,
                          background: style.control,
                          visualSize: 38,
                          borderColor: style.border,
                          isLoading: _saving,
                          onTap: () {
                            if (!_deleting) _toggleSaved(context, live);
                          },
                        ),
                      ),
                    ),
                  ],
                  if (owner) ...[
                    const SizedBox(width: 5),
                    Material(
                      color: style.control,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: style.border),
                      ),
                      child: PopupMenuButton<_OutingAction>(
                        tooltip: l10n.outingActionsLabel,
                        enabled: !actionsDisabled,
                        icon: Icon(
                          Icons.more_horiz,
                          color: style.icon,
                          size: 22,
                        ),
                        onSelected: (action) {
                          if (!_ownsOuting(id)) return;
                          final current = context
                              .read<OutingsProvider>()
                              .findById(id)!;
                          if (action != _OutingAction.delete &&
                              !_editable(current)) {
                            return;
                          }
                          switch (action) {
                            case _OutingAction.edit:
                              Get.to(() => EditOutingPage(outing: current));
                            case _OutingAction.cancel:
                              _cancel(current);
                            case _OutingAction.delete:
                              _delete(current);
                          }
                        },
                        itemBuilder: (_) => [
                          if (canEdit) ...[
                            PopupMenuItem(
                              value: _OutingAction.edit,
                              child: Text(l10n.editOuting),
                            ),
                            PopupMenuItem(
                              value: _OutingAction.cancel,
                              child: Text(l10n.cancelOuting),
                            ),
                          ],
                          PopupMenuItem(
                            value: _OutingAction.delete,
                            child: Text(l10n.deleteOuting),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: style.background),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 22),
                child: live == null
                    ? loading
                          ? _OutingInfoSkeleton(
                              cover: showCoverDuringPush
                                  ? _heroCover(
                                      widget.event,
                                      widget.event.image,
                                      128,
                                    )
                                  : null,
                            )
                          : Column(
                              children: [
                                AppEmptyState(
                                  icon: Icons.event_busy_outlined,
                                  message: l10n.dataLoadFailed,
                                ),
                                if (available)
                                  TextButton(
                                    onPressed: _refreshLifecycle,
                                    child: Text(l10n.tryAgain),
                                  ),
                              ],
                            )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutingOverview(
                            outing: live,
                            cover: _OutingInfoGallery(
                              key: ValueKey((
                                id,
                                placeId,
                                live.status,
                                tied,
                                details.round,
                              )),
                              placeId: placeId,
                              outing: live,
                              coverUrl: _coverImage(live),
                              optionImages:
                                  location == null &&
                                      live.status == OutingStatus.voting
                                  ? _optionImages(live, tied)
                                  : const [],
                              heroCover: _heroCover,
                              canView: canViewDetails,
                            ),
                            tied: tied,
                            participantCount: eligible
                                ? details.participantCount
                                : null,
                            canOpenGroup: canOpenGroup,
                          ),
                          if (widget.createdVotingDeadline case final deadline?
                              when live.status == OutingStatus.voting &&
                                  !tied &&
                                  details.round == 1) ...[
                            const SizedBox(height: 12),
                            Text(
                              l10n.votingDeadlineSummary(deadline),
                              style: style.type(13),
                            ),
                          ],
                          if (widget.initialSection ==
                                  OutingDetailsSection.placeVoting &&
                              live.status == OutingStatus.voting)
                            SizedBox.shrink(key: _initialSectionKey),
                          if (live.status == OutingStatus.voting)
                            const SizedBox(height: 12),
                          OutingVoteWidget(
                            outing: live,
                            canParticipate: participant,
                          ),
                          const SizedBox(height: 12),
                          OutingAttendanceWidget(
                            key:
                                widget.initialSection ==
                                    OutingDetailsSection.attendance
                                ? _initialSectionKey
                                : null,
                            outing: live,
                            userId: userId!,
                            onRetry: !_loadingDetails && !eligible && !invited
                                ? _refreshLifecycle
                                : null,
                          ),

                          if (participant) ...[
                            const SizedBox(height: 12),
                            OutingArrivalsSection(
                              key: ValueKey((id, userId)),
                              outing: live,
                              userId: userId,
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutingLocationSection(
                            key:
                                widget.initialSection ==
                                        OutingDetailsSection.placeVoting &&
                                    live.status != OutingStatus.voting
                                ? _initialSectionKey
                                : null,
                            location: location,
                            canView: canViewDetails,
                          ),

                          if (participant &&
                              _editable(live) &&
                              live.scheduledAt != null) ...[
                            const SizedBox(height: 12),
                            if (live.status == OutingStatus.confirmed &&
                                live.scheduledAt!.isAfter(DateTime.now()))
                              OutingDepartureReminderSection(
                                outingId: live.id,
                                revision: (
                                  live.scheduledAt,
                                  location?.latitude,
                                  location?.longitude,
                                  placeId,
                                ),
                              )
                            else
                              StartingLocationEditor(
                                scope: (
                                  context: StartingLocationContext.outing,
                                  id: live.id,
                                ),
                              ),
                          ],
                          if (participant) ...[
                            const SizedBox(height: 10),
                            _QuickActions(
                              actions: [
                                _DetailAction(
                                  icon: Icons.chat_bubble_outline,
                                  label: l10n.outingChat,
                                  primary: true,
                                  onTap: _deleting
                                      ? null
                                      : () => _openChat(context, live),
                                ),
                                if (live.status == OutingStatus.confirmed &&
                                    _editable(live) &&
                                    live.scheduledAt != null &&
                                    location?.hasCoordinates == true)
                                  _DetailAction(
                                    icon: Icons.route_outlined,
                                    label: l10n.routePreviewTitle,
                                    onTap: () => Navigator.of(context)
                                        .push<void>(
                                          MaterialPageRoute(
                                            builder: (_) => RoutePreviewPage(
                                              target: (
                                                scope: (
                                                  context:
                                                      StartingLocationContext
                                                          .outing,
                                                  id: live.id,
                                                ),
                                                recommendation: null,
                                              ),
                                            ),
                                          ),
                                        ),
                                  ),
                                if (location?.hasCoordinates == true)
                                  _DetailAction(
                                    icon: Icons.map_outlined,
                                    label: l10n.placeDirections,
                                    onTap: () =>
                                        openOutingVenue(context, location!),
                                  ),
                                if (eligible)
                                  _DetailAction(
                                    icon: Icons.groups_outlined,
                                    label: l10n.outingParticipants,
                                    detail: details.participantCount == null
                                        ? null
                                        : '(${l10n.n(details.participantCount!)})',
                                    onTap: () => OutingGoingSheet.show(
                                      live,
                                      viewerId: userId,
                                    ),
                                  ),
                                if (placeId != null && placeId.isNotEmpty)
                                  _DetailAction(
                                    icon: Icons.image_outlined,
                                    label: l10n.discoverPlaceDetails,
                                    onTap: () => Get.to(
                                      () => DiscoverPlaceDetailsPage(
                                        placeId: placeId,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (widget.manualWhatsAppUrls.isNotEmpty &&
                              owner) ...[
                            const SizedBox(height: 12),
                            _manualInvites(),
                          ],
                          if (owner || invited)
                            OutingManagementActions(
                              outing: live,
                              userId: userId,
                            ),
                          const SizedBox(height: 13),
                          const _AboutOutingCard(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    return PopScope(canPop: !_deleting, child: page);
  }

  Widget _manualInvites() {
    final l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.whatsappInvites, style: context.texts.titleMedium),
          Text(l10n.sendEventInvitesManually),
          for (final url in widget.manualWhatsAppUrls)
            TextButton.icon(
              icon: const Icon(Icons.send_outlined),
              label: Text(l10n.digits('+${Uri.parse(url).pathSegments.first}')),
              onPressed: () async {
                if (!await AppLauncher.openWhatsAppUrl(url) &&
                    mounted &&
                    _sameAccount) {
                  AppSnackBar.show(l10n.couldNotOpenLink);
                }
              },
            ),
        ],
      ),
    );
  }

  String _coverImage(Outing outing) {
    final store = context.read<OutingsProvider>();
    if (outing.status == OutingStatus.voting) {
      return _optionImages(outing, store.isTied(outing.id)).firstOrNull ??
          outing.image;
    }
    final winner = store.winningOptionFor(outing.id);
    return (winner != null && winner.imageUrl.trim().isNotEmpty)
        ? winner.imageUrl
        : outing.image;
  }

  List<String> _optionImages(Outing outing, bool tied) {
    final store = context.read<OutingsProvider>();
    final options = tied
        ? store.tiedOptionsFor(outing.id)
        : store.optionsFor(outing.id);
    return [
      for (final option in options)
        if (option.imageUrl.trim().isNotEmpty) option.imageUrl,
    ];
  }

  Widget _heroCover(Outing outing, String url, double height) => KeyedSubtree(
    key: _coverKey,
    child: AppHero(
      tag: url == widget.event.image ? widget.coverHeroTag : null,
      url: url,
      radius: 18,
      child: PlanningCover(
        url: url,
        art: outing.occasion.coverArt,
        width: double.infinity,
        height: height,
        radius: 18,
      ),
    ),
  );

  void _openChat(BuildContext context, Outing live) {
    if (!_sameAccount) return;
    if (!live.canOpenChat) {
      AppSnackBar.show(context.l10n.chatNeedsSuggestion);
      return;
    }
    Get.to(() => OutingChatPage(event: live));
  }

  Future<void> _toggleSaved(BuildContext context, Outing live) async {
    if (_saving || !_sameAccount || FlyingItemAnimator.isFlying) return;
    setState(() => _saving = true);
    final added = await context.read<SavedOutingsProvider>().toggle(live);
    if (!context.mounted || !_sameAccount) return;
    setState(() => _saving = false);

    if (added == null) {
      AppSnackBar.showError(context.l10n.unexpectedError);
      return;
    }

    if (added) {
      final coverUrl = _coverImage(live);
      if (coverUrl.trim().isNotEmpty) {
        unawaited(
          FlyingItemAnimator.fly(
            context: context,
            sourceKey: _coverKey,
            targetKey: _bookmarkKey,
            imageUrl: coverUrl,
            borderRadius: 24.r,
            duration: AppMotion.reduce(context)
                ? Duration.zero
                : const Duration(milliseconds: 700),
            onArrived: _bounceBookmark,
          ),
        );
      } else {
        _bounceBookmark();
      }
    }

    AppSnackBar.show(
      added ? context.l10n.outingSaved : context.l10n.outingRemoved,
    );
  }

  void _bounceBookmark() {
    if (!mounted || AppMotion.reduce(context)) return;
    _bookmarkBounce
      ..stop()
      ..forward(from: 0);
  }
}

enum _OutingAction { edit, cancel, delete }

class _OutingInfoGallery extends StatefulWidget {
  const _OutingInfoGallery({
    super.key,
    required this.placeId,
    required this.outing,
    required this.coverUrl,
    required this.optionImages,
    required this.heroCover,
    required this.canView,
  });

  final String? placeId;
  final Outing outing;
  final String coverUrl;
  final List<String> optionImages;
  final bool Function(BuildContext) canView;
  final Widget Function(Outing outing, String url, double height) heroCover;

  @override
  State<_OutingInfoGallery> createState() => _OutingInfoGalleryState();
}

class _OutingInfoGalleryState extends State<_OutingInfoGallery> {
  late final SuggestedPlace? _cached;
  Future<SuggestedPlace?>? _details;

  @override
  void initState() {
    super.initState();
    final discover = context.read<DiscoverProvider>();
    final id = widget.placeId;
    _cached = id == null ? null : discover.findById(id);
    if (id != null && id.isNotEmpty && (_cached?.images.length ?? 0) < 2) {
      _details = discover.repository
          .getPlace(id)
          .then((result) => result.fold((_) => null, (place) => place));
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) {
      final height = (limits.maxWidth / 3).clamp(100.0, 185.0);
      return FutureBuilder<SuggestedPlace?>(
        future: _details,
        builder: (context, snapshot) {
          final place = snapshot.data ?? _cached;
          final images = <String>{
            widget.coverUrl.trim(),
            if (place != null) place.coverImageUrl.trim(),
            if (place != null)
              for (final image in place.images) image.imageUrl.trim(),
            ...widget.optionImages,
          }..removeWhere((url) => url.isEmpty);
          return OutingPlaceGallery(
            art: widget.outing.occasion.coverArt,
            images: images.toList(growable: false),
            height: height,
            canViewFullscreen: widget.canView,
            border: OutingInfoStyle(context).border,
            firstPhoto: widget.heroCover(
              widget.outing,
              images.firstOrNull ?? '',
              height,
            ),
          );
        },
      );
    },
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});
  final List<_DetailAction> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) {
      final scale = MediaQuery.textScalerOf(context).scale(12);
      final columns = limits.maxWidth >= 325 && scale <= 15
          ? actions.length
          : limits.maxWidth >= 215 && scale <= 24
          ? 2
          : 1;
      return Column(
        children: [
          for (var start = 0; start < actions.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 8),
                    Expanded(
                      child: start + column < actions.length
                          ? actions[start + column]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    return OutingInfoPanel(
      radius: 14,
      gradient: primary ? OutingInfoStyle.purple : null,
      outline: primary ? const Color(0xFF6C3A99) : null,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? Colors.white : style.icon, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: style.type(11, color: primary ? Colors.white : style.text),
            ),
            if (detail != null)
              Text(detail!, textAlign: TextAlign.center, style: style.type(11)),
          ],
        ),
      ),
    );
  }
}

class _AboutOutingCard extends StatelessWidget {
  const _AboutOutingCard();

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    final l10n = context.l10n;
    return OutingInfoPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.article_outlined, color: style.icon, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.outingAboutTitle,
                    style: style.type(17, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.noGroupBio,
                  style: style.type(13, color: style.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutingInfoSkeleton extends StatelessWidget {
  const _OutingInfoSkeleton({this.cover});
  final Widget? cover;

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 3,
          child: cover ?? const ShimmerBone(radius: 18),
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: ShimmerLine(width: 172, height: 28),
        ),
        const SizedBox(height: 8),
        const ShimmerBone(height: 51, radius: 14),
        for (final height in const [168.0, 100.0, 94.0, 76.0, 68.0]) ...[
          const SizedBox(height: 12),
          ShimmerBone(height: height, radius: 16),
        ],
      ],
    ),
  );
}
