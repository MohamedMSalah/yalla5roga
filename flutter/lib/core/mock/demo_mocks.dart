import 'package:mockito/annotations.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/groups/domain/repositories/groups_repository.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outing_chat_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/saved_outings_repository.dart';

/// Annotation anchor for the demo Mockito classes in `demo_mocks.mocks.dart`.
@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<GroupsRepository>(),
  MockSpec<OutingsRepository>(),
  MockSpec<OutingChatRepository>(),
  MockSpec<DiscoverRepository>(),
  MockSpec<NotificationsRepository>(),
  MockSpec<SavedOutingsRepository>(),
  MockSpec<LocationRepository>(),
])
abstract final class DemoMockAnchors {}
