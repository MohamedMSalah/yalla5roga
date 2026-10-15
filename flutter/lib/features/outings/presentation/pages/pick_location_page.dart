import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/app_permissions.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/pick_location_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_chat_skeleton.dart';

export 'package:yalla_5roga/features/outings/presentation/providers/pick_location_provider.dart'
    show PickedPlace;

class PickLocationPage extends StatelessWidget {
  const PickLocationPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.placeName,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? placeName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PickLocationProvider(
        geocoding: context.read<LocationRepository>(),
        prefs: context.read<SharedPreferences>(),
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        placeName: placeName,
      ),
      child: const _PickLocationView(),
    );
  }
}

class _PickLocationView extends StatefulWidget {
  const _PickLocationView();

  @override
  State<_PickLocationView> createState() => _PickLocationViewState();
}

class _PickLocationViewState extends State<_PickLocationView> {
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askLocationOnFirstOpen();
    });
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _moveTo(LatLng point, {double zoom = 16}) {
    try {
      _map.move(point, zoom);
    } catch (_) {}
  }

  Future<void> _askLocationOnFirstOpen() async {
    final map = context.read<PickLocationProvider>();
    final prompt = await map.firstOpenPrompt();
    if (prompt == LocationPrompt.skip || !mounted) return;
    final l10n = context.l10n;
    final result = await AppPermissions.promptLocationAccess(l10n);
    await map.markPromptShown();
    if (!mounted || result != AppPermissionResult.granted) return;
    await _useCurrentLocation();
  }

  Future<void> _dropPin(LatLng point, {String? name}) async {
    final map = context.read<PickLocationProvider>();
    _moveTo(point);
    await map.dropPin(
      point,
      name: name,
      fallbackName: context.l10n.customPlace,
    );
  }

  Future<void> _useCurrentLocation() async {
    final map = context.read<PickLocationProvider>();
    final l10n = context.l10n;
    final permission = await AppPermissions.ensureLocation(l10n);
    if (!mounted) return;
    if (permission != AppPermissionResult.granted) return;

    final error = await map.useCurrentLocation(l10n);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.show(error);
      return;
    }
    final pin = map.pin;
    if (pin != null) _moveTo(pin);
  }

  Future<void> _openSearch() async {
    final hit = await Get.bottomSheet<PlaceSearchHit>(
      ChangeNotifierProvider(
        create: (_) => PlaceSearchProvider(context.read<LocationRepository>()),
        child: const _PlaceSearchSheet(),
      ),
      isScrollControlled: true,
    );
    if (hit == null || !mounted) return;
    await _dropPin(hit.point, name: hit.name);
  }

  void _confirm() {
    final result = context.read<PickLocationProvider>().confirm(context.l10n);
    if (result == null) return;
    Get.back(result: result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final map = context.watch<PickLocationProvider>();
    final pin = map.pin;
    final center = map.center;

    return Scaffold(
      // AppPageBar — pick location + search
      appBar: AppPageBar(
        title: l10n.pickLocation,
        subtitle: map.nameController.text.trim().isEmpty
            ? null
            : map.nameController.text.trim(),
        trailingIcon: Icons.search,
        onTrailingTap: _openSearch,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: pin == null ? 12 : 15,
                    onTap: (_, point) => _dropPin(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.yalla_5roga',
                    ),
                    if (pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pin,
                            width: 40,
                            height: 40,
                            alignment: Alignment.bottomCenter,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.brand600,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 16.w,
                  bottom: 16.h,
                  child: Column(
                    children: [
                      AppIconButton(
                        icon: Icons.search,
                        background: Colors.white,
                        onTap: _openSearch,
                      ),
                      8.gapH,
                      AppIconButton(
                        icon: Icons.my_location,
                        background: AppColors.brand600,
                        foreground: Colors.white,
                        isLoading: map.locating,
                        onTap: _useCurrentLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: Responsive.padding(horizontal: 20, top: 12, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomTextField(
                    controller: map.nameController,
                    label: l10n.chooseLocation,
                    hint: l10n.customPlace,
                    prefixIcon: Icons.place_outlined,
                  ),
                  Responsive.spaceSm.gapH,
                  Text(
                    map.lookingUp ? l10n.lookingUpLocation : l10n.tapToPin,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: Responsive.fontSm,
                    ),
                  ),
                  Responsive.spaceSm.gapH,
                  CustomButton(
                    label: l10n.confirmLocation,
                    icon: Icons.check,
                    isLoading: map.lookingUp,
                    onPressed: pin == null || map.lookingUp ? null : _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSearchSheet extends StatelessWidget {
  const _PlaceSearchSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final search = context.watch<PlaceSearchProvider>();

    return SafeArea(
      child: Container(
        height: Responsive.height * 0.7,
        padding: Responsive.padding(all: 20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.searchPlace,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: Responsive.fontMd,
              ),
            ),
            Responsive.spaceMd.gapH,
            CustomTextField(
              controller: search.queryController,
              label: l10n.searchPlace,
              hint: l10n.searchPlaceHint,
              prefixIcon: Icons.search,
              textInputAction: TextInputAction.search,
            ),
            Responsive.spaceSm.gapH,
            CustomButton(
              label: l10n.searchPlace,
              icon: Icons.search,
              isLoading: search.searching,
              onPressed: search.searching ? null : search.search,
            ),
            Responsive.spaceMd.gapH,
            Expanded(
              child: search.searching
                  ? const PlaceSearchSkeleton()
                  : !search.searched
                  ? const SizedBox.shrink()
                  : search.results.isEmpty
                  ? AppEmptyState(
                      icon: Icons.search_off_outlined,
                      message: l10n.noPlaceResults,
                      subtitle: l10n.noPlaceResultsHint,
                      compact: true,
                    )
                  : ListView.builder(
                      itemCount: search.results.length,
                      itemBuilder: (context, index) {
                        final hit = search.results[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == search.results.length - 1
                                ? 0
                                : 8.h,
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.place_outlined,
                              color: AppColors.brand600,
                            ),
                            title: Text(
                              hit.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => Get.back(result: hit),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
