import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_fade_switcher.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/image_source_sheet.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/invite_guests_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/pick_location_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_basics_step.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_location_step.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_review_step.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_step_header.dart';

class CreateOutingPage extends StatelessWidget {
  const CreateOutingPage({
    super.key,
    this.group,
    this.suggestedPlace,
    this.saved,
    this.draft,
    this.specialEvent = false,
    this.letVote = false,
  });

  final Group? group;
  final SuggestedPlace? suggestedPlace;
  final SavedOuting? saved;
  final OutingDraft? draft;
  final bool specialEvent;

  /// Opens the shared create form in multi-place voting mode (replaces the
  /// old separate "suggest places" sheet).
  final bool letVote;

  @override
  Widget build(BuildContext context) {
    // Read dependencies in build — Provider.create must not listen to InheritedWidgets.
    final groups = context.read<GroupsProvider>();
    final outings = context.read<OutingsProvider>();
    final discover = context.read<DiscoverProvider>();
    final l10n = context.l10n;

    return ChangeNotifierProvider(
      create: (_) {
        final form = CreateOutingProvider(
          groups: groups.groups,
          contacts: groups.contacts,
          catalogPlaces: discover.catalogPlaces().isNotEmpty
              ? discover.catalogPlaces()
              : outings.places,
          specialEventImage: outings.specialEventImage,
          group: group,
          suggestedPlace: suggestedPlace,
          saved: saved,
          draft: draft,
          specialEvent: specialEvent,
          letVote: letVote,
        );
        form.applySuggestionTitle(l10n);
        return form;
      },
      child: const _CreateOutingView(),
    );
  }
}

/// Slides wizard steps along the reading direction: forward enters from the
/// end side, back enters from the start side. Keyed on the step index only,
/// so form edits within a step never replay the transition.
class _StepSwitcher extends StatefulWidget {
  const _StepSwitcher({required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  State<_StepSwitcher> createState() => _StepSwitcherState();
}

class _StepSwitcherState extends State<_StepSwitcher> {
  var _forward = true;

  @override
  void didUpdateWidget(covariant _StepSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _forward = widget.step > oldWidget.step;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFadeSwitcher(
      axis: AppRevealAxis.horizontal,
      forward: _forward,
      alignment: AlignmentDirectional.topStart,
      child: widget.child,
    );
  }
}

class _CreateOutingView extends StatefulWidget {
  const _CreateOutingView();

  @override
  State<_CreateOutingView> createState() => _CreateOutingViewState();
}

class _CreateOutingViewState extends State<_CreateOutingView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goBack(CreateOutingProvider form) {
    if (form.step == 0) {
      Get.back();
      return;
    }
    FocusScope.of(context).unfocus();
    form.back();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _uploadPhoto(
    BuildContext context,
    CreateOutingProvider form,
  ) async {
    final path = await ImageSourceSheet.pick(title: context.l10n.uploadPhoto);
    if (path == null) return;
    form.setImage(path);
  }

  Future<void> _pickCustomLocation(
    BuildContext context,
    CreateOutingProvider form,
  ) async {
    final discover = context.read<DiscoverProvider>();
    final multi = form.multiPlaceMode;
    final selected = await Get.to<List<Place>>(
      () => PickLocationPage(
        catalog: discover.catalogPlaces(),
        initial: multi ? null : form.mapInitialPlace,
        selected: multi ? form.selectedPlaces : const [],
        maxSelections: multi ? OutingsProvider.maxVotePlaces : 1,
      ),
    );
    if (selected == null || !context.mounted) return;
    form.replaceMapSelection(selected);
  }

  Future<void> _pickDate(
    BuildContext context,
    CreateOutingProvider form,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: form.clampDate(form.date),
      firstDate: form.minDate,
      lastDate: form.maxDate,
    );
    if (picked == null) return;
    form.setDate(picked);
  }

  Future<void> _pickTime(
    BuildContext context,
    CreateOutingProvider form,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: form.time,
    );
    if (picked == null) return;
    form.setTime(picked);
  }

  Future<void> _inviteGuests(
    BuildContext context,
    CreateOutingProvider form,
  ) async {
    final selected = await Get.to<SelectedEventGuests>(
      () => InviteGuestsPage(
        contacts: form.contacts,
        initialSelectedIds: form.guestIds,
        initialSelectedPhones: form.guestPhones,
      ),
    );
    if (selected == null || !context.mounted) return;
    form.setGuests(selected.ids, phones: selected.phones);
  }

  Future<void> _pickGroup(
    BuildContext context,
    CreateOutingProvider form,
  ) async {
    if (form.groupLocked) return;
    final selected = await Get.bottomSheet<Group>(
      SafeArea(
        child: Builder(
          builder: (context) {
            final palette = context.palette;
            final l10n = context.l10n;
            final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
            return Material(
              color: palette.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: Responsive.padding(all: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.chooseGroup,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontMd,
                        ),
                      ),
                      Responsive.spaceMd.gapH,
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: form.groups.length,
                          itemBuilder: (context, index) {
                            final group = form.groups[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: PlanningCover(
                                url: group.image,
                                art: PlanningCoverArt.group,
                                width: 40.w,
                                height: 40.w,
                                radius: 12.r,
                              ),
                              title: Text(
                                group.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                l10n.membersWillBeInvited(group.memberCount),
                              ),
                              trailing: form.group?.id == group.id
                                  ? Icon(
                                      Icons.check_circle,
                                      color: AppColors.brand600,
                                      size: 22.w,
                                    )
                                  : null,
                              onTap: () => Get.back(result: group),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: AppMotion.sheetEnter,
      exitBottomSheetDuration: AppMotion.sheetExit,
    );
    if (selected == null) return;
    form.setGroup(selected);
  }

  void _next(BuildContext context, CreateOutingProvider form) {
    final error = form.next(context.l10n);
    if (error != null) {
      AppSnackBar.show(error);
      return;
    }
    FocusScope.of(context).unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _create(BuildContext context, CreateOutingProvider form) async {
    final outings = context.read<OutingsProvider>();
    if (outings.isCreating) return;
    if (form.guestPhones.isNotEmpty) {
      final l10n = context.l10n;
      final optedIn = await AppAlert.confirm(
        title: l10n.whatsappInvites,
        message: l10n.whatsappOptInPrompt,
        confirmText: l10n.confirmWhatsAppInvites,
        cancelText: l10n.cancel,
      );
      if (!context.mounted || !optedIn || outings.isCreating) return;
    }
    final userId = context.read<AuthProvider>().user?.id;
    final outing = form.buildOuting(createdById: userId);
    final created = await outings.add(outing);
    if (!context.mounted || created == null) return;
    if (form.draft != null) {
      await context.read<SavedOutingsProvider>().removeDraft(form.draft!.id);
    }
    if (!context.mounted) return;
    AppSnackBar.show(context.l10n.outingCreated);
    Get.off(
      () => EventPage(
        event: created.outing,
        manualWhatsAppUrls: created.manualWhatsAppUrls,
      ),
    );
  }

  Future<void> _saveDraft(
    BuildContext context,
    CreateOutingProvider form,
  ) async {
    if (context.read<OutingsProvider>().isCreating) return;
    final l10n = context.l10n;
    final error = form.draftError(l10n);
    if (error != null) {
      AppSnackBar.show(error);
      return;
    }
    await context.read<SavedOutingsProvider>().saveDraft(form.toDraft());
    if (!context.mounted) return;
    AppSnackBar.show(l10n.draftSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final form = context.watch<CreateOutingProvider>()..syncLocale(l10n);
    final creating = context.watch<OutingsProvider>().isCreating;
    final actions = [
      form.multiPlaceMode ? l10n.continueToPlaces : l10n.continueToLocation,
      l10n.continueToReview,
      l10n.createAndGo,
    ];

    return Scaffold(
      // AppPageBar — create outing / special event
      appBar: AppPageBar(
        title: form.specialEvent ? l10n.createSpecialEvent : l10n.createOuting,
        backIcon: form.step == 0 ? Icons.close : context.chevronBack,
        onBack: creating ? () {} : () => _goBack(form),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: Responsive.pagePadding(),
                    children: [
                      CreateOutingStepHeader(form: form),
                      _StepSwitcher(
                        step: form.step,
                        child: switch (form.step) {
                          0 => CreateOutingBasicsStep(
                            key: const ValueKey(0),
                            form: form,
                            onUploadPhoto: () => _uploadPhoto(context, form),
                            onInviteGuests: () => _inviteGuests(context, form),
                            onPickGroup: () => _pickGroup(context, form),
                            onPickDate: () => _pickDate(context, form),
                            onPickTime: () => _pickTime(context, form),
                          ),
                          1 => CreateOutingLocationStep(
                            key: const ValueKey(1),
                            form: form,
                            onPickCustomLocation: () =>
                                _pickCustomLocation(context, form),
                          ),
                          _ => CreateOutingReviewStep(
                            key: const ValueKey(2),
                            form: form,
                          ),
                        },
                      ),
                    ],
                  ),
                ),
                Material(
                  color: context.palette.background,
                  child: Padding(
                    padding: Responsive.pagePadding(top: 8, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomButton(
                          label: form.step == 2 && form.specialEvent
                              ? l10n.createSpecialEvent
                              : actions[form.step],
                          icon: form.step == 2
                              ? Icons.check
                              : context.chevronForward,
                          isLoading: form.step == 2 && creating,
                          onPressed: creating
                              ? null
                              : form.step == 2
                              ? () => _create(context, form)
                              : () => _next(context, form),
                        ),
                        if (form.step == 2)
                          TextButton(
                            onPressed: creating
                                ? null
                                : () => _saveDraft(context, form),
                            child: Text(l10n.saveDraft),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
