import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle_example/widgets/claim_entitlement_sheet.dart';

const _claim = PendingClaim(
  productId: 'com.justone.premium.weekly',
  originalTransactionId: 'otid-1',
  existingOwnerHint: 'a3f1',
  purchaseToken: 'play-token-xyz',
);

Product _product(String id, String name) => Product(
      id: id,
      displayName: name,
      productDescription: '',
      type: ZSProductType.autoRenewableSubscription,
    );

/// Pumps the sheet inside a minimal app, opening it immediately so the test
/// can interact with the modal content.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required Future<void> Function({required String productId}) onTransfer,
  Future<Product?> Function(String productId)? resolveProduct,
  VoidCallback? onClosed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                await showClaimEntitlementSheet(
                  context,
                  claim: _claim,
                  onTransfer: onTransfer,
                  resolveProduct: resolveProduct,
                );
                onClosed?.call();
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ClaimEntitlementSheet', () {
    testWidgets('renders title, masked owner hint, and product name', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        onTransfer: ({required String productId}) async {},
        resolveProduct: (id) async =>
            _product(id, 'Premium (Weekly)'),
      );

      expect(find.text('Subscription already in use'), findsOneWidget);
      // Owner hint rendered as ••••<hint>.
      expect(find.textContaining('••••a3f1'), findsOneWidget);
      // Product display name resolved from the catalog.
      expect(find.textContaining('Premium (Weekly)'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
    });

    testWidgets('falls back to productId when product resolution returns null',
        (tester) async {
      await _pumpSheet(
        tester,
        onTransfer: ({required String productId}) async {},
        resolveProduct: (id) async => null,
      );

      expect(
        find.textContaining('com.justone.premium.weekly'),
        findsOneWidget,
      );
    });

    testWidgets('Transfer invokes the facade with the claim productId', (
      tester,
    ) async {
      String? transferred;
      await _pumpSheet(
        tester,
        onTransfer: ({required String productId}) async {
          transferred = productId;
        },
        resolveProduct: (id) async => _product(id, 'Premium (Weekly)'),
      );

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(transferred, 'com.justone.premium.weekly');
    });

    testWidgets('Transfer shows a spinner while the transfer is in flight', (
      tester,
    ) async {
      final completer = Completer<void>();
      await _pumpSheet(
        tester,
        onTransfer: ({required String productId}) => completer.future,
        resolveProduct: (id) async => _product(id, 'Premium (Weekly)'),
      );

      await tester.tap(find.text('Transfer'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('dismisses on a successful transfer', (tester) async {
      var closed = false;
      await _pumpSheet(
        tester,
        onTransfer: ({required String productId}) async {},
        resolveProduct: (id) async => _product(id, 'Premium (Weekly)'),
        onClosed: () => closed = true,
      );

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(find.text('Subscription already in use'), findsNothing);
    });

    testWidgets('error path shows the message inline and does not dismiss', (
      tester,
    ) async {
      var closed = false;
      await _pumpSheet(
        tester,
        onTransfer: ({required String productId}) async {
          throw Exception('transfer failed: token rejected');
        },
        resolveProduct: (id) async => _product(id, 'Premium (Weekly)'),
        onClosed: () => closed = true,
      );

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      // Sheet stays open; error surfaced inline.
      expect(closed, isFalse);
      expect(find.text('Subscription already in use'), findsOneWidget);
      expect(find.textContaining('token rejected'), findsOneWidget);
      // The transfer action remains available for a retry.
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Not now dismisses without calling the facade', (tester) async {
      var transferCalled = false;
      var closed = false;
      await _pumpSheet(
        tester,
        onTransfer: ({required String productId}) async {
          transferCalled = true;
        },
        resolveProduct: (id) async => _product(id, 'Premium (Weekly)'),
        onClosed: () => closed = true,
      );

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(transferCalled, isFalse);
      expect(closed, isTrue);
      expect(find.text('Subscription already in use'), findsNothing);
    });
  });
}
