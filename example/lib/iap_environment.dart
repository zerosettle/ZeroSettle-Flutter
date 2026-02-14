import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum IAPEnvironment {
  sandbox(
    displayName: 'Sandbox',
    description: 'Stripe test mode with production URLs',
    publishableKey: 'zs_pk_test_0e20a7a5e31fa3ea13ebc100ff42d0993fd2baa9cfccdc6a',
    baseUrlOverride: null,
  ),
  live(
    displayName: 'Live',
    description: 'Production environment with live payments',
    publishableKey: 'zs_pk_live_4b96dfe517998cda605845f6562e70c17fa9cd914073b1cd',
    baseUrlOverride: null,
  ),
  internalSandbox(
    displayName: 'Sandbox (Internal)',
    description: 'Internal development with ngrok URLs (sandbox)',
    publishableKey: 'zs_pk_test_9ea585f147db0483b60edf628eb75610114d02432c76e801',
    baseUrlOverride: 'https://api.zerosettle.ngrok.app/v1',
  ),
  internalLive(
    displayName: 'Live (Internal)',
    description: 'Internal development with ngrok URLs (live)',
    publishableKey: 'zs_pk_live_1bc267a2d156fd9e70f475adf5a89fb8db8cdee203b604a7',
    baseUrlOverride: 'https://api.zerosettle.ngrok.app/v1',
  );

  const IAPEnvironment({
    required this.displayName,
    required this.description,
    required this.publishableKey,
    required this.baseUrlOverride,
  });

  final String displayName;
  final String description;
  final String publishableKey;
  final String? baseUrlOverride;

  String get truncatedKey =>
      '${publishableKey.substring(0, 25)}...';

  String get effectiveUrl =>
      baseUrlOverride ?? 'https://api.zerosettle.io/v1';

  static const _prefsKey = 'com.zerosettle.flutter_example.environment';

  static Future<IAPEnvironment> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsKey);
    return IAPEnvironment.values.firstWhere(
      (e) => e.name == name,
      orElse: () => IAPEnvironment.sandbox,
    );
  }

  static Future<void> save(IAPEnvironment env) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, env.name);
  }
}

class IAPEnvironmentNotifier extends ValueNotifier<IAPEnvironment> {
  IAPEnvironmentNotifier(super.value);

  Future<void> switchTo(IAPEnvironment env) async {
    value = env;
    await IAPEnvironment.save(env);
  }
}
