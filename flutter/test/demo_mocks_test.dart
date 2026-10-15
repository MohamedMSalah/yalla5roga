import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/mock/mock_data.dart';
import 'package:yalla_5roga/core/mock/mock_repositories.dart';

void main() {
  test('demo Mockito stubs read and update MockData', () async {
    final mocks = createDemoMocks();
    expect(identical(mocks, createDemoMocks()), isTrue);

    final login = await mocks.auth.login(
      email: 'sara.hassan@gmail.com',
      password: 'secret',
    );
    expect(login, isA<Right>());
    expect(mocks.auth.hasFirebaseSession, isTrue);

    final groups = await mocks.groups.getGroups();
    expect(groups.getOrElse(() => const []), isNotEmpty);

    final places = await mocks.discover.getPlaces();
    expect(places.getOrElse(() => const []), isNotEmpty);

    final hits = await mocks.location.search('cairo');
    expect(hits, isA<List>());

    await mocks.auth.logout();
    expect(mocks.auth.hasFirebaseSession, isFalse);
    MockData.sessionActive = true;
  });
}
