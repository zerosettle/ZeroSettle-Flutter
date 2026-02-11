// Basic Flutter integration test for the ZeroSettle plugin.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:zerosettle/zerosettle.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ZeroSettle instance is accessible', (WidgetTester tester) async {
    // Verify the singleton accessor works
    final instance = ZeroSettle.instance;
    expect(instance, isNotNull);
  });
}
