import 'package:yalla_5roga/features/place_reviews/data/datasources/place_reviews_remote_datasource.dart';
import 'package:yalla_5roga/features/place_reviews/data/repositories/place_reviews_repository_impl.dart';
import 'package:yalla_5roga/features/place_reviews/domain/repositories/place_reviews_repository.dart';
import 'package:yalla_5roga/core/media/media_upload_service.dart';
import 'package:yalla_5roga/features/smart_meetup/data/datasources/smart_meetup_remote_datasource.dart';
import 'package:yalla_5roga/features/smart_meetup/data/repositories/smart_meetup_repository_impl.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/repositories/smart_meetup_repository.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/location_travel_notification_repository.dart';
import 'package:yalla_5roga/features/notifications/data/datasources/location_travel_notification_remote_datasource.dart';
import 'package:yalla_5roga/features/notifications/data/repositories/location_travel_notification_repository_impl.dart';
import 'package:yalla_5roga/features/route_preview/domain/route_preview_repository.dart';
import 'package:yalla_5roga/features/route_preview/data/route_preview_remote_data_source.dart';
import 'package:yalla_5roga/features/route_preview/data/route_preview_repository_impl.dart';
import 'package:yalla_5roga/features/starting_location/domain/repositories/starting_location_repository.dart';
import 'package:yalla_5roga/features/starting_location/data/datasources/starting_location_remote_datasource.dart';
import 'package:yalla_5roga/features/starting_location/data/repositories/starting_location_repository_impl.dart';
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
import 'package:yalla_5roga/features/discover/data/datasources/places_local_store.dart';
import 'package:yalla_5roga/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:yalla_5roga/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:yalla_5roga/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:yalla_5roga/features/groups/domain/repositories/groups_repository.dart';
import 'package:yalla_5roga/features/invitations/data/datasources/invitations_remote_datasource.dart';
import 'package:yalla_5roga/features/invitations/data/repositories/invitations_repository_impl.dart';
import 'package:yalla_5roga/features/location_privacy/data/datasources/location_privacy_remote_datasource.dart';
import 'package:yalla_5roga/features/location_privacy/data/repositories/location_privacy_repository_impl.dart';
import 'package:yalla_5roga/features/location_privacy/domain/repositories/location_privacy_repository.dart';
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

import 'package:yalla_5roga/features/saved_locations/data/datasources/saved_locations_remote_datasource.dart';
import 'package:yalla_5roga/features/saved_locations/data/repositories/saved_locations_repository_impl.dart';

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

  PlaceReviewsRepository placeReviews(String? Function() currentUserId) =>
      PlaceReviewsRepositoryImpl(
        PlaceReviewsRemoteDataSource(apiClient),
        currentUserId,
      );
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

  LocationTravelNotificationRepository locationTravelNotifications() =>
      LocationTravelNotificationRepositoryImpl(
        LocationTravelNotificationRemoteDataSource(apiClient),
        networkInfo,
      );

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

  DiscoverRepositoryImpl discover() {
    return DiscoverRepositoryImpl(
      remote: DiscoverRemoteDataSource(apiClient),
      local: PlacesLocalStore(config.apiBaseUrl),
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

  SavedLocationsRepositoryImpl savedLocations(
    String? Function() activeAccount,
  ) => SavedLocationsRepositoryImpl(
    SavedLocationsRemoteDataSource(apiClient),
    networkInfo,
    () {
      final owner = activeAccount();
      return owner == firebaseAuth.currentUser?.uid ? owner : null;
    },
  );

  LocationPrivacyRepository locationPrivacy(String? Function() activeAccount) =>
      LocationPrivacyRepositoryImpl(
        LocationPrivacyRemoteDataSource(apiClient),
        networkInfo,
        () {
          final owner = activeAccount();
          return owner == firebaseAuth.currentUser?.uid ? owner : null;
        },
      );

  LocationRepository geocoding() {
    return GeocodingHttpRepository(apiClient);
  }

  RoutePreviewRepository routePreview() => RoutePreviewRepositoryImpl(
    RoutePreviewRemoteDataSource(apiClient),
    networkInfo,
  );

  StartingLocationRepository startingLocation() =>
      StartingLocationRepositoryImpl(
        StartingLocationRemoteDataSource(apiClient),
        networkInfo,
      );

  SmartMeetupRepository smartMeetup() => SmartMeetupRepositoryImpl(
    SmartMeetupRemoteDataSource(apiClient),
    networkInfo,
  );

  InvitationsRepositoryImpl invitations() {
    return InvitationsRepositoryImpl(
      remote: InvitationsRemoteDataSourceImpl(apiClient),
      networkInfo: networkInfo,
    );
  }
}
