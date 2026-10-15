import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/image_source_sheet.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
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
  });

  final Group? group;
  final SuggestedPlace? suggestedPlace;
  final SavedOuting? saved;
  final OutingDraft? draft;
  final bool specialEvent;

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
        );
        form.applySuggestionTitle(l10n);
        return form;
      },
      child: const _CreateOutingView(),
    );
  }
}

class _CreateOutingView extends StatelessWidget {
  const _CreateOutingView();

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
    final picked = await Get.to<PickedPlace>(
      () => PickLocationPage(
        placeName: form.customPlaceController.text.trim(),
        initialLatitude: form.customLatitude,
        initialLongitude: form.customLongitude,
      ),
    );
    if (picked == null || !context.mounted) return;
    form.applyPickedPlace(picked);
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
    final selected = await Get.to<Set<String>>(
      () => InviteGuestsPage(
        contacts: form.contacts,
        initialSelectedIds: form.guestIds,
      ),
    );
    if (selected == null || !context.mounted) return;
    form.setGuests(selected);
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
                              leading: AppNetworkImage(
                                url: group.image,
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
    );
    if (selected == null) return;
    form.setGroup(selected);
  }

  void _next(BuildContext context, CreateOutingProvider form) {
    final error = form.next(context.l10n);
    if (error != null) AppSnackBar.show(error);
  }

  Future<void> _create(BuildContext context, CreateOutingProvider form) async {
    final outings = context.read<OutingsProvider>();
    if (outings.isCreating) return;
    final userId = context.read<AuthProvider>().user?.id;
    final outing = form.buildOuting(createdById: userId);
    final ok = await outings.add(outing);
    if (!context.mounted || !ok) return;
    if (form.draft != null) {
      await context.read<SavedOutingsProvider>().removeDraft(form.draft!.id);
    }
    if (!context.mounted) return;
    AppSnackBar.show(context.l10n.outingCreated);
    Get.off(() => EventPage(event: outing));
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
      l10n.continueToLocation,
      l10n.continueToReview,
      l10n.createAndGo,
    ];

    return Scaffold(
      // AppPageBar — create outing / special event
      appBar: AppPageBar(
        title: form.specialEvent ? l10n.createSpecialEvent : l10n.createOuting,
        subtitle: form.specialEvent
            ? l10n.specialEventSubtitle
            : l10n.funStartsHere,
        backIcon: form.step == 0 ? Icons.close : Icons.chevron_left,
        onBack: creating
            ? () {}
            : () => form.step == 0 ? Get.back() : form.back(),
        trailing: form.step == 2
            ? TextButton(
                onPressed: creating ? null : () => _saveDraft(context, form),
                child: Text(
                  l10n.saveDraft,
                  style: TextStyle(
                    color: AppColors.brand600,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSm,
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: Responsive.padding(
                  horizontal: 20,
                  top: 16,
                  bottom: 20,
                ),
                children: [
                  CreateOutingStepHeader(form: form),
                  if (form.step == 0)
                    CreateOutingBasicsStep(
                      form: form,
                      onUploadPhoto: () => _uploadPhoto(context, form),
                      onInviteGuests: () => _inviteGuests(context, form),
                      onPickGroup: () => _pickGroup(context, form),
                      onPickDate: () => _pickDate(context, form),
                      onPickTime: () => _pickTime(context, form),
                    ),
                  if (form.step == 1)
                    CreateOutingLocationStep(
                      form: form,
                      onPickCustomLocation: () =>
                          _pickCustomLocation(context, form),
                    ),
                  if (form.step == 2) CreateOutingReviewStep(form: form),
                ],
              ),
            ),
            Padding(
              padding: Responsive.padding(horizontal: 20, top: 8, bottom: 16),
              child: CustomButton(
                label: form.step == 2 && form.specialEvent
                    ? l10n.createSpecialEvent
                    : actions[form.step],
                icon: Icons.arrow_forward,
                isLoading: form.step == 2 && creating,
                onPressed: creating
                    ? null
                    : form.step == 2
                    ? () => _create(context, form)
                    : () => _next(context, form),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
