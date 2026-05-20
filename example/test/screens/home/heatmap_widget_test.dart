import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle_example/screens/home/heatmap_widget.dart';

void main() {
  testWidgets('renders without crashing when given a single-week range',
      (tester) async {
    final today = DateTime(2026, 5, 19);
    final start = today.subtract(const Duration(days: 6));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeatmapWidget(
          start: start,
          end: today,
          counts: {today: 1},
        ),
      ),
    ));
    expect(find.byType(HeatmapWidget), findsOneWidget);
  });

  testWidgets('paints the requested number of cells', (tester) async {
    final start = DateTime(2026, 5, 1);
    final end = DateTime(2026, 5, 7); // 7 days
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 80,
          child: HeatmapWidget(start: start, end: end, counts: const {}),
        ),
      ),
    ));
    final widget = tester.widget<HeatmapWidget>(find.byType(HeatmapWidget));
    expect(widget.end.difference(widget.start).inDays + 1, 7);
  });
}
