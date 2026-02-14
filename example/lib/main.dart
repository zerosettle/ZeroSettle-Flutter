import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import 'app_state.dart';
import 'iap_environment.dart';
import 'screens/home_screen.dart';
import 'screens/store_screen.dart';
import 'screens/entitlements_screen.dart';
import 'screens/settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _envNotifier = IAPEnvironmentNotifier(IAPEnvironment.sandbox);
    _loadEnvironmentAndBoot();
  }

  @override
  void dispose() {
    _entitlementSub?.cancel();
    _envNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadEnvironmentAndBoot() async {
    final env = await IAPEnvironment.load();
    _envNotifier.value = env;
    setState(() => _envLoaded = true);
    await _configureAndBootstrap(env);
  }

  Future<void> _configureAndBootstrap(IAPEnvironment env) async {
    _appState.setLoading(true);
    _appState.setError(null);

    try {
      // 1. Set base URL override (before configure)
      await ZeroSettle.instance.setBaseUrlOverride(env.baseUrlOverride);

      // 2. Configure
      await ZeroSettle.instance.configure(publishableKey: env.publishableKey);

      // 3. Listen to entitlement updates
      _entitlementSub?.cancel();
      _entitlementSub =
          ZeroSettle.instance.entitlementUpdates.listen((entitlements) {
        _appState.setEntitlements(entitlements);
      });

      // 4. Bootstrap
      final catalog =
          await ZeroSettle.instance.bootstrap(userId: _appState.userId);
      _appState.setProducts(catalog.products);
      _appState.setRemoteConfig(catalog.config);
      _appState.setInitialized(true);

      // 5. Restore entitlements
      try {
        final entitlements = await ZeroSettle.instance
            .restoreEntitlements(userId: _appState.userId);
        _appState.setEntitlements(entitlements);
      } catch (_) {
        // Non-fatal: entitlements may be empty for new users
      }
    } on ZSException catch (e) {
      _appState.setError(e.message);
    } finally {
      _appState.setLoading(false);
    }
  }

  Future<void> _switchEnvironment(IAPEnvironment env) async {
    await _envNotifier.switchTo(env);
    _appState.setInitialized(false);
    _appState.setProducts([]);
    _appState.setEntitlements([]);
    await _configureAndBootstrap(env);
  }

  @override
  Widget build(BuildContext context) {
    if (!_envLoaded) {
      return _buildLoadingScreen(context);
    }

    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
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
              ),
              StoreScreen(appState: _appState),
              EntitlementsScreen(appState: _appState),
              SettingsScreen(
                appState: _appState,
                envNotifier: _envNotifier,
                onSwitchEnvironment: _switchEnvironment,
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
