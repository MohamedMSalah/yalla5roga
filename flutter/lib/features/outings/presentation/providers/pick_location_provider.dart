import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';

class PickedPlace {
  const PickedPlace({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  final double latitude;
  final double longitude;
  final String name;
}

enum LocationPrompt { skip, ask }

class PlaceSearchHit {
  const PlaceSearchHit({required this.name, required this.point});

  factory PlaceSearchHit.fromGeocoding(LocationHit hit) {
    return PlaceSearchHit(
      name: hit.name,
      point: LatLng(hit.latitude, hit.longitude),
    );
  }

  final String name;
  final LatLng point;
}

class PickLocationProvider extends ChangeNotifier {
  PickLocationProvider({
    required this.geocoding,
    required this.prefs,
    double? initialLatitude,
    double? initialLongitude,
    String? placeName,
  }) {
    pin = initialLatitude != null && initialLongitude != null
        ? LatLng(initialLatitude, initialLongitude)
        : null;
    nameController = TextEditingController(text: placeName ?? '');
    nameController.addListener(notifyListeners);
  }

  static const cairo = LatLng(30.0444, 31.2357);

  final LocationRepository geocoding;
  final SharedPreferences prefs;

  late final TextEditingController nameController;
  LatLng? pin;
  var lookingUp = false;
  var locating = false;
  var _disposed = false;
  var _lookupEpoch = 0;

  LatLng get center => pin ?? cairo;

  Future<LocationPrompt> firstOpenPrompt() async {
    if (prefs.getBool(AppConstants.locationPromptShownKey) ?? false) {
      return LocationPrompt.skip;
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await prefs.setBool(AppConstants.locationPromptShownKey, true);
      return LocationPrompt.skip;
    }
    return LocationPrompt.ask;
  }

  Future<void> markPromptShown() async {
    await prefs.setBool(AppConstants.locationPromptShownKey, true);
  }

  void _emit() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> dropPin(
    LatLng point, {
    String? name,
    String fallbackName = '',
  }) async {
    final token = ++_lookupEpoch;
    pin = point;
    lookingUp = name == null;
    _emit();
    if (name != null && name.trim().isNotEmpty) {
      nameController.text = name.trim();
      lookingUp = false;
      _emit();
      return;
    }
    final lookedUp = await lookupName(point);
    if (_disposed || token != _lookupEpoch) return;
    if (lookedUp != null && lookedUp.isNotEmpty) {
      nameController.text = lookedUp;
    } else if (nameController.text.trim().isEmpty) {
      nameController.text = fallbackName;
    }
    lookingUp = false;
    _emit();
  }

  Future<String?> lookupName(LatLng point) {
    return geocoding.reverseGeocode(
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  Future<String?> useCurrentLocation(L10n l10n) async {
    if (locating) return null;
    locating = true;
    _emit();
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return l10n.locationDisabled;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return l10n.locationPermissionDenied;
      }
      final position = await Geolocator.getCurrentPosition();
      if (_disposed) return null;
      await dropPin(
        LatLng(position.latitude, position.longitude),
        fallbackName: l10n.customPlace,
      );
      return null;
    } catch (_) {
      return l10n.couldNotGetLocation;
    } finally {
      locating = false;
      _emit();
    }
  }

  PickedPlace? confirm(L10n l10n) {
    final current = pin;
    if (current == null || lookingUp) return null;
    final name = nameController.text.trim().isEmpty
        ? l10n.customPlace
        : nameController.text.trim();
    return PickedPlace(
      latitude: current.latitude,
      longitude: current.longitude,
      name: name,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    nameController.removeListener(notifyListeners);
    nameController.dispose();
    super.dispose();
  }
}

class PlaceSearchProvider extends ChangeNotifier {
  PlaceSearchProvider(this.geocoding);

  final LocationRepository geocoding;
  final queryController = TextEditingController();
  var results = const <PlaceSearchHit>[];
  var searching = false;
  var searched = false;
  var _disposed = false;
  var _searchEpoch = 0;

  void _emit() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> search() async {
    final query = queryController.text.trim();
    if (query.isEmpty) return;
    final token = ++_searchEpoch;
    searching = true;
    searched = true;
    _emit();
    try {
      final hits = await geocoding.search(query);
      if (_disposed || token != _searchEpoch) return;
      results = [for (final hit in hits) PlaceSearchHit.fromGeocoding(hit)];
      searching = false;
      _emit();
    } catch (_) {
      if (_disposed || token != _searchEpoch) return;
      results = const [];
      searching = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    queryController.dispose();
    super.dispose();
  }
}
