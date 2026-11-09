import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';

void main() {
  test(
    'outings and special occasions select distinct bundled cover art',
    () async {
      expect(OutingOccasion.none.coverArt, PlanningCoverArt.outing);
      expect(OutingOccasion.birthday.coverArt, PlanningCoverArt.birthday);
      expect(OutingOccasion.wedding.coverArt, PlanningCoverArt.wedding);

      for (final art in PlanningCoverArt.values) {
        final svg = await rootBundle.loadString(
          'assets/covers/${art.name}.svg',
        );
        expect(svg, contains('<svg'));
      }
    },
  );

  testWidgets('blank covers render SVG at thumbnail and banner sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PlanningCover(
                url: ' ',
                art: PlanningCoverArt.group,
                width: 54,
                height: 54,
              ),
              PlanningCover(
                url: '',
                art: PlanningCoverArt.wedding,
                width: double.infinity,
                height: 144,
              ),
            ],
          ),
        ),
      ),
    );

    final svg = find.byType(SvgPicture);
    expect(svg, findsNWidgets(2));
    expect(tester.getSize(svg.first).width, lessThan(54));
    expect(tester.getSize(svg.last).height, lessThan(144));
    expect(tester.takeException(), isNull);
  });
}
