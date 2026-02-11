import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  runApp(const ZeroSettleExampleApp());
}

class ZeroSettleExampleApp extends StatelessWidget {
  const ZeroSettleExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroSettle Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Pass via: flutter run --dart-define=ZS_PUBLISHABLE_KEY=zs_pk_test_xxx
  static const _publishableKey = String.fromEnvironment('ZS_PUBLISHABLE_KEY');
  static const _userId = 'flutter_example_user';

  bool _configured = false;
  bool _loading = false;
  String? _error;
  List<ZSProduct> _products = [];
  List<Entitlement> _entitlements = [];
  StreamSubscription<List<Entitlement>>? _entitlementSub;

  @override
  void dispose() {
    _entitlementSub?.cancel();
    super.dispose();
  }

  Future<void> _configure() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ZeroSettle.instance.configure(publishableKey: _publishableKey);
      _entitlementSub = ZeroSettle.instance.entitlementUpdates.listen((entitlements) {
        if (mounted) {
          setState(() => _entitlements = entitlements);
        }
      });
      setState(() => _configured = true);
    } on ZSException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _bootstrap() async {
    setState(() { _loading = true; _error = null; });
    try {
      final catalog = await ZeroSettle.instance.bootstrap(userId: _userId);
      setState(() => _products = catalog.products);
    } on ZSException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _presentPaymentSheet(ZSProduct product) async {
    setState(() { _error = null; });
    try {
      final txn = await ZeroSettle.instance.presentPaymentSheet(
        productId: product.id,
        userId: _userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase complete: ${txn.id}')),
        );
      }
      // Refresh entitlements after purchase
      final entitlements = await ZeroSettle.instance.restoreEntitlements(userId: _userId);
      setState(() => _entitlements = entitlements);
    } on ZSCancelledException {
      // User dismissed — no action needed
    } on ZSCheckoutFailedException catch (e) {
      setState(() => _error = e.message);
    } on ZSException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _restoreEntitlements() async {
    setState(() { _loading = true; _error = null; });
    try {
      final entitlements = await ZeroSettle.instance.restoreEntitlements(userId: _userId);
      setState(() => _entitlements = entitlements);
    } on ZSException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _manageSubscription() async {
    try {
      await ZeroSettle.instance.showManageSubscription(userId: _userId);
    } on ZSException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZeroSettle Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -- Status --
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),

          if (_loading) const LinearProgressIndicator(),

          const SizedBox(height: 8),

          if (_publishableKey.isEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Missing ZS_PUBLISHABLE_KEY. Run with:\nflutter run --dart-define=ZS_PUBLISHABLE_KEY=zs_pk_test_xxx',
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
            ),

          // -- Configure --
          if (!_configured) ...[
            FilledButton(
              onPressed: _loading || _publishableKey.isEmpty ? null : _configure,
              child: const Text('Configure SDK'),
            ),
          ] else ...[
            // -- Bootstrap --
            FilledButton(
              onPressed: _loading ? null : _bootstrap,
              child: const Text('Fetch Products'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : _restoreEntitlements,
              child: const Text('Restore Entitlements'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _manageSubscription,
              child: const Text('Manage Subscription'),
            ),
          ],

          const SizedBox(height: 24),

          // -- Products --
          if (_products.isNotEmpty) ...[
            Text('Products', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._products.map((product) => Card(
              child: ListTile(
                title: Text(product.displayName),
                subtitle: Text(
                  '${product.webPrice.formatted}'
                  '${product.savingsPercent != null ? " (Save ${product.savingsPercent}%)" : ""}',
                ),
                trailing: FilledButton(
                  onPressed: () => _presentPaymentSheet(product),
                  child: const Text('Buy'),
                ),
              ),
            )),
          ],

          const SizedBox(height: 24),

          // -- Entitlements --
          if (_entitlements.isNotEmpty) ...[
            Text('Entitlements', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._entitlements.map((ent) => Card(
              color: ent.isActive
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                title: Text(ent.productId),
                subtitle: Text(
                  '${ent.source.rawValue} · ${ent.isActive ? "Active" : "Inactive"}'
                  '${ent.expiresAt != null ? " · Expires ${ent.expiresAt}" : ""}',
                ),
                leading: Icon(
                  ent.isActive ? Icons.check_circle : Icons.cancel,
                  color: ent.isActive ? Colors.green : Colors.red,
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}
