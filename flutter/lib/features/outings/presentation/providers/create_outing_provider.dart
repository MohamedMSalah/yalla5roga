import 'dart:async';
import 'dart:math';

import 'package:yalla_5roga/features/outings/domain/entities/voting_deadline.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class CreateOutingProvider extends ChangeNotifier {
  CreateOutingProvider({
    required this._groups,
    required this._contacts,
    required this._catalogPlaces,
    required this._specialEventImage,
    this.placeCatalog,
    Group? group,
    SuggestedPlace? suggestedPlace,
    this.saved,
    this.draft,
    bool specialEvent = false,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _group = group,
       _groupLocked =
           group != null && !specialEvent && !(draft?.specialEvent ?? false),
       _specialEvent =
           specialEvent ||
           (draft?.specialEvent ?? false) ||
           (saved?.occasion ?? OutingOccasion.none) != OutingOccasion.none,
       _draftId = draft?.id ?? _newDraftId() {
    _deadlineNow = _now();
    if (draft == null) _date = _now().add(const Duration(days: 1));
    nameController = TextEditingController(
      text: saved?.title ?? draft?.title ?? '',
    );
    nameController.addListener(notifyListeners);
    if (_specialEvent) _occasion = OutingOccasion.birthday;
    if (suggestedPlace != null) {
      final place = suggestedPlace.toOutingPlace();
      _vibe = place.vibe.index;
      _selectedPlaces = List.unmodifiable([place]);
    }
    if (saved != null) {
      nameController.text = saved!.title;
      if (saved!.occasion != OutingOccasion.none) {
        _occasion = saved!.occasion;
      }
      _applyLocation(saved!.location);
    }
    if (draft != null) {
      nameController.text = draft!.title;
      _vibe = draft!.vibe;
      _time = draft!.time;
      _date = draft!.date;
      _occasion = draft!.occasion == OutingOccasion.none && _specialEvent
          ? OutingOccasion.birthday
          : draft!.occasion;
      _guestIds.addAll(draft!.guestIds);
      _guestPhones.addAll(draft!.guestPhones);
      if (draft!.groupId != null) {
        _group = _groups.cast<Group?>().firstWhere(
          (item) => item?.id == draft!.groupId,
          orElse: () => group,
        );
      }
      _applyLocation(draft!.location);
      _voteDeadlineHours = draft!.voteDeadlineHours ?? 3;
      if (!_specialEvent &&
          draft!.letVote &&
          draft!.selectedPlaces.isNotEmpty) {
        _selectedPlaces = _normalizeSelection(draft!.selectedPlaces);
      }
    }
    _date = clampDate(_date);
    _deadlineUnit =
        _voteDeadlineHours % 24 == 0 &&
            VotingDeadlinePolicy.dayPresets.contains(_voteDeadlineHours ~/ 24)
        ? VotingDeadlineUnit.days
        : VotingDeadlineUnit.hours;
    markDraftSaved();
    _deadlineTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshDeadlineClock(),
    );
  }

  static String _newDraftId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  final DateTime Function() _now;
  late DateTime _deadlineNow;
  Timer? _deadlineTimer;
  VotingDeadlineUnit _deadlineUnit = VotingDeadlineUnit.hours;
  final List<Group> _groups;
  final List<GroupMember> _contacts;
  final List<Place> _catalogPlaces;
  final PlaceCatalogProvider? placeCatalog;
  final String Function(OutingOccasion) _specialEventImage;
  final SavedOuting? saved;
  final OutingDraft? draft;
  final bool _specialEvent;
  final bool _groupLocked;
  final String _draftId;
  final _guestIds = <String>{};
  final _guestPhones = <String>{};

  late final TextEditingController nameController;

  int _step = 0;
  int _vibe = 0;
  int _voteDeadlineHours = 3;
  Group? _group;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 11, minute: 30);
  List<Place> _selectedPlaces = const [];
  late String _savedState;

  String get _draftState => toDraft().toJson().toString();
  bool get hasUnsavedChanges => _savedState != _draftState;
  void markDraftSaved() => _savedState = _draftState;
  OutingOccasion _occasion = OutingOccasion.none;
  Locale _locale = const Locale('en');

  int get step => _step;

  int get vibe => _vibe;

  int get voteDeadlineHours => _voteDeadlineHours;

  VotingDeadlineUnit get deadlineUnit => _deadlineUnit;
  DateTime get scheduledAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
  DateTime get previewVotingDeadline =>
      VotingDeadlinePolicy.endsAt(_deadlineNow, _voteDeadlineHours);
  bool get isVotingDeadlineValid => _deadlineProblem(_deadlineNow) == null;

  // The existing API validates deadline metadata for fixed venues as well.
  // Use the shortest supported group duration and the established event default.
  int get _fixedLocationDeadlineHours =>
      _specialEvent ? 3 : VotingDeadlinePolicy.hourPresets.first;
  int get _submittedDeadlineHours =>
      multiPlaceMode ? _voteDeadlineHours : _fixedLocationDeadlineHours;

  VotingDeadlineProblem? _deadlineProblem(DateTime now, [int? hours]) =>
      VotingDeadlinePolicy.validate(
        now: now,
        hours: hours ?? _voteDeadlineHours,
        scheduledAt: scheduledAt,
      );

  bool canSelectDeadlineHours(int hours) =>
      _deadlineProblem(_deadlineNow, hours) == null;

  String? votingDeadlineError(L10n l10n) =>
      _deadlineMessage(_deadlineProblem(_deadlineNow), l10n);

  String? validateVotingDeadlineNow(L10n l10n) =>
      _deadlineMessage(_deadlineProblem(_now()), l10n);

  String? _deadlineMessage(VotingDeadlineProblem? problem, L10n l10n) =>
      switch (problem) {
        null => null,
        VotingDeadlineProblem.unsupportedDuration =>
          l10n.votingDeadlineDurationInvalid,
        VotingDeadlineProblem.notFuture => l10n.votingDeadlineMustBeFuture,
        VotingDeadlineProblem.afterOutingStart =>
          l10n.votingDeadlineBeforeOuting,
      };

  void refreshDeadlineClock() {
    _deadlineNow = _now();
    if (_step == 1) notifyListeners();
  }

  void setDeadlineUnit(VotingDeadlineUnit unit) {
    if (_deadlineUnit == unit) return;
    _deadlineUnit = unit;
    _deadlineNow = _now();
    final hours = unit == VotingDeadlineUnit.hours
        ? VotingDeadlinePolicy.hourPresets
        : [for (final days in VotingDeadlinePolicy.dayPresets) days * 24];
    if (!hours.contains(_voteDeadlineHours) ||
        !canSelectDeadlineHours(_voteDeadlineHours)) {
      _voteDeadlineHours =
          hours.where(canSelectDeadlineHours).firstOrNull ?? hours.first;
    }
    notifyListeners();
  }

  Group? get group => _group;

  DateTime get date => _date;

  TimeOfDay get time => _time;

  List<Place> get selectedPlaces => _selectedPlaces;

  LatLng? _distanceOrigin;
  LatLng? get distanceOrigin => _distanceOrigin;

  void setDistanceOrigin(LatLng? point) {
    _distanceOrigin = point;
    notifyListeners();
  }

  double? placeDistanceKm(Place place) {
    final origin = _distanceOrigin;
    if (origin == null || !place.hasCoordinates) return null;
    return const Distance(roundResult: false).as(
      LengthUnit.Kilometer,
      origin,
      LatLng(place.latitude!, place.longitude!),
    );
  }

  List<Place> get catalogPlaces => List.unmodifiable(_catalogPlaces);

  OutingOccasion get occasion => _occasion;

  bool get specialEvent => _specialEvent;

  bool get groupLocked => _groupLocked;

  Set<String> get guestIds => _guestIds;
  Set<String> get guestPhones => Set.unmodifiable(_guestPhones);

  List<Group> get groups => List.unmodifiable(_groups);

  List<GroupMember> get contacts => List.unmodifiable(_contacts);

  bool get allGuestsSelected => _guestIds.length == contacts.length;

  bool get multiPlaceMode => _selectedPlaces.length > 1;
  int get maxSelections => _specialEvent ? 1 : OutingsProvider.maxVotePlaces;

  DateTime get minDate {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get maxDate {
    final now = _now();
    if (_specialEvent) {
      return DateTime(now.year + 1, now.month, now.day);
    }
    return DateTime(now.year, now.month + 1, now.day);
  }

  String get resolvedImage {
    if (_selectedPlaces.firstOrNull case final place?) return place.imageUrl;
    if (_specialEvent) return _specialEventImage(_occasion);
    return '';
  }

  PlaceLocation? get selectedLocation =>
      _selectedPlaces.firstOrNull?.toLocation();

  String get locationLabel =>
      _selectedPlaces.map((place) => place.name).join(' · ');

  String get formattedDate => L10n(_locale).formatDate(_date);

  String get shortDate {
    final l10n = L10n(_locale);
    final text = DateFormat.MMMd(_locale.languageCode).format(_date);
    return l10n.digits(
      _locale.languageCode == 'ar' ? text : text.toUpperCase(),
    );
  }

  String get formattedTime {
    final value = DateTime(0, 1, 1, _time.hour, _time.minute);
    return L10n(_locale).formatTime(value);
  }

  List<String> get guestNames => [
    for (final id in _guestIds)
      if (_memberById(id) != null) _memberById(id)!.name,
  ];

  GroupMember? _memberById(String id) {
    for (final person in _contacts) {
      if (person.id == id) return person;
    }
    return null;
  }

  DateTime clampDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(minDate)) return minDate;
    if (day.isAfter(maxDate)) return maxDate;
    return day;
  }

  void applySuggestionTitle(L10n l10n) {
    _locale = l10n.locale;
  }

  void syncLocale(L10n l10n) {
    _locale = l10n.locale;
  }

  void _applyLocation(PlaceLocation location) {
    final id = location.placeId;
    final match = _catalogPlaces.where(
      (item) => id != null
          ? item.id == id
          : item.name == location.name &&
                (location.area.isEmpty || item.area == location.area),
    );
    if (match.isNotEmpty && (id != null || !location.hasCoordinates)) {
      _selectedPlaces = List.unmodifiable([match.first]);
      return;
    }
    if (location.name.trim().isEmpty && id == null) return;
    _selectedPlaces = List.unmodifiable([
      Place(
        id: id ?? '',
        name: location.name,
        area: location.area,
        address: location.address,
        categoryId: location.categoryId,
        latitude: location.latitude,
        longitude: location.longitude,
        vibe: OutingVibe.values[_vibe.clamp(0, OutingVibe.values.length - 1)],
      ),
    ]);
  }

  void back() {
    if (_step == 0) return;
    _step -= 1;
    notifyListeners();
  }

  String? validateLocation(L10n l10n) {
    if (_selectedPlaces.isEmpty) return l10n.locationRequired;
    if (_selectedPlaces.any((place) => !_eligible(place))) {
      return l10n.pickLocationRequired;
    }
    return null;
  }

  static bool _eligible(Place place) =>
      place.name.trim().isNotEmpty &&
      place.status != 'permanently_closed' &&
      ((place.id.isNotEmpty && !place.id.startsWith('private:')) ||
          place.hasCoordinates);

  String? scheduleError(L10n l10n) {
    if (!scheduledAt.isAfter(_now()) || date.isAfter(maxDate)) {
      return l10n.creationFutureStart;
    }
    if (!multiPlaceMode &&
        _deadlineProblem(_now(), _fixedLocationDeadlineHours) != null) {
      return l10n.creationFixedStartLeadTime(_fixedLocationDeadlineHours);
    }
    return null;
  }

  String? audienceError(L10n l10n) {
    if (_specialEvent) {
      if (_group == null && _guestIds.isEmpty && _guestPhones.isEmpty) {
        return l10n.guestsRequired;
      }
    } else if (_group == null) {
      return l10n.groupRequired;
    }
    return null;
  }

  String? validateDetails(L10n l10n) =>
      Validators.outingName(nameController.text, l10n) ??
      scheduleError(l10n) ??
      audienceError(l10n) ??
      (multiPlaceMode ? validateVotingDeadlineNow(l10n) : null);

  String? next(L10n l10n) {
    if (_step != 0) return null;
    final error = validateLocation(l10n);
    if (error != null) return error;
    _step = 1;
    _deadlineNow = _now();
    notifyListeners();
    return null;
  }

  String? draftError(L10n l10n) =>
      Validators.outingName(nameController.text, l10n) ??
      validateLocation(l10n);

  void setOccasion(OutingOccasion value) {
    _occasion = value;
    notifyListeners();
  }

  void setVoteDeadlineHours(int hours) {
    _voteDeadlineHours = hours;
    _deadlineNow = _now();
    notifyListeners();
  }

  bool canAddPlace(Place place) =>
      _selectedPlaces.length < maxSelections &&
      _eligible(place) &&
      !_selectedPlaces.any(place.matchesSelection);

  void addPlace(Place place) {
    if (canAddPlace(place)) replaceMapSelection([..._selectedPlaces, place]);
  }

  void removePlace(Place place) => replaceMapSelection(
    _selectedPlaces.where((item) => !place.matchesSelection(item)).toList(),
  );

  List<Place> _normalizeSelection(Iterable<Place> places) {
    final ordered = <Place>[];
    for (final place in places) {
      if (ordered.length == maxSelections) break;
      if (!ordered.any(place.matchesSelection)) ordered.add(place);
    }
    return List.unmodifiable(ordered);
  }

  void replaceMapSelection(List<Place> places) {
    _selectedPlaces = _normalizeSelection(places);
    notifyListeners();
  }

  void setGroup(Group? value) {
    if (_groupLocked) return;
    _group = value;
    notifyListeners();
  }

  void setDate(DateTime value) {
    _date = clampDate(value);
    _deadlineNow = _now();
    notifyListeners();
  }

  void setTime(TimeOfDay value) {
    _time = value;
    _deadlineNow = _now();
    notifyListeners();
  }

  void toggleGuest(String id) {
    if (!_guestIds.add(id)) _guestIds.remove(id);
    notifyListeners();
  }

  void toggleSelectAll() {
    if (allGuestsSelected) {
      _guestIds.clear();
    } else {
      _guestIds
        ..clear()
        ..addAll(contacts.map((person) => person.id));
    }
    notifyListeners();
  }

  void setGuests(Iterable<String> ids, {Iterable<String> phones = const []}) {
    _guestPhones
      ..clear()
      ..addAll(phones);
    _guestIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  OutingDraft toDraft() {
    return OutingDraft(
      id: _draftId,
      remoteVersion: draft?.remoteVersion,
      title: nameController.text.trim(),
      image: resolvedImage,
      location: selectedLocation ?? PlaceLocation(name: locationLabel),
      date: _date,
      hour: _time.hour,
      minute: _time.minute,
      vibe: _selectedPlaces.firstOrNull?.vibe.index ?? _vibe,
      groupId: _group?.id,
      occasion: _occasion,
      specialEvent: _specialEvent,
      guestIds: _guestIds.toList(),
      guestPhones: _guestPhones.toList(),
      letVote: multiPlaceMode,
      voteDeadlineHours: _voteDeadlineHours,
      selectedPlaces: _voteOptions,
    );
  }

  List<Place> get _voteOptions => [
    if (multiPlaceMode)
      for (final place in _selectedPlaces)
        place.id.startsWith('private:') ? place.copyWith(id: '') : place,
  ];

  Outing buildOuting({String? createdById}) {
    final guests = [
      for (final id in _guestIds)
        if (_memberById(id) != null) id,
    ];
    final voting = multiPlaceMode;
    final places = _voteOptions;
    return Outing(
      id: 'outing-${DateTime.now().millisecondsSinceEpoch}',
      image: resolvedImage,
      title: nameController.text.trim(),
      meta: voting
          ? '${places.length} places · vote open'
          : '$locationLabel · $formattedTime',
      date: formattedDate,
      time: formattedTime,
      going: _specialEvent
          ? guests.length + _guestPhones.length + (_group?.memberCount ?? 0)
          : _group!.memberCount,
      groupId: _group?.id,
      type: _specialEvent ? OutingType.specialEvent : OutingType.group,
      location: voting ? null : selectedLocation,
      occasion: _occasion,
      guestIds: guests,
      guestPhones: _specialEvent ? _guestPhones.toList() : const [],
      createRequestKey: _draftId,
      status: voting
          ? OutingStatus.voting
          : selectedLocation != null
          ? OutingStatus.confirmed
          : OutingStatus.draft,
      votePlaces: places,
      // Backend create requires a deadline even when voting UI is off.
      voteDeadlineHours: _submittedDeadlineHours,
      createdById: createdById,
      scheduledAt: scheduledAt,
    );
  }

  @override
  void dispose() {
    placeCatalog?.dispose();
    _deadlineTimer?.cancel();
    nameController.dispose();
    super.dispose();
  }
}
