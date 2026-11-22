import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';
import 'package:yalla_5roga/features/invitations/domain/repositories/invitations_repository.dart';
import 'package:yalla_5roga/features/invitations/presentation/pages/invitations_page.dart';
import 'package:yalla_5roga/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
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

  Future<_Groups> pumpPage(
    WidgetTester tester,
    InvitationsRepository repository,
  ) async {
    final provider = InvitationsProvider(repository: repository);
    final groups = _Groups();
    final auth = _Auth();
    final sync = _Sync();
    final outings = _Outings();
    final shell = ShellProvider();
    addTearDown(provider.dispose);
    addTearDown(groups.dispose);
    addTearDown(auth.dispose);
    addTearDown(sync.dispose);
    addTearDown(outings.dispose);
    addTearDown(shell.dispose);
    addTearDown(Get.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InvitationsProvider>.value(value: provider),
          ChangeNotifierProvider<GroupsProvider>.value(value: groups),
          ChangeNotifierProvider<ShellProvider>.value(value: shell),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<AppSyncProvider>.value(value: sync),
          ChangeNotifierProvider<OutingsProvider>.value(value: outings),
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
          home: const InvitationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return groups;
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

  testWidgets('shows empty state when there are no invitations', (
    tester,
  ) async {
    await pumpPage(tester, _Repository(items: []));
    final l10n = L10n(const Locale('en'));
    expect(find.text(l10n.noInvitations), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accept calls the repository, removes the card, and opens the group',
    (tester) async {
      final repo = _Repository(items: [invitation]);
      final groups = await pumpPage(tester, repo);
      final l10n = L10n(const Locale('en'));

      await tester.tap(find.text(l10n.accept));
      await tester.pumpAndSettle();

      expect(repo.accepted, ['inv-1']);
      expect(find.byType(GroupDetailsPage), findsOneWidget);
      expect(find.text(l10n.groupDetails), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(groups.opened, ['group-1']);
      expect(groups.loaded, ['group-1']);
      Navigator.of(tester.element(find.byType(GroupDetailsPage))).pop();
      await tester.pumpAndSettle();
      expect(groups.closed, ['group-1']);
      expect(find.text(l10n.accept), findsNothing);
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pumpAndSettle();
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
  final opened = <String>[];
  final closed = <String>[];
  final loaded = <String>[];
  static const group = Group(
    id: 'group-1',
    name: 'Friends',
    outings: 0,
    image: '',
    members: [],
  );

  @override
  void openGroup(String groupId) => opened.add(groupId);

  @override
  void closeGroup(String groupId) => closed.add(groupId);

  @override
  Group? findById(String groupId) => groupId == group.id ? group : null;

  @override
  bool canParticipate(Group group, String? accountId) => accountId == 'member';

  @override
  String roleLabel(GroupRole role, L10n l10n) => l10n.member;

  @override
  Future<void> loadGroups({bool forceRefresh = false}) async {}

  @override
  Future<Group?> ensureGroupLoaded(
    String groupId, {
    bool forceRefresh = false,
    bool allowStale = true,
  }) async {
    loaded.add(groupId);
    return findById(groupId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User? get user =>
      const User(id: 'member', name: 'Nour', phone: '+201001234567');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Outings extends ChangeNotifier implements OutingsProvider {
  @override
  Map<String, int>? get groupOutingCounts => const {};
  @override
  List<Outing> get activeVotes => const [];
  @override
  List<Outing> get upcoming => const [];
  @override
  List<Outing> get history => const [];
  @override
  bool get hasLoaded => true;
  @override
  String? get errorMessage => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sync extends ChangeNotifier implements AppSyncProvider {
  @override
  void retainRealtime(
    Object owner, {
    String? groupId,
    String? outingId,
    bool revalidate = true,
  }) {}

  @override
  void releaseRealtime(Object owner) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
