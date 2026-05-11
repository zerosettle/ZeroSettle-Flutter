import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle_example/widgets/offer_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfferCard (example adopter widget)', () {
    const handleId = 'offer_card_test_handle';
    final methodChannel = MethodChannel('zerosettle/offer_manager_$handleId');
    late OfferManager manager;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        // OfferCard only invokes channel methods on user interaction
        // (dismiss / present). The smoke test below never taps the CTA, so
        // returning null for any call is safe.
        return null;
      });
      manager = OfferManager.fromHandleId(handleId);
    });

    tearDown(() async {
      await manager.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    testWidgets(
      'renders empty when no state has been emitted (default loading state)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: OfferCard(manager: manager)),
          ),
        );
        // Without any state emissions from the (mocked-silent) iOS bridge,
        // the widget should render the empty SizedBox.shrink fallback —
        // never a Card.
        expect(find.byType(Card), findsNothing);
        expect(find.byType(OfferCard), findsOneWidget);
      },
    );

    // TODO(test): exercise the eligible/presented rendering and the
    // canonical 1-call `presentPaymentSheet` CTA path once OfferManager
    // exposes a test seam (e.g. @visibleForTesting constructor accepting a
    // synthetic Stream<OfferManagerState>). The state stream currently
    // flows through an iOS-side EventChannel that's hard to drive from a
    // pure-Dart unit test without leaking SDK internals.
  });
}
