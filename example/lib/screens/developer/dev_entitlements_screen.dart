import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Developer inspector for cached entitlements.
///
/// Shows the full list of [Entitlement]s returned by the SDK, live-updating
/// via [ZeroSettle.instance.entitlementUpdates]. A "Restore" AppBar action
/// triggers [ZeroSettle.instance.restoreEntitlements] and shows a SnackBar
/// with the result count (or an error message).
///
/// Mirrors [EntitlementsScreen.kt] from the JustOne Android sample.
class DevEntitlementsScreen extends StatefulWidget {
  const DevEntitlementsScreen({super.key});

  @override
  State<DevEntitlementsScreen> createState() => _DevEntitlementsScreenState();
}

class _DevEntitlementsScreenState extends State<DevEntitlementsScreen> {
  /// Seed from the last [ZeroSettle.instance.getEntitlements] call, used as
  /// the StreamBuilder fallback before the stream emits its first event.
  List<Entitlement>? _seed;

  /// Guards against double-taps on "Restore" while a call is in-flight.
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    ZeroSettle.instance
        .getEntitlements()
        .then((v) {
          if (mounted) setState(() => _seed = v);
        })
        .catchError((_) {});
  }

  Future<void> _restore(BuildContext ctx) async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      final result = await ZeroSettle.instance.restoreEntitlements();
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Restored ${result.length} entitlement(s)')),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entitlements'),
        actions: [
          TextButton(
            onPressed: _restoring ? null : () => _restore(context),
            child: const Text('Restore'),
          ),
        ],
      ),
      body: StreamBuilder<List<Entitlement>>(
        stream: ZeroSettle.instance.entitlementUpdates,
        builder: (ctx, snap) {
          final entitlements = snap.data ?? _seed ?? const <Entitlement>[];

          if (entitlements.isEmpty) {
            return const Center(child: Text('No entitlements'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entitlements.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) =>
                _EntitlementCard(entitlement: entitlements[index]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card widget
// ---------------------------------------------------------------------------

class _EntitlementCard extends StatelessWidget {
  final Entitlement entitlement;
  const _EntitlementCard({required this.entitlement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entitlement;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.productId, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _row('source', e.source.rawValue),
            _row('status', e.status ?? 'n/a'),
            _row('isActive', '${e.isActive}'),
            _row('willRenew', '${e.willRenew}'),
            _row('isTrial', '${e.isTrial}'),
            _row('expiresAt', _fmt(e.expiresAt)),
            if (e.pausedAt != null) _row('pausedAt', _fmt(e.pausedAt)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? dt) =>
      dt != null
          ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
          : 'n/a';
}
