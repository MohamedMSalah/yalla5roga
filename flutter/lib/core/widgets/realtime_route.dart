import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';

/// Keeps route ownership out of rendering and releases covered routes too.
mixin RealtimeRoute<T extends StatefulWidget> on State<T> {
  AppSyncProvider? _realtimeSync;
  bool _hasBeenVisible = false;
  String? get realtimeGroupId => null;
  String? get realtimeOutingId => null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _realtimeSync ??= context.read<AppSyncProvider>();
    if (ModalRoute.isCurrentOf(context) ?? true) {
      _realtimeSync!.retainRealtime(
        this,
        groupId: realtimeGroupId,
        outingId: realtimeOutingId,
        // Initial route hydration already belongs to the existing page loader.
        revalidate: _hasBeenVisible,
      );
      _hasBeenVisible = true;
    } else {
      _realtimeSync!.releaseRealtime(this);
    }
  }

  @override
  void dispose() {
    _realtimeSync?.releaseRealtime(this);
    super.dispose();
  }
}
