import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle_example/screens/home/habit_list_item.dart';

void main() {
  testWidgets('renders emoji + name + check button', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HabitListItem(
          emoji: '📖',
          name: 'Read',
          completedToday: false,
          onCheck: () => tapped = true,
        ),
      ),
    ));
    expect(find.text('📖'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(tapped, isTrue);
  });

  testWidgets('renders checked state visually', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HabitListItem(
          emoji: '📖',
          name: 'Read',
          completedToday: true,
          onCheck: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
