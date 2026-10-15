import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/setting/presentation/widgets/cards/about_developer_card.dart';

class AboutDeveloperPage extends StatelessWidget {
  const AboutDeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppPageBar — about developer
      appBar: AppPageBar(title: context.l10n.aboutDeveloper),
      body: ListView(
        padding: Responsive.pagePadding(),
        children: const [
          // AboutDeveloperCard — bio and contact
          AboutDeveloperCard(),
        ],
      ),
    );
  }
}
