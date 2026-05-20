import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// A user habit (e.g. "Read 10 minutes", "Walk").
@DataClassName('Habit')
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get emoji => text().withLength(min: 1, max: 8)();

  /// ARGB int, e.g. `0xFF6CA358` (brand green).
  IntColumn get colorValue => integer()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

/// One row per (habit, day) the user marked complete.
@DataClassName('Completion')
class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get completedOn => dateTime()();
}

/// Drift database for the JustOne example app.
@DriftDatabase(tables: [Habits, Completions], daos: [HabitDao])
class AppDatabase extends _$AppDatabase {
  /// Production constructor opens an on-device SQLite file.
  AppDatabase() : super(_openConnection());

  /// Test-only constructor; passes [e] directly to Drift.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Opens the on-device SQLite file in the app documents directory.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'justone.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftAccessor(tables: [Habits, Completions])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);

  Future<int> insertHabit(HabitsCompanion h) => into(habits).insert(h);

  Future<List<Habit>> allHabits() => select(habits).get();

  Stream<List<Habit>> watchAllHabits() => select(habits).watch();

  Future<void> deleteHabit(int id) =>
      (delete(habits)..where((h) => h.id.equals(id))).go();

  Future<int> insertCompletion(CompletionsCompanion c) =>
      into(completions).insert(c);

  Future<List<Completion>> completionsForHabit(int habitId) =>
      (select(completions)..where((c) => c.habitId.equals(habitId))).get();

  Stream<List<Completion>> watchCompletionsForHabit(int habitId) =>
      (select(completions)..where((c) => c.habitId.equals(habitId))).watch();

  Future<List<Completion>> allCompletions() => select(completions).get();
}
