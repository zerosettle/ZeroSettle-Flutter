import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle_example/widgets/pending_claim_listener.dart';

PendingClaim _claim(String productId, {String hint = 'a3f1'}) => PendingClaim(
      productId: productId,
      originalTransactionId: 'otid-$productId',
      existingOwnerHint: hint,
      purchaseToken: 'token-$productId',
    );

/// Pumps the listener inside the *production* wiring shape — a
/// `MaterialApp.router` with a `GoRouter` whose `ShellRoute` mounts the
/// listener below the router's Navigator. This is the shape that lets
/// `showModalBottomSheet` find a Navigator ancestor; testing it directly
/// guards against the listener silently regressing above the Navigator.
Future<void> _pump(
  WidgetTester tester,
  Stream<List<PendingClaim>> stream,
) async {
  final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (_, _, child) => PendingClaimListener(
          claimsStream: stream,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('home'))),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  group('PendingClaimListener', () {
    testWidgets('shows the sheet when a non-empty list is emitted', (
      tester,
    ) async {
      final controller = StreamController<List<PendingClaim>>();
      await _pump(tester, controller.stream);

      expect(find.text('Subscription already in use'), findsNothing);

      controller.add([_claim('com.justone.premium.weekly')]);
      await tester.pumpAndSettle();

      expect(find.text('Subscription already in use'), findsOneWidget);

      await controller.close();
    });

    testWidgets('does nothing for an empty list', (tester) async {
      final controller = StreamController<List<PendingClaim>>();
      await _pump(tester, controller.stream);

      controller.add(<PendingClaim>[]);
      await tester.pumpAndSettle();

      expect(find.text('Subscription already in use'), findsNothing);
      await controller.close();
    });

    testWidgets('shows only one sheet at a time', (tester) async {
      final controller = StreamController<List<PendingClaim>>();
      await _pump(tester, controller.stream);

      controller.add([_claim('a'), _claim('b')]);
      await tester.pumpAndSettle();

      // A single sheet — the second claim waits.
      expect(find.text('Subscription already in use'), findsOneWidget);
      await controller.close();
    });

    testWidgets('drains the queue: dismissing one surfaces the next', (
      tester,
    ) async {
      final controller = StreamController<List<PendingClaim>>();
      await _pump(tester, controller.stream);

      controller.add([_claim('a', hint: 'aaaa'), _claim('b', hint: 'bbbb')]);
      await tester.pumpAndSettle();
      expect(find.textContaining('••••aaaa'), findsOneWidget);

      // Dismiss the first — the second claim should now surface.
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Subscription already in use'), findsOneWidget);
      expect(find.textContaining('••••bbbb'), findsOneWidget);

      await controller.close();
    });

    testWidgets('does not re-show a claim dismissed this session', (
      tester,
    ) async {
      final controller = StreamController<List<PendingClaim>>();
      await _pump(tester, controller.stream);

      final claim = _claim('com.justone.premium.weekly');
      controller.add([claim]);
      await tester.pumpAndSettle();
      expect(find.text('Subscription already in use'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Subscription already in use'), findsNothing);

      // The same still-pending claim re-emits — it must not re-prompt.
      controller.add([claim]);
      await tester.pumpAndSettle();
      expect(find.text('Subscription already in use'), findsNothing);

      await controller.close();
    });
  });
}
