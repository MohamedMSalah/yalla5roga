import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

import '../../domain/entities/default_starting_location.dart';
import '../../domain/entities/saved_location.dart';
import '../../domain/usecases/saved_location_usecases.dart';

class SavedLocationsProvider extends ChangeNotifier {
  SavedLocationsProvider(this._locations, this._account);

  final SavedLocationUseCases _locations;
  String? _account;
  int _session = 0;
  int _readRevision = 0;
  int get session => _session;
  bool get hasAccount => _account != null;
  Future<void>? _read;
  bool _refreshAfterWrite = false;

  List<SavedLocation> locations = const [];
  DefaultStartingLocation? defaultLocation;
  String? _startingLocationId;

  /// An explicit personal point for this session, falling back to the default.
  DefaultStartingLocation? get startingLocation {
    final selected = locations
        .where((location) => location.id == _startingLocationId)
        .firstOrNull;
    return selected == null
        ? defaultLocation
        : DefaultStartingLocation.personal(selected);
  }

  bool useAsStartingLocation(StartingLocationSource source, String id) {
    if (!hasAccount) return false;
    if (source == StartingLocationSource.savedLocation) {
      if (!locations.any((location) => location.id == id)) return false;
      _startingLocationId = id;
    } else {
      if (!(defaultLocation?.matches(source, id) ?? false)) return false;
      _startingLocationId = null;
    }
    notifyListeners();
    return true;
  }

  bool isLoading = false;
  bool hasLoaded = false;
  bool isSaving = false;
  Failure? readFailure;
  Failure? writeFailure;

  void bindAccount(String? account) {
    if (_account == account) return;
    _account = account;
    _session++;
    _cancelRead();
    _refreshAfterWrite = false;
    locations = const [];
    defaultLocation = null;
    _startingLocationId = null;
    hasLoaded = false;
    isSaving = false;
    readFailure = null;
    writeFailure = null;
    notifyListeners();
  }

  bool matchesSession(int session) => _session == session && hasAccount;

  @override
  void dispose() {
    _session++;
    _cancelRead();
    super.dispose();
  }

  void _cancelRead() {
    _readRevision++;
    _read = null;
    isLoading = false;
  }

  Future<void> refresh() {
    if (!hasAccount || isSaving) return Future.value();
    final revision = _readRevision;
    return _read ??= _load(revision).whenComplete(() {
      if (_readRevision == revision) _read = null;
    });
  }

  Future<void> _load(int revision) async {
    isLoading = true;
    notifyListeners();
    final locationsRequest = _locations.list();
    final defaultRequest = _locations.getDefault();
    final list = await locationsRequest;
    final selection = await defaultRequest;
    if (revision != _readRevision) return;
    isLoading = false;
    final failure =
        list.fold<Failure?>((failure) => failure, (_) => null) ??
        selection.fold<Failure?>((failure) => failure, (_) => null);
    readFailure = failure;
    if (failure == null) {
      locations = list.getOrElse(() => const []);
      defaultLocation = selection.getOrElse(() => null);
      if (!locations.any((location) => location.id == _startingLocationId)) {
        _startingLocationId = null;
      }
      hasLoaded = true;
    } else if (failure is AuthFailure || failure.statusCode == 403) {
      locations = const [];
      defaultLocation = null;
      _startingLocationId = null;
      hasLoaded = false;
    }
    notifyListeners();
  }

  Future<bool> _write<T>(
    Future<Either<Failure, T>> Function() request,
    void Function(T) apply,
  ) async {
    if (!hasAccount || isSaving) return false;
    final session = _session;
    _cancelRead();
    isSaving = true;
    writeFailure = null;
    notifyListeners();
    final result = await request();
    if (!matchesSession(session)) return false;
    result.fold((failure) => writeFailure = failure, apply);
    isSaving = false;
    final refresh =
        _refreshAfterWrite ||
        (result.isRight() && !hasLoaded) ||
        writeFailure?.statusCode == 404 ||
        writeFailure?.statusCode == 409;
    _refreshAfterWrite = false;
    notifyListeners();
    if (refresh) unawaited(this.refresh());
    return result.isRight();
  }

  Future<Either<Failure, SavedLocation>> get(String id) => _locations.get(id);

  Future<SavedLocation?> save(SavedLocationDraft draft, {String? id}) async {
    SavedLocation? committed;
    await _write(() => _locations.save(draft, id: id), (saved) {
      committed = saved;
      final exists = locations.any((location) => location.id == saved.id);
      locations = List.unmodifiable(
        exists
            ? locations.map(
                (location) => location.id == saved.id ? saved : location,
              )
            : [saved, ...locations],
      );
      if (defaultLocation?.matches(
            StartingLocationSource.savedLocation,
            saved.id,
          ) ??
          false) {
        defaultLocation = DefaultStartingLocation.personal(saved);
      }
    });
    return committed;
  }

  Future<bool> delete(String id) => _write(() => _locations.delete(id), (_) {
    locations = List.unmodifiable(
      locations.where((location) => location.id != id),
    );
    if (_startingLocationId == id) _startingLocationId = null;
    if (defaultLocation?.matches(StartingLocationSource.savedLocation, id) ??
        false) {
      defaultLocation = null;
    }
  });

  Future<bool> setDefault(StartingLocationSource source, String id) => _write(
    () => _locations.setDefault(source, id),
    (selected) => defaultLocation = selected,
  );

  Future<bool> updateDefaultBookmarkTransportation(
    TransportationMode? mode,
  ) async {
    final selected = defaultLocation;
    if (selected == null ||
        selected.source != StartingLocationSource.savedPlace ||
        selected.preferredTransportationMode == mode) {
      return false;
    }
    return _write(
      () => _locations.updateBookmarkTransportation(selected.referenceId, mode),
      (savedMode) {
        final current = defaultLocation;
        if (current != null &&
            current.matches(selected.source, selected.referenceId)) {
          defaultLocation = current.withTransportation(savedMode);
        }
      },
    );
  }

  Future<bool> clearDefault() =>
      _write(_locations.clearDefault, (_) => defaultLocation = null);

  void savedPlaceRemoved(String id) {
    if (!hasAccount || (!hasLoaded && !isLoading && !isSaving)) return;
    if (defaultLocation?.matches(StartingLocationSource.savedPlace, id) ??
        false) {
      defaultLocation = null;
    }
    if (isSaving) {
      _refreshAfterWrite = true;
      notifyListeners();
      return;
    }
    _cancelRead();
    unawaited(refresh());
  }
}
