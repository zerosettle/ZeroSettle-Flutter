import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle_example/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('inserts and reads a habit', () async {
    final id = await db.habitDao.insertHabit(
      HabitsCompanion.insert(name: 'Read', emoji: '📖', colorValue: 0xFF6CA358),
    );
    final all = await db.habitDao.allHabits();
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.name, 'Read');
  });

  test('records a completion and reads completions for a habit', () async {
    final id = await db.habitDao.insertHabit(
      HabitsCompanion.insert(name: 'Read', emoji: '📖', colorValue: 0xFF6CA358),
    );
    final today = DateTime(2026, 5, 19);
    await db.habitDao.insertCompletion(
      CompletionsCompanion.insert(habitId: id, completedOn: today),
    );
    final list = await db.habitDao.completionsForHabit(id);
    expect(list, hasLength(1));
    expect(list.single.completedOn, today);
  });

  test('deletes a habit cascades its completions', () async {
    final id = await db.habitDao.insertHabit(
      HabitsCompanion.insert(name: 'Read', emoji: '📖', colorValue: 0xFF6CA358),
    );
    await db.habitDao.insertCompletion(
      CompletionsCompanion.insert(habitId: id, completedOn: DateTime(2026, 5, 19)),
    );
    await db.habitDao.deleteHabit(id);
    expect(await db.habitDao.allHabits(), isEmpty);
    expect(await db.habitDao.completionsForHabit(id), isEmpty);
  });
}
