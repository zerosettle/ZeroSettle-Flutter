import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../app/routes.dart';

/// Account info card shown at the top of [SettingsScreen].
///
/// Displays the current user ID and SDK version (via [FutureBuilder] — these
/// stay in their loading state under test since the method channel never
/// completes in that environment, which is fine). Always renders the static
/// "Restore purchases" and "Sign out" buttons.
///
/// Mirrors the `AccountCard` Composable in the JustOne Android sample.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  Future<void> _restorePurchases(BuildContext context) async {
    final results = await ZeroSettle.instance.restoreEntitlements();
    if (!context.mounted) return;
    final count = results.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'No purchases to restore.'
              : 'Restored $count entitlement${count == 1 ? '' : 's'}.',
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await ZeroSettle.instance.logout();
    if (!context.mounted) return;
    await InheritedJustOne.of(context).prefs.clearAll();
    if (!context.mounted) return;
    context.go(Routes.createUser);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Account',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // User ID row
            Text(
              'User ID',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            FutureBuilder<String?>(
              future: ZeroSettle.instance.getCurrentUserId(),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? '—',
                  style: theme.textTheme.bodyMedium,
                );
              },
            ),

            const SizedBox(height: 8),

            // SDK version row
            FutureBuilder<String>(
              future: ZeroSettle.instance.getSdkVersion(),
              builder: (context, snapshot) {
                final version = snapshot.data;
                return Text(
                  version != null ? 'Version $version' : 'Version —',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: () => _restorePurchases(context),
              child: const Text('Restore purchases'),
            ),

            const SizedBox(height: 8),

            OutlinedButton(
              onPressed: () => _signOut(context),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
