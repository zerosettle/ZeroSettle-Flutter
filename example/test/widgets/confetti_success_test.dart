import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle_example/widgets/confetti_success.dart';

void main() {
  testWidgets('ConfettiSuccess renders without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ConfettiSuccess()),
      ),
    );
    // One initial pump to build the widget tree.
    await tester.pump();

    // The success message should be visible.
    expect(find.text('Subscription cancelled'), findsOneWidget);

    // Unmount cleanly and drain the animation controller.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('ConfettiSuccess shows check icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ConfettiSuccess()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
