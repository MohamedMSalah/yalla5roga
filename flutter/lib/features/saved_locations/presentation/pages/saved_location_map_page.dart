import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';
import 'package:yalla_5roga/core/maps/yalla_map_controller.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/yalla_map_view.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

import '../providers/saved_locations_provider.dart';

class SavedLocationMapPage extends StatefulWidget {
  const SavedLocationMapPage({super.key, this.initial, required this.session});

  final LatLng? initial;
  final int session;

  @override
  State<SavedLocationMapPage> createState() => _SavedLocationMapPageState();
}

class _SavedLocationMapPageState extends State<SavedLocationMapPage> {
  final _controller = YallaMapController();
  late LatLng? _point = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final point = _point;
    final validAccount = context.watch<SavedLocationsProvider>().matchesSession(
      widget.session,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.startingPickOnMap)),
      body: SafeArea(
        child: validAccount
            ? Column(
                children: [
                  Expanded(
                    child: YallaMapView(
                      controller: _controller,
                      center: widget.initial ?? cairoMapCenter,
                      zoom: widget.initial == null ? 12 : 16,
                      onTap: (point) => setState(() => _point = point),
                      selection: YallaMapPlaceSelection(
                        mode: YallaMapSelectionMode.single,
                        selected: [
                          if (point != null)
                            Place(
                              name: l.startingPointSelected,
                              area: '',
                              latitude: point.latitude,
                              longitude: point.longitude,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: Responsive.pagePadding(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListenableBuilder(
                          listenable: _controller,
                          builder: (context, _) => Text(
                            _controller.failed
                                ? l.offlineMapsUnavailable
                                : l.startingTapMap,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomButton(
                          label: l.selectMapLocation,
                          onPressed: point == null
                              ? null
                              : () => Navigator.of(context).pop(point),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : AppEmptyState(message: l.dataLoadFailed),
      ),
    );
  }
}
