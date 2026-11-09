import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/cards/featured_outing_card.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);
  Outing outing(String id, DateTime? date, [OutingStatus status = OutingStatus.confirmed]) =>
      Outing(id: id, image: '', title: id, meta: '', date: '', scheduledAt: date, status: status);

  test('chooses the earliest future plan regardless of input order', () {
    final later = outing('later', now.add(const Duration(days: 3)));
    final next = outing('next', now.add(const Duration(days: 1)), OutingStatus.voting);
    expect(nextHomeOuting([later, next], now), same(next));
  });

  test('ignores undated, elapsed, past and cancelled plans', () {
    expect(nextHomeOuting([
      outing('undated', null),
      outing('elapsed', now.subtract(const Duration(minutes: 1))),
      outing('past', now.add(const Duration(hours: 1)), OutingStatus.past),
      outing('cancelled', now.add(const Duration(hours: 2)), OutingStatus.cancelled),
    ], now), isNull);
  });
}
