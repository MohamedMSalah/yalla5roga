import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

void main() {
  testWidgets('outings move to history at their scheduled start', (
    tester,
  ) async {
    var now = DateTime.parse('2026-11-10T10:00:00Z');
    final repository = _ScheduleRepository([
      _outing('earlier-today', at: '2026-11-10T11:00:00+02:00'),
      _outing('next', at: '2026-11-10T12:01:00+02:00'),
      _outing('later', at: '2026-11-10T10:02:00Z'),
      _outing('unscheduled', status: OutingStatus.draft),
      _outing('cancelled', status: OutingStatus.cancelled),
      _outing('completed', status: OutingStatus.past),
    ]);
    final provider = OutingsProvider(repository: repository, now: () => now);
    addTearDown(provider.dispose);
    await provider.load();

    final initialUpcoming = ['next', 'later', 'unscheduled'];
    expect(provider.upcoming.map((outing) => outing.id), initialUpcoming);
    expect(
      provider.history.map((outing) => outing.id),
      unorderedEquals(['earlier-today', 'cancelled', 'completed']),
    );

    var updates = 0;
    provider.addListener(() => updates++);
    const almostAMinute = Duration(seconds: 59);
    now = now.add(almostAMinute);
    await tester.pump(almostAMinute);
    expect(updates, 0);
    expect(provider.upcoming.map((outing) => outing.id), initialUpcoming);

    const oneSecond = Duration(seconds: 1);
    now = now.add(oneSecond);
    await tester.pump(oneSecond);
    expect(updates, 1);
    expect(provider.upcoming.map((outing) => outing.id), [
      'later',
      'unscheduled',
    ]);
    expect(provider.history.first.id, 'next');
    expect(provider.history.first.status, OutingStatus.confirmed);

    const oneMinute = Duration(minutes: 1);
    now = now.add(oneMinute);
    await tester.pump(oneMinute);
    expect(updates, 2);
    expect(provider.upcoming.map((outing) => outing.id), ['unscheduled']);
    expect(provider.history.first.id, 'later');
    expect(repository.loads, 1);
  });
}

Outing _outing(
  String id, {
  String? at,
  OutingStatus status = OutingStatus.confirmed,
}) => Outing(
  id: id,
  image: '',
  title: id,
  meta: '',
  date: '',
  scheduledAt: at == null ? null : DateTime.parse(at),
  status: status,
);

class _ScheduleRepository implements OutingsRepository {
  _ScheduleRepository(this.outings);

  final List<Outing> outings;
  var loads = 0;

  @override
  Future<Either<Failure, OutingSnapshot>> load({
    bool forceRefresh = false,
  }) async {
    loads++;
    return Right(
      OutingSnapshot(
        outings: outings,
        suggestions: [],
        votesByOuting: {},
        attendanceByOuting: {},
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
