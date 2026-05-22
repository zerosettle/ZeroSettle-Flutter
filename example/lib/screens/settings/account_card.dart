import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../app/routes.dart';
import '../../app_environment.dart';

/// Account info card shown at the top of [SettingsScreen].
///
/// Displays the current user ID and SDK version (via [FutureBuilder] — these
/// stay in their loading state under test since the method channel never
/// completes in that environment, which is fine). Always renders the static
/// "Restore purchases" and "Sign out" buttons.
///
/// The user-id / SDK-version futures are created once in [initState] and
/// cached — passing `getCurrentUserId()` inline to a [FutureBuilder] would
/// spawn a fresh Future on every `build`, resetting the builder to its
/// `waiting` state and flickering. Mirrors the `StatefulWidget` pattern in
/// sibling screens (`ConsumableShopScreen`, `LaunchPaywallScreen`).
///
/// Mirrors the `AccountCard` Composable in the JustOne Android sample.
class AccountCard extends StatefulWidget {
  const AccountCard({super.key});

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  late final Future<String?> _userIdFuture;
  late final Future<String> _sdkVersionFuture;

  @override
  void initState() {
    super.initState();
    _userIdFuture = ZeroSettle.instance.getCurrentUserId();
    _sdkVersionFuture = ZeroSettle.instance.getSdkVersion();
  }

  Future<void> _restorePurchases(BuildContext context) async {
    try {
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
    } on ZeroSettleException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    // Capture the scope references before any await so cleanup never depends
    // on `context` still being mounted.
    final scope = InheritedJustOne.of(context);
    final prefs = scope.prefs;
    final identityStore = scope.identityStore;
    try {
      await ZeroSettle.instance.logout();
    } on ZeroSettleException catch (e) {
      // Surface the error if we can, but DON'T return — a failed server
      // logout must not trap the user on the settings screen.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
    // Always clear local state; navigate whenever the context is still alive.
    // Clear the *active* identity for this env (routing falls back to
    // onboarding) but keep the saved identity so it can be re-selected.
    await prefs.clearAll();
    final env = await AppEnvironment.load();
    await identityStore.clearActive(env.name);
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

            // User ID row — surfaced prominently so the active identity is
            // always visible (matters when switching between test users).
            Text(
              'Signed in as',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            FutureBuilder<String?>(
              future: _userIdFuture,
              builder: (context, snapshot) {
                final userId = snapshot.data;
                return Text(
                  userId == null || userId.isEmpty ? 'Not identified' : userId,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // SDK version row
            FutureBuilder<String>(
              future: _sdkVersionFuture,
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
