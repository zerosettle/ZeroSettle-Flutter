import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('zerosettle');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async { calls.add(c); return null; });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('reportOfferViewed invokes channel with args', () async {
    await MethodChannelZeroSettle().reportOfferViewed(productId: 'com.app.pro', variantId: 7, flowType: 'migration');
    expect(calls.single.method, 'reportOfferViewed');
    expect(calls.single.arguments['productId'], 'com.app.pro');
    expect(calls.single.arguments['variantId'], 7);
    expect(calls.single.arguments['flowType'], 'migration');
  });
  test('reportOfferViewed omits null args', () async {
    await MethodChannelZeroSettle().reportOfferViewed();
    expect(calls.single.arguments.containsKey('productId'), false);
  });
}
