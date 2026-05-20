import 'package:flutter/material.dart';

import 'env_switcher_screen.dart';

/// Developer tools shell screen.
///
/// A [ListView] of 7 sub-screen entry [ListTile]s. Each tile pushes its
/// target via [Navigator.push] (not go_router — developer sub-screens are
/// outside the app's route graph). Sub-screens not yet built (Tasks 15–17)
/// use the private [_ComingSoon] placeholder.
///
/// Mirrors [DeveloperScreen.kt] from the JustOne Android sample.
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_DevEntry>[
      _DevEntry(
        label: 'Environment',
        screen: const EnvSwitcherScreen(),
      ),
      _DevEntry(
        label: 'Entitlements',
        screen: const _ComingSoon('Entitlements'),
      ),
      _DevEntry(
        label: 'Offers',
        screen: const _ComingSoon('Offers'),
      ),
      _DevEntry(
        label: 'Pending actions',
        screen: const _ComingSoon('Pending actions'),
      ),
      _DevEntry(
        label: 'Cancel flow',
        screen: const _ComingSoon('Cancel flow'),
      ),
      _DevEntry(
        label: 'Upgrade offer',
        screen: const _ComingSoon('Upgrade offer'),
      ),
      _DevEntry(
        label: 'Debug',
        screen: const _ComingSoon('Debug'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Developer')),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
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

// ---------------------------------------------------------------------------
// Placeholder for sub-screens not yet implemented (Tasks 15–17).
// ---------------------------------------------------------------------------

class _ComingSoon extends StatelessWidget {
  final String name;
  const _ComingSoon(this.name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
