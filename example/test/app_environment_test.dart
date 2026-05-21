import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppEnvironment.publishableKey', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('resolves the Android key on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        AppEnvironment.local.publishableKey,
        AppEnvironment.local.androidPublishableKey,
      );
    });

    test('resolves the iOS key on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        AppEnvironment.local.publishableKey,
        AppEnvironment.local.iosPublishableKey,
      );
    });
  });

  group('AppEnvironment.hasKey', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('local has a key on both platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppEnvironment.local.hasKey, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppEnvironment.local.hasKey, isTrue);
    });

    test('staging has an Android key but no iOS key yet', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppEnvironment.staging.hasKey, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppEnvironment.staging.hasKey, isFalse);
    });

    test('prod has no key yet on either platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppEnvironment.prod.hasKey, isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppEnvironment.prod.hasKey, isFalse);
    });
  });

  group('AppEnvironment.load()', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('honors a persisted env that is usable on this platform', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({
        'com.zerosettle.flutter_example.environment': 'local',
      });
      expect(await AppEnvironment.load(), AppEnvironment.local);
    });

    test('falls back to a usable env when the persisted env is keyless here',
        () async {
      // prod has no iOS publishable key. load() must NOT return it — that
      // would boot the SDK unconfigured and every product screen would throw
      // ZSNotConfiguredException.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({
        'com.zerosettle.flutter_example.environment': 'prod',
      });
      final env = await AppEnvironment.load();
      expect(env.hasKey, isTrue);
      expect(env, AppEnvironment.local);
    });

    test('falls back to a usable env when nothing is persisted', () async {
      // The default (prod) is keyless on both platforms today.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      expect((await AppEnvironment.load()).hasKey, isTrue);
    });

    test('falls back when the persisted env name is no longer valid',
        () async {
      // A user who had one of the old 6 envs (e.g. "sandbox") persisted.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({
        'com.zerosettle.flutter_example.environment': 'sandbox',
      });
      expect((await AppEnvironment.load()).hasKey, isTrue);
    });

    test('save() then load() round-trips a usable environment', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      await AppEnvironment.save(AppEnvironment.local);
      expect(await AppEnvironment.load(), AppEnvironment.local);
    });
  });
}
