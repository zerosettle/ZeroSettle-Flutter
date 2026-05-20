import 'package:flutter/material.dart';

import '../../app/inherited_just_one.dart';

/// Card with a "Daily reminder" toggle that persists the user's preference
/// via [UserPrefs.setReminderEnabled].
///
/// **Scheduling is NOT wired here** — Task 12 will add real notification
/// scheduling to the toggle handler. For now, toggling only persists the pref
/// so the switch survives app restarts.
///
/// Mirrors `ReminderCard` in the JustOne Android sample (simplified: Flutter
/// does not use the Android permission launcher or time-picker dialog in this
/// task — those are part of Task 12's scheduling implementation).
class ReminderCard extends StatefulWidget {
  const ReminderCard({super.key});

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> {
  late bool _enabled;

  /// One-time guard so a later [InheritedJustOne] change can't re-stomp the
  /// user's live toggle state with the persisted pref.
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed local state from the persisted pref exactly once. After that the
    // user's local toggle state is the authoritative source.
    if (!_seeded) {
      _enabled = InheritedJustOne.of(context).prefs.reminderEnabled;
      _seeded = true;
    }
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _enabled = value);
    // Capture the prefs reference BEFORE the await — Task 12 will add code
    // after the suspension point and must not touch `context` post-await.
    final prefs = InheritedJustOne.of(context).prefs;
    await prefs.setReminderEnabled(value);
    // Task 12 wires actual scheduling into this handler.
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        title: const Text('Daily reminder'),
        value: _enabled,
        onChanged: _onToggle,
      ),
    );
  }
}
