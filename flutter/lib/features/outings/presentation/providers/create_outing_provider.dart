import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
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
    Group? group,
    SuggestedPlace? suggestedPlace,
    this.saved,
    this.draft,
    bool specialEvent = false,
    bool letVote = false,
  }) : _group = group,
       _groupLocked = group != null,
       _specialEvent =
           specialEvent ||
           (draft?.specialEvent ?? false) ||
           (saved?.occasion ?? OutingOccasion.none) != OutingOccasion.none,
       _draftId =
           draft?.id ??
           'draft-${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}' {
    nameController = TextEditingController(
      text: saved?.title ?? draft?.title ?? '',
    );
    customPlaceController = TextEditingController();
    customPlaceController.addListener(_onCustomPlaceChanged);
    if (_specialEvent) _occasion = OutingOccasion.birthday;
    // Multi-place voting is group-outing only (suggest + create share one form).
    _letVote = !_specialEvent && letVote;
    if (suggestedPlace != null) {
      final place = suggestedPlace.toOutingPlace();
      _vibe = suggestedPlace.vibe.index;
      _image = suggestedPlace.coverImageUrl;
      if (_letVote) {
        _selectedPlaces.add(place);
      } else {
        _place = place;
      }
    }
    if (saved != null) {
      nameController.text = saved!.title;
      _image = saved!.image;
      if (saved!.occasion != OutingOccasion.none) {
        _occasion = saved!.occasion;
      }
      _applyLocation(saved!.location);
    }
    if (draft != null) {
      nameController.text = draft!.title;
      _image = draft!.image;
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
      if (draft!.letVote) {
        _letVote = true;
        _selectedPlaces
          ..clear()
          ..addAll(draft!.selectedPlaces);
        _voteDeadlineHours = draft!.voteDeadlineHours ?? 3;
      }
    }
    _date = clampDate(_date);
  }

  final List<Group> _groups;
  final List<GroupMember> _contacts;
  final List<Place> _catalogPlaces;
  final String Function(OutingOccasion) _specialEventImage;
  final SavedOuting? saved;
  final OutingDraft? draft;
  final bool _specialEvent;
  final bool _groupLocked;
  final String _draftId;
  final _guestIds = <String>{};
  final _guestPhones = <String>{};

  late final TextEditingController nameController;
  late final TextEditingController customPlaceController;

  int _step = 0;
  int _vibe = 0;
  bool _letVote = false;
  int _voteDeadlineHours = 3;
  String? _image;
  Group? _group;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 11, minute: 30);
  Place? _place;
  final _selectedPlaces = <Place>[];
  String _customArea = '';
  double? _customLatitude;
  double? _customLongitude;
  OutingOccasion _occasion = OutingOccasion.none;
  Locale _locale = const Locale('en');

  int get step => _step;

  int get vibe => _vibe;

  bool get letVote => _letVote;

  int get voteDeadlineHours => _voteDeadlineHours;

  String? get image => _image;

  Group? get group => _group;

  DateTime get date => _date;

  TimeOfDay get time => _time;

  Place? get place => _place;

  List<Place> get selectedPlaces => List.unmodifiable(_selectedPlaces);

  List<Place> get catalogPlaces => List.unmodifiable(_catalogPlaces);

  /// Places matching the selected vibe (all places for special events).
  List<Place> get suggestedPlaces {
    if (_specialEvent) return catalogPlaces;
    final selectedVibe =
        OutingVibe.values[_vibe.clamp(0, OutingVibe.values.length - 1)];
    return [
      for (final place in _catalogPlaces)
        if (place.vibe == selectedVibe) place,
    ];
  }

  double? get customLatitude => _customLatitude;

  double? get customLongitude => _customLongitude;

  OutingOccasion get occasion => _occasion;

  bool get specialEvent => _specialEvent;

  bool get groupLocked => _groupLocked;

  Set<String> get guestIds => _guestIds;
  Set<String> get guestPhones => Set.unmodifiable(_guestPhones);

  List<Group> get groups => List.unmodifiable(_groups);

  List<GroupMember> get contacts => List.unmodifiable(_contacts);

  bool get allGuestsSelected => _guestIds.length == contacts.length;

  bool get multiPlaceMode => !_specialEvent && _letVote;

  DateTime get minDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get maxDate {
    final now = DateTime.now();
    if (_specialEvent) {
      return DateTime(now.year + 1, now.month, now.day);
    }
    return DateTime(now.year, now.month + 1, now.day);
  }

  String get resolvedImage {
    if (_image != null && _image!.isNotEmpty) return _image!;
    if (_specialEvent) return _specialEventImage(_occasion);
    return '';
  }

  bool get isCustomPlace => customPlaceController.text.trim().isNotEmpty;

  bool get customPlacePinned =>
      _customLatitude != null && _customLongitude != null;

  PlaceLocation? get selectedLocation {
    if (multiPlaceMode) {
      return _selectedPlaces.firstOrNull?.toLocation();
    }
    if (isCustomPlace) {
      return PlaceLocation(
        name: customPlaceController.text.trim(),
        area: _customArea,
        latitude: _customLatitude,
        longitude: _customLongitude,
      );
    }
    return _place?.toLocation();
  }

  String get locationLabel {
    if (multiPlaceMode && _selectedPlaces.isNotEmpty) {
      return _selectedPlaces.map((place) => place.name).join(' · ');
    }
    if (customPlaceController.text.trim().isNotEmpty) {
      return customPlaceController.text.trim();
    }
    if (_place != null) return '${_place!.name}, ${_place!.area}';
    return '';
  }

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
    if (match.isNotEmpty) {
      _place = match.first;
      return;
    }
    if (id != null) {
      _place = Place(
        id: id,
        name: location.name,
        area: location.area,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      return;
    }
    customPlaceController.text = location.name;
    _customArea = location.area;
    _customLatitude = location.latitude;
    _customLongitude = location.longitude;
  }

  void _onCustomPlaceChanged() {
    if (isCustomPlace && _place != null) {
      _place = null;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  void back() {
    if (_step == 0) return;
    _step -= 1;
    notifyListeners();
  }

  String? validateStep(L10n l10n) {
    if (_step == 0) {
      final nameError = Validators.outingName(nameController.text, l10n);
      if (nameError != null) return nameError;
      // Cover photo is optional until a remote upload pipeline exists.
      if (_specialEvent) {
        if (_guestIds.isEmpty && _guestPhones.isEmpty) {
          return l10n.guestsRequired;
        }
      } else if (_group == null) {
        return l10n.groupRequired;
      }
    }
    if (_step == 1) {
      if (multiPlaceMode) {
        if (_selectedPlaces.length < 2) return l10n.pickAtLeastTwoPlaces;
        if (_selectedPlaces.length > OutingsProvider.maxVotePlaces) {
          return l10n.pickAtMostFivePlaces;
        }
      } else {
        if (locationLabel.isEmpty) return l10n.locationRequired;
        if (isCustomPlace && !customPlacePinned) {
          return l10n.pickLocationRequired;
        }
      }
    }
    return null;
  }

  String? next(L10n l10n) {
    final error = validateStep(l10n);
    if (error != null) return error;
    _step += 1;
    notifyListeners();
    return null;
  }

  String? draftError(L10n l10n) {
    final nameError = Validators.outingName(nameController.text, l10n);
    if (nameError != null) return nameError;
    if (multiPlaceMode) {
      if (_selectedPlaces.length < 2) return l10n.pickAtLeastTwoPlaces;
      if (_selectedPlaces.length > OutingsProvider.maxVotePlaces) {
        return l10n.pickAtMostFivePlaces;
      }
    } else if (locationLabel.isEmpty) {
      return l10n.locationRequired;
    }
    return null;
  }

  void setImage(String path) {
    _image = path;
    notifyListeners();
  }

  void setVibe(int value) {
    _vibe = value;
    final selectedVibe =
        OutingVibe.values[_vibe.clamp(0, OutingVibe.values.length - 1)];
    _selectedPlaces.removeWhere((place) => place.vibe != selectedVibe);
    if (_place != null && _place!.vibe != selectedVibe) {
      _place = null;
    }
    notifyListeners();
  }

  void setOccasion(OutingOccasion value) {
    _occasion = value;
    notifyListeners();
  }

  void setLetVote(bool value) {
    if (_specialEvent || _letVote == value) return;
    if (value && _selectedPlaces.isEmpty) {
      if (_place case final place?) {
        _selectedPlaces.add(place);
      } else if (customPlacePinned && isCustomPlace) {
        _selectedPlaces.add(
          mapInitialPlace!.copyWith(
            vibe:
                OutingVibe.values[_vibe.clamp(0, OutingVibe.values.length - 1)],
          ),
        );
      }
    }
    _letVote = value;
    notifyListeners();
  }

  void toggleLetVote() => setLetVote(!_letVote);

  void setVoteDeadlineHours(int hours) {
    _voteDeadlineHours = hours.clamp(1, 72);
    notifyListeners();
  }

  bool isPlaceSelected(Place place) =>
      _selectedPlaces.any(place.matchesSelection);

  Place? get mapInitialPlace {
    if (_place != null) return _place;
    final location = selectedLocation;
    if (location == null) return null;
    return Place(
      name: location.name,
      area: location.area,
      latitude: location.latitude,
      longitude: location.longitude,
      vibe: OutingVibe.values[_vibe.clamp(0, OutingVibe.values.length - 1)],
    );
  }

  void replaceMapSelection(List<Place> places) {
    if (!multiPlaceMode) {
      if (places.length == 1) applyPickedPlace(places.single);
      return;
    }
    final ordered = <Place>[];
    for (final place in places.take(OutingsProvider.maxVotePlaces)) {
      if (ordered.any(place.matchesSelection)) continue;
      ordered.add(
        place.id.isNotEmpty
            ? place
            : place.copyWith(
                vibe: OutingVibe
                    .values[_vibe.clamp(0, OutingVibe.values.length - 1)],
              ),
      );
    }
    _selectedPlaces
      ..clear()
      ..addAll(ordered);
    notifyListeners();
  }

  bool get canAddMorePlaces =>
      multiPlaceMode && _selectedPlaces.length < OutingsProvider.maxVotePlaces;

  void addSelectedPlace(Place place) {
    if (!multiPlaceMode) {
      setCatalogPlace(place);
      return;
    }
    if (isPlaceSelected(place)) return;
    if (_selectedPlaces.length >= OutingsProvider.maxVotePlaces) return;
    _selectedPlaces.add(place);
    notifyListeners();
  }

  void removeSelectedPlace(Place place) {
    _selectedPlaces.removeWhere((item) => item.matchesSelection(place));
    notifyListeners();
  }

  void togglePlace(Place place) {
    if (!multiPlaceMode) {
      setCatalogPlace(place);
      return;
    }
    if (isPlaceSelected(place)) {
      removeSelectedPlace(place);
    } else {
      addSelectedPlace(place);
    }
  }

  void setGroup(Group value) {
    if (_groupLocked) return;
    _group = value;
    notifyListeners();
  }

  void setDate(DateTime value) {
    _date = clampDate(value);
    notifyListeners();
  }

  void setTime(TimeOfDay value) {
    _time = value;
    notifyListeners();
  }

  void setCatalogPlace(Place value) {
    if (multiPlaceMode) {
      togglePlace(value);
      return;
    }
    _place = value;
    _customArea = '';
    _customLatitude = null;
    _customLongitude = null;
    customPlaceController.clear();
    notifyListeners();
  }

  void applyPickedPlace(Place picked) {
    if (picked.id.isNotEmpty) {
      setCatalogPlace(picked);
      return;
    }
    _place = null;
    _customArea = picked.area;
    _customLatitude = picked.latitude;
    _customLongitude = picked.longitude;
    customPlaceController.text = picked.name;
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
      title: nameController.text.trim(),
      image: resolvedImage,
      location: selectedLocation ?? PlaceLocation(name: locationLabel),
      date: _date,
      hour: _time.hour,
      minute: _time.minute,
      vibe: _vibe,
      groupId: _group?.id,
      occasion: _occasion,
      specialEvent: _specialEvent,
      guestIds: _guestIds.toList(),
      guestPhones: _guestPhones.toList(),
      letVote: _letVote,
      voteDeadlineHours: _letVote ? _voteDeadlineHours : null,
      selectedPlaces: multiPlaceMode ? List.of(_selectedPlaces) : const [],
    );
  }

  Outing buildOuting({String? createdById}) {
    final guests = [
      for (final id in _guestIds)
        if (_memberById(id) != null) id,
    ];
    final voting = !_specialEvent && _letVote;
    final places = voting ? List<Place>.of(_selectedPlaces) : const <Place>[];
    final scheduled = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
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
          ? guests.length + _guestPhones.length
          : _group!.memberCount,
      groupId: _specialEvent ? null : _group!.id,
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
      voteDeadlineHours: _voteDeadlineHours,
      createdById: createdById,
      scheduledAt: scheduled,
    );
  }

  @override
  void dispose() {
    customPlaceController.removeListener(_onCustomPlaceChanged);
    nameController.dispose();
    customPlaceController.dispose();
    super.dispose();
  }
}
