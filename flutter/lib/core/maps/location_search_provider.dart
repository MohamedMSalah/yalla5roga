import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/maps/location_repository.dart';

/// Debounced, cancellable search over the existing geocoding repository.
class LocationSearchProvider extends ChangeNotifier {
  LocationSearchProvider(this.repository, {required this.language});
  final LocationRepository repository;
  final String language;
  Timer? _timer;
  Completer<void>? _request;
  bool busy = false, failed = false;
  String? attribution;
  List<LocationHit> hits = const [];

  void search(String input) {
    _timer?.cancel();
    _request?.complete();
    _request = null;
    hits = const [];
    failed = false;
    final query = input.trim();
    busy = query.length >= 2 && query.length <= 120;
    if (busy) {
      final request = _request = Completer<void>();
      _timer = Timer(const Duration(milliseconds: 350), () async {
        try {
          final result = await repository.search(
            query,
            language: language,
            cancelled: request.future,
          );
          if (_request != request) return;
          hits = result.hits;
          attribution = result.attribution;
          failed = !result.available;
        } catch (_) {
          if (_request == request) failed = true;
        } finally {
          if (_request == request) {
            _request = null;
            busy = false;
            notifyListeners();
          }
        }
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _request?.complete();
    _request = null;
    super.dispose();
  }
}
