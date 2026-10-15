import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_nav.dart';

class AppBottomNavLayout extends StatelessWidget {
  const AppBottomNavLayout({
    super.key,
    required this.pages,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<Widget> pages;
  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: AppBottomNav(
        items: items,
        currentIndex: currentIndex,
        onChanged: onChanged,
      ),
    );
  }
}
