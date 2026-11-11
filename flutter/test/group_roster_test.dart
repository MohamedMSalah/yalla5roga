import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/group_member_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_members_section.dart';

void main() {
  const phone = '+201001234567';
  const active = GroupMember(id: 'member-id', name: 'Member', avatar: '');
  const pending = GroupMember(
    id: 'association-id',
    name: '',
    avatar: '',
    phone: phone,
    isPending: true,
  );

  test('roster keeps pending entries out of the active count and uses their revoke route', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final deleted = <String>[];
    var isPending = true;
    var registered = false;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.method == 'DELETE') {
            deleted.add(request.path);
            isPending = false;
          }
          final body = request.path.endsWith('/members')
              ? {
                  'data': [
                    {'user_id': 'owner-id', 'name': 'Owner', 'role': 'owner'},
                    if (registered)
                      {
                        'user_id': 'member-id',
                        'name': 'Member',
                        'phone': phone,
                      },
                  ],
                  'pending_members': [
                    if (isPending)
                      {
                        'invitation_id': pending.id,
                        'phone': phone,
                        'status': 'pending',
                      },
                  ],
                }
              : {
                  'data': {'id': 'g', 'name': 'Friends', 'my_role': 'owner'},
                };
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: body),
          );
        },
      ),
    );
    final remote = GroupsRemoteDataSource(ApiClient(dio));
    final initial = await remote.getGroup('g');
    expect(initial.memberCount, 1);
    expect(initial.pendingMembers.single.isPending, isTrue);
    expect(initial.pendingMembers.single.phone, phone);
    registered = true;
    isPending = false;
    final refreshed = await remote.getGroup('g');
    expect(refreshed.pendingMembers, isEmpty);
    expect(refreshed.memberCount, 2);
    expect(refreshed.members.last.isPending, isFalse);

    registered = false;
    isPending = true;
    final revoked = await remote.removeMember('g', pending.id, pending: true);
    expect(deleted, ['/api/groups/g/pending-memberships/association-id']);
    expect(revoked.pendingMembers, isEmpty);
    expect(revoked.memberCount, 1);
  });

  for (final (locale, size, mode) in [
    (const Locale('en'), const Size(720, 700), ThemeMode.light),
    (const Locale('ar'), const Size(320, 700), ThemeMode.dark),
  ]) {
    testWidgets('pending roster row renders in ${locale.languageCode}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final removed = <GroupMember>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: GroupMembersSection(
              members: const [active, pending],
              canManage: true,
              onAddMember: () {},
              onRemoveMember: removed.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = L10n(locale);
      final pendingCard = find.byWidgetPredicate(
        (widget) => widget is GroupMemberCard && widget.member.isPending,
      );
      expect(find.text('Member'), findsOneWidget);
      expect(find.text(l10n.pendingGroupRegistration), findsOneWidget);
      expect(find.text(l10n.digits(phone)), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: pendingCard,
          matching: find.byTooltip(l10n.removeMember),
        ),
      );
      expect(removed, [pending]);
      expect(tester.takeException(), isNull);
    });
  }
}
