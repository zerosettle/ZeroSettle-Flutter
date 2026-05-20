import 'package:flutter/material.dart';

import '../../app/inherited_just_one.dart';

/// Card with a "Daily reminder" toggle that persists the user's preference
/// and schedules/cancels the EOD notification via [NotificationService].
///
/// Toggling on calls [NotificationService.scheduleEodReminder] (daily at
/// 20:00 device-local time); toggling off calls
/// [NotificationService.cancelEodReminder]. The preference survives app
/// restarts via [UserPrefs.setReminderEnabled].
///
/// Mirrors `ReminderCard` in the JustOne Android sample.
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
    // Capture InheritedJustOne references BEFORE the first await so we never
    // touch `context` after a suspension point.
    final scope = InheritedJustOne.of(context);
    final prefs = scope.prefs;
    final notifications = scope.notifications;
    await prefs.setReminderEnabled(value);
    try {
      if (value) {
        await notifications.scheduleEodReminder();
      } else {
        await notifications.cancelEodReminder();
      }
    } catch (_) {
      // Scheduling can fail (e.g. notification permission denied on
      // Android 13+). Revert the pref + UI so the switch reflects reality.
      await prefs.setReminderEnabled(!value);
      if (!mounted) return;
      setState(() => _enabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't update reminder")),
      );
    }
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
