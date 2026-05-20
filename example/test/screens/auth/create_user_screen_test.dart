import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle_example/screens/auth/create_user_screen.dart';

void main() {
  testWidgets('renders name field + Continue button (disabled when empty)',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: CreateUserScreen()));
    expect(find.byType(TextField), findsOneWidget);
    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(continueButton, findsOneWidget);
    final btn = tester.widget<FilledButton>(continueButton);
    expect(btn.onPressed, isNull, reason: 'Continue is disabled until a name is typed');
  });

  testWidgets('Continue button enables after typing a name', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: CreateUserScreen()));
    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump();
    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(btn.onPressed, isNotNull);
  });
}
