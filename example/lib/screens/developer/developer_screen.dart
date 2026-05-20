import 'package:flutter/material.dart';

import 'dev_cancel_debug_screen.dart';
import 'dev_debug_screen.dart';
import 'dev_entitlements_screen.dart';
import 'dev_offers_screen.dart';
import 'dev_pending_actions_screen.dart';
import 'dev_upgrade_offer_screen.dart';
import 'env_switcher_screen.dart';

/// Developer tools shell screen.
///
/// A [ListView] of 7 sub-screen entry [ListTile]s. Each tile pushes its
/// target via [Navigator.push] (not go_router — developer sub-screens are
/// outside the app's route graph).
///
/// Mirrors [DeveloperScreen.kt] from the JustOne Android sample.
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  /// The 7 developer sub-screen entries, in display order. Hoisted to a
  /// `static const` so it isn't rebuilt on every [build].
  static const List<_DevEntry> _entries = [
    _DevEntry(
      label: 'Environment',
      screen: EnvSwitcherScreen(),
    ),
    _DevEntry(
      label: 'Entitlements',
      screen: DevEntitlementsScreen(),
    ),
    _DevEntry(
      label: 'Offers',
      screen: DevOffersScreen(),
    ),
    _DevEntry(
      label: 'Pending actions',
      screen: DevPendingActionsScreen(),
    ),
    _DevEntry(
      label: 'Cancel flow',
      screen: DevCancelDebugScreen(),
    ),
    _DevEntry(
      label: 'Upgrade offer',
      screen: DevUpgradeOfferScreen(),
    ),
    _DevEntry(
      label: 'Debug',
      screen: DevDebugScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer')),
      body: ListView.separated(
        itemCount: _entries.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return ListTile(
            title: Text(entry.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => entry.screen,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class _DevEntry {
  final String label;
  final Widget screen;
  const _DevEntry({required this.label, required this.screen});
}
