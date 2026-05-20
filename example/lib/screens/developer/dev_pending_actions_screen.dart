import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Developer inspector for backend-driven pending actions.
///
/// Shows all [PendingAction]s in the SDK's reactive list, live-updating via
/// [ZeroSettle.instance.pendingActionsUpdates]. Also embeds a
/// [ZeroSettlePendingActionBanner] at the top (the native Android banner;
/// renders [SizedBox.shrink] on iOS).
///
/// Each action renders in a [Card] with its [PendingAction.userMessage] and a
/// "Dismiss" button that calls [ZeroSettle.instance.dismissPendingAction].
///
/// Mirrors [PendingActionsScreen.kt] from the JustOne Android sample.
class DevPendingActionsScreen extends StatefulWidget {
  const DevPendingActionsScreen({super.key});

  @override
  State<DevPendingActionsScreen> createState() =>
      _DevPendingActionsScreenState();
}

class _DevPendingActionsScreenState extends State<DevPendingActionsScreen> {
  /// Seed from the last [ZeroSettle.instance.getPendingActions] call.
  List<PendingAction>? _seed;

  /// Per-action dismiss-in-flight guard: keyed by transactionId.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    ZeroSettle.instance
        .getPendingActions()
        .then((v) {
          if (mounted) setState(() => _seed = v);
        })
        .catchError((_) {});
  }

  Future<void> _dismiss(BuildContext ctx, String transactionId) async {
    if (_busy.contains(transactionId)) return;
    setState(() => _busy.add(transactionId));
    try {
      await ZeroSettle.instance.dismissPendingAction(
        transactionId: transactionId,
      );
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Action dismissed')),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Dismiss failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(transactionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending actions')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Native Android banner (SizedBox.shrink on iOS).
          const ZeroSettlePendingActionBanner(),

          Expanded(
            child: StreamBuilder<List<PendingAction>>(
              stream: ZeroSettle.instance.pendingActionsUpdates,
              builder: (ctx, snap) {
                final actions = snap.data ?? _seed ?? const <PendingAction>[];

                if (actions.isEmpty) {
                  return const Center(child: Text('No pending actions'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: actions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final action = actions[index];
                    return _PendingActionCard(
                      action: action,
                      isBusy: _busy.contains(action.transactionId),
                      onDismiss: () => _dismiss(context, action.transactionId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card widget
// ---------------------------------------------------------------------------

class _PendingActionCard extends StatelessWidget {
  final PendingAction action;
  final bool isBusy;
  final VoidCallback onDismiss;

  const _PendingActionCard({
    required this.action,
    required this.isBusy,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Type label + extra fields from sealed subtypes.
    final String typeLabel;
    final List<Widget> extraRows;

    switch (action) {
      case final PendingActionMigrationCompletedInfo a:
        typeLabel = 'Migration Completed Info';
        extraRows = [
          if (a.playAccessEndsAt != null)
            _row(context, 'playAccessEndsAt', a.playAccessEndsAt!),
          if (a.newSubscriptionPriceCents != null)
            _row(context, 'price', '${a.newSubscriptionPriceCents} ${a.newSubscriptionCurrency ?? ''}'),
          if (a.newSubscriptionInterval != null)
            _row(context, 'interval', a.newSubscriptionInterval!),
        ];
      case final PendingActionManualPlayCancel a:
        typeLabel = 'Manual Play Cancel';
        extraRows = [
          _row(context, 'deepLink', a.deepLink),
          if (a.expiresAt != null) _row(context, 'expiresAt', a.expiresAt!),
        ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(typeLabel, style: theme.textTheme.titleSmall),
                ),
                if (isBusy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(action.userMessage, style: theme.textTheme.bodyMedium),
            _row(context, 'transactionId', action.transactionId),
            ...extraRows,
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: isBusy ? null : onDismiss,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final baseStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: baseStyle,
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
}
