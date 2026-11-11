import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:yalla_5roga/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/group_bio_card.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  const l10n = L10n(Locale('en'));

  testWidgets('member can read the bio without an edit action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [L10n.delegate],
        home: Scaffold(body: GroupBioCard(bio: 'Existing bio')),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Existing bio'), findsOneWidget);
    expect(find.text(l10n.editGroupBio), findsNothing);
  });

  testWidgets(
    'bio editor keeps the draft after failure and can clear the bio',
    (tester) async {
      final bio = ValueNotifier('Existing bio');
      addTearDown(bio.dispose);
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [L10n.delegate],
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: bio,
              builder: (_, value, _) => GroupBioCard(
                bio: value,
                onSave: (value) async {
                  submitted.add(value);
                  if (submitted.length == 1) return false;
                  bio.value = value;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.editGroupBio));
      await tester.pumpAndSettle();
      expect(find.text('Existing bio'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  New bio  ');
      await tester.tap(find.text(l10n.saveChanges));
      await tester.pumpAndSettle();
      expect(submitted, ['New bio']);
      expect(find.text('  New bio  '), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text(l10n.saveChanges));
      await tester.pumpAndSettle();
      expect(submitted, ['New bio', '']);
      expect(find.text(l10n.noGroupBio), findsOneWidget);
    },
  );

  test(
    'bio PATCH leaves owner and member information in the provider',
    () async {
      final dio = Dio();
      final shell = ShellProvider();
      addTearDown(dio.close);
      addTearDown(shell.dispose);
      final updates = <Object?>[];
      var canAccess = true;
      const id = 'group-1';
      const cover = 'https://example.test/cover.png';
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (!canAccess) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  response: Response(requestOptions: request, statusCode: 403),
                  type: DioExceptionType.badResponse,
                ),
              );
              return;
            }
            const group = {'id': id, 'name': 'Friends', 'image_url': cover};
            if (request.method == 'PATCH') updates.add(request.data);
            final data = switch (request.path) {
              '/api/groups/group-1/members' => [
                {'user_id': 'me', 'name': 'Owner', 'role': 'owner'},
                {'user_id': 'other', 'name': 'Friend', 'role': 'member'},
              ],
              '/api/groups/group-1' => {
                ...group,
                'bio': request.method == 'PATCH' ? '' : 'Original bio',
              },
              _ => throw StateError('Unexpected route'),
            };
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: request,
                statusCode: 200,
                data: {'success': true, 'data': data},
              ),
            );
          },
        ),
      );
      final groups = GroupsProvider(
        shell: shell,
        repository: GroupsRepositoryImpl(
          remote: GroupsRemoteDataSource(ApiClient(dio)),
          networkInfo: _Online(),
          currentUserId: () => 'me',
        ),
      );
      addTearDown(groups.dispose);

      final initial = await groups.ensureGroupLoaded(id);
      expect(initial?.isOwner, isTrue);
      expect(await groups.updateBio(id, '  '), isTrue);
      final updated = groups.findById(id)!;
      expect(updates, [
        {'bio': ''},
      ]);
      expect(updated.bio, isEmpty);
      expect(updated.image, cover);
      expect(updated.members, initial!.members);
      expect(updated.isOwner, isTrue);

      canAccess = false;
      expect(await groups.ensureGroupLoaded(id), isNotNull);
      expect(
        await groups.ensureGroupLoaded(
          id,
          forceRefresh: true,
          allowStale: false,
        ),
        isNull,
      );
    },
  );
}
