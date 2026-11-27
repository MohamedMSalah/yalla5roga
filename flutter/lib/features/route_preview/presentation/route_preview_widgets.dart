import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/transportation/presentation/widgets/transportation_mode_chip.dart';

import '../domain/route_preview_entity.dart';

class RouteInformationCard extends StatelessWidget {
  const RouteInformationCard({
    super.key,
    required this.preview,
    required this.selected,
  });

  final RoutePreviewEntity preview;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final route = preview.routes.isEmpty ? null : preview.routes[selected];
    String pointName(RoutePreviewPoint value) {
      final name = l.locale.languageCode == 'ar'
          ? value.arabicName ?? value.name
          : value.name;
      return name ??
          l.digits(
            [
              value.point.latitude,
              value.point.longitude,
            ].map((coordinate) => coordinate.toStringAsFixed(5)).join(', '),
          );
    }

    final origin = preview.origin;
    final originLabel = origin == null
        ? switch (preview.startingLocationStatus) {
            EffectiveLocationStatus.consentRequired =>
              l.startingContextConsentRequired,
            EffectiveLocationStatus.excluded => l.startingContextExcluded,
            _ => l.startingLocationSetupRequired,
          }
        : pointName(origin);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            for (final (label, value) in [
              (l.meetupStartingPoint, originLabel),
              (l.routePreviewDestination, pointName(preview.destination)),
              (
                l.transportationTitle,
                TransportationModeChip.label(l, preview.mode),
              ),
              (
                l.routePreviewDistance,
                route == null
                    ? l.routePreviewNoEstimate
                    : l.routePreviewMeters(route.distanceMeters.round()),
              ),
              (
                l.routePreviewDuration,
                route == null
                    ? l.routePreviewNoEstimate
                    : l.routePreviewMinutes(
                        (route.durationSeconds / 60).ceil(),
                      ),
              ),
            ])
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.texts.titleSmall),
                  Text(value),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class RouteAlternativeSelector extends StatelessWidget {
  const RouteAlternativeSelector({
    super.key,
    required this.preview,
    required this.selected,
    required this.onSelected,
  });

  final RoutePreviewEntity preview;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (preview.capabilities?.supportsAlternatives != true ||
        preview.routes.length < 2) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var i = 0; i < preview.routes.length; i++)
          ChoiceChip(
            label: Text(
              i == 0 ? l.routePreviewPrimary : l.routePreviewAlternative(i),
            ),
            selected: selected == i,
            onSelected: (value) {
              if (value) onSelected(i);
            },
          ),
      ],
    );
  }
}

class RouteUnavailableWidget extends StatelessWidget {
  const RouteUnavailableWidget({super.key, required this.status});

  final RoutePreviewStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      child: Text(switch (status) {
        RoutePreviewStatus.unsupportedMode => l.routePreviewUnsupported,
        RoutePreviewStatus.startingLocationRequired =>
          l.startingLocationSetupRequired,
        RoutePreviewStatus.transportationRequired => l.routePreviewChooseMode,
        RoutePreviewStatus.noRoute => l.routePreviewNoRoute,
        _ => l.routePreviewUnavailable,
      }),
    );
  }
}

class ExternalNavigationAction extends StatelessWidget {
  const ExternalNavigationAction({super.key, required this.destination});

  final RoutePreviewPoint destination;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.open_in_new),
    label: Text(context.l10n.routePreviewExternal),
    onPressed: () async {
      final point = destination.point;
      final opened = await AppLauncher.openDirections(
        latitude: point.latitude,
        longitude: point.longitude,
        query: '',
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.couldNotOpenLink)));
      }
    },
  );
}
