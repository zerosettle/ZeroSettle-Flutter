import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/inherited_just_one.dart';
import '../../app/routes.dart';
import '../../data/database.dart';
import '../../domain/habit_calc.dart';
import 'habit_list_item.dart';
import 'heatmap_widget.dart';

/// Top-level screen. Streams habits + completions from the Drift DAO and
/// renders (1) an aggregated 12-week heatmap across all habits, (2) the
/// list of habits with check-off buttons. FAB navigates to /add-habit.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = InheritedJustOne.of(context);
    final dao = scope.db.habitDao;
    final today = DateTime.now();
    final heatmapStart = today.subtract(const Duration(days: 84)); // 12 weeks

    return Scaffold(
      appBar: AppBar(title: const Text('JustOne')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(Routes.addHabit),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Habit>>(
        stream: dao.watchAllHabits(),
        builder: (context, habitsSnap) {
          final habits = habitsSnap.data ?? const <Habit>[];
          return FutureBuilder<List<Completion>>(
            future: dao.allCompletions(),
            builder: (context, completionsSnap) {
              final completions =
                  completionsSnap.data ?? const <Completion>[];
              final heatmapCounts = HabitCalc.completionHeatmap(
                completions.map((c) => c.completedOn).toList(),
                start: heatmapStart,
                end: today,
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SizedBox(
                    height: 100,
                    child: HeatmapWidget(
                      start: heatmapStart,
                      end: today,
                      counts: heatmapCounts,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Today',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (habits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('No habits yet. Tap + to add one.'),
                      ),
                    )
                  else
                    ...habits.map((h) => _HabitRow(habit: h, dao: dao)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HabitRow extends StatefulWidget {
  final Habit habit;
  final HabitDao dao;
  const _HabitRow({required this.habit, required this.dao});

  @override
  State<_HabitRow> createState() => _HabitRowState();
}

class _HabitRowState extends State<_HabitRow> {
  late Future<bool> _completedTodayFuture;

  @override
  void initState() {
    super.initState();
    _completedTodayFuture = _loadCompletedToday();
  }

  Future<bool> _loadCompletedToday() async {
    final list =
        await widget.dao.completionsForHabit(widget.habit.id);
    final today = HabitCalc.dayOf(DateTime.now());
    return list.any((c) => HabitCalc.dayOf(c.completedOn) == today);
  }

  Future<void> _checkOff() async {
    await widget.dao.insertCompletion(
      CompletionsCompanion.insert(
        habitId: widget.habit.id,
        completedOn: DateTime.now(),
      ),
    );
    setState(() {
      _completedTodayFuture = _loadCompletedToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completedTodayFuture,
      builder: (context, snap) {
        final done = snap.data ?? false;
        return HabitListItem(
          emoji: widget.habit.emoji,
          name: widget.habit.name,
          completedToday: done,
          onCheck: done ? () {} : _checkOff,
          onTap: () =>
              context.push(Routes.habitDetail(widget.habit.id)),
        );
      },
    );
  }
}
