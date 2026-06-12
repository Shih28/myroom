import 'dart:async';

import 'package:flutter/foundation.dart';

/// Standard go_router adapter: calls [notifyListeners] on each stream event so
/// the router re-evaluates `redirect` when auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
