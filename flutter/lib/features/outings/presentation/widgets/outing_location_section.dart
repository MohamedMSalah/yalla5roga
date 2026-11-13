import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/widgets/place_card.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class OutingLocationSection extends StatelessWidget {
  const OutingLocationSection({super.key, required this.outing});
  final Outing outing;
  @override
  Widget build(BuildContext context) {
    final options = context.watch<OutingsProvider>().optionsFor(outing.id);
    final location = outing.location;
    if (location == null && options.length != 1) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlaceCard(
          title: location?.name ?? options.single.label,
          subtitle: location?.area ?? options.single.area,
          cover: PlanningCover(
            url: outing.image,
            art: PlanningCoverArt.outing,
            width: double.infinity,
            height: 180.h,
          ),
          onTap: () async {
            if (location == null) return;
            final ok = await AppLauncher.openMaps(
              latitude: location.latitude,
              longitude: location.longitude,
              query: location.label,
            );
            if (!ok && context.mounted) {
              AppSnackBar.show(context.l10n.couldNotOpenLink);
            }
          },
        ),
        if (location != null) ...[
          Responsive.spaceSm.gapH,
          OutingLocationButton(event: outing),
        ],
      ],
    );
  }
}

class OutingLocationButton extends StatefulWidget {
  const OutingLocationButton({super.key, required this.event});

  final Outing event;

  @override
  State<OutingLocationButton> createState() => OutingLocationButtonState();
}

class OutingLocationButtonState extends State<OutingLocationButton> {
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
