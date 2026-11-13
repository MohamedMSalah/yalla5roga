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
  int _epoch = 0;
  Future<void>? _syncingDrafts;
  bool get hasPendingDrafts => _drafts.any((d) => d.pending);
  bool get hasDraftConflicts => _drafts.any((d) => d.conflict);
  Future<void> syncDrafts() => _syncingDrafts ??= _loadDrafts().whenComplete(
    () => _syncingDrafts = null,
  );
  Future<void> _loadDrafts() async {
    final epoch = _epoch;
    final result = await repository.getDrafts();
    if (epoch != _epoch) return;
    result.fold((_) {}, (items) => _drafts = List.of(items));
    notifyListeners();
  }

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
    final epoch = _epoch;
    final savedFuture = repository.getSaved();
    final draftFuture = repository.getDrafts();
    final savedResult = await savedFuture;
    final draftResult = await draftFuture;
    if (epoch != _epoch) return;
    savedResult.fold((_) {}, (items) => _saved = List.of(items));
    draftResult.fold((_) {}, (items) => _drafts = List.of(items));
    _hasLoaded = true;
    notifyListeners();
  }

  void removeDeletedOuting(String outingId) {
    final before = _saved.length;
    _saved.removeWhere((outing) => outing.id == outingId);
    if (_saved.length != before) notifyListeners();
  }

  void clear() {
    _epoch++;
    _syncingDrafts = null;
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

  /// Toggles bookmark state.
  ///
  /// Returns `true` when the outing was saved, `false` when it was removed,
  /// and `null` when the repository call failed (state unchanged).
  Future<bool?> toggle(Outing event) async {
    if (isSaved(event.id)) {
      final result = await repository.removeSaved(event.id);
      return result.fold((_) => null, (items) {
        _saved = List.of(items);
        notifyListeners();
        return false;
      });
    }
    final result = await repository.saveOuting(SavedOuting.fromEvent(event));
    return result.fold((_) => null, (items) {
      _saved = List.of(items);
      notifyListeners();
      return true;
    });
  }

  Future<void> removeSaved(String id) async {
    final result = await repository.removeSaved(id);
    result.fold((_) {}, (items) => _saved = List.of(items));
    notifyListeners();
  }

  Future<void> saveDraft(OutingDraft draft) async {
    final epoch = _epoch;
    final result = await repository.saveDraft(draft);
    if (epoch != _epoch) return;
    result.fold((_) {}, (items) => _drafts = List.of(items));
    notifyListeners();
  }

  Future<void> removeDraft(String id) async {
    final epoch = _epoch;
    final result = await repository.removeDraft(id);
    if (epoch != _epoch) return;
    result.fold((_) {}, (items) => _drafts = List.of(items));
    notifyListeners();
  }

  Future<void> remove(SavedItem item) {
    return item.isDraft ? removeDraft(item.id) : removeSaved(item.id);
  }
}
