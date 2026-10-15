import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/di/app_dependencies.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/localization/locale_provider.dart';
import 'package:yalla_5roga/core/theme/app_theme.dart';
import 'package:yalla_5roga/core/theme/theme_provider.dart';
import 'package:yalla_5roga/core/utils/app_permissions.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outing_chat_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';
import 'package:yalla_5roga/features/setting/presentation/providers/settings_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/pages/main_shell.dart';
import 'package:yalla_5roga/features/splash/presentation/pages/splash_page.dart';

class App extends StatelessWidget {
  const App({super.key, required this.deps});

  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: deps.theme),
        ChangeNotifierProvider<LocaleProvider>.value(value: deps.locale),
        ChangeNotifierProvider<AuthProvider>.value(value: deps.auth),
        ChangeNotifierProvider<NotificationsProvider>.value(
          value: deps.notifications,
        ),
        ChangeNotifierProvider<FcmProvider>.value(value: deps.fcm),
        ChangeNotifierProvider<OutingChatProvider>.value(
          value: deps.outingChat,
        ),
        ChangeNotifierProvider<OutingsProvider>.value(value: deps.outings),
        ChangeNotifierProvider<SavedOutingsProvider>.value(
          value: deps.savedOutings,
        ),
        ChangeNotifierProvider<ShellProvider>.value(value: deps.shell),
        ChangeNotifierProvider<GroupsProvider>.value(value: deps.groups),
        ChangeNotifierProvider<DiscoverProvider>.value(value: deps.discover),
        ChangeNotifierProvider<SettingsProvider>.value(value: deps.settings),
        Provider<LocationRepository>.value(value: deps.geocoding),
        Provider<SharedPreferences>.value(value: deps.prefs),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, theme, locale, _) {
          return GetMaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(locale.locale),
            darkTheme: AppTheme.dark(locale.locale),
            themeMode: theme.themeMode,
            locale: locale.locale,
            supportedLocales: L10n.supportedLocales,
            localizationsDelegates: const [
              L10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: deps.auth.isAuthenticated
                ? const MainShell()
                : const SplashPage(),
            builder: (context, child) {
              Responsive.init(context);
              final theme = Theme.of(context);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.textScalerOf(context).scale(1).clamp(0.9, 1.15),
                  ),
                ),
                child: Theme(
                  data: theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      // Use fontScale (shortest-side aware) so fold-open /
                      // landscape do not oversize Material text.
                      fontSizeFactor: Responsive.fontScale,
                    ),
                  ),
                  child: _PushBootstrap(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Wires push listeners after the first frame and opens a cold-start tap.
///
/// Notification permission is requested later, once the home feed is visible.
class _PushBootstrap extends StatefulWidget {
  const _PushBootstrap({required this.child});

  final Widget child;

  @override
  State<_PushBootstrap> createState() => _PushBootstrapState();
}

class _PushBootstrapState extends State<_PushBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Mock/demo mode skips native push setup entirely.
      if (AppConfig.useMockData) return;

      final fcm = context.read<FcmProvider>();
      // Listeners and local notifications run after the first frame.
      // getToken waits until notification permission is settled.
      await fcm.initialize();
      if (!mounted) return;
      fcm.flushPendingNavigation();
      if (!await AppPermissions.isNotificationGranted || !mounted) return;
      await fcm.refreshToken();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
