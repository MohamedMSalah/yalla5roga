import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/mock/mock_repositories.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:yalla_5roga/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:yalla_5roga/features/auth/data/datasources/firebase_auth_service.dart';
import 'package:yalla_5roga/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';
import 'package:yalla_5roga/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:yalla_5roga/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:yalla_5roga/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:yalla_5roga/features/groups/domain/repositories/groups_repository.dart';
import 'package:yalla_5roga/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:yalla_5roga/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outing_chat_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/data/datasources/saved_outings_local_datasource.dart';
import 'package:yalla_5roga/features/outings/data/repositories/geocoding_http_repository.dart';
import 'package:yalla_5roga/features/outings/data/repositories/outing_chat_repository_impl.dart';
import 'package:yalla_5roga/features/outings/data/repositories/outings_repository_impl.dart';
import 'package:yalla_5roga/features/outings/data/repositories/saved_outings_repository_impl.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outing_chat_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/saved_outings_repository.dart';

/// Builds API-backed repositories (plus local prefs for saved/drafts).
/// When [AppConfig.useMockData] is true, returns Mockito stubs over the demo fixtures.
class RepositoryFactory {
  const RepositoryFactory({
    required this.apiClient,
    required this.networkInfo,
    required this.prefs,
    required this.firebaseAuth,
  });

  final ApiClient apiClient;
  final NetworkInfo networkInfo;
  final SharedPreferences prefs;
  final FirebaseAuthService firebaseAuth;

  AuthRepository auth() {
    if (AppConfig.useMockData) return createDemoMocks().auth;
    return AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(apiClient),
      local: AuthLocalDataSourceImpl(prefs),
      networkInfo: networkInfo,
      firebaseAuth: firebaseAuth,
    );
  }

  NotificationsRepository notifications() {
    if (AppConfig.useMockData) return createDemoMocks().notifications;
    return NotificationsRepositoryImpl(
      remote: NotificationsRemoteDataSourceImpl(apiClient),
      networkInfo: networkInfo,
    );
  }

  GroupsRepository groups() {
    if (AppConfig.useMockData) return createDemoMocks().groups;
    return GroupsRepositoryImpl(
      remote: GroupsRemoteDataSource(apiClient),
      networkInfo: networkInfo,
    );
  }

  OutingChatRepository outingChat() {
    if (AppConfig.useMockData) return createDemoMocks().outingChat;
    return OutingChatRepositoryImpl(
      remote: OutingChatRemoteDataSourceImpl(apiClient),
      networkInfo: networkInfo,
    );
  }

  OutingsRepository outings() {
    if (AppConfig.useMockData) return createDemoMocks().outings;
    return OutingsRepositoryImpl(
      remote: OutingsRemoteDataSource(apiClient),
      networkInfo: networkInfo,
    );
  }

  DiscoverRepository discover() {
    if (AppConfig.useMockData) return createDemoMocks().discover;
    return DiscoverRepositoryImpl(
      remote: DiscoverRemoteDataSource(apiClient),
      networkInfo: networkInfo,
    );
  }

  SavedOutingsRepository savedOutings() {
    if (AppConfig.useMockData) return createDemoMocks().savedOutings;
    return SavedOutingsRepositoryImpl(
      local: SavedOutingsLocalDataSourceImpl(prefs),
    );
  }

  LocationRepository geocoding() {
    if (AppConfig.useMockData) return createDemoMocks().location;
    return GeocodingHttpRepository();
  }
}
