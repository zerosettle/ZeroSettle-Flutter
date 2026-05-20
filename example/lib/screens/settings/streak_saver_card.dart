import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/inherited_just_one.dart';
import '../../app/routes.dart';

/// Card showing the user's owned Streak Saver count with a "Buy more" button
/// that navigates to the consumable shop.
///
/// Reads [UserPrefs.streakSaverCount] synchronously from the scope —
/// no async needed because [SharedPreferences] caches the value in memory.
///
/// Mirrors `StreakSaverCard` in the JustOne Android sample.
class StreakSaverCard extends StatelessWidget {
  const StreakSaverCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = InheritedJustOne.of(context).prefs;
    final count = prefs.streakSaverCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Streak Savers',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Use a Streak Saver to protect your streak when you miss a day.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(Routes.shop),
              child: const Text('Buy more'),
            ),
          ],
        ),
      ),
    );
  }
}
