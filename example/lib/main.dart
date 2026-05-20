import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import 'app/app_routes.dart';
import 'app/app_theme.dart';
import 'app/inherited_just_one.dart';
import 'data/database.dart';
import 'data/user_prefs.dart';
import 'domain/premium_status.dart';
import 'iap_environment.dart';
import 'notifications/notification_service.dart';

// ---------------------------------------------------------------------------
// Deep-link / web-checkout return handling
// ---------------------------------------------------------------------------
// ZeroSettle.instance.purchase() is fully awaitable on both platforms.
// On Android, ZeroSettleHostActivity handles the Custom Tab return internally
// and resolves the Future; no app-side onNewIntent / deep-link wiring is
// required in this sample.
// On iOS, the SDK exposes handleUniversalLink(String url) → Future<bool>
// for apps that need to explicitly forward universal-link callbacks (e.g. when
// the host app processes all universal links centrally).  This sample does NOT
// need it because purchase() self-resolves — the awaited call in
// DualPriceButtons completes once the user returns from the web checkout
// Custom Tab / SFSafariViewController, regardless of platform.
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Local-only services.
  final prefs = await UserPrefs.create();
  final db = AppDatabase();
  final notifications = NotificationService();
  await notifications.init();

  // 2. ZeroSettle SDK. Use the existing env roster.
  // IAPEnvironment has no synchronous activeEnvironment getter — load() is
  // the canonical way to resolve the persisted (or default-first-enabled) env.
  final env = await IAPEnvironment.load();
  if (env.baseUrlOverride != null) {
    await ZeroSettle.instance.setBaseUrlOverride(env.baseUrlOverride);
  }
  await ZeroSettle.instance.configure(
    publishableKey: env.publishableKey,
  );

  // 3. If a userId was persisted from a prior launch, re-identify so the
  //    SDK is bootstrapped without re-prompting the user.
  final persistedId = prefs.userId;
  final persistedName = prefs.displayName;
  final isOnboarded = persistedId != null && persistedId.isNotEmpty;
  if (isOnboarded) {
    try {
      await ZeroSettle.instance.identify(
        Identity.user(id: persistedId, name: persistedName),
      );
    } catch (_) {
      // Non-fatal on launch; the user can re-onboard.
    }
  }

  // 4. Determine whether to route the user to the launch paywall on startup.
  //    Condition: onboarded user who has never dismissed the paywall AND is
  //    not currently premium.
  String? initialLocationOverride;
  if (isOnboarded && prefs.paywallDismissedAt == null) {
    bool notPremium = true;
    try {
      final entitlements = await ZeroSettle.instance.getEntitlements();
      notPremium = !isPremium(entitlements);
    } catch (_) {
      // Treat errors as "not premium" — show the paywall conservatively.
    }
    if (notPremium) {
      initialLocationOverride = Routes.launchPaywall;
    }
  }

  runApp(JustOneApp(
    scope: JustOneScope(db: db, prefs: prefs, notifications: notifications),
    startAtHome: isOnboarded,
    initialLocationOverride: initialLocationOverride,
  ));
}

class JustOneApp extends StatelessWidget {
  final JustOneScope scope;
  final bool startAtHome;
  final String? initialLocationOverride;

  const JustOneApp({
    super.key,
    required this.scope,
    required this.startAtHome,
    this.initialLocationOverride,
  });

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(
      startAtHome: startAtHome,
      initialLocationOverride: initialLocationOverride,
    );
    return InheritedJustOne(
      scope: scope,
      child: MaterialApp.router(
        title: 'JustOne',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
      ),
    );
  }
}
