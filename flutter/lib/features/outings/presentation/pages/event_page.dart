import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/avatar_stack.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_going_sheet.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_vote_widget.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key, required this.event});

  final Outing event;

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<OutingsProvider>().refreshLifecycle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final outings = context.watch<OutingsProvider>();
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

    return Scaffold(
      appBar: AppPageBar(
        title: live.title,
        trailing: AppIconButton(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          background: saved ? AppColors.brand600 : null,
          foreground: saved ? Colors.white : null,
          onTap: () => _toggleSaved(context, live),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Responsive.pagePadding(),
          children: [
            AppNetworkImage(
              url: live.image,
              width: double.infinity,
              height: 220.h,
              radius: 24.r,
              placeholderIcon: Icons.explore_outlined,
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
                AppBadge(
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
              live.meta,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: Responsive.fontBody,
              ),
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
                  live.date,
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
                  live.time,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontBody,
                  ),
                ),
              ],
            ),
            Responsive.spaceMd.gapH,
            OutingVoteWidget(outing: live),
            Responsive.spaceMd.gapH,
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
                      AttendanceStatus.notVoted => l10n.stillNotVoted,
                    },
                    color: switch (attendance) {
                      AttendanceStatus.going => AppColors.emerald50,
                      AttendanceStatus.notGoing => AppColors.rose50,
                      AttendanceStatus.notVoted => palette.surfaceMuted,
                    },
                    textColor: switch (attendance) {
                      AttendanceStatus.going => const Color(0xFF059669),
                      AttendanceStatus.notGoing => AppColors.rose600,
                      AttendanceStatus.notVoted => palette.textMuted,
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
              onPressed: () => AppSnackBar.show(l10n.comingSoonFeature),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSaved(BuildContext context, Outing live) async {
    final added = await context.read<SavedOutingsProvider>().toggle(live);
    if (!context.mounted) return;
    AppSnackBar.show(
      added ? context.l10n.outingSaved : context.l10n.outingRemoved,
    );
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
      query: location?.label ?? widget.event.meta.split('·').first.trim(),
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
