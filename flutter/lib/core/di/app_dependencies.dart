import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/features/chat/data/datasources/chat_send_queue.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/di/repository_factory.dart';
import 'package:yalla_5roga/core/localization/locale_provider.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics_interceptor.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/performance_interceptor.dart';
import 'package:yalla_5roga/core/theme/theme_provider.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/features/auth/data/datasources/firebase_auth_service.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';
import 'package:yalla_5roga/features/chat/presentation/providers/outing_chat_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invites/presentation/providers/invite_deep_link_provider.dart';
import 'package:yalla_5roga/features/notifications/data/datasources/fcm_token_remote_datasource.dart';
import 'package:yalla_5roga/features/notifications/data/repositories/push_messaging_repository_impl.dart';
import 'package:yalla_5roga/features/notifications/data/services/fcm_messaging_service.dart';
import 'package:yalla_5roga/features/notifications/data/services/local_notifications_service.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outing_arrivals_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outing_arrival_service.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/providers/settings_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

class AppDependencies {
  const AppDependencies({
    required this.config,
    required this.theme,
    required this.locale,
    required this.auth,
    required this.notifications,
    required this.fcm,
    required this.inviteDeepLinks,
    required this.outingChat,
    required this.outings,
    required this.outingArrivals,
    required this.savedOutings,
    required this.shell,
    required this.groups,
    required this.discover,
    required this.settings,
    required this.geocoding,
    required this.prefs,
    required this.sync,
  });

  final AppConfig config;
  final ThemeProvider theme;
  final LocaleProvider locale;
  final AuthProvider auth;
  final NotificationsProvider notifications;
  final FcmProvider fcm;
  final InviteDeepLinkProvider inviteDeepLinks;
  final OutingChatProvider outingChat;
  final OutingsProvider outings;
  final OutingArrivalService outingArrivals;
  final SavedOutingsProvider savedOutings;
  final ShellProvider shell;
  final GroupsProvider groups;
  final DiscoverProvider discover;
  final SettingsProvider settings;
  final LocationRepository geocoding;
  final SharedPreferences prefs;
  final AppSyncProvider sync;

  static Future<AppDependencies> create({AppConfig? config}) async {
    final appConfig = config ?? AppConfig.instance;
    final prefs = await SharedPreferences.getInstance();
    final networkInfo = NetworkInfoImpl(Connectivity());

    final firebaseAuth = FirebaseAuthService();
    String? uid() => firebaseAuth.currentUser?.uid;
    final snapshots = OfflineSnapshots(prefs, uid, appConfig.apiBaseUrl);
    final queue = ChatSendQueue(prefs, uid, appConfig.apiBaseUrl);
    final authInterceptor = AuthInterceptor(
      currentUserId: uid,
      tokenProvider: ({bool forceRefresh = false}) =>
          firebaseAuth.idToken(forceRefresh: forceRefresh),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: appConfig.apiBaseUrl,
        connectTimeout: appConfig.connectTimeout,
        receiveTimeout: appConfig.receiveTimeout,
        sendTimeout: appConfig.connectTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    authInterceptor.bind(dio);
    dio.interceptors.addAll([
      authInterceptor,
      AppLogInterceptor(),
      if (kDebugMode) RequestDiagnosticsInterceptor(),
      PerformanceInterceptor(),
      ErrorInterceptor(),
    ]);
    if (kDebugMode) {
      RequestDiagnostics.instance.clear();
      cachedRemoteDeduper.clear();
    }

    AppSyncProvider? activeSync;
    final apiClient = ApiClient(
      dio,
      snapshots: snapshots,
      networkInfo: networkInfo,
      onReadFailure: () => activeSync?.retrySynchronization(),
    );
    final repos = RepositoryFactory(
      apiClient: apiClient,
      networkInfo: networkInfo,
      prefs: prefs,
      firebaseAuth: firebaseAuth,
      config: appConfig,
    );

    final authRepository = repos.auth();
    final outingsRepository = repos.outings();
    final groupsRepository = repos.groups();
    final discoverRepository = repos.discover();
    final savedOutingsRepository = repos.savedOutings();

    final auth = AuthProvider(repository: authRepository);
    await auth.restoreSession();

    MemberDisplayName.memberByPhoneLookup = groupsRepository.memberByPhone;

    final localNotifications = LocalNotificationsService();
    final fcmMessaging = FcmMessagingService(
      prefs: prefs,
      localNotifications: localNotifications,
    );
    final pushMessaging = PushMessagingRepositoryImpl(
      messaging: fcmMessaging,
      tokenRemote: FcmTokenRemoteDataSource(apiClient),
    );
    // FCM (local notifications + getToken) is deferred until after first frame.
    final fcm = FcmProvider(messaging: pushMessaging);

    // Feature data loads when MainShell mounts — not during splash/auth boot.
    final outings = OutingsProvider(repository: outingsRepository);
    final shell = ShellProvider();
    final groups = GroupsProvider(repository: groupsRepository, shell: shell);
    final discover = DiscoverProvider(repository: discoverRepository);
    final savedOutings = SavedOutingsProvider(
      repository: savedOutingsRepository,
    );
    final inviteDeepLinks = InviteDeepLinkProvider(
      prefs: prefs,
      isAuthenticated: () => auth.isAuthenticated,
      groups: groups,
      shell: shell,
    );

    final outingChatSocket = OutingChatSocketClient(
      baseUrl: appConfig.apiBaseUrl,
      tokenProvider: ({bool forceRefresh = false}) =>
          firebaseAuth.idToken(forceRefresh: forceRefresh),
    );

    final chatRepository = repos.outingChat(queue);
    final notifications = NotificationsProvider(
      repository: repos.notifications(),
    );
    late final AppSyncProvider sync;
    final outingChat = OutingChatProvider(
      repository: chatRepository,
      sendUpdates: queue.updates,
      onQueued: () => sync.sendsChanged(),
      persistLiveMessage: chatRepository.persistLiveMessage,
      socketClient: outingChatSocket,
    );
    sync = AppSyncProvider(
      chat: outingChat,
      auth: auth,
      network: networkInfo,
      socket: outingChatSocket,
      snapshots: snapshots,
      queue: queue,
      flushSends: chatRepository.flushSends,
      groups: groups,
      outings: outings,
      notifications: notifications,
    );
    activeSync = sync;
    return AppDependencies(
      sync: sync,
      config: appConfig,
      theme: ThemeProvider(prefs),
      locale: LocaleProvider(prefs),
      auth: auth,
      notifications: notifications,
      fcm: fcm,
      inviteDeepLinks: inviteDeepLinks,
      outingChat: outingChat,
      outings: outings,
      outingArrivals: OutingArrivalService(
        OutingArrivalsRemoteDataSource(apiClient),
        outingChatSocket,
      ),
      savedOutings: savedOutings,
      shell: shell,
      groups: groups,
      discover: discover,
      settings: SettingsProvider(),
      geocoding: repos.geocoding(),
      prefs: prefs,
    );
  }
}
