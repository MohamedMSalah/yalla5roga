import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/saved_outings_repository.dart';

export 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';

class SavedOutingsProvider extends ChangeNotifier {
  SavedOutingsProvider({required this.repository});

  final SavedOutingsRepository repository;

  var _saved = <SavedOuting>[];
  var _drafts = <OutingDraft>[];
  int _tab = 0;
  var _hasLoaded = false;

  List<SavedOuting> get saved => List.unmodifiable(_saved);

  List<OutingDraft> get drafts => List.unmodifiable(_drafts);

  List<SavedItem> get items => [
    for (final draft in _drafts) SavedItem.draft(draft),
    for (final outing in _saved) SavedItem.bookmark(outing),
  ];

  List<SavedItem> get visible => showingDrafts
      ? [for (final draft in _drafts) SavedItem.draft(draft)]
      : items;

  int get totalCount => _saved.length + _drafts.length;

  int get tab => _tab;

  bool get showingDrafts => _tab == 1;

  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    final savedResult = await repository.getSaved();
    savedResult.fold((_) {}, (items) => _saved = List.of(items));
    final draftResult = await repository.getDrafts();
    draftResult.fold((_) {}, (items) => _drafts = List.of(items));
    _hasLoaded = true;
    notifyListeners();
  }

  void clear() {
    _saved = [];
    _drafts = [];
    _tab = 0;
    _hasLoaded = false;
    notifyListeners();
  }

  void setTab(int value) {
    if (_tab == value) return;
    _tab = value;
    notifyListeners();
  }

  bool isSaved(String id) => _saved.any((outing) => outing.id == id);

  Future<bool> toggle(Outing event) async {
    if (isSaved(event.id)) {
      final result = await repository.removeSaved(event.id);
      result.fold((_) {}, (items) => _saved = List.of(items));
      notifyListeners();
      return false;
    }
    final result = await repository.saveOuting(SavedOuting.fromEvent(event));
    result.fold((_) {}, (items) => _saved = List.of(items));
    notifyListeners();
    return true;
  }

  Future<void> removeSaved(String id) async {
    final result = await repository.removeSaved(id);
    result.fold((_) {}, (items) => _saved = List.of(items));
    notifyListeners();
  }

  Future<void> saveDraft(OutingDraft draft) async {
    final result = await repository.saveDraft(draft);
    result.fold((_) {}, (items) => _drafts = List.of(items));
    notifyListeners();
  }

  Future<void> removeDraft(String id) async {
    final result = await repository.removeDraft(id);
    result.fold((_) {}, (items) => _drafts = List.of(items));
    notifyListeners();
  }

  Future<void> remove(SavedItem item) {
    return item.isDraft ? removeDraft(item.id) : removeSaved(item.id);
  }
}
