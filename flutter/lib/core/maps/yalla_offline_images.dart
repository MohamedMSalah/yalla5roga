import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/media/media_reference.dart';
import 'package:yalla_5roga/core/media/media_url_resolver.dart';
import 'package:yalla_5roga/core/media/media_url_store.dart';

/// User-downloaded photos are stored outside the ordinary image eviction cache.
class YallaOfflineImages {
  static final instance = YallaOfflineImages();
  static const perRegionBytes = 25 * 1024 * 1024;
  static const maxBytes = 100 * 1024 * 1024;
  static const _manifest = 'map.offline.photos.v1';
  final _packs = <String, Map<String, int>>{};
  final _finished = <String>{};
  final _known = <String, int>{};
  Directory? _directory;
  SharedPreferences? _prefs;
  int _uncommitted = 0;
  int _totalBytes = 0;

  Future<void> initialize(SharedPreferences prefs) async {
    if (_directory != null) return;
    final root = await getApplicationSupportDirectory();
    final directory = await Directory.fromUri(
      root.uri.resolve('offline-place-images/'),
    ).create(recursive: true);
    _prefs = prefs;
    try {
      final manifest = jsonDecode(prefs.getString(_manifest) ?? '{}') as Map;
      for (final entry in manifest.entries) {
        final value = entry.value as Map;
        _packs[entry.key as String] = (value['files'] as Map)
            .cast<String, int>();
        if (value['complete'] == true) _finished.add(entry.key as String);
      }
    } on Object {
      _packs.clear();
      _finished.clear();
    }
    _rebuildIndex();
    _directory = directory;
    await for (final file in directory.list()) {
      if (file is File && !_known.containsKey(file.uri.pathSegments.last)) {
        await file.delete();
      }
    }
  }

  bool get available => _directory != null;

  bool finished(String pack) => _finished.contains(pack);
  int bytes(String pack) =>
      _packs[pack]?.values.fold<int>(0, (a, b) => a + b) ?? 0;
  int get storageBytes => _totalBytes;
  int count(String pack) => _packs[pack]?.length ?? 0;

  String _key(String reference) =>
      sha256.convert(utf8.encode(reference)).toString();

  String? pathFor(String reference) {
    if (_known.isEmpty) return null;
    final directory = _directory;
    if (directory == null) return null;
    final key = _key(reference);
    if (!_known.containsKey(key)) return null;
    return File.fromUri(directory.uri.resolve(key)).path;
  }

  Future<void> pin(String pack, String reference) async {
    final directory = _directory;
    if (reference.isEmpty) return;
    if (directory == null) {
      throw StateError('Offline image storage unavailable');
    }
    final key = _key(reference.trim());
    final files = _packs.putIfAbsent(pack, () => {});
    if (files.containsKey(key)) return;

    final file = File.fromUri(directory.uri.resolve(key));
    var size = _known[key];
    if (size != null && !await file.exists()) size = null;
    if (size == null) {
      var url = reference.trim();
      String? cacheKey;
      if (parseMediaId(reference) case final id?) {
        final resolver = MediaUrlResolver.active;
        final entry = await resolver?.resolve(id);
        if (entry == null) throw StateError('Place image unavailable');
        if (entry.visibility != MediaVisibility.public) return;
        url = entry.url;
        cacheKey = resolver!.cacheKeyFor(id, entry.visibility);
      }
      final uri = Uri.tryParse(url);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
      final cache = DefaultCacheManager();
      final existing = await cache.getFileFromCache(cacheKey ?? url);
      final source =
          existing?.file ?? await cache.getSingleFile(url, key: cacheKey);
      size = await source.length();
      if (storageBytes + size > maxBytes ||
          bytes(pack) + size > perRegionBytes) {
        throw StateError('Offline image limit exceeded');
      }
      final temp = await source.copy('${file.path}.tmp');
      await temp.rename(file.path);
    } else if (bytes(pack) + size > perRegionBytes) {
      throw StateError('Offline image limit exceeded');
    }
    files[key] = size;
    _totalBytes += size - (_known[key] ?? 0);
    _known[key] = size;
    if (++_uncommitted >= 16) await flush();
  }

  Future<void> flush() async {
    if (_uncommitted > 0) await _save();
  }

  Future<void> markFinished(String pack) async {
    _packs.putIfAbsent(pack, () => {});
    _finished.add(pack);
    try {
      await _save();
    } catch (_) {
      _finished.remove(pack);
      rethrow;
    }
  }

  Future<void> remove(String pack) async {
    final files = _packs.remove(pack);
    _finished.remove(pack);
    _rebuildIndex();
    await _save();
    final directory = _directory;
    if (directory == null || files == null) return;
    for (final key in files.keys.where((key) => !_known.containsKey(key))) {
      final file = File.fromUri(directory.uri.resolve(key));
      if (await file.exists()) await file.delete();
    }
  }

  void _rebuildIndex() {
    _known.clear();
    for (final files in _packs.values) {
      _known.addAll(files);
    }
    _totalBytes = _known.values.fold(0, (a, b) => a + b);
  }

  Future<void> _save() async {
    final saved = await _prefs?.setString(
      _manifest,
      jsonEncode({
        for (final entry in _packs.entries)
          entry.key: {
            'files': entry.value,
            'complete': _finished.contains(entry.key),
          },
      }),
    );
    if (saved != true) throw StateError('Offline image manifest unavailable');
    _uncommitted = 0;
  }
}
