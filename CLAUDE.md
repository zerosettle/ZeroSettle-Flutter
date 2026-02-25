# CLAUDE.md - ZeroSettle Flutter Plugin

## Overview
`zerosettle` is the Flutter wrapper around the native `ZeroSettleKit` (iOS) and `zerosettle-android` (Android) SDKs. It uses Flutter's standard 3-layer plugin architecture with MethodChannel/EventChannel to bridge Dart ↔ Swift/Kotlin.

## Architecture
```
lib/
  zerosettle.dart                      → Public facade (ZeroSettle.instance singleton)
  zerosettle_platform_interface.dart   → Abstract platform contract
  zerosettle_method_channel.dart       → MethodChannel + EventChannel implementation
  models/                              → Dart model classes (mirror native types)
  errors/                              → ZSException sealed hierarchy
  widgets/                             → Flutter widgets wrapping native PlatformViews
ios/Classes/
  ZeroSettlePlugin.swift               → Native Swift bridge
  ZSMigrateTipViewFactory.swift        → PlatformView factory for ZSMigrateTipView
  ZSMigrateTipViewFlutterContainer.swift → UIHostingController wrapper for SwiftUI view
android/src/main/kotlin/com/zerosettle/flutter/
  ZeroSettlePlugin.kt                  → Native Kotlin bridge
```

## Key Files
* `lib/zerosettle.dart` — Public API facade, deserialization, error mapping
* `lib/zerosettle_method_channel.dart` — MethodChannel(`zerosettle`), EventChannel(`zerosettle/entitlement_updates`, `zerosettle/checkout_events`)
* `ios/Classes/ZeroSettlePlugin.swift` — Swift bridge: method dispatch, EventChannel stream handlers, `toFlutterMap()` serializers, `PaymentSheetHeader` SwiftUI view
* `ios/zerosettle.podspec` — CocoaPods spec with `ZeroSettleKit` dependency
* `android/src/main/kotlin/com/zerosettle/flutter/ZeroSettlePlugin.kt` — Kotlin bridge: method dispatch, EventChannel stream handlers, `toFlutterMap()` serializers
* `android/build.gradle` — Gradle config with `io.zerosettle:zerosettle-android` dependency

## Channels
* `MethodChannel('zerosettle')` — All request/response calls
* `EventChannel('zerosettle/entitlement_updates')` — Streams entitlement changes
* `EventChannel('zerosettle/checkout_events')` — Streams checkout delegate callbacks

## PlatformViews
* `zerosettle/migrate_tip_view` — Embeds native `ZSMigrateTipView` SwiftUI component via UIHostingController
  - Factory: `ZSMigrateTipViewFactory` creates `ZSMigrateTipViewFlutterContainer`
  - Container wraps SwiftUI view in `UIHostingController` and attaches to view hierarchy
  - Creation params: `backgroundColor` (ARGB int32), `userId` (String)
  - Widget: `ZSMigrateTipView` in `lib/widgets/` — renders `UiKitView` on iOS, `SizedBox.shrink()` on Android
  - Pattern: Thin wrapper around autonomous native view — no callbacks, no reactive updates, props set once at creation

## Bridge Pattern
* **iOS:** Swift `handle()` is nonisolated; dispatches to `@MainActor handleOnMainActor()` via `Task { @MainActor in }` (required because `ZeroSettle.shared` is `@MainActor`-isolated)
* **iOS:** Payment sheet: gets root VC → calls `ZSPaymentSheet.present(from:header:...)` → maps `Result<ZSTransaction, Error>` back to `FlutterResult`
* **Android:** Kotlin `onMethodCall()` launches coroutines on `Dispatchers.Main` for suspend functions
* **Android:** Payment sheet: delegates to `ZeroSettle.purchase(activity, ...)` which launches `ZSPaymentSheetActivity` internally
* **Android:** `preloadPaymentSheet` and `warmUpPaymentSheet` are no-ops (iOS-specific optimizations)
* Dates serialize as ISO 8601 strings across the bridge (Android SDK stores dates as strings natively)
* Errors map: native `ZSError` → `FlutterError(code:)` → Dart `PlatformException` → `ZSException` subtypes
* Android bridge serializes `playStoreAvailable`/`playStorePrice` as `storeKitAvailable`/`storeKitPrice` to share the same Dart model

## Cross-Framework API Compatibility
This plugin wraps `ZeroSettleKit` (iOS) and `zerosettle-android` (Android). When a source SDK's public API changes:
1. Update `ios/Classes/ZeroSettlePlugin.swift` and/or `android/.../ZeroSettlePlugin.kt` — bridge methods, `toFlutterMap()` serializers
2. Update `lib/models/` — Dart model classes and `fromMap()`/`toMap()` to match new serialization
3. Update `lib/errors/` — if new error codes are added
4. Update `lib/zerosettle.dart` — facade methods and exports
5. Run `flutter test` to verify all tests pass
6. Run `flutter build ios --no-codesign` from `example/` to verify iOS native compilation
7. Run `flutter build apk --debug` from `example/` to verify Android native compilation

### Version Sync
When `ZeroSettleKit` bumps its version:
* Update `ios/zerosettle.podspec` → `s.dependency 'ZeroSettleKit', '~> X.Y.Z'`
* Update `pubspec.yaml` → `version` (follow semver appropriate to the scope of changes)
* Update `ios/zerosettle.podspec` → `s.version` to match pubspec

When `zerosettle-android` bumps its version:
* Update `android/build.gradle` → `implementation 'io.zerosettle:zerosettle-android:X.Y.Z'`
* Update `pubspec.yaml` → `version` (follow semver appropriate to the scope of changes)

## Development
* Run tests: `cd /path/to/ZeroSettle-Flutter && flutter test`
* Build iOS: `cd /path/to/ZeroSettle-Flutter/example && flutter build ios --no-codesign`
* Build Android: `cd /path/to/ZeroSettle-Flutter/example && flutter build apk --debug`
* Local iOS SDK development: The example Podfile can point to a local ZeroSettleKit checkout via `pod 'ZeroSettleKit', :path => '/path/to/ZeroSettleKit'`
* Local Android SDK development: Add `mavenLocal()` to example app's `settings.gradle.kts` repositories and `publishToMavenLocal` the SDK

## Backward Compatibility
**Never introduce breaking changes unless explicitly approved by the user.** This plugin is consumed by third-party Flutter apps.

Safe (non-breaking) changes:
* Adding new optional fields with defaults (`null`/`false`/`0`)
* Adding new API response fields (old clients ignore unknown keys)
* Adding new methods or types
* Adding new optional parameters with defaults to existing methods

Breaking changes (require explicit approval):
* Removing or renaming public classes, methods, fields, or enum values
* Changing method signatures or `fromMap()`/`toMap()` keys
* Removing fields that clients depend on
* Changing default values in ways that alter existing behavior

## Coding Standards
* Models use `fromMap()`/`toMap()` with `==`/`hashCode` overrides
* Enums use `rawValue` string mapping with `fromRawValue()` factory
* The facade layer (`zerosettle.dart`) handles all deserialization and error mapping — platform interface methods return raw `Map`/`List` types
* Neutral language: "External Purchase," "Web Checkout" — never "bypass" or "evade"
