import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  test('decodes PurchaseSucceeded', () {
    final e = ZeroSettleEvent.fromMap({
      'type': 'purchaseSucceeded', 'productId': 'p1', 'transactionId': 't1',
    });
    expect(e, isA<ZSEventPurchaseSucceeded>());
    expect((e as ZSEventPurchaseSucceeded).transactionId, 't1');
  });
  test('decodes SyncFailed', () {
    final e = ZeroSettleEvent.fromMap({
      'type': 'syncFailed', 'purchaseToken': 'tok', 'attempts': 3, 'terminal': true,
    });
    expect((e as ZSEventSyncFailed).terminal, true);
  });
  test('unknown type decodes to ZSEventUnknown', () {
    expect(ZeroSettleEvent.fromMap({'type': 'somethingNew'}),
        isA<ZSEventUnknown>());
  });
}
