import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/inherited_just_one.dart';
import '../../data/database.dart';
import '../../domain/habit_calc.dart';

/// Per-habit detail — current streak + completion history + a delete action.
class HabitDetailScreen extends StatelessWidget {
  final int habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    final dao = InheritedJustOne.of(context).db.habitDao;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                await dao.deleteHabit(habitId);
                if (context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete habit')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Habit>>(
        future: dao.allHabits(),
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = all.where((h) => h.id == habitId);
          final habit = matches.isEmpty ? null : matches.first;
          if (habit == null) {
            return const Center(child: Text('Habit not found.'));
          }
          return StreamBuilder<List<Completion>>(
            stream: dao.watchCompletionsForHabit(habitId),
            builder: (context, cSnap) {
              final completions = cSnap.data ?? const <Completion>[];
              final streak = HabitCalc.currentStreak(
                completions.map((c) => c.completedOn).toList(),
                today: DateTime.now(),
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    Text(habit.emoji, style: const TextStyle(fontSize: 40)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(habit.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current streak',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text('$streak day${streak == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.displaySmall),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('History',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (completions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No completions yet.'),
                    )
                  else
                    ...completions.map((c) => ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(_formatDate(c.completedOn)),
                        )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
