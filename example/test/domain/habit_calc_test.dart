import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle_example/domain/habit_calc.dart';

DateTime d(int y, int m, int dd) => DateTime(y, m, dd);

void main() {
  group('currentStreak', () {
    test('returns 0 when no completions', () {
      expect(HabitCalc.currentStreak(const [], today: d(2026, 5, 19)), 0);
    });

    test('returns 1 when only today is completed', () {
      expect(
        HabitCalc.currentStreak([d(2026, 5, 19)], today: d(2026, 5, 19)),
        1,
      );
    });

    test('returns 3 for today + previous 2 consecutive days', () {
      expect(
        HabitCalc.currentStreak(
          [d(2026, 5, 19), d(2026, 5, 18), d(2026, 5, 17)],
          today: d(2026, 5, 19),
        ),
        3,
      );
    });

    test('returns 2 when yesterday + day before; today missing breaks streak today', () {
      expect(
        HabitCalc.currentStreak(
          [d(2026, 5, 18), d(2026, 5, 17)],
          today: d(2026, 5, 19),
        ),
        2,
      );
    });

    test('returns 0 when gap at yesterday', () {
      expect(
        HabitCalc.currentStreak(
          [d(2026, 5, 17), d(2026, 5, 16)],
          today: d(2026, 5, 19),
        ),
        0,
      );
    });

    test('deduplicates same-day completions', () {
      expect(
        HabitCalc.currentStreak(
          [d(2026, 5, 19), d(2026, 5, 19), d(2026, 5, 18)],
          today: d(2026, 5, 19),
        ),
        2,
      );
    });
  });

  group('completionHeatmap', () {
    test('empty completions returns all-zero map for the range', () {
      final map = HabitCalc.completionHeatmap(
        const [],
        start: d(2026, 5, 1),
        end: d(2026, 5, 3),
      );
      expect(map, {
        d(2026, 5, 1): 0,
        d(2026, 5, 2): 0,
        d(2026, 5, 3): 0,
      });
    });

    test('counts completions per day, ignoring time-of-day', () {
      final map = HabitCalc.completionHeatmap(
        [
          DateTime(2026, 5, 1, 9),
          DateTime(2026, 5, 1, 21),
          DateTime(2026, 5, 3, 12),
        ],
        start: d(2026, 5, 1),
        end: d(2026, 5, 3),
      );
      expect(map, {
        d(2026, 5, 1): 2,
        d(2026, 5, 2): 0,
        d(2026, 5, 3): 1,
      });
    });

    test('out-of-range completions are excluded', () {
      final map = HabitCalc.completionHeatmap(
        [d(2026, 4, 30), d(2026, 5, 2), d(2026, 5, 4)],
        start: d(2026, 5, 1),
        end: d(2026, 5, 3),
      );
      expect(map[d(2026, 5, 2)], 1);
      expect(map.keys.where((k) => k.month == 4), isEmpty);
      expect(map.keys.where((k) => k.day == 4), isEmpty);
    });
  });
}
