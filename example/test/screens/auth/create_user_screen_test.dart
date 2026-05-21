import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/screens/auth/create_user_screen.dart';

const _envPrefsKey = 'com.zerosettle.flutter_example.environment';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders name field, env picker, and a disabled Continue button',
      (tester) async {
    SharedPreferences.setMockInitialValues({_envPrefsKey: 'local'});
    await tester.pumpWidget(const MaterialApp(home: CreateUserScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // The three environment segments.
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Staging'), findsOneWidget);
    expect(find.text('Prod'), findsOneWidget);

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(btn.onPressed, isNull, reason: 'disabled until a name is typed');
  });

  testWidgets('Continue enables after typing a name when the env has a key',
      (tester) async {
    SharedPreferences.setMockInitialValues({_envPrefsKey: 'local'});
    await tester.pumpWidget(const MaterialApp(home: CreateUserScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump();

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('picking a keyless env disables Continue and shows a hint',
      (tester) async {
    // Picking an env runs applyEnvironment(), which calls platform methods
    // (logout / setBaseUrlOverride). Stub the channel so the switch completes
    // in-test instead of hanging the busy spinner forever.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zerosettle'),
      (call) async => null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zerosettle'), null));

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: CreateUserScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump();

    // Pick prod via the segmented control — it has no publishable key on
    // either platform. (load() never *starts* on a keyless env, so this is
    // the only way to reach the no-key state.)
    await tester.tap(find.text('Prod'));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(btn.onPressed, isNull, reason: 'prod has no publishable key');
    expect(find.textContaining('No publishable key'), findsOneWidget);
  });
}
