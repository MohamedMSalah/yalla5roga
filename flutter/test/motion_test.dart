import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/navigation/app_page_transition.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_nav.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_nav_layout.dart';
import 'package:yalla_5roga/core/widgets/app_fade_switcher.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';

void main() {
  for (final (rtl, highContrast) in [(false, false), (true, true)]) {
    testWidgets(
      'bottom bar layers over the body (high contrast: $highContrast)',
      (tester) async {
        final labels = rtl
            ? ['الرئيسية', 'المجموعات', 'الخروجات', 'استكشف', 'الإعدادات']
            : ['Home', 'Groups', 'Outings', 'Discover', 'Settings'];
        int? selected;
        tester.view.physicalSize = rtl
            ? const Size(320, 740)
            : const Size(800, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: rtl ? Brightness.dark : Brightness.light,
              extensions: [rtl ? AppPalette.dark : AppPalette.light],
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: highContrast),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              ),
            ),
            home: AppBottomNavLayout(
              pages: List.filled(5, const ColoredBox(color: Colors.teal)),
              items: [
                for (final label in labels)
                  AppBottomNavItem(icon: Icons.circle, label: label),
              ],
              currentIndex: 0,
              onChanged: (index) => selected = index,
            ),
          ),
        );

        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).extendBody,
          isTrue,
        );
        expect(
          find.byType(BackdropFilter),
          highContrast ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.text(labels[3]));
        expect(selected, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('HeroTags', () {
    test('same item on different surfaces never collides', () {
      final tags = {
        HeroTags.outingCover('featured', 'o1'),
        HeroTags.outingCover('home', 'o1'),
        HeroTags.outingCover('outings', 'o1'),
        HeroTags.outingCover('group', 'o1'),
        HeroTags.placeCover('home-featured', 'o1'),
        HeroTags.placeCover('home-nearby', 'o1'),
        HeroTags.placeCover('outings-featured', 'o1'),
        HeroTags.placeCover('discover-featured', 'o1'),
        HeroTags.placeCover('discover-nearby', 'o1'),
        HeroTags.groupCover('o1'),
      };
      expect(tags.length, 10);
    });

    test('empty ids from a live API stub do not produce a tag', () {
      expect(HeroTags.outingCover('home', ''), isNull);
      expect(HeroTags.outingCover('home', '   '), isNull);
      expect(HeroTags.placeCover('', 'p1'), isNull);
      expect(HeroTags.groupCover(''), isNull);
    });
  });

  group('AppHero', () {
    testWidgets('renders no Hero when tag is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppHero(
            tag: null,
            radius: 12,
            child: SizedBox.square(dimension: 40),
          ),
        ),
      );
      expect(find.byType(Hero), findsNothing);
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('renders no Hero when the artwork URL is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppHero(
            tag: 'cover',
            url: '',
            radius: 12,
            child: SizedBox.square(dimension: 40),
          ),
        ),
      );
      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('renders no Hero when motion is reduced', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const AppHero(
              tag: 'x',
              radius: 12,
              child: SizedBox.square(dimension: 40),
            ),
          ),
        ),
      );
      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('flies between routes and lands without errors', (
      tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(
            body: AppHero(
              tag: 'cover',
              radius: 12,
              child: SizedBox.square(
                dimension: 48,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Hero), findsOneWidget);

      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: AppHero(
              tag: 'cover',
              radius: 24,
              child: SizedBox(
                width: 300,
                height: 200,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(Hero), findsOneWidget);
    });
  });

  group('DiscoverPlaceDetailsPage.heroGallery', () {
    SuggestedPlace place({
      required String cover,
      List<String> images = const [],
    }) {
      return SuggestedPlace(
        id: 'p1',
        name: 'Lotus',
        area: 'Palm',
        vibe: OutingVibe.food,
        coverImageUrl: cover,
        images: [for (final url in images) DiscoverPlaceImage(imageUrl: url)],
      );
    }

    test('matching cover stays at its gallery index', () {
      final laidOut = DiscoverPlaceDetailsPage.heroGallery(
        place: place(cover: 'cover.jpg', images: ['cover.jpg', 'menu.jpg']),
      );
      expect(laidOut.coverIndex, 0);
      expect(laidOut.gallery.length, 2);
    });

    test('live-API gallery that omits the card cover prepends it', () {
      final laidOut = DiscoverPlaceDetailsPage.heroGallery(
        place: place(cover: 'thumb.jpg', images: ['wide.jpg', 'menu.jpg']),
        tappedCoverUrl: 'thumb.jpg',
      );
      expect(laidOut.coverIndex, 0);
      expect(laidOut.gallery.first.imageUrl, 'thumb.jpg');
      expect(laidOut.gallery.length, 3);
    });

    test('empty cover skips the Hero slot', () {
      final laidOut = DiscoverPlaceDetailsPage.heroGallery(
        place: place(cover: '', images: ['wide.jpg']),
        tappedCoverUrl: '',
      );
      expect(laidOut.coverIndex, -1);
    });
  });

  group('AppBottomNavLayout.swapDirection', () {
    test('higher index enters from the end side', () {
      expect(
        AppBottomNavLayout.swapDirection(
          from: 0,
          to: 1,
          textDirection: TextDirection.ltr,
        ),
        1,
      );
      expect(
        AppBottomNavLayout.swapDirection(
          from: 0,
          to: 1,
          textDirection: TextDirection.rtl,
        ),
        -1,
      );
    });

    test('lower index enters from the start side', () {
      expect(
        AppBottomNavLayout.swapDirection(
          from: 2,
          to: 0,
          textDirection: TextDirection.ltr,
        ),
        -1,
      );
      expect(
        AppBottomNavLayout.swapDirection(
          from: 2,
          to: 0,
          textDirection: TextDirection.rtl,
        ),
        1,
      );
    });
  });

  group('AppPageTransition', () {
    Widget host(TextDirection direction, AnimationController controller) {
      return Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) => AppPageTransition().buildTransition(
              context,
              null,
              null,
              controller,
              const AlwaysStoppedAnimation(0),
              const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    testWidgets('incoming page enters from the end side', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: AppMotion.emphasis,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(host(TextDirection.ltr, controller));
      var enter = tester
          .widgetList<SlideTransition>(find.byType(SlideTransition))
          .last;
      expect(enter.position.value.dx, greaterThan(0));

      await tester.pumpWidget(host(TextDirection.rtl, controller));
      enter = tester
          .widgetList<SlideTransition>(find.byType(SlideTransition))
          .last;
      expect(enter.position.value.dx, lessThan(0));
    });

    testWidgets('survives a full push-pop without ticker leaks', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: tester,
        duration: AppMotion.emphasis,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(host(TextDirection.ltr, controller));
      controller.forward();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      controller.reverse();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('is a no-op when motion is reduced', (tester) async {
      final controller = AnimationController(vsync: tester);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => AppPageTransition().buildTransition(
                context,
                null,
                null,
                controller,
                const AlwaysStoppedAnimation(0),
                const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SlideTransition), findsNothing);
      expect(find.byType(FadeTransition), findsNothing);
    });
  });

  group('AppFadeSwitcher', () {
    testWidgets('skips transitions when motion is reduced', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AppFadeSwitcher(child: Text('a', key: ValueKey('a'))),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AppFadeSwitcher),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('crossfades only when the key changes', (tester) async {
      Future<void> pump(String text, String key) {
        return tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.ltr,
              child: AppFadeSwitcher(child: Text(text, key: ValueKey(key))),
            ),
          ),
        );
      }

      await pump('a', 'k');
      await tester.pumpAndSettle();
      // Same key, new content: no outgoing child is kept around.
      await pump('b', 'k');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('a'), findsNothing);
      expect(find.text('b'), findsOneWidget);

      // New key: both states coexist mid-transition.
      await pump('c', 'k2');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('b'), findsNothing);
    });
  });

  group('AppPressable', () {
    testWidgets('scales down while pressed and restores on release', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AppPressable(
              onTap: () => taps++,
              child: const SizedBox.square(dimension: 80),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppPressable)),
      );
      await tester.pump(AppMotion.press);
      final pressed = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(pressed.scale, AppMotion.pressScale);

      await gesture.up();
      await tester.pumpAndSettle();
      final released = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(released.scale, 1);
      expect(taps, 1);
    });
  });
}
