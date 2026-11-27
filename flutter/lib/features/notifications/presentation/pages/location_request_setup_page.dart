import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/starting_location/presentation/widgets/starting_location_editor.dart';

class LocationRequestSetupPage extends StatelessWidget {
  const LocationRequestSetupPage({
    super.key,
    required this.sessionId,
    required this.account,
  });

  final String sessionId;
  final String account;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.meetupStartingPoint)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: ListView(
              padding: Responsive.pagePadding(),
              children: [
                if (auth.isAuthenticated && auth.user?.id == account)
                  StartingLocationEditor(
                    scope: (
                      context: StartingLocationContext.meetup,
                      id: sessionId,
                    ),
                  )
                else
                  Text(context.l10n.errorSessionExpired),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
