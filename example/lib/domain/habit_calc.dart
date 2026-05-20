/// Pure functions over a completion history. No Flutter imports — runs
/// without a device. Mirrors JustOne Android's `HabitCalc.kt`.
class HabitCalc {
  HabitCalc._();

  /// Strip the time-of-day so two `DateTime`s on the same calendar day
  /// compare equal.
  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Number of consecutive days, ending at [today] (or, if [today] has no
  /// completion, ending at yesterday), on which the user has at least one
  /// completion.
  ///
  /// Examples:
  /// - completions `[today, yesterday, dayBefore]` -> 3.
  /// - completions `[yesterday, dayBefore]` (no today) -> 2 (the streak
  ///   carries from yesterday; today is not yet a missed day, just unmarked).
  /// - completions `[dayBefore]` (gap at yesterday) -> 0.
  static int currentStreak(
    List<DateTime> completions, {
    required DateTime today,
  }) {
    final days = completions.map(dayOf).toSet();
    var cursor = dayOf(today);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Returns a map `day -> count` for every day from [start] to [end]
  /// inclusive. Completions outside the range are dropped. The map is
  /// ordered chronologically by insertion.
  static Map<DateTime, int> completionHeatmap(
    List<DateTime> completions, {
    required DateTime start,
    required DateTime end,
  }) {
    final s = dayOf(start);
    final e = dayOf(end);
    final out = <DateTime, int>{};
    for (var day = s;
        !day.isAfter(e);
        day = day.add(const Duration(days: 1))) {
      out[day] = 0;
    }
    for (final c in completions) {
      final d = dayOf(c);
      if (out.containsKey(d)) {
        out[d] = (out[d] ?? 0) + 1;
      }
    }
    return out;
  }
}
