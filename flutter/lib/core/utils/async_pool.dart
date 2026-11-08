/// Runs [items] through [mapper] with at most [concurrency] in flight.
Future<List<R>> mapPool<T, R>(
  Iterable<T> items,
  Future<R> Function(T item) mapper, {
  int concurrency = 4,
}) async {
  final list = items.toList(growable: false);
  if (list.isEmpty) return const [];
  final limit = concurrency < 1 ? 1 : concurrency;
  final results = List<R?>.filled(list.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next;
      next++;
      if (index >= list.length) return;
      results[index] = await mapper(list[index]);
    }
  }

  await Future.wait([
    for (var i = 0; i < limit && i < list.length; i++) worker(),
  ]);

  return [
    for (final item in results) item as R,
  ];
}
