import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import 'app_state.dart';
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
  static const _publishableKey = String.fromEnvironment('ZS_PUBLISHABLE_KEY');

  final _appState = AppState();
  int _currentTab = 0;
  StreamSubscription<List<Entitlement>>? _entitlementSub;
  bool _initStarted = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _entitlementSub?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_publishableKey.isEmpty || _initStarted) return;
    _initStarted = true;
    _appState.setLoading(true);

    try {
      // 1. Configure
      await ZeroSettle.instance.configure(publishableKey: _publishableKey);

      // 2. Listen to entitlement updates
      _entitlementSub =
          ZeroSettle.instance.entitlementUpdates.listen((entitlements) {
        _appState.setEntitlements(entitlements);
      });

      // 3. Bootstrap
      final catalog =
          await ZeroSettle.instance.bootstrap(userId: _appState.userId, freeTrialDays: 7);
      _appState.setProducts(catalog.products);
      _appState.setRemoteConfig(catalog.config);
      _appState.setInitialized(true);

      // 4. Restore entitlements
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

  @override
  Widget build(BuildContext context) {
    if (_publishableKey.isEmpty) {
      return _buildMissingKeyScreen(context);
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
              SettingsScreen(appState: _appState),
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

  Widget _buildMissingKeyScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.key_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                'Missing Publishable Key',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Run the app with your ZeroSettle publishable key:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SelectableText(
                  'flutter run --dart-define=ZS_PUBLISHABLE_KEY=zs_pk_test_xxx',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
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
    );
  }

}
