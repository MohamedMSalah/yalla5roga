import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/di/repository_factory.dart';
import 'package:yalla_5roga/core/localization/locale_provider.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/performance_interceptor.dart';
import 'package:yalla_5roga/core/theme/theme_provider.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/features/auth/data/datasources/firebase_auth_service.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/notifications/data/repositories/push_messaging_repository_impl.dart';
import 'package:yalla_5roga/features/notifications/data/services/fcm_messaging_service.dart';
import 'package:yalla_5roga/features/notifications/data/services/local_notifications_service.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outing_chat_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/providers/settings_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

class AppDependencies {
  const AppDependencies({
    required this.theme,
    required this.locale,
    required this.auth,
    required this.notifications,
    required this.fcm,
    required this.outingChat,
    required this.outings,
    required this.savedOutings,
    required this.shell,
    required this.groups,
    required this.discover,
    required this.settings,
    required this.geocoding,
    required this.prefs,
  });

  final ThemeProvider theme;
  final LocaleProvider locale;
  final AuthProvider auth;
  final NotificationsProvider notifications;
  final FcmProvider fcm;
  final OutingChatProvider outingChat;
  final OutingsProvider outings;
  final SavedOutingsProvider savedOutings;
  final ShellProvider shell;
  final GroupsProvider groups;
  final DiscoverProvider discover;
  final SettingsProvider settings;
  final LocationRepository geocoding;
  final SharedPreferences prefs;

  static Future<AppDependencies> create() async {
    final prefs = await SharedPreferences.getInstance();
    final networkInfo = NetworkInfoImpl(Connectivity());

    final firebaseAuth = FirebaseAuthService();
    final authInterceptor = AuthInterceptor(
      tokenProvider: ({bool forceRefresh = false}) =>
          firebaseAuth.idToken(forceRefresh: forceRefresh),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.addAll([
      authInterceptor,
      AppLogInterceptor(),
      PerformanceInterceptor(),
      ErrorInterceptor(),
    ]);

    final repos = RepositoryFactory(
      apiClient: ApiClient(dio),
      networkInfo: networkInfo,
      prefs: prefs,
      firebaseAuth: firebaseAuth,
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
    final pushMessaging = PushMessagingRepositoryImpl(messaging: fcmMessaging);
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

    return AppDependencies(
      theme: ThemeProvider(prefs),
      locale: LocaleProvider(prefs),
      auth: auth,
      notifications: NotificationsProvider(repository: repos.notifications()),
      fcm: fcm,
      outingChat: OutingChatProvider(),
      outings: outings,
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
