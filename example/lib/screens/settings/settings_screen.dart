import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../widgets/offer_tip_card.dart';
import 'account_card.dart';
import 'reminder_card.dart';
import 'streak_saver_card.dart';
import 'subscription_card.dart';

/// Top-level settings screen for JustOne.
///
/// Renders a [ListView] of cards: [AccountCard], [SubscriptionCard],
/// [StreakSaverCard], [ReminderCard], and an [OfferTipCard] slot.
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
          const SizedBox(height: 12),
          const StreakSaverCard(),
          const SizedBox(height: 12),
          const ReminderCard(),
          const SizedBox(height: 12),
          const OfferTipCard(),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Developer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.developer),
            ),
          ),
        ],
      ),
    );
  }
}
