import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';

abstract class SavedOutingsLocalDataSource {
  Future<List<SavedOuting>> getSaved();
  Future<List<OutingDraft>> getDrafts();
  Future<List<SavedOuting>> saveOuting(SavedOuting outing);
  Future<List<SavedOuting>> removeSaved(String id);
  Future<List<OutingDraft>> saveDraft(OutingDraft draft);
  Future<List<OutingDraft>> removeDraft(String id);
  Future<bool> isSaved(String id);
}

class SavedOutingsLocalDataSourceImpl implements SavedOutingsLocalDataSource {
  SavedOutingsLocalDataSourceImpl(
    this._prefs, {
    this.userId,
    this.origin = '',
  }) {
    _load();
  }

  final SharedPreferences _prefs;
  final String? Function()? userId;
  final String origin;
  String get _draftKey => userId == null
      ? AppConstants.outingDraftsKey
      : '${AppConstants.outingDraftsKey}:$origin:${userId!() ?? "signed-out"}';
  var _saved = <SavedOuting>[];
  var _drafts = <OutingDraft>[];

  void _load() {
    final savedRaw = _prefs.getString(AppConstants.savedOutingsKey);
    if (savedRaw != null) {
      final decoded = jsonDecode(savedRaw);
      if (decoded is List) {
        _saved = [
          for (final item in decoded)
            if (item is Map)
              SavedOuting.fromJson(Map<String, dynamic>.from(item)),
        ];
      }
    }
    _drafts = [];
    final draftRaw = _prefs.getString(_draftKey);
    if (draftRaw != null) {
      final decoded = jsonDecode(draftRaw);
      if (decoded is List) {
        _drafts = [
          for (final item in decoded)
            if (item is Map)
              OutingDraft.fromJson(Map<String, dynamic>.from(item)),
        ];
      }
    }
  }

  Future<void> _persistSaved() {
    return _prefs.setString(
      AppConstants.savedOutingsKey,
      jsonEncode([for (final item in _saved) item.toJson()]),
    );
  }

  Future<void> _persistDrafts() {
    return _prefs.setString(
      _draftKey,
      jsonEncode([for (final item in _drafts) item.toJson()]),
    );
  }

  @override
  Future<List<SavedOuting>> getSaved() async => List.unmodifiable(_saved);

  @override
  Future<List<OutingDraft>> getDrafts() async {
    _load();
    return List.unmodifiable(_drafts);
  }

  @override
  Future<List<SavedOuting>> saveOuting(SavedOuting outing) async {
    _saved = [outing, ..._saved.where((item) => item.id != outing.id)];
    await _persistSaved();
    return getSaved();
  }

  @override
  Future<List<SavedOuting>> removeSaved(String id) async {
    _saved = [
      for (final item in _saved)
        if (item.id != id) item,
    ];
    await _persistSaved();
    return getSaved();
  }

  @override
  Future<List<OutingDraft>> saveDraft(OutingDraft draft) async {
    _load();
    _drafts = [draft, ..._drafts.where((item) => item.id != draft.id)];
    await _persistDrafts();
    return getDrafts();
  }

  @override
  Future<List<OutingDraft>> removeDraft(String id) async {
    _load();
    _drafts = [
      for (final item in _drafts)
        if (item.id != id) item,
    ];
    await _persistDrafts();
    return getDrafts();
  }

  @override
  Future<bool> isSaved(String id) async => _saved.any((item) => item.id == id);
}
