import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import 'app/app_routes.dart';
import 'app/app_theme.dart';
import 'app/inherited_just_one.dart';
import 'app_environment.dart';
import 'data/database.dart';
import 'data/user_prefs.dart';
import 'domain/premium_status.dart';
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

  // 2. ZeroSettle SDK. Resolve the persisted environment (or the default
  //    for a fresh install) and configure against it. The user can switch
  //    environments from the create-user screen's segmented control.
  //
  //    configure() throws if the publishable key isn't a real
  //    `zs_pk_live_`/`zs_pk_test_` value, so skip it when the resolved env
  //    has no key issued yet (e.g. the default `prod`) — otherwise a fresh
  //    install crashes here before runApp(). The create-user screen surfaces
  //    the missing key and lets the user pick a usable environment.
  final env = await AppEnvironment.load();
  if (env.hasKey) {
    try {
      await ZeroSettle.instance.setBaseUrlOverride(env.baseUrl);
      await ZeroSettle.instance.configure(publishableKey: env.publishableKey);
    } catch (e) {
      // Non-fatal at startup; the env picker can re-configure. Logged so a
      // launch-time SDK failure is visible (it leaves products/entitlements
      // unloaded — e.g. an empty paywall).
      debugPrint('[ZeroSettle] configure() failed at startup: $e');
    }
  }

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
    } catch (e) {
      // Non-fatal on launch; the user can re-onboard. Logged so a failed
      // identify() is visible — it leaves the product catalog unfetched,
      // which surfaces downstream as an empty paywall / empty shop.
      debugPrint('[ZeroSettle] identify() failed at launch: $e');
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
