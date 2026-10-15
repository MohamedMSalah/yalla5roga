import 'package:dartz/dartz.dart';
import 'package:mockito/mockito.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/mock/demo_mocks.mocks.dart';
import 'package:yalla_5roga/core/mock/mock_data.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/repositories/groups_repository.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:yalla_5roga/features/outings/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_chat_read_result.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outing_chat_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/saved_outings_repository.dart';

// Temporary Mockito stubs for AppConfig.useMockData.
// Delete this file with lib/core/mock/ when demos are done.

/// Stubbed demo repositories. Built once so every screen shares the same fakes.
class DemoMocks {
  const DemoMocks({
    required this.auth,
    required this.groups,
    required this.outings,
    required this.outingChat,
    required this.discover,
    required this.notifications,
    required this.savedOutings,
    required this.location,
  });

  final AuthRepository auth;
  final GroupsRepository groups;
  final OutingsRepository outings;
  final OutingChatRepository outingChat;
  final DiscoverRepository discover;
  final NotificationsRepository notifications;
  final SavedOutingsRepository savedOutings;
  final LocationRepository location;
}

DemoMocks? _demoMocks;

DemoMocks createDemoMocks() => _demoMocks ??= _buildDemoMocks();

DemoMocks _buildDemoMocks() {
  final auth = MockAuthRepository();
  final groups = MockGroupsRepository();
  final outings = MockOutingsRepository();
  final outingChat = MockOutingChatRepository();
  final discover = MockDiscoverRepository();
  final notifications = MockNotificationsRepository();
  final savedOutings = MockSavedOutingsRepository();
  final location = MockLocationRepository();

  _stubAuth(auth);
  _stubGroups(groups);
  _stubOutings(outings);
  _stubOutingChat(outingChat);
  _stubDiscover(discover);
  _stubNotifications(notifications);
  _stubSavedOutings(savedOutings);
  _stubLocation(location);

  return DemoMocks(
    auth: auth,
    groups: groups,
    outings: outings,
    outingChat: outingChat,
    discover: discover,
    notifications: notifications,
    savedOutings: savedOutings,
    location: location,
  );
}

void _stubAuth(MockAuthRepository auth) {
  when(auth.hasFirebaseSession).thenAnswer((_) => MockData.sessionActive);
  when(auth.hasPasswordProvider).thenReturn(true);

  when(auth.getCachedUser()).thenAnswer((_) async {
    if (!MockData.sessionActive) {
      return const Left(CacheFailure('No mock session'));
    }
    return Right(MockData.currentUser);
  });

  when(auth.saveUser(any)).thenAnswer((invocation) async {
    final user = _arg<User>(invocation, 0);
    MockData.currentUser = user;
    MockData.sessionActive = true;
    return Right(user);
  });

  when(auth.login(email: anyNamed('email'), password: anyNamed('password')))
      .thenAnswer((invocation) async {
        MockData.sessionActive = true;
        MockData.updateCurrentUser(email: _named<String>(invocation, #email));
        return Right(MockData.currentUser);
      });

  when(
    auth.register(
      name: anyNamed('name'),
      email: anyNamed('email'),
      password: anyNamed('password'),
      phone: anyNamed('phone'),
      verificationId: anyNamed('verificationId'),
      smsCode: anyNamed('smsCode'),
    ),
  ).thenAnswer((invocation) async {
    MockData.sessionActive = true;
    MockData.currentUser = User(
      id: MockData.currentUser.id,
      name: _named<String>(invocation, #name),
      phone: _named<String>(invocation, #phone),
      email: _named<String>(invocation, #email),
      token: 'mock-demo-token',
      imageUrl: MockData.currentUser.imageUrl,
    );
    return Right(MockData.currentUser);
  });

  when(auth.signInWithGoogle()).thenAnswer((_) async {
    MockData.sessionActive = true;
    return Right(MockData.currentUser);
  });

  when(auth.signInWithApple()).thenAnswer((_) async {
    MockData.sessionActive = true;
    return Right(MockData.currentUser);
  });

  when(
    auth.updateProfileData(
      name: anyNamed('name'),
      imageUrl: anyNamed('imageUrl'),
    ),
  ).thenAnswer((invocation) async {
    MockData.updateCurrentUser(
      name: _named<String?>(invocation, #name),
      imageUrl: _named<String?>(invocation, #imageUrl),
    );
    return Right(MockData.currentUser);
  });

  when(auth.confirmPassword(password: anyNamed('password'))).thenAnswer((
    invocation,
  ) async {
    final password = _named<String>(invocation, #password);
    if (password.trim().isEmpty) {
      return const Left(AuthFailure('Incorrect password', 'wrong-password'));
    }
    return const Right(null);
  });

  when(
    auth.syncProfileToBackend(
      name: anyNamed('name'),
      email: anyNamed('email'),
      phone: anyNamed('phone'),
      imageUrl: anyNamed('imageUrl'),
    ),
  ).thenAnswer((invocation) async {
    MockData.updateCurrentUser(
      name: _named<String?>(invocation, #name),
      email: _named<String?>(invocation, #email),
      phone: _named<String?>(invocation, #phone),
      imageUrl: _named<String?>(invocation, #imageUrl),
    );
    return Right(MockData.currentUser);
  });

  when(
    auth.requestEmailChange(
      newEmail: anyNamed('newEmail'),
      currentPassword: anyNamed('currentPassword'),
    ),
  ).thenAnswer((invocation) async {
    MockData.updateCurrentUser(email: _named<String>(invocation, #newEmail));
    return const Right(null);
  });

  when(
    auth.updatePassword(
      currentPassword: anyNamed('currentPassword'),
      newPassword: anyNamed('newPassword'),
    ),
  ).thenAnswer((_) async => Right(MockData.currentUser));

  when(
    auth.updatePhoneNumber(
      verificationId: anyNamed('verificationId'),
      smsCode: anyNamed('smsCode'),
      phone: anyNamed('phone'),
    ),
  ).thenAnswer((invocation) async {
    MockData.updateCurrentUser(phone: _named<String>(invocation, #phone));
    return Right(MockData.currentUser);
  });

  when(auth.logout()).thenAnswer((_) async {
    MockData.sessionActive = false;
    return const Right(null);
  });

  when(
    auth.sendOtp(
      phone: anyNamed('phone'),
      forceResendingToken: anyNamed('forceResendingToken'),
      updateCurrentUser: anyNamed('updateCurrentUser'),
    ),
  ).thenAnswer(
    (_) async => const Right(
      PhoneVerification(verificationId: 'mock-verification-id', resendToken: 1),
    ),
  );

  when(
    auth.verifyOtpAndCache(
      verificationId: anyNamed('verificationId'),
      smsCode: anyNamed('smsCode'),
      phone: anyNamed('phone'),
      name: anyNamed('name'),
    ),
  ).thenAnswer((invocation) async {
    MockData.sessionActive = true;
    MockData.updateCurrentUser(
      phone: _named<String>(invocation, #phone),
      name: _named<String?>(invocation, #name),
    );
    return Right(MockData.currentUser);
  });

  when(auth.idToken(forceRefresh: anyNamed('forceRefresh')))
      .thenAnswer((_) async => Right(MockData.currentUser.token));

  when(auth.debugPrintSwaggerIdToken()).thenAnswer((_) async {});

  when(auth.signOutFirebase()).thenAnswer((_) async {
    MockData.sessionActive = false;
    return const Right(null);
  });
}

void _stubGroups(MockGroupsRepository groups) {
  when(groups.getGroups(forceRefresh: anyNamed('forceRefresh')))
      .thenAnswer((_) async => Right(List<Group>.from(MockData.groups)));

  when(groups.getGroup(any, forceRefresh: anyNamed('forceRefresh')))
      .thenAnswer((invocation) async {
        final groupId = _arg<String>(invocation, 0);
        final group = MockData.groups.cast<Group?>().firstWhere(
          (item) => item?.id == groupId,
          orElse: () => null,
        );
        if (group == null) {
          return const Left(ServerFailure('Group not found'));
        }
        return Right(group);
      });

  when(groups.createGroup(any)).thenAnswer((invocation) async {
    final group = _arg<Group>(invocation, 0);
    final id = group.id.isEmpty
        ? 'g_${DateTime.now().millisecondsSinceEpoch}'
        : group.id;
    final created = group.copyWith(
      image: group.image.isEmpty ? MockData.defaultCoverImage : group.image,
    );
    final withId = Group(
      id: id,
      name: created.name,
      outings: created.outings,
      bio: created.bio,
      image: created.image,
      members: created.members,
      cuserRole: created.cuserRole,
    );
    return Right(MockData.upsertGroup(withId));
  });

  when(groups.updateGroup(any)).thenAnswer((invocation) async {
    return Right(MockData.upsertGroup(_arg<Group>(invocation, 0)));
  });

  when(groups.addMember(any, any)).thenAnswer((invocation) async {
    final updated = MockData.addMember(
      _arg<String>(invocation, 0),
      _arg<GroupMember>(invocation, 1),
    );
    if (updated == null) {
      return const Left(ServerFailure('Group not found'));
    }
    return Right(updated);
  });

  when(groups.removeMember(any, any)).thenAnswer((invocation) async {
    final updated = MockData.removeMember(
      _arg<String>(invocation, 0),
      _arg<String>(invocation, 1),
    );
    if (updated == null) {
      return const Left(ServerFailure('Group not found'));
    }
    return Right(updated);
  });

  when(groups.leaveGroup(any)).thenAnswer((invocation) async {
    final ok = MockData.leaveGroup(_arg<String>(invocation, 0));
    if (!ok) {
      return const Left(ServerFailure('Group not found'));
    }
    return const Right(null);
  });

  when(groups.memberById(any)).thenAnswer(
    (invocation) => MockData.memberById(_arg<String>(invocation, 0)),
  );

  when(groups.memberByPhone(any)).thenAnswer(
    (invocation) => MockData.memberByPhone(_arg<String>(invocation, 0)),
  );

  when(groups.groupsForMember(any)).thenAnswer(
    (invocation) => MockData.groupsForMember(_arg<String>(invocation, 0)),
  );

  when(groups.contacts).thenAnswer((_) => MockData.contacts);
}

void _stubOutings(MockOutingsRepository outings) {
  when(outings.catalogPlaces).thenAnswer((_) => MockData.catalogPlaces);

  when(outings.membersForOuting(any)).thenAnswer(
    (invocation) => MockData.membersForOuting(_arg<Outing>(invocation, 0)),
  );

  when(outings.specialEventImage(any)).thenAnswer(
    (invocation) =>
        MockData.specialEventImage(_arg<OutingOccasion>(invocation, 0)),
  );

  when(outings.load(forceRefresh: anyNamed('forceRefresh')))
      .thenAnswer((_) async => Right(MockData.outingSnapshot()));

  when(outings.add(any, creatorId: anyNamed('creatorId')))
      .thenAnswer((invocation) async {
        return Right(
          MockData.addOuting(
            _arg<Outing>(invocation, 0),
            creatorId: _named<String?>(invocation, #creatorId),
          ),
        );
      });

  when(
    outings.suggestPlaces(
      groupId: anyNamed('groupId'),
      title: anyNamed('title'),
      places: anyNamed('places'),
      deadlineHours: anyNamed('deadlineHours'),
      createdBy: anyNamed('createdBy'),
      createdById: anyNamed('createdById'),
      image: anyNamed('image'),
      scheduledAt: anyNamed('scheduledAt'),
    ),
  ).thenAnswer((invocation) async {
    return Right(
      MockData.suggestPlaces(
        groupId: _named<String>(invocation, #groupId),
        title: _named<String>(invocation, #title),
        places: _named<List<Place>>(invocation, #places),
        deadlineHours: _named<int>(invocation, #deadlineHours),
        createdBy: _named<String>(invocation, #createdBy),
        createdById: _named<String?>(invocation, #createdById),
        image: _named<String?>(invocation, #image),
        scheduledAt: _named<DateTime?>(invocation, #scheduledAt),
      ),
    );
  });

  when(outings.selectVote(any, any)).thenAnswer((invocation) async {
    return Right(
      MockData.selectVote(
        _arg<String>(invocation, 0),
        _arg<int>(invocation, 1),
      ),
    );
  });

  when(outings.finalizeVote(any)).thenAnswer((invocation) async {
    return Right(MockData.finalizeVote(_arg<String>(invocation, 0)));
  });

  when(outings.clearVotes(any)).thenAnswer((invocation) async {
    return Right(MockData.clearVotes(_arg<String>(invocation, 0)));
  });

  when(
    outings.setAttendance(
      outingId: anyNamed('outingId'),
      memberId: anyNamed('memberId'),
      status: anyNamed('status'),
    ),
  ).thenAnswer((invocation) async {
    return Right(
      MockData.setAttendance(
        outingId: _named<String>(invocation, #outingId),
        memberId: _named<String>(invocation, #memberId),
        status: _named<AttendanceStatus>(invocation, #status),
      ),
    );
  });

  when(outings.refreshLifecycle())
      .thenAnswer((_) async => Right(MockData.refreshLifecycle()));
}

void _stubOutingChat(MockOutingChatRepository outingChat) {
  when(
    outingChat.sendMessage(
      outingId: anyNamed('outingId'),
      text: anyNamed('text'),
      senderId: anyNamed('senderId'),
      senderName: anyNamed('senderName'),
    ),
  ).thenAnswer((invocation) async {
    return Right(
      ChatMessage(
        id: 'fixed_send',
        outingId: _named<String>(invocation, #outingId),
        sender: _named<String>(invocation, #senderName),
        senderId: _named<String>(invocation, #senderId),
        text: _named<String>(invocation, #text),
        time: '',
        isMine: true,
      ),
    );
  });

  when(outingChat.markRead(any)).thenAnswer((invocation) async {
    final outingId = _arg<String>(invocation, 0);
    return Right(
      OutingChatReadResult(
        outingId: outingId,
        unreadCount: 0,
        unreadChatCount: 0,
      ),
    );
  });
}

void _stubDiscover(MockDiscoverRepository discover) {
  when(
    discover.getPlaces(
      vibe: anyNamed('vibe'),
      forceRefresh: anyNamed('forceRefresh'),
    ),
  ).thenAnswer((invocation) async {
    final all = MockData.suggestedPlaces;
    final vibe = _named<OutingVibe?>(invocation, #vibe);
    if (vibe == null) return Right(List.of(all));
    return Right(all.where((place) => place.vibe == vibe).toList());
  });

  when(discover.getFeaturedPlaces(forceRefresh: anyNamed('forceRefresh')))
      .thenAnswer(
        (_) async => Right(
          MockData.suggestedPlaces.where((place) => place.featured).toList(),
        ),
      );

  when(discover.getPlace(any, forceRefresh: anyNamed('forceRefresh')))
      .thenAnswer((invocation) async {
        final placeId = _arg<String>(invocation, 0);
        final place = MockData.suggestedPlaces.cast<dynamic>().firstWhere(
          (item) => item.id == placeId,
          orElse: () => null,
        );
        if (place == null) {
          return const Left(ServerFailure('Place not found'));
        }
        return Right(place);
      });

  when(discover.catalogPlaces()).thenAnswer((_) => MockData.catalogPlaces);
}

void _stubNotifications(MockNotificationsRepository notifications) {
  when(notifications.getNotifications(forceRefresh: anyNamed('forceRefresh')))
      .thenAnswer((_) async => Right(MockData.notificationsFeed()));

  when(notifications.markAllRead())
      .thenAnswer((_) async => Right(MockData.markAllNotificationsRead()));

  when(notifications.markRead(any)).thenAnswer((invocation) async {
    return Right(MockData.markNotificationRead(_arg<String>(invocation, 0)));
  });
}

void _stubSavedOutings(MockSavedOutingsRepository savedOutings) {
  when(savedOutings.getSaved()).thenAnswer(
    (_) async => Right(List<SavedOuting>.from(MockData.savedOutings)),
  );

  when(savedOutings.getDrafts())
      .thenAnswer((_) async => Right(List<OutingDraft>.from(MockData.drafts)));

  when(savedOutings.saveOuting(any)).thenAnswer((invocation) async {
    final outing = _arg<SavedOuting>(invocation, 0);
    MockData.savedOutings = [
      outing,
      ...MockData.savedOutings.where((item) => item.id != outing.id),
    ];
    return Right(List<SavedOuting>.from(MockData.savedOutings));
  });

  when(savedOutings.removeSaved(any)).thenAnswer((invocation) async {
    final id = _arg<String>(invocation, 0);
    MockData.savedOutings = MockData.savedOutings
        .where((item) => item.id != id)
        .toList();
    return Right(List<SavedOuting>.from(MockData.savedOutings));
  });

  when(savedOutings.saveDraft(any)).thenAnswer((invocation) async {
    final draft = _arg<OutingDraft>(invocation, 0);
    MockData.drafts = [
      draft,
      ...MockData.drafts.where((item) => item.id != draft.id),
    ];
    return Right(List<OutingDraft>.from(MockData.drafts));
  });

  when(savedOutings.removeDraft(any)).thenAnswer((invocation) async {
    final id = _arg<String>(invocation, 0);
    MockData.drafts = MockData.drafts.where((item) => item.id != id).toList();
    return Right(List<OutingDraft>.from(MockData.drafts));
  });

  when(savedOutings.isSaved(any)).thenAnswer((invocation) async {
    final id = _arg<String>(invocation, 0);
    return Right(MockData.savedOutings.any((item) => item.id == id));
  });
}

void _stubLocation(MockLocationRepository location) {
  when(
    location.reverseGeocode(
      latitude: anyNamed('latitude'),
      longitude: anyNamed('longitude'),
    ),
  ).thenAnswer((invocation) async {
    final latitude = _named<double>(invocation, #latitude);
    final longitude = _named<double>(invocation, #longitude);
    LocationHit? best;
    var bestDistance = double.infinity;
    for (final hit in MockData.geocodingHits) {
      final dLat = hit.latitude - latitude;
      final dLng = hit.longitude - longitude;
      final distance = dLat * dLat + dLng * dLng;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = hit;
      }
    }
    return best?.name ?? 'Demo City';
  });

  when(location.search(any)).thenAnswer((invocation) async {
    final query = _arg<String>(invocation, 0).trim().toLowerCase();
    if (query.isEmpty) return const [];
    return MockData.geocodingHits
        .where((hit) => hit.name.toLowerCase().contains(query))
        .toList();
  });
}

T _arg<T>(Invocation invocation, int index) =>
    invocation.positionalArguments[index] as T;

T _named<T>(Invocation invocation, Symbol name) =>
    invocation.namedArguments[name] as T;
