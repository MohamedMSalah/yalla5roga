import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/responsive/responsive.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/groups/data/datasources/groups_remote_datasource.dart';
import 'package:yalla_5roga/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/create_group_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/add_member_phone_sheet.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_invitee_picker.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/pick_device_contacts_page.dart';

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);
  testWidgets('create group requires consent and editing recipients clears it', (
    tester,
  ) async {
    final dio = Dio();
    final shell = ShellProvider();
    final groups = GroupsProvider(
      repository: GroupsRepositoryImpl(
        remote: GroupsRemoteDataSource(ApiClient(dio)),
        networkInfo: _Online(),
        currentUserId: () => 'me',
      ),
      shell: shell,
    );
    addTearDown(dio.close);
    addTearDown(shell.dispose);
    addTearDown(groups.dispose);
    // Provider also rejects unchecked creation before any repository mutation.
    expect(await groups.createGroup('Friends', ownerName: 'Owner'), isNull);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: groups,
        child: _app(home: const CreateGroupPage()),
      ),
    );
    await tester.pumpAndSettle();
    final create = find.widgetWithText(
      CustomButton,
      const L10n(Locale('en')).createGroup,
    );
    expect(tester.widget<CustomButton>(create).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<CustomButton>(create).onPressed, isNotNull);
    final phone = find.byType(TextFormField).last;
    await tester.ensureVisible(phone);
    await tester.pumpAndSettle();
    await tester.enterText(phone, '01001234567');
    await tester.pumpAndSettle();
    expect(tester.widget<CustomButton>(create).onPressed, isNull);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  test('selected calling code normalizes local and pasted numbers', () {
    expect(
      Validators.normalizeGroupPhone('01001234567', callingCode: '+20'),
      '+201001234567',
    );
    expect(
      Validators.normalizeGroupPhone('٠٥٠١٢٣٤٥٦٧', callingCode: '+966'),
      '+966501234567',
    );
    expect(
      Validators.normalizeGroupPhone('0501234567', callingCode: '+971'),
      '+971501234567',
    );
    expect(
      Validators.normalizeGroupPhone('06 6982 1234', callingCode: '+39'),
      '+390669821234',
    );
    expect(
      Validators.normalizeGroupPhone('+44 7700 900123', callingCode: '+20'),
      '+447700900123',
    );
    expect(
      Validators.normalizeGroupPhone('00447700900123', callingCode: '+20'),
      '+447700900123',
    );
    expect(Validators.normalizeGroupPhone('', callingCode: '+966'), isNull);
    expect(
      Validators.normalizeGroupPhone('abc1234567', callingCode: '+966'),
      isNull,
    );
    expect(Validators.normalizeGroupPhone('01001234567'), '+201001234567');
  });

  for (final (locale, size, mode) in [
    (const Locale('en'), const Size(720, 800), ThemeMode.light),
    (const Locale('ar'), const Size(320, 700), ThemeMode.dark),
  ]) {
    testWidgets('create picker selects a code in ${locale.languageCode}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var code = '+20';
      var contactsOpened = false;
      String? added;
      await tester.pumpWidget(
        _app(
          locale: locale,
          mode: mode,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SingleChildScrollView(
                child: GroupInviteePicker(
                  phoneController: controller,
                  phones: const [],
                  isCreating: false,
                  whatsappOptIn: false,
                  onWhatsAppOptInChanged: (_) {},
                  callingCode: code,
                  onCallingCodeChanged: (value) => setState(() => code = value),
                  onPickContacts: () => contactsOpened = true,
                  onAddPhone: () => added = Validators.normalizeGroupPhone(
                    controller.text,
                    callingCode: code,
                  ),
                  onRemovePhone: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = L10n(locale);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        '+20',
      );
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.digits('+44')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(l10n.digits('+44')).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '7700900123');
      await tester.tap(find.text(l10n.addPhone));
      expect(added, '+447700900123');
      await tester.tap(find.text(l10n.selectFromContacts));
      expect(contactsOpened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'group info sheet defaults to Egypt and returns normalized phones',
    (tester) async {
      ({List<String> phones, bool whatsappOptIn})? result;
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await AddMemberPhoneSheet.show(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.text(const L10n(Locale('en')).selectFromContacts),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        '+20',
      );
      await tester.enterText(find.byType(TextFormField), '01001234567');
      final addButton = find.widgetWithText(
        CustomButton,
        const L10n(Locale('en')).addPhone,
      );
      expect(tester.widget<CustomButton>(addButton).onPressed, isNull);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(addButton);
      await tester.tap(find.text(const L10n(Locale('en')).addPhone));
      await tester.pumpAndSettle();
      expect(result?.phones, ['+201001234567']);
      expect(result?.whatsappOptIn, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'group info retains contact selections and deduplicates manual input',
    (tester) async {
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        permissions,
        (_) async => 0,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissions,
          null,
        ),
      );
      const l10n = L10n(Locale('en'));
      ({List<String> phones, bool whatsappOptIn})? result;
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            body: TextButton(
              onPressed: () async => result = await AddMemberPhoneSheet.show(),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.selectFromContacts));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PickDeviceContactsPage), findsOneWidget);
      await tester.tap(find.text(l10n.notNow));
      await tester.pumpAndSettle();
      // Simulate the contacts page's normalized result without a native address book.
      Get.back(result: ['+201001234567', '+447700900123']);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(find.byType(Chip), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField), '01001234567');
      final submit = find.text(l10n.addSelectedContacts(2));
      expect(
        tester
            .widget<CustomButton>(
              find.widgetWithText(CustomButton, l10n.addSelectedContacts(2)),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(result?.phones, ['+201001234567', '+447700900123']);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app({
  required Widget home,
  Locale locale = const Locale('en'),
  ThemeMode mode = ThemeMode.light,
}) => GetMaterialApp(
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
  builder: (context, child) {
    Responsive.init(context);
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.5)),
      child: child!,
    );
  },
  home: home,
);
