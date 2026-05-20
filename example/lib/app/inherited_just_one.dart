import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../data/user_prefs.dart';
import '../notifications/notification_service.dart';

/// Top-level app scope shared with screens via [InheritedJustOne].
/// Lives in its own file so screens can depend on it WITHOUT importing
/// `main.dart` — which in turn imports `app_routes.dart`, which imports
/// the screens. Decoupling here prevents a circular/dangling import graph
/// while individual screens are being built.
class JustOneScope {
  final AppDatabase db;
  final UserPrefs prefs;
  final NotificationService notifications;

  const JustOneScope({
    required this.db,
    required this.prefs,
    required this.notifications,
  });
}

class InheritedJustOne extends InheritedWidget {
  final JustOneScope scope;
  const InheritedJustOne({
    super.key,
    required this.scope,
    required super.child,
  });

  static JustOneScope of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<InheritedJustOne>();
    assert(w != null, 'InheritedJustOne not found in widget tree');
    return w!.scope;
  }

  @override
  bool updateShouldNotify(InheritedJustOne old) => old.scope != scope;
}
