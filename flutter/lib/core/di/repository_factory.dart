import 'package:yalla_5roga/core/media/media_upload_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/features/chat/data/datasources/chat_send_queue.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:yalla_5roga/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:yalla_5roga/features/auth/data/datasources/firebase_auth_service.dart';
import 'package:yalla_5roga/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_local_datasource.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_remote_datasource.dart';
import 'package:yalla_5roga/features/chat/data/repositories/outing_chat_repository_impl.dart';
import 'package:yalla_5roga/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:yalla_5roga/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:yalla_5roga/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:yalla_5roga/features/groups/domain/repositories/groups_repository.dart';
import 'package:yalla_5roga/features/invitations/data/datasources/invitations_remote_datasource.dart';
import 'package:yalla_5roga/features/invitations/data/repositories/invitations_repository_impl.dart';
import 'package:yalla_5roga/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:yalla_5roga/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/data/datasources/saved_outings_local_datasource.dart';
import 'package:yalla_5roga/features/outings/data/datasources/saved_outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/data/repositories/geocoding_http_repository.dart';
import 'package:yalla_5roga/features/outings/data/repositories/outings_repository_impl.dart';
import 'package:yalla_5roga/features/outings/data/repositories/saved_outings_repository_impl.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/outings_repository.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/saved_outings_repository.dart';

/// Builds API-backed repositories (plus local prefs where used as cache only).
class RepositoryFactory {
  const RepositoryFactory({
    required this.apiClient,
    required this.networkInfo,
    required this.prefs,
    required this.firebaseAuth,
    required this.config,
  });

  final ApiClient apiClient;
  final NetworkInfo networkInfo;
  final SharedPreferences prefs;
  final FirebaseAuthService firebaseAuth;
  final AppConfig config;

  AuthRepository auth() {
    return AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(apiClient),
      local: AuthLocalDataSourceImpl(prefs),
      networkInfo: networkInfo,
      firebaseAuth: firebaseAuth,
    );
  }

  NotificationsRepository notifications() {
    return NotificationsRepositoryImpl(
      remote: NotificationsRemoteDataSourceImpl(apiClient),
      networkInfo: networkInfo,
    );
  }

  GroupsRepository groups() {
    return GroupsRepositoryImpl(
      remote: GroupsRemoteDataSource(apiClient),
      networkInfo: networkInfo,
      currentUserId: () => firebaseAuth.currentUser?.uid,
    );
  }

  OutingChatRepositoryImpl outingChat(ChatSendQueue sendQueue) {
    return OutingChatRepositoryImpl(
      remote: OutingChatRemoteDataSourceImpl(apiClient),
      local: OutingChatLocalDataSourceImpl(
        prefs,
        userId: () => firebaseAuth.currentUser?.uid,
        origin: config.apiBaseUrl,
      ),
      sendQueue: sendQueue,
      networkInfo: networkInfo,
    );
  }

  OutingsRepository outings() {
    return OutingsRepositoryImpl(
      remote: OutingsRemoteDataSource(apiClient),
      networkInfo: networkInfo,
    );
  }

  DiscoverRepository discover() {
    return DiscoverRepositoryImpl(
      remote: DiscoverRemoteDataSource(apiClient),
      networkInfo: networkInfo,
    );
  }

  SavedOutingsRepository savedOutings({MediaUploadService? mediaUploads}) {
    return SavedOutingsRepositoryImpl(
      remote: SavedOutingsRemoteDataSource(apiClient),
      local: SavedOutingsLocalDataSourceImpl(
        prefs,
        userId: () => firebaseAuth.currentUser?.uid,
        origin: config.apiBaseUrl,
      ),
      currentUserId: () => firebaseAuth.currentUser?.uid,
      networkInfo: networkInfo,
    );
  }

  LocationRepository geocoding() {
    return GeocodingHttpRepository(apiClient);
  }

  InvitationsRepositoryImpl invitations() {
    return InvitationsRepositoryImpl(
      remote: InvitationsRemoteDataSourceImpl(apiClient),
      networkInfo: networkInfo,
    );
  }
}
