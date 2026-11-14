import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.surface,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.contentMaxWidth.clamp(0, 560),
          ),
          child: ListView(
            padding: Responsive.pagePadding(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
      ),
    ),
  );
}
