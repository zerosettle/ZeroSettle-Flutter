import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import 'account_card.dart';
import 'subscription_card.dart';

/// Top-level settings screen for JustOne.
///
/// Renders a [ListView] of cards, currently just [AccountCard] — the
/// remaining cards land in Tasks 10–11 (see the in-body placeholder).
///
/// A "Developer" [ListTile] is always visible at the bottom of the list
/// (no 7-tap easter egg in the sample — developer tools are always accessible).
///
/// Mirrors the `SettingsScreen` Composable in the JustOne Android sample.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const AccountCard(),
          const SizedBox(height: 12),
          const SubscriptionCard(),
          // TODO(Task 11): StreakSaverCard, ReminderCard, offer tip
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Developer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.developer),
            ),
          ),
        ],
      ),
    );
  }
}
