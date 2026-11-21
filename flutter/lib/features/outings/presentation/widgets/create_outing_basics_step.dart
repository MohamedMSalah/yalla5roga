import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_step_header.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_place_gallery.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/special_event_fields.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/voting_deadline_selector.dart';

class CreateOutingBasicsStep extends StatelessWidget {
  const CreateOutingBasicsStep({
    super.key,
    required this.form,
    required this.onInviteGuests,
    required this.onPickGroup,
    required this.onPickSchedule,
    required this.onEditLocation,
    required this.onPickDeadline,
  });

  final CreateOutingProvider form;
  final VoidCallback onInviteGuests, onPickGroup, onPickSchedule;
  final VoidCallback onEditLocation, onPickDeadline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = OutingCreationStyle(context);
    final places = form.selectedPlaces;
    final first = places.firstOrNull;
    final language = l10n.locale.languageCode;
    final distance = first == null ? null : form.placeDistanceKm(first);
    final voting = form.multiPlaceMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9, bottom: 8),
          child: CreationSectionHeading(
            icon: Icons.image_outlined,
            title: l10n.creationReview,
            subtitle: l10n.creationReviewHint,
          ),
        ),
        LayoutBuilder(
          builder: (_, constraints) => OutingPlaceGallery(
            images: places.isEmpty
                ? [form.resolvedImage]
                : places.map((place) => place.imageUrl).toList(),
            candidateLabels: places
                .map((p) => p.displayName(language))
                .toList(),
            art: form.occasion.coverArt,
            height: constraints.maxWidth / 2,
            border: style.border,
          ),
        ),
        const SizedBox(height: 0),
        _CreationFieldCard(
          icon: Icons.title_rounded,
          label: form.specialEvent ? l10n.eventName : l10n.outingName,
          child: TextFormField(
            controller: form.nameController,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              InputFormatters.maxLength(AppConstants.maxOutingNameLength),
            ],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => Validators.outingName(value, l10n),
            style: _fieldValueStyle(context),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              constraints: const BoxConstraints(minHeight: 29),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: form.specialEvent
                  ? l10n.eventName
                  : l10n.creationNameHint,
              hintStyle: TextStyle(color: style.muted),
            ),
          ),
        ),
        _CreationFieldCard(
          icon: Icons.location_on_rounded,
          label: voting ? l10n.creationVotingLocations : l10n.wizardLocation,
          value: voting
              ? l10n.creationSelectedCount(places.length)
              : first?.displayName(language) ?? l10n.creationPickFirst,
          helper: voting
              ? l10n.creationVoteHint
              : distance == null
              ? null
              : l10n.catalogDistanceLabel(distance),
          error: form.validateLocation(l10n),
          onTap: onEditLocation,
        ),
        _CreationFieldCard(
          icon: Icons.calendar_month_rounded,
          label: l10n.creationDateTime,
          value:
              '${l10n.formatCreationDate(form.date)} · ${form.formattedTime}',
          error: form.scheduleError(l10n),
          onTap: onPickSchedule,
        ),
        _CreationFieldCard(
          icon: Icons.groups_rounded,
          label: form.specialEvent
              ? l10n.eventGroupOptional
              : l10n.creationGroup,
          value:
              form.group?.name ??
              (form.specialEvent ? l10n.independentEvent : l10n.chooseGroup),
          error: form.specialEvent ? null : form.audienceError(l10n),
          onTap: form.groupLocked ? null : onPickGroup,
        ),
        if (form.specialEvent) ...[
          const SizedBox(height: 4),
          SpecialEventFields(form: form, onInviteGuests: onInviteGuests),
          if (form.audienceError(l10n) case final error?)
            Text(error, style: TextStyle(color: context.colors.error)),
        ],
        if (voting)
          _VotingConfiguration(form: form, onPickDeadline: onPickDeadline),
      ],
    );
  }
}

TextStyle? _fieldValueStyle(BuildContext context) =>
    context.texts.bodyLarge?.copyWith(
      color: OutingCreationStyle(context).ink,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

class _CreationFieldCard extends StatelessWidget {
  const _CreationFieldCard({
    required this.icon,
    required this.label,
    this.value,
    this.helper,
    this.error,
    this.child,
    this.onTap,
    this.nested = false,
  });

  final IconData icon;
  final String label;
  final String? value, helper, error;
  final Widget? child;
  final VoidCallback? onTap;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final style = OutingCreationStyle(context);
    final labelStyle = context.texts.labelLarge?.copyWith(
      color: style.accent,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    );
    final contents = Padding(
      padding: EdgeInsets.symmetric(horizontal: nested ? 0 : 15, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: style.active, size: 24),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(label, style: labelStyle),
                if (value != null)
                  Text(
                    value!,
                    style: _fieldValueStyle(context),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ?child,
                if (helper != null)
                  Text(
                    helper!,
                    style: context.texts.bodySmall?.copyWith(
                      color: style.muted,
                    ),
                  ),
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 8),
              child: Icon(context.chevronForward, size: 19, color: style.muted),
            ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: nested ? const BoxDecoration() : style.surface(raised: true),
      child: Semantics(
        button: onTap != null,
        label: child == null ? null : label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: contents,
          ),
        ),
      ),
    );
  }
}

class _VotingConfiguration extends StatelessWidget {
  const _VotingConfiguration({
    required this.form,
    required this.onPickDeadline,
  });
  final CreateOutingProvider form;
  final VoidCallback onPickDeadline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = OutingCreationStyle(context);
    final language = l10n.locale.languageCode;
    final categories = form.placeCatalog?.categories ?? const [];
    return DecoratedBox(
      decoration: style.surface(raised: true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              children: [
                Icon(Icons.how_to_vote_outlined, color: style.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.creationGroupVote,
                    style: context.texts.titleMedium?.copyWith(
                      color: style.ink,
                    ),
                  ),
                ),
                Chip(
                  label: Text(l10n.n(form.selectedPlaces.length)),
                  backgroundColor: style.elevated,
                ),
              ],
            ),
            Text(l10n.creationVotePrompt, style: TextStyle(color: style.muted)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 12,
                children: [
                  for (final place in form.selectedPlaces)
                    SizedBox(
                      width: 156,
                      child: Row(
                        children: [
                          PlanningCover(
                            url: place.imageUrl,
                            art: PlanningCoverArt.outing,
                            width: 42,
                            height: 42,
                            radius: 9,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.displayName(language),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _fieldValueStyle(context),
                                ),
                                if (categories
                                        .where((c) => c.id == place.categoryId)
                                        .firstOrNull
                                    case final category?)
                                  Text(
                                    category.label(language),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: style.muted),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _CreationFieldCard(
              icon: Icons.schedule_rounded,
              label: l10n.votingDeadlineTitle,
              value: l10n.votingDeadlineSummary(form.previewVotingDeadline),
              error: form.votingDeadlineError(l10n),
              onTap: onPickDeadline,
              nested: true,
            ),
            Text(
              l10n.creationVoteWinner,
              style: context.texts.bodySmall?.copyWith(color: style.muted),
            ),
            Text(
              l10n.creationVoteTie,
              style: context.texts.bodySmall?.copyWith(color: style.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class CreationDeadlineSheet extends StatelessWidget {
  const CreationDeadlineSheet({
    super.key,
    required this.form,
    required this.isActive,
  });
  final CreateOutingProvider form;
  final bool Function() isActive;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: form,
    builder: (_, _) => isActive()
        ? VotingDeadlineSelector(form: form)
        : const SizedBox.shrink(),
  );
}
