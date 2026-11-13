import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/media/media_url_store.dart';

void main() {
  const accountA = 'user-a';
  const accountB = 'user-b';
  const assetId = '0f8fad5b-d9cb-469f-a165-70867728950e';

  late SharedPreferences prefs;
  late MediaUrlStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = MediaUrlStore(prefs);
  });

  test('persists and reloads URLs per account', () async {
    final entry = MediaUrlEntry(
      url: 'https://signed.example.com/a.jpg',
      visibility: MediaVisibility.private,
      expiresAt: DateTime.utc(2026, 11, 12, 12),
    );
    await store.putAll(accountA, {assetId: entry});

    final reloaded = MediaUrlStore(prefs);
    final entries = await reloaded.entriesFor(accountA);
    expect(entries[assetId]?.url, entry.url);
    expect(entries[assetId]?.visibility, MediaVisibility.private);
    expect(entries[assetId]?.expiresAt, entry.expiresAt);
    expect(reloaded.peek(accountA, assetId)?.url, entry.url);
  });

  test('accounts are isolated and clearing one keeps the other', () async {
    final privateEntry = MediaUrlEntry(
      url: 'https://signed.example.com/a.jpg',
      visibility: MediaVisibility.private,
    );
    final otherEntry = MediaUrlEntry(
      url: 'https://signed.example.com/b.jpg',
      visibility: MediaVisibility.private,
    );
    await store.putAll(accountA, {assetId: privateEntry});
    await store.putAll(accountB, {assetId: otherEntry});

    expect(store.peek(accountA, assetId)?.url, privateEntry.url);
    expect(store.peek(accountB, assetId)?.url, otherEntry.url);

    final removed = await store.clearAccount(accountA);
    expect(removed.single.key, assetId);
    expect(store.peek(accountA, assetId), isNull);
    expect(store.peek(accountB, assetId)?.url, otherEntry.url);

    final reloaded = MediaUrlStore(prefs);
    expect(await reloaded.entriesFor(accountA), isEmpty);
    expect((await reloaded.entriesFor(accountB))[assetId]?.url, otherEntry.url);
  });

  test('expired entries are reported stale near the signing window', () {
    final now = DateTime.utc(2026, 11, 12, 12);
    final storeWithClock = MediaUrlStore(prefs, clock: () => now);
    final fresh = MediaUrlEntry(
      url: 'https://signed.example.com/a.jpg',
      visibility: MediaVisibility.private,
      expiresAt: now.add(const Duration(minutes: 5)),
    );
    final stale = MediaUrlEntry(
      url: 'https://signed.example.com/b.jpg',
      visibility: MediaVisibility.private,
      expiresAt: now.add(const Duration(seconds: 5)),
    );
    expect(fresh.isExpired(storeWithClock.now()), isFalse);
    expect(stale.isExpired(storeWithClock.now()), isTrue);
  });

  test('public URLs never expire', () {
    final entry = MediaUrlEntry(
      url: 'https://cdn.example.com/places/a.jpg',
      visibility: MediaVisibility.public,
    );
    expect(entry.isExpired(DateTime.utc(2030)), isFalse);
  });
}
