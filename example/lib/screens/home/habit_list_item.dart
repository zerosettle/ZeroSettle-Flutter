import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// A single habit row with emoji, name, and a "check off today" button.
/// When [completedToday] is `true`, the button shows a filled green check.
class HabitListItem extends StatelessWidget {
  final String emoji;
  final String name;
  final bool completedToday;
  final VoidCallback onCheck;
  final VoidCallback? onTap;

  const HabitListItem({
    super.key,
    required this.emoji,
    required this.name,
    required this.completedToday,
    required this.onCheck,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = completedToday
        ? Icons.check_circle
        : Icons.radio_button_unchecked;
    final iconColor = completedToday
        ? AppTheme.brandGreen
        : Theme.of(context).colorScheme.outline;
    return ListTile(
      onTap: onTap,
      leading: Text(emoji, style: const TextStyle(fontSize: 28)),
      title: Text(name, style: Theme.of(context).textTheme.titleMedium),
      trailing: IconButton(
        icon: Icon(iconData, color: iconColor, size: 32),
        tooltip: completedToday ? 'Completed' : 'Check off today',
        onPressed: onCheck,
      ),
    );
  }
}
