import 'package:yalla_5roga/features/outings/presentation/widgets/outing_management_actions.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/animations/flying_item_animator.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_fade_switcher.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/avatar_stack.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/chat/presentation/pages/outing_chat_page.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_arrivals_section.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_going_sheet.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_vote_widget.dart';

enum OutingDetailsSection { placeVoting, attendance }

class EventPage extends StatefulWidget {
  const EventPage({
    super.key,
    required this.event,
    this.coverHeroTag,
    this.initialSection,
    this.manualWhatsAppUrls = const [],
  });

  final Outing event;
  final OutingDetailsSection? initialSection;
  final List<String> manualWhatsAppUrls;

  /// Hero tag of the card thumbnail that opened this page; null for deep
  /// links, notifications and post-create navigation (no source image).
  final String? coverHeroTag;

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage>
    with SingleTickerProviderStateMixin {
  final _coverKey = GlobalKey();
  final _initialSectionKey = GlobalKey();
  final _bookmarkKey = GlobalKey();

  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeListener;
  late final AnimationController _bookmarkBounce;
  var _saving = false;
  var _deleting = false;
  var _loadingDetails = true;
  OutingsProvider? _openOutingProvider;

  @override
  void initState() {
    super.initState();
    _openOutingProvider = context.read<OutingsProvider>()
      ..openOuting(widget.event.id);
    _bookmarkBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _initialSectionKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target);
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
    if (!mounted) return;
    if (!_loadingDetails) setState(() => _loadingDetails = true);
    final outings = context.read<OutingsProvider>();
    final changed = await OfflineSnapshots.preview(
      () => outings.refreshLifecycle(outingId: widget.event.id),
    );
    if (mounted && changed) setState(() => _loadingDetails = false);
    await outings.refreshLifecycle(outingId: widget.event.id);
    await outings.loadGuests(widget.event.id);
    if (mounted && _loadingDetails) setState(() => _loadingDetails = false);
  }

  Future<void> _delete(Outing outing) async {
    if (_deleting) return;
    final l10n = context.l10n;
    final confirmed = await AppAlert.confirm(
      title: l10n.deleteOutingTitle,
      message: l10n.deleteOutingBody,
      confirmText: l10n.deleteOuting,
      cancelText: l10n.cancel,
      destructive: true,
    );
    if (!mounted || !confirmed || _deleting) return;
    final saved = context.read<SavedOutingsProvider>();
    setState(() => _deleting = true);
    final deleted = await context.read<OutingsProvider>().delete(outing.id);
    if (deleted) saved.removeDeletedOuting(outing.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (deleted) {
      Navigator.of(context).pop();
      AppSnackBar.show(l10n.outingDeleted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final outings = context.watch<OutingsProvider>();
    if (outings.isUnavailable(widget.event.id)) {
      return Scaffold(
        appBar: AppPageBar(title: l10n.navOutings),
        body: AppEmptyState(
          icon: Icons.event_busy_outlined,
          message: l10n.dataLoadFailed,
        ),
      );
    }
    final live = outings.findById(widget.event.id) ?? widget.event;
    final saved = context.watch<SavedOutingsProvider>().isSaved(live.id);
    final userId = context.watch<AuthProvider>().user?.id;
    final attendance = outings.cuserAttendance(live.id, userId);
    final going = outings.goingCountFor(live.id);
    final goingAvatars = [
      for (final member in outings.membersForOuting(live))
        if (outings.attendanceFor(live.id, member.id) ==
                AttendanceStatus.going &&
            member.avatar.trim().isNotEmpty)
          member.avatar,
    ];
    final goingAvatarUrls = goingAvatars.take(3).toList();

    final bounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.28,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.28,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
    ]).animate(_bookmarkBounce);

    final page = Scaffold(
      appBar: AppPageBar(
        title: live.title,
        trailing: ScaleTransition(
          scale: bounce,
          child: KeyedSubtree(
            key: _bookmarkKey,
            child: AppIconButton(
              icon: saved ? Icons.bookmark : Icons.bookmark_border,
              background: saved ? AppColors.brand600 : null,
              foreground: saved ? Colors.white : null,
              isLoading: _saving,
              onTap: () {
                if (!_deleting) _toggleSaved(context, live);
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: Responsive.pagePadding(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: _coverKey,
                child: AppHero(
                  tag: widget.coverHeroTag,
                  url: _coverUrl(live),
                  radius: 24.r,
                  child: PlanningCover(
                    url: _coverUrl(live),
                    art: live.occasion.coverArt,
                    width: double.infinity,
                    height: 220.h,
                  ),
                ),
              ),
              Responsive.spaceMd.gapH,
              Text(
                live.title,
                style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w800),
              ),
              Responsive.spaceXs.gapH,
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  // Status reflects provider state; the badge only animates
                  // once the outing actually moves (voting -> confirmed -> past).
                  AppFadeSwitcher(
                    axis: AppRevealAxis.vertical,
                    alignment: AlignmentDirectional.centerStart,
                    child: AppBadge(
                      key: ValueKey(live.status),
                      label: switch (live.status) {
                        OutingStatus.voting => l10n.voting,
                        OutingStatus.past => l10n.past,
                        _ => l10n.confirmed,
                      },
                      color: live.status == OutingStatus.voting
                          ? AppColors.amber100
                          : AppColors.emerald500,
                      textColor: live.status == OutingStatus.voting
                          ? AppColors.amber700
                          : Colors.white,
                    ),
                  ),
                  if (live.occasion == OutingOccasion.birthday)
                    AppBadge(
                      label: l10n.birthday,
                      color: AppColors.brand50,
                      textColor: AppColors.brand700,
                    ),
                  if (live.occasion == OutingOccasion.wedding)
                    AppBadge(
                      label: l10n.wedding,
                      color: const Color(0xFFEDE9FE),
                      textColor: const Color(0xFF7C3AED),
                    ),
                ],
              ),
              Responsive.spaceSm.gapH,
              Text(
                live.localizedMeta(l10n),
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: Responsive.fontBody,
                ),
              ),
              if (widget.manualWhatsAppUrls.isNotEmpty) ...[
                Responsive.spaceLg.gapH,
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.whatsappInvites,
                        style: context.texts.titleMedium,
                      ),
                      Text(l10n.sendEventInvitesManually),
                      for (final url in widget.manualWhatsAppUrls)
                        TextButton.icon(
                          icon: const Icon(Icons.send_outlined),
                          label: Text(
                            l10n.digits(
                              '+${Uri.parse(url).pathSegments.first}',
                            ),
                          ),
                          onPressed: () async {
                            if (!await AppLauncher.openWhatsAppUrl(url) &&
                                context.mounted) {
                              AppSnackBar.show(l10n.couldNotOpenLink);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
              if (userId != null && live.scheduledAt != null)
                OutingArrivalsSection(
                  key: ValueKey(live.id),
                  outing: live,
                  userId: userId,
                ),
              Responsive.spaceMd.gapH,
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: Responsive.iconMd,
                    color: AppColors.brand600,
                  ),
                  8.gapW,
                  Text(
                    live.localizedDate(l10n),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontBody,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.schedule,
                    size: Responsive.iconMd,
                    color: AppColors.brand600,
                  ),
                  8.gapW,
                  Text(
                    live.localizedTime(l10n),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontBody,
                    ),
                  ),
                ],
              ),
              Responsive.spaceMd.gapH,
              if (!outings.hasAttendanceFor(live.id)) ...[
                if (_loadingDetails)
                  const LinearProgressIndicator()
                else
                  TextButton(
                    onPressed: _refreshLifecycle,
                    child: Text(l10n.tryAgain),
                  ),
              ],
              OutingVoteWidget(
                outing: live,
                placeVotingKey:
                    widget.initialSection == OutingDetailsSection.placeVoting
                    ? _initialSectionKey
                    : null,
                attendanceKey:
                    widget.initialSection == OutingDetailsSection.attendance
                    ? _initialSectionKey
                    : null,
              ),
              Responsive.spaceMd.gapH,
              if (outings.hasAttendanceFor(live.id))
                AppCard(
                  onTap: () => OutingGoingSheet.show(live),
                  radius: 18,
                  padding: EdgeInsets.all(14.w),
                  child: Row(
                    children: [
                      if (going > 0) ...[
                        AvatarStack(
                          urls: goingAvatarUrls,
                          extra: (going - goingAvatarUrls.length).clamp(0, 99),
                        ),
                        12.gapW,
                      ],
                      Expanded(
                        child: Text(
                          l10n.goingCount(going),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: Responsive.fontSm,
                          ),
                        ),
                      ),
                      AppBadge(
                        label: switch (attendance) {
                          AttendanceStatus.going => l10n.imIn,
                          AttendanceStatus.notGoing => l10n.notIn,
                          AttendanceStatus.maybe => l10n.maybe,
                          AttendanceStatus.unset => l10n.stillNotVoted,
                        },
                        color: switch (attendance) {
                          AttendanceStatus.going => AppColors.emerald50,
                          AttendanceStatus.notGoing => AppColors.rose50,
                          AttendanceStatus.maybe => AppColors.amber100,
                          AttendanceStatus.unset => palette.surfaceMuted,
                        },
                        textColor: switch (attendance) {
                          AttendanceStatus.going => const Color(0xFF059669),
                          AttendanceStatus.notGoing => AppColors.rose600,
                          AttendanceStatus.maybe => AppColors.amber700,
                          AttendanceStatus.unset => palette.textMuted,
                        },
                      ),
                    ],
                  ),
                ),
              Responsive.spaceLg.gapH,
              if (!live.isLocationHidden && live.location != null) ...[
                _MapsButton(event: live),
                Responsive.spaceSm.gapH,
              ],
              CustomButton(
                label: l10n.outingChat,
                icon: Icons.chat_bubble_outline,
                variant: AppButtonVariant.outlined,
                onPressed: _deleting ? null : () => _openChat(context, live),
              ),
              OutingManagementActions(outing: live, userId: userId),
              if (userId != null && userId == live.createdById) ...[
                Responsive.spaceXl.gapH,
                CustomButton(
                  label: l10n.deleteOuting,
                  icon: Icons.delete_outline,
                  variant: AppButtonVariant.danger,
                  isLoading: _deleting,
                  onPressed: _deleting || _saving ? null : () => _delete(live),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return PopScope(canPop: !_deleting, child: page);
  }

  /// Prefer the cover the user tapped so a live refresh cannot swap the
  /// Hero artwork mid-flight. Fall back to the provider copy when the
  /// snapshot had no image (empty API payload that later hydrates).
  String _coverUrl(Outing live) {
    final tapped = widget.event.image.trim();
    if (tapped.isNotEmpty) return widget.event.image;
    return live.image;
  }

  void _openChat(BuildContext context, Outing live) {
    if (!live.canOpenChat) {
      AppSnackBar.show(context.l10n.chatNeedsSuggestion);
      return;
    }
    Get.to(() => OutingChatPage(event: live));
  }

  Future<void> _toggleSaved(BuildContext context, Outing live) async {
    if (_saving || FlyingItemAnimator.isFlying) return;
    setState(() => _saving = true);
    final added = await context.read<SavedOutingsProvider>().toggle(live);
    if (!context.mounted) return;
    setState(() => _saving = false);

    if (added == null) {
      AppSnackBar.showError(context.l10n.unexpectedError);
      return;
    }

    if (added) {
      final coverUrl = _coverUrl(live);
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
    if (!mounted) return;
    _bookmarkBounce
      ..stop()
      ..forward(from: 0);
  }
}

class _MapsButton extends StatefulWidget {
  const _MapsButton({required this.event});

  final Outing event;

  @override
  State<_MapsButton> createState() => _MapsButtonState();
}

class _MapsButtonState extends State<_MapsButton> {
  var _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final location = widget.event.location;
    final opened = await AppLauncher.openMaps(
      latitude: location?.latitude,
      longitude: location?.longitude,
      query: location?.label ?? widget.event.meta.split('Â·').first.trim(),
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) AppSnackBar.show(context.l10n.couldNotOpenLink);
  }

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      label: context.l10n.viewLocation,
      icon: Icons.near_me_outlined,
      isLoading: _opening,
      onPressed: _open,
    );
  }
}
