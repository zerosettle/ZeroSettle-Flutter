import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle/zerosettle.dart';

/// Backend environments the example app can run against.
///
/// Each env bakes in its Stripe mode: `local` and `staging` run Stripe test
/// mode; `prod` runs live payments. Publishable keys are issued per platform
/// (the iOS and Android example apps have distinct bundle IDs), so each env
/// carries both an iOS and an Android key — [publishableKey] resolves the one
/// for the running platform.
enum AppEnvironment {
  local(
    displayName: 'Local',
    baseUrl: 'https://api.zerosettle.ngrok.app',
    iosPublishableKey:
        'zs_pk_test_645cf2772166ab65845c9d53b14e1b53d1c33697748d3e2c',
    androidPublishableKey:
        'zs_pk_test_8d144f1add3d8a4c9dde5ef0436ffb75acbb1c56886ac070',
    isLive: false,
  ),
  staging(
    displayName: 'Staging',
    baseUrl: 'https://api-staging.zerosettle.io',
    // TODO: staging iOS publishable key not yet issued.
    iosPublishableKey: '',
    androidPublishableKey:
        'zs_pk_test_bded1f5dddde6f79ac538bff33b70737244a3557555d863c',
    isLive: false,
  ),
  prod(
    displayName: 'Prod',
    baseUrl: 'https://api.zerosettle.io',
    // TODO: prod publishable keys not yet issued (both platforms).
    iosPublishableKey: '',
    androidPublishableKey: '',
    isLive: true,
  );

  const AppEnvironment({
    required this.displayName,
    required this.baseUrl,
    required this.iosPublishableKey,
    required this.androidPublishableKey,
    required this.isLive,
  });

  final String displayName;

  /// API origin (scheme + host) — e.g. `https://api.zerosettle.io`. The SDK
  /// appends the versioned `/v1/...` path itself, so this must NOT include a
  /// `/v1` segment — doing so produces a doubled `/v1/v1/...` request → 404.
  final String baseUrl;

  final String iosPublishableKey;
  final String androidPublishableKey;

  /// Whether this env processes live payments (vs Stripe test mode).
  final bool isLive;

  /// The publishable key for the platform the app is running on.
  String get publishableKey => defaultTargetPlatform == TargetPlatform.iOS
      ? iosPublishableKey
      : androidPublishableKey;

  /// Whether a usable publishable key exists for the running platform.
  /// `false` for envs whose key has not been issued yet (staging iOS, prod).
  bool get hasKey => publishableKey.isNotEmpty;

  static const _prefsKey = 'com.zerosettle.flutter_example.environment';

  /// Environment used on a fresh install (before the user picks one).
  static const AppEnvironment fallback = AppEnvironment.prod;

  /// The environment to run against: the persisted choice, or [fallback] if
  /// none has been chosen.
  ///
  /// Guarantees the result is usable on the current platform — i.e. it has a
  /// publishable key (see [hasKey]). An env with no key cannot be `configure()`d,
  /// so returning it would boot the app with an unconfigured SDK and every
  /// product screen would throw `ZSNotConfiguredException`. When the resolved
  /// env is keyless here, the first env that *is* usable is substituted.
  static Future<AppEnvironment> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsKey);
    final resolved = AppEnvironment.values.firstWhere(
      (e) => e.name == name,
      orElse: () => fallback,
    );
    if (resolved.hasKey) return resolved;
    return AppEnvironment.values.firstWhere(
      (e) => e.hasKey,
      orElse: () => resolved,
    );
  }

  static Future<void> save(AppEnvironment env) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, env.name);
  }
}

/// Persists [env] and re-points the ZeroSettle SDK at it: clears any current
/// identity, applies the base URL, and re-configures with the platform key.
///
/// Does NOT re-identify — the caller decides what happens next (the create-user
/// screen identifies on "Continue"; the developer screen re-identifies from
/// persisted prefs).
Future<void> applyEnvironment(AppEnvironment env) async {
  await AppEnvironment.save(env);
  await ZeroSettle.instance.logout();
  await ZeroSettle.instance.setBaseUrlOverride(env.baseUrl);
  // configure() rejects any key that isn't a `zs_pk_live_`/`zs_pk_test_`
  // value, so skip it for envs whose key has not been issued yet (staging
  // iOS, prod). The SDK simply stays unconfigured for that env until a real
  // key lands — the caller is expected to check [AppEnvironment.hasKey].
  if (env.hasKey) {
    await ZeroSettle.instance.configure(publishableKey: env.publishableKey);
  }
}
