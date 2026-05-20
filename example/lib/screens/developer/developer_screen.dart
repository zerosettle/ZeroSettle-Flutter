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

  /// The 7 developer sub-screen entries, in display order. Hoisted to a
  /// `static const` so it isn't rebuilt on every [build].
  static const List<_DevEntry> _entries = [
    _DevEntry(
      label: 'Environment',
      screen: EnvSwitcherScreen(),
    ),
    _DevEntry(
      label: 'Entitlements',
      screen: _ComingSoon('Entitlements'),
    ),
    _DevEntry(
      label: 'Offers',
      screen: _ComingSoon('Offers'),
    ),
    _DevEntry(
      label: 'Pending actions',
      screen: _ComingSoon('Pending actions'),
    ),
    _DevEntry(
      label: 'Cancel flow',
      screen: _ComingSoon('Cancel flow'),
    ),
    _DevEntry(
      label: 'Upgrade offer',
      screen: _ComingSoon('Upgrade offer'),
    ),
    _DevEntry(
      label: 'Debug',
      screen: _ComingSoon('Debug'),
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

// ---------------------------------------------------------------------------
// Placeholder for sub-screens not yet implemented (Tasks 15–17).
// ---------------------------------------------------------------------------

class _ComingSoon extends StatelessWidget {
  final String name;
  // No `key` param: this private placeholder is only ever constructed via
  // `const _ComingSoon('<name>')` with no key, so a `super.key` parameter
  // would be flagged dead by the analyzer (unused_element_parameter).
  const _ComingSoon(this.name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
