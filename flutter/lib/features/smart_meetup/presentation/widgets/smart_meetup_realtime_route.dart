import 'package:flutter/widgets.dart';

/// Binds the current planning or results view to the shared connection.
mixin SmartMeetupRealtimeRoute<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  bool _visible = false;
  bool _foreground = false;

  void setMeetupRouteActive(bool active);

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = ModalRoute.isCurrentOf(context) ?? true;
    setMeetupRouteActive(_visible && _foreground);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    setMeetupRouteActive(_visible && _foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
