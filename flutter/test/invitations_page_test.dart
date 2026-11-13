import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';
import 'package:yalla_5roga/features/invitations/domain/repositories/invitations_repository.dart';
import 'package:yalla_5roga/features/invitations/presentation/pages/invitations_page.dart';
import 'package:yalla_5roga/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

void main() {
  final invitation = GroupInvitation(
    invitationId: 'inv-1',
    groupId: 'group-1',
    groupName: 'Friends',
    groupImage: '',
    invitedPhone: '+201001234567',
    status: InvitationStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    inviterName: 'Ahmed',
  );

  Future<void> pumpPage(
    WidgetTester tester,
    InvitationsRepository repository,
  ) async {
    final provider = InvitationsProvider(repository: repository);
    final groups = _Groups();
    final shell = ShellProvider();
    addTearDown(provider.dispose);
    addTearDown(shell.dispose);
    addTearDown(Get.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InvitationsProvider>.value(value: provider),
          ChangeNotifierProvider<GroupsProvider>.value(value: groups),
          ChangeNotifierProvider<ShellProvider>.value(value: shell),
        ],
        child: GetMaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [L10n.delegate],
          theme: ThemeData.light(),
          builder: (context, child) {
            Responsive.init(context);
            return child!;
          },
          getPages: [
            GetPage(
              name: '/group/:id',
              page: () => const Scaffold(body: Text('Group details stub')),
            ),
          ],
          home: const InvitationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders invitation card with message and Accept/Decline buttons',
    (tester) async {
      await pumpPage(tester, _Repository(items: [invitation]));
      final l10n = L10n(const Locale('en'));

      // Card shows the group name and the "invited you to join" message.
      expect(find.text('Friends'), findsOneWidget);
      expect(
        find.textContaining(l10n.invitedYouToJoin('Ahmed')),
        findsOneWidget,
      );
      // Both decision buttons are present.
      expect(find.text(l10n.accept), findsOneWidget);
      expect(find.text(l10n.decline), findsOneWidget);
      // No grey-screen: the page built without an exception.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows empty state when there are no invitations', (tester) async {
    await pumpPage(tester, _Repository(items: []));
    final l10n = L10n(const Locale('en'));
    expect(find.text(l10n.noInvitations), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accept calls the repository, removes the card, and opens the group',
    (tester) async {
      final repo = _Repository(items: [invitation]);
      await pumpPage(tester, repo);
      final l10n = L10n(const Locale('en'));

      await tester.tap(find.text(l10n.accept));
      await tester.pumpAndSettle();

      expect(repo.accepted, ['inv-1']);
      expect(find.text('Friends'), findsNothing);
      expect(find.text('Group details stub'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Repository implements InvitationsRepository {
  _Repository({required this.items});

  List<GroupInvitation> items;
  final List<String> accepted = [];

  @override
  Future<Either<Failure, List<GroupInvitation>>> getInvitations({
    bool forceRefresh = false,
  }) async {
    return Right(items);
  }

  @override
  Future<Either<Failure, void>> acceptInvitation(String invitationId) async {
    accepted.add(invitationId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> declineInvitation(String invitationId) async {
    return const Right(null);
  }

  @override
  void clearCache() {}
}

class _Groups extends ChangeNotifier implements GroupsProvider {
  @override
  Future<void> loadGroups({bool forceRefresh = false}) async {}

  @override
  Future<Group?> ensureGroupLoaded(
    String groupId, {
    bool forceRefresh = false,
    bool allowStale = true,
  }) async {
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
