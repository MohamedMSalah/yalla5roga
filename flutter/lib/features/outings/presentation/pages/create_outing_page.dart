import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/invite_guests_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_basics_step.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_location_step.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_step_header.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/smart_meetup_location_source.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/meetup_result_handoff_model.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/widgets/stale_meetup_result_dialog.dart';

class CreateOutingPage extends StatefulWidget {
  const CreateOutingPage({
    super.key,
    this.group,
    this.suggestedPlace,
    this.initialPlaces = const [],
    this.suggestionOwner,
    this.meetupSelection,
    this.saved,
    this.draft,
    this.specialEvent = false,
  });

  final Group? group;
  final SuggestedPlace? suggestedPlace;
  final List<Place> initialPlaces;
  final String? suggestionOwner;
  final MeetupResultHandoffModel? meetupSelection;
  final SavedOuting? saved;
  final OutingDraft? draft;
  final bool specialEvent;

  @override
  State<CreateOutingPage> createState() => _CreateOutingPageState();
}

class _CreateOutingPageState extends State<CreateOutingPage> {
  late final _owner = context.read<AuthProvider>().user?.id;

  @override
  Widget build(BuildContext context) {
    final owner = context.select((AuthProvider p) => p.user?.id);
    if (_owner == null || _owner != owner) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.creationTitle)),
        body: Center(child: Text(context.l10n.creationSignInAgain)),
      );
    }
    final groups = context.read<GroupsProvider>();
    final outings = context.read<OutingsProvider>();
    final discover = context.read<DiscoverProvider>();
    final l10n = context.l10n;
    final acceptsSuggestion =
        widget.suggestionOwner == null || widget.suggestionOwner == owner;

    return ChangeNotifierProvider(
      key: ValueKey(owner),
      create: (_) {
        final form = CreateOutingProvider(
          placeCatalog:
              PlaceCatalogProvider(
                  discover.repository,
                  searchAcrossBounds: true,
                )
                ..privateOwner = owner
                ..loadDefinitions(),
          groups: groups.groups,
          contacts: groups.contacts,
          catalogPlaces: discover.catalogPlaces().isNotEmpty
              ? discover.catalogPlaces()
              : outings.places,
          specialEventImage: outings.specialEventImage,
          group: widget.group,
          initialPlaces: acceptsSuggestion ? widget.initialPlaces : const [],
          suggestedPlace: acceptsSuggestion ? widget.suggestedPlace : null,
          meetupSelection: acceptsSuggestion ? widget.meetupSelection : null,
          saved: widget.saved,
          draft: widget.draft,
          specialEvent: widget.specialEvent,
        );
        form.applySuggestionTitle(l10n);
        return form;
      },
      child: _CreateOutingView(owner: owner!),
    );
  }
}

class _CreateOutingView extends StatefulWidget {
  const _CreateOutingView({required this.owner});

  final String owner;

  @override
  State<_CreateOutingView> createState() => _CreateOutingViewState();
}

class _CreateOutingViewState extends State<_CreateOutingView> {
  bool _submitting = false;
  bool _confirmingExit = false;
  bool _savingDraft = false;
  bool _pickingMeetup = false;

  bool get _isCurrent =>
      mounted && context.read<AuthProvider>().user?.id == widget.owner;

  Future<void> _goBack(CreateOutingProvider form) async {
    if (_submitting ||
        _savingDraft ||
        _pickingMeetup ||
        _confirmingExit ||
        !_isCurrent) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (form.step > 0) {
      form.placeCatalog?.resumeBrowsing();
      form.back();
      return;
    }
    if (form.hasUnsavedChanges) {
      final l10n = context.l10n;
      _confirmingExit = true;
      final discard = await AppAlert.confirm(
        title: l10n.creationDiscardTitle,
        message: l10n.creationDiscardMessage,
        confirmText: l10n.creationDiscard,
        cancelText: l10n.cancel,
        destructive: true,
      );
      _confirmingExit = false;
      if (!discard || !_isCurrent) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showInfo(CreateOutingProvider form) {
    final l10n = context.l10n;
    return AppBottomSheet.show<void>(
      context: context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(l10n.creationInfo, style: sheetContext.texts.titleLarge),
          Text(
            form.specialEvent
                ? l10n.creationEventOnePlace
                : l10n.creationFixedHint,
          ),
          if (!form.specialEvent) ...[
            Text(l10n.creationVoteDeadlineHint),
            Text(l10n.creationVoteWinner),
            Text(l10n.creationVoteTie),
          ],
        ],
      ),
    );
  }

  Future<void> _pickSchedule(CreateOutingProvider form) =>
      AppBottomSheet.show<void>(
        context: context,
        builder: (sheetContext) => ListenableBuilder(
          listenable: form,
          builder: (context, _) => !_isCurrent
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(context.l10n.date),
                      subtitle: Text(
                        context.l10n.formatCreationDate(form.date),
                      ),
                      trailing: Icon(context.chevronForward),
                      onTap: () => _pickDate(sheetContext, form),
                    ),
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(context.l10n.time),
                      subtitle: Text(form.formattedTime),
                      trailing: Icon(context.chevronForward),
                      onTap: () => _pickTime(sheetContext, form),
                    ),
                  ],
                ),
        ),
      );

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
    if (picked == null || !_isCurrent) return;
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
    if (picked == null || !_isCurrent) return;
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
    if (selected == null || !_isCurrent) return;
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
                      if (form.specialEvent && !form.groupLocked)
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(l10n.independentEvent),
                          onTap: () {
                            if (_isCurrent) form.setGroup(null);
                            Get.back();
                          },
                        ),
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
    if (selected == null || !_isCurrent) return;
    form.setGroup(selected);
  }

  void _next(CreateOutingProvider form) {
    if (form.step != 0 || _pickingMeetup) return;
    final error = form.next(context.l10n);
    if (error != null) {
      AppSnackBar.show(error);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    form.placeCatalog?.pauseBrowsing();
  }

  Future<void> _pickMeetup(
    CreateOutingProvider form, {
    bool refresh = false,
  }) async {
    if (_pickingMeetup || !_isCurrent) return;
    setState(() => _pickingMeetup = true);
    try {
      final source = form.meetupSelection;
      final selected = await SmartMeetupLocationSource.pick(
        context,
        groupId: source == null ? form.group?.id : source.groupId,
        limit: form.maxSelections,
        refresh: refresh,
      );
      if (!_isCurrent || selected == null) return;
      if (form.applyMeetupSelection(selected)) {
        form.placeCatalog?.resumeBrowsing();
      }
    } finally {
      if (mounted) setState(() => _pickingMeetup = false);
    }
  }

  Future<void> _create(CreateOutingProvider form) async {
    final outings = context.read<OutingsProvider>();
    if (_submitting || _savingDraft || outings.isCreating || !_isCurrent) {
      return;
    }
    final l10n = context.l10n;
    final error = form.validateLocation(l10n) ?? form.validateDetails(l10n);
    if (error != null) {
      AppSnackBar.show(error);
      return;
    }
    final sync = context.read<AppSyncProvider>();
    final savedOutings = context.read<SavedOutingsProvider>();
    if (sync.status == SyncStatus.offline) {
      AppSnackBar.showError(l10n.noInternet);
      return;
    }

    setState(() => _submitting = true);
    FocusManager.instance.primaryFocus?.unfocus();
    bool routed = false;
    try {
      if (form.guestPhones.isNotEmpty) {
        final optedIn = await AppAlert.confirm(
          title: l10n.whatsappInvites,
          message: l10n.whatsappOptInPrompt,
          confirmText: l10n.confirmWhatsAppInvites,
          cancelText: l10n.cancel,
        );
        if (!_isCurrent || !optedIn) return;
      }
      final latestError = form.validateDetails(l10n);
      if (latestError != null) {
        form.refreshDeadlineClock();
        AppSnackBar.show(latestError);
        return;
      }

      var staleMeetup = false;
      final created = await outings.add(
        form.buildOuting(createdById: widget.owner),
        creatorId: widget.owner,
        onStaleMeetupResult: () => staleMeetup = true,
      );
      if (!mounted || !_isCurrent) return;
      if (created == null) {
        if (staleMeetup) {
          final refresh = await StaleMeetupResultDialog.show(context);
          if (refresh && _isCurrent) await _pickMeetup(form, refresh: true);
        } else if (outings.errorMessage case final error?) {
          AppSnackBar.show(error);
        }
        return;
      }
      if (form.draft case final draft?) {
        await savedOutings.removeDraft(draft.id);
      }
      if (!_isCurrent) return;
      routed = true;
      AppSnackBar.show(l10n.outingCreated);
      unawaited(
        Get.off(
          () => EventPage(
            event: created.outing,
            createdVotingDeadline: form.multiPlaceMode
                ? created.outing.voteEndsAt
                : null,
            manualWhatsAppUrls: created.manualWhatsAppUrls,
          ),
        ),
      );
    } finally {
      if (!routed && _isCurrent) setState(() => _submitting = false);
    }
  }

  Future<void> _saveDraft(CreateOutingProvider form) async {
    if (_savingDraft || _submitting || !_isCurrent) return;
    final l10n = context.l10n;
    final error = form.draftError(l10n);
    if (error != null) {
      AppSnackBar.show(error);
      return;
    }
    final draft = form.toDraft();
    final store = context.read<SavedOutingsProvider>();
    setState(() => _savingDraft = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final saved = await store.saveDraft(draft);
      if (!_isCurrent) return;
      if (saved == null) {
        AppSnackBar.showError(l10n.dataSendFailed);
        return;
      }
      if (!saved.conflict) form.markDraftSaved();
      AppSnackBar.show(
        saved.deviceLocalLocation
            ? l10n.localLocationDraft
            : saved.conflict
            ? l10n.draftSyncConflict
            : saved.pending
            ? l10n.draftPending
            : l10n.draftSaved,
      );
    } finally {
      if (_isCurrent) setState(() => _savingDraft = false);
    }
  }

  Widget _details(
    CreateOutingProvider form, {
    required bool creating,
    required bool offline,
  }) {
    final l10n = context.l10n;
    final style = OutingCreationStyle(context);
    final sending = _submitting || creating;
    final locked = sending || _savingDraft || _pickingMeetup;
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) {
        final validLocation = form.validateLocation(l10n) == null;
        final canSubmit =
            validLocation && form.validateDetails(l10n) == null && !offline;
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(
                child: ExcludeFocus(
                  excluding: locked,
                  child: AbsorbPointer(
                    absorbing: locked,
                    child: CreateOutingBasicsStep(
                      form: form,
                      onEditLocation: () => _goBack(form),
                      onInviteGuests: () => _inviteGuests(context, form),
                      onPickGroup: () => _pickGroup(context, form),
                      onPickSchedule: () => _pickSchedule(form),
                      onPickDeadline: () => AppBottomSheet.show<void>(
                        context: context,
                        builder: (_) => CreationDeadlineSheet(
                          form: form,
                          isActive: () => _isCurrent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (offline)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            l10n.noInternet,
                            style: TextStyle(color: style.muted),
                          ),
                        ),
                      CreationPrimaryButton(
                        label: form.specialEvent
                            ? l10n.createSpecialEvent
                            : l10n.creationSubmit,
                        icon: Icons.send_outlined,
                        loading: sending,
                        onPressed: canSubmit && !locked
                            ? () => _create(form)
                            : null,
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: style.muted,
                        ),
                        onPressed: locked ? null : () => _goBack(form),
                        child: Text(l10n.back),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: style.muted,
                        ),
                        onPressed: locked || form.draftError(l10n) != null
                            ? null
                            : () => _saveDraft(form),
                        child: Text(l10n.saveDraft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final form = context.read<CreateOutingProvider>()..syncLocale(l10n);
    final details = context.select((CreateOutingProvider p) => p.step == 1);
    final creating = context.select((OutingsProvider p) => p.isCreating);
    final offline = context.select(
      (AppSyncProvider p) => p.status == SyncStatus.offline,
    );
    final locked = _submitting || creating || _savingDraft || _pickingMeetup;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !locked) unawaited(_goBack(form));
      },
      child: Scaffold(
        backgroundColor: OutingCreationStyle(context).base,
        body: OutingCreationBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidth,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutingCreationAppBar(
                        title: form.specialEvent
                            ? l10n.createSpecialEvent
                            : l10n.creationTitle,
                        onBack: locked ? null : () => _goBack(form),
                        onInfo: locked ? null : () => _showInfo(form),
                      ),
                      if (constraints.maxHeight >= 360)
                        CreateOutingStepHeader(
                          details: details,
                          onLocation: locked ? null : () => _goBack(form),
                        ),
                      if (!details)
                        ListenableBuilder(
                          listenable: form,
                          builder: (context, _) => SmartMeetupLocationSource(
                            onPick: locked || offline
                                ? null
                                : () => _pickMeetup(form),
                            onManual: locked || form.meetupSelection == null
                                ? null
                                : () => form.replaceMapSelection(const []),
                          ),
                        ),
                      Expanded(
                        child: details
                            ? _details(
                                form,
                                creating: creating,
                                offline: offline,
                              )
                            : CreateOutingLocationStep(
                                key: ValueKey(l10n.locale.languageCode),
                                form: form,
                                onNext: () => _next(form),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
