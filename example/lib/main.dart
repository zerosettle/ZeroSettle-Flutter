import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import 'app_state.dart';
import 'debug/debug_account.dart';
import 'iap_environment.dart';
import 'identity_choice.dart';
import 'screens/entitlements_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/store_screen.dart';
import 'screens/transactions_screen.dart';
import 'widgets/identity_choice_sheet.dart';

void main() {
  runApp(const ZeroSettleExampleApp());
}

class ZeroSettleExampleApp extends StatelessWidget {
  const ZeroSettleExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroSettle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _appState = AppState();
  late final IAPEnvironmentNotifier _envNotifier;
  int _currentTab = 0;
  StreamSubscription<List<Entitlement>>? _entitlementSub;
  bool _envLoaded = false;
  bool _identityPromptShown = false;

  @override
  void initState() {
    super.initState();
    _envNotifier = IAPEnvironmentNotifier(IAPEnvironment.sandbox);
    _bootstrapApp();
  }

  @override
  void dispose() {
    _entitlementSub?.cancel();
    _envNotifier.dispose();
    super.dispose();
  }

  Future<void> _bootstrapApp() async {
    final env = await IAPEnvironment.load();
    debugPrint('[ZS] bootstrap: loaded env=${env.name}');
    _envNotifier.value = env;
    setState(() => _envLoaded = true);

    await _configureSdk(env);

    // Replay persisted identity choice, or prompt the user to pick one.
    final stored = await IdentityChoiceStore.load();
    debugPrint('[ZS] bootstrap: persisted identity=${stored?.runtimeType ?? 'none'}');
    if (stored != null) {
      await _applyIdentity(stored, persist: false);
    } else if (mounted) {
      // Defer the sheet to after first frame so the AppShell is mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptForIdentity());
    }
  }

  Future<void> _configureSdk(IAPEnvironment env) async {
    debugPrint('[ZS] configure: start env=${env.name} baseUrl=${env.baseUrlOverride ?? 'default'} key=${env.truncatedKey}');
    _appState.setLoading(true);
    _appState.setError(null);

    try {
      // Set base URL override (must run before configure).
      await ZeroSettle.instance.setBaseUrlOverride(env.baseUrlOverride);

      // 1.3.0 configuration:
      // - syncStoreKitTransactions: forwards native StoreKit purchases to ZeroSettle.
      //   Set to false if you use RevenueCat or another aggregator.
      // - appleMerchantId: your Apple Pay merchant identifier. The SDK falls
      //   back to the dashboard-configured merchant if you omit this.
      // - preloadCheckout / maxPreloadedWebViews: pre-render WKWebViews so the
      //   first checkout opens with no network delay. Each pre-rendered view
      //   costs ~3-7 MB; cap with maxPreloadedWebViews or pass 0 to disable.
      await ZeroSettle.instance.configure(
        publishableKey: env.publishableKey,
        syncStoreKitTransactions: true,
        appleMerchantId: 'merchant.com.example.zerosettle.flutter',
        preloadCheckout: true,
        maxPreloadedWebViews: 3,
      );

      final isConfigured = await ZeroSettle.instance.getIsConfigured();
      debugPrint('[ZS] configure: done. SDK reports isConfigured=$isConfigured');

      // Subscribe to entitlement updates from the native SDK.
      _entitlementSub?.cancel();
      _entitlementSub =
          ZeroSettle.instance.entitlementUpdates.listen((entitlements) {
        _appState.setEntitlements(entitlements);
      });
    } on ZeroSettleException catch (e) {
      debugPrint('[ZS] configure: FAILED — ${e.message}');
      _appState.setError(e.message);
    } finally {
      _appState.setLoading(false);
    }
  }

  /// Apply an identity to the SDK and refresh user-scoped state.
  Future<void> _applyIdentity(Identity identity, {bool persist = true}) async {
    debugPrint('[ZS] identify: ${identity.runtimeType} (persist=$persist)');
    final preCheck = await ZeroSettle.instance.getIsConfigured();
    debugPrint('[ZS] identify: pre-call isConfigured=$preCheck');
    _appState.setLoading(true);
    _appState.setError(null);
    _appState.setIdentity(identity);

    try {
      final catalog = await ZeroSettle.instance.identify(identity);
      debugPrint('[ZS] identify: success, catalog=${catalog == null ? 'null (deferred)' : '${catalog.products.length} products'}');
      if (catalog != null) {
        _appState.setProducts(catalog.products);
        _appState.setRemoteConfig(catalog.config);
      }
      _appState.setInitialized(true);

      // restoreEntitlements requires a non-deferred identity. Skip on deferred.
      if (identity is! IdentityDeferred) {
        try {
          final entitlements = await ZeroSettle.instance.restoreEntitlements();
          _appState.setEntitlements(entitlements);
        } catch (_) {
          // Non-fatal: entitlements may be empty for new users.
        }
      }
    } on ZeroSettleException catch (e) {
      debugPrint('[ZS] identify: FAILED — ${e.runtimeType}: ${e.message}');
      _appState.setError(e.message);
    } finally {
      _appState.setLoading(false);
    }

    if (persist) {
      await IdentityChoiceStore.save(identity);
    }
  }

  Future<void> _promptForIdentity() async {
    if (_identityPromptShown || !mounted) return;
    _identityPromptShown = true;

    Identity? choice;
    while (choice == null && mounted) {
      choice = await IdentityChoiceSheet.show(
        context,
        dismissible: false,
        current: _appState.currentIdentity,
      );
    }
    if (choice == null) return; // unmounted
    await _applyIdentity(choice);
    _identityPromptShown = false;
  }

  /// Public entry point used by [SettingsScreen] for switching identity.
  Future<void> switchIdentity() async {
    final choice = await IdentityChoiceSheet.show(
      context,
      dismissible: true,
      current: _appState.currentIdentity,
    );
    if (choice != null) {
      await _applyIdentity(choice);
    }
  }

  /// Public entry point used by [SettingsScreen] for sign-out.
  Future<void> signOut() async {
    try {
      await ZeroSettle.instance.logout();
    } on ZeroSettleException {
      // Logout failures are non-fatal — clear local state regardless.
    }
    await IdentityChoiceStore.clear();
    _appState.setIdentity(null);
    _appState.setInitialized(false);
    _appState.setProducts([]);
    _appState.setEntitlements([]);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptForIdentity());
    }
  }

  Future<void> _switchEnvironment(IAPEnvironment env) async {
    await _envNotifier.switchTo(env);
    _appState.setInitialized(false);
    _appState.setProducts([]);
    _appState.setEntitlements([]);
    await _configureSdk(env);

    // Re-apply identity to refresh products/entitlements against the new env.
    final identity = _appState.currentIdentity;
    if (identity != null) {
      await _applyIdentity(identity, persist: false);
    }
  }

  // -- Debug-only callbacks (consumed by DebugSettingsScreen). --
  //
  // These bypass the user-facing identity sheet so engineers can rebootstrap
  // the SDK at runtime without UI noise. The methods are still safe in
  // release because the screen that calls them is gated behind kDebugMode.

  /// Switch env at runtime. If [restoreIdentity] is provided, log out and
  /// re-identify as that account. Otherwise, preserve the current identity
  /// (and its persisted choice) and just re-bootstrap the SDK against the
  /// new env.
  ///
  /// Does NOT trigger the identity sheet.
  Future<void> _applyDebugEnv(
    IAPEnvironment env, {
    Identity? restoreIdentity,
  }) async {
    if (restoreIdentity != null) {
      // Caller picked an explicit account to restore in the new env. Sign
      // out, swap env, and identify as the requested account.
      try {
        await ZeroSettle.instance.logout();
      } on ZeroSettleException {
        // Non-fatal — we still want to swap env.
      }
      _appState.setIdentity(null);
      _appState.setInitialized(false);
      _appState.setProducts([]);
      _appState.setEntitlements([]);

      await _envNotifier.switchTo(env);
      await _configureSdk(env);
      await _applyIdentity(restoreIdentity);
      return;
    }

    // No explicit account to restore: keep the current identity (and its
    // persisted choice) so the user isn't surprised by an identity sheet
    // on next launch. Just re-bootstrap the SDK against the new env.
    final current = _appState.currentIdentity;
    _appState.setInitialized(false);
    _appState.setProducts([]);
    _appState.setEntitlements([]);

    await _envNotifier.switchTo(env);
    await _configureSdk(env);

    if (current != null) {
      await _applyIdentity(current, persist: false);
    }
  }

  /// Logout and identify as the user described by [account]. Persists via
  /// [IdentityChoiceStore].
  Future<void> _switchToDebugAccount(DebugAccount account) async {
    try {
      await ZeroSettle.instance.logout();
    } on ZeroSettleException {
      // Non-fatal — proceed to identify.
    }
    await _applyIdentity(
      Identity.user(id: account.id, name: account.label),
    );
  }

  /// Logout and clear local state without showing the identity sheet.
  Future<void> _debugClearIdentity() async {
    try {
      await ZeroSettle.instance.logout();
    } on ZeroSettleException {
      // Non-fatal — clear local state regardless.
    }
    await IdentityChoiceStore.clear();
    _appState.setIdentity(null);
    _appState.setInitialized(false);
    _appState.setProducts([]);
    _appState.setEntitlements([]);
  }

  @override
  Widget build(BuildContext context) {
    if (!_envLoaded) {
      return _buildLoadingScreen(context);
    }

    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        // Show the loading screen until SDK has at least been configured.
        if (!_appState.isInitialized && _appState.isLoading) {
          return _buildLoadingScreen(context);
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentTab,
            children: [
              HomeScreen(
                appState: _appState,
                onNavigateToStore: () => setState(() => _currentTab = 1),
                onSignIn: switchIdentity,
              ),
              StoreScreen(appState: _appState, onSignIn: switchIdentity),
              EntitlementsScreen(appState: _appState),
              TransactionsScreen(appState: _appState),
              SettingsScreen(
                appState: _appState,
                envNotifier: _envNotifier,
                onSwitchEnvironment: _switchEnvironment,
                onSwitchIdentity: switchIdentity,
                onSignOut: signOut,
                onApplyDebugEnv: _applyDebugEnv,
                onSwitchToDebugAccount: _switchToDebugAccount,
                onDebugClearIdentity: _debugClearIdentity,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTab,
            onDestinationSelected: (index) =>
                setState(() => _currentTab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store),
                label: 'Store',
              ),
              NavigationDestination(
                icon: Icon(Icons.verified_outlined),
                selectedIcon: Icon(Icons.verified),
                label: 'Entitlements',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Transactions',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo, Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.diamond, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'ZeroSettle',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Initializing...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
