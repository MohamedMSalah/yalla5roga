import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/theme/app_theme.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/setting/presentation/pages/about_developer_page.dart';
import 'package:yalla_5roga/features/setting/presentation/pages/contact_us_page.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/cards/developer_link_card.dart';

void main() {
  testWidgets(
    'contact draft preserves Arabic text and offers a copy fallback',
    (tester) async {
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger = tester.binding.defaultBinaryMessenger;
      Uri? draft;
      String? copiedAddress;
      messenger.setMockMethodCallHandler(launcher, (call) async {
        final arguments = call.arguments as Map<Object?, Object?>;
        draft = Uri.parse(arguments['url']! as String);
        throw PlatformException(code: 'NO_HANDLER');
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          copiedAddress = arguments['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(launcher, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      const locale = Locale('ar');
      final l10n = L10n(locale);
      await _pumpPage(
        tester,
        const ContactUsPage(initialTopic: SupportTopic.deletion),
        locale: locale,
        brightness: Brightness.dark,
      );
      final fields = find.byType(TextFormField);
      final submit = find.text(l10n.openEmailApp);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(draft, isNull);
      expect(find.text(l10n.supportMessageRequired), findsOneWidget);

      const subject = 'حسابي & بياناتي + سؤال؟';
      const message = 'مرحبًا، أحتاج مساعدة.\nالمرجع #123';
      await tester.enterText(fields.at(0), subject);
      await tester.enterText(fields.at(1), message);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(draft?.scheme, 'mailto');
      expect(draft?.path, AppConfig.contactEmail);
      expect(draft?.queryParameters['subject'], subject);
      expect(
        draft?.queryParameters['body'],
        '${l10n.supportCategory}: ${l10n.accountAndDataDeletion}\r\n\r\n'
        '${message.replaceAll('\n', '\r\n')}',
      );
      expect(draft?.query, isNot(contains('+')));
      expect(find.text(l10n.noEmailApp), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      final copy = find.text(l10n.copyEmailAddress);
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copiedAddress, AppConfig.contactEmail);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final (locale, brightness) in [
    (const Locale('en'), Brightness.light),
    (const Locale('ar'), Brightness.dark),
  ]) {
    testWidgets('developer page fits narrow ${locale.languageCode} layout', (
      tester,
    ) async {
      final l10n = L10n(locale);
      await _pumpPage(
        tester,
        const AboutDeveloperPage(),
        locale: locale,
        brightness: brightness,
      );
      expect(find.text(l10n.developerName), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);

      await tester.scrollUntilVisible(
        find.text(l10n.developerCopyright(DateTime.now().year)),
        240,
        scrollable: find.byType(Scrollable),
      );
      expect(find.byType(DeveloperLinkCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  required Locale locale,
  required Brightness brightness,
}) async {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    GetMaterialApp(
      home: page,
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      theme: brightness == Brightness.dark
          ? AppTheme.dark(locale)
          : AppTheme.light(locale),
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.5));
        return MediaQuery(
          data: media,
          child: Builder(
            builder: (context) {
              Responsive.init(context);
              return child!;
            },
          ),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}
