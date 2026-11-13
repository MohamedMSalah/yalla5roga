import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Raw JSON snapshots let existing data sources use the same parsers offline.
class OfflineSnapshots {
  OfflineSnapshots(this._prefs, this.userId, this.origin);

  final SharedPreferences _prefs;
  final String? Function() userId;
  final String origin;
  int _generation = 0;
  static const _limit = 200;
  static final _cacheOnly = Object();

  static bool get cacheOnly => Zone.current[_cacheOnly] == true;

  static Future<T> preview<T>(Future<T> Function() load) =>
      runZoned(load, zoneValues: {_cacheOnly: true});

  String _prefix(String uid) => 'snapshots.v1:$origin:$uid:';

  static final _resource = RegExp(
    r'^/api/(groups/(cuser|[a-f0-9-]{36}(/members)?)|outings/(cuser|[a-f0-9-]{36}(/voting-state|/attendance|/vote-options|/guests)?))$',
  );

  String? keyFor(String path, Map<String, dynamic>? query) {
    final uid = userId();
    if (uid == null ||
        (query?.isNotEmpty ?? false) ||
        !_resource.hasMatch(path)) {
      return null;
    }
    return '${_prefix(uid)}$path';
  }

  int get generation => _generation;

  T? read<T>(String? key) {
    if (key == null) return null;
    try {
      final raw = _prefs.getString(key);
      if (raw != null) {
        final data = (jsonDecode(raw) as Map)['data'];
        if (data is T) return data;
      }
    } catch (_) {
      // A malformed snapshot is a cache miss.
    }
    return null;
  }

  Future<void> write(String key, Object? data, int generation) async {
    if (generation != _generation || data is! Map) return;
    final uid = userId();
    if (uid == null || !key.startsWith(_prefix(uid))) return;
    try {
      final encoded = jsonEncode({
        'at': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      });
      if (encoded.length > 512 * 1024) {
        await remove(key);
        return;
      }
      await _prefs.setString(key, encoded);
      if (generation != _generation) return;
      final keys = _prefs
          .getKeys()
          .where((k) => k.startsWith(_prefix(uid)))
          .toList();
      if (keys.length <= _limit) return;
      keys.sort((a, b) => _age(a).compareTo(_age(b)));
      await Future.wait(keys.take(keys.length - _limit).map(remove));
    } catch (_) {
      // A failed cache write must not hide the authoritative response.
    }
  }

  int _age(String key) {
    try {
      return (jsonDecode(_prefs.getString(key)!) as Map)['at'] as int;
    } catch (_) {
      return 0;
    }
  }

  Future<void> mergeCollectionItem(
    String path,
    Map<String, dynamic> item, {
    bool remove = false,
  }) async {
    final key = keyFor(path, null);
    if (key == null) return;
    final raw = read<Map<String, dynamic>>(key);
    if (raw == null || raw['data'] is! List) return;
    var found = false;
    final rows = <Map>[];
    for (final row in raw['data'] as List) {
      if (row is! Map) continue;
      if (row['id'] == item['id']) {
        found = true;
        if (!remove) rows.add(item);
      } else {
        rows.add(row);
      }
    }
    if (!found && !remove) rows.insert(0, item);
    await write(key, {...raw, 'data': rows}, generation);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  Future<void> removeResource(String key) async {
    final path = key.indexOf(':/api/');
    if (path == -1) return;
    final resource =
        key.substring(0, path + 1) +
        key.substring(path + 1).split('/').take(4).join('/');
    await Future.wait(
      _prefs
          .getKeys()
          .where((entry) => entry == resource || entry.startsWith('$resource/'))
          .map(remove),
    );
  }

  Future<void> clear(String uid) async {
    _generation++;
    await Future.wait(
      _prefs.getKeys().where((k) => k.startsWith(_prefix(uid))).map(remove),
    );
  }
}
