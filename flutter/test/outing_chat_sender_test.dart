import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/features/chat/data/models/chat_message_model.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/outing_chat_message_list.dart';

void main() {
  for (final (locale, size, mode) in [
    (const Locale('en'), const Size(720, 620), ThemeMode.light),
    (const Locale('ar'), const Size(320, 620), ThemeMode.dark),
  ]) {
    testWidgets(
      'renders sender identity and self label in ${locale.languageCode}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final messages = [
          ChatMessageModel.fromJson({
            'id': '1',
            'sender_id': 'their-uid',
            'sender': 'Ahmed',
            'text': 'See you soon',
          }),
          ChatMessageModel.fromJson({
            'id': '2',
            'sender_id': 'my-uid',
            'sender': 'Old name',
            'text': 'On the way',
          }),
          ChatMessageModel.fromJson({
            'id': '3',
            'sender_id': 'missing-uid',
            'text': 'Historical message',
          }),
        ];
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              L10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            home: Scaffold(
              body: OutingChatMessageList(
                messages: messages,
                members: const [],
                currentUserId: 'my-uid',
                currentUserName: 'Mohamed',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = L10n(locale);
        expect(find.text('Ahmed'), findsOneWidget);
        expect(find.text(l10n.chatMessageFromNotification), findsNothing);
        expect(find.text('Mohamed (${l10n.you})'), findsOneWidget);
        expect(find.text(l10n.chatUnknownSender), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
