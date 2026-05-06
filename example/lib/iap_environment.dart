import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum IAPEnvironment {
  // Each env carries an explicit `isEnabled` flag. Flip an env to true once
  // its publishable key has been (re)issued under the canonical example
  // bundle ID `io.zerosettle.ZSStoreFrontFlutter` — keys issued under the
  // old `com.example.zerosettlekitFlutterExample` placeholder won't see
  // any StoreKit products.
  sandbox(
    displayName: 'Sandbox',
    description: 'Stripe test mode with production URLs',
    publishableKey: 'zs_pk_test_0e20a7a5e31fa3ea13ebc100ff42d0993fd2baa9cfccdc6a',
    baseUrlOverride: null,
    isEnabled: false,
  ),
  live(
    displayName: 'Live',
    description: 'Production environment with live payments',
    publishableKey: 'zs_pk_live_4b96dfe517998cda605845f6562e70c17fa9cd914073b1cd',
    baseUrlOverride: null,
    isEnabled: false,
  ),
  stagingSandbox(
    displayName: 'Sandbox (Staging)',
    description: 'Staging backend with Stripe test mode',
    publishableKey: 'zs_pk_test_df393dce005b783e2e30afd4849c5b4e83bfc2289f0fa84d',
    baseUrlOverride: 'https://api-staging.zerosettle.io/v1',
    isEnabled: true,
  ),
  stagingLive(
    displayName: 'Live (Staging)',
    description: 'Staging backend with live payment processing',
    publishableKey: 'zs_pk_live_893e511699f82bb6453d7cefcfbd33e0b7e14a3cf5baa3b2',
    baseUrlOverride: 'https://api-staging.zerosettle.io/v1',
    isEnabled: false,
  ),
  internalSandbox(
    displayName: 'Sandbox (Internal)',
    description: 'Internal development with ngrok URLs (sandbox)',
    publishableKey: 'zs_pk_test_ee11e51db0389e82c9f1129c3b5abfa9e0877c8c9aabcb71',
    baseUrlOverride: 'https://api.zerosettle.ngrok.app/v1',
    isEnabled: false,
  ),
  internalLive(
    displayName: 'Live (Internal)',
    description: 'Internal development with ngrok URLs (live)',
    publishableKey: 'zs_pk_live_1bc267a2d156fd9e70f475adf5a89fb8db8cdee203b604a7',
    baseUrlOverride: 'https://api.zerosettle.ngrok.app/v1',
    isEnabled: false,
  );

  const IAPEnvironment({
    required this.displayName,
    required this.description,
    required this.publishableKey,
    required this.baseUrlOverride,
    required this.isEnabled,
  });

  final String displayName;
  final String description;
  final String publishableKey;
  final String? baseUrlOverride;

  /// Whether this environment is currently selectable in the example app.
  /// Set per-env above; flip to `true` once you have a valid publishable
  /// key for that env tied to the example's bundle ID.
  final bool isEnabled;

  String get truncatedKey =>
      '${publishableKey.substring(0, 25)}...';

  String get effectiveUrl =>
      baseUrlOverride ?? 'https://api.zerosettle.io/v1';

  /// First enabled environment in declaration order. Used as a sane default
  /// when the persisted env has been disabled since last launch.
  static IAPEnvironment get firstEnabled =>
      IAPEnvironment.values.firstWhere((e) => e.isEnabled);

  static const _prefsKey = 'com.zerosettle.flutter_example.environment';

  static Future<IAPEnvironment> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsKey);
    final loaded = IAPEnvironment.values.firstWhere(
      (e) => e.name == name,
      orElse: () => firstEnabled,
    );
    // If the persisted env was disabled since last launch, fall back to the
    // first enabled env so the user isn't trapped in a non-selectable env.
    return loaded.isEnabled ? loaded : firstEnabled;
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
