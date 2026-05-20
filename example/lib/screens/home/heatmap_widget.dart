import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Paints a calendar heatmap from [start] to [end] (inclusive). Each day
/// is a small square; opacity scales with the per-day completion count
/// from [counts].
class HeatmapWidget extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final Map<DateTime, int> counts;

  const HeatmapWidget({
    super.key,
    required this.start,
    required this.end,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
      return CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _HeatmapPainter(
          start: _dayOf(start),
          end: _dayOf(end),
          counts: counts,
          maxCount: maxCount == 0 ? 1 : maxCount,
          color: AppTheme.brandGreen,
          emptyColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      );
    });
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
}

class _HeatmapPainter extends CustomPainter {
  final DateTime start;
  final DateTime end;
  final Map<DateTime, int> counts;
  final int maxCount;
  final Color color;
  final Color emptyColor;

  _HeatmapPainter({
    required this.start,
    required this.end,
    required this.counts,
    required this.maxCount,
    required this.color,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalDays = end.difference(start).inDays + 1;
    if (totalDays <= 0) return;
    // 7 rows (days of week), N columns (weeks). One leading column may
    // be partial depending on what weekday `start` falls on.
    const rows = 7;
    final cellSize = (size.height / rows).clamp(6.0, 18.0);
    const cellGap = 2.0;
    final cellRadius = Radius.circular(cellSize / 3);

    var day = start;
    var col = 0;
    var row = (day.weekday - 1) % 7; // Mon=0..Sun=6

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < totalDays; i++) {
      final count = counts[day] ?? 0;
      final t = count / maxCount;
      paint.color = count == 0
          ? emptyColor
          : Color.lerp(emptyColor, color, t.clamp(0.2, 1.0))!;
      final rect = Rect.fromLTWH(
        col * (cellSize + cellGap),
        row * (cellSize + cellGap),
        cellSize,
        cellSize,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, cellRadius), paint);
      day = day.add(const Duration(days: 1));
      row += 1;
      if (row >= rows) {
        row = 0;
        col += 1;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.start != start ||
      old.end != end ||
      old.maxCount != maxCount ||
      !_mapsEqual(old.counts, counts);

  static bool _mapsEqual(Map<DateTime, int> a, Map<DateTime, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
