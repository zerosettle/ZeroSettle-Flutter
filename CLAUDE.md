# CLAUDE.md - ZeroSettle Flutter Plugin

## Overview
`zerosettle` is the Flutter wrapper around the native `ZeroSettleKit` iOS SDK. It uses Flutter's standard 3-layer plugin architecture with MethodChannel/EventChannel to bridge Dart ↔ Swift.

## Architecture
```
lib/
  zerosettle.dart                      → Public facade (ZeroSettle.instance singleton)
  zerosettle_platform_interface.dart   → Abstract platform contract
  zerosettle_method_channel.dart       → MethodChannel + EventChannel implementation
  models/                              → Dart model classes (mirror native types)
  errors/                              → ZSException sealed hierarchy
ios/Classes/
  ZeroSettlePlugin.swift               → Native Swift bridge
```

## Key Files
* `lib/zerosettle.dart` — Public API facade, deserialization, error mapping
* `lib/zerosettle_method_channel.dart` — MethodChannel(`zerosettle`), EventChannel(`zerosettle/entitlement_updates`, `zerosettle/checkout_events`)
* `ios/Classes/ZeroSettlePlugin.swift` — Swift bridge: method dispatch, EventChannel stream handlers, `toFlutterMap()` serializers, `PaymentSheetHeader` SwiftUI view
* `ios/zerosettle.podspec` — CocoaPods spec with `ZeroSettleKit` dependency

## Channels
* `MethodChannel('zerosettle')` — All request/response calls
* `EventChannel('zerosettle/entitlement_updates')` — Streams entitlement changes
* `EventChannel('zerosettle/checkout_events')` — Streams checkout delegate callbacks

## Bridge Pattern
* Swift `handle()` is nonisolated; dispatches to `@MainActor handleOnMainActor()` via `Task { @MainActor in }` (required because `ZeroSettle.shared` is `@MainActor`-isolated)
* Payment sheet: gets root VC → calls `ZSPaymentSheet.present(from:header:...)` → maps `Result<ZSTransaction, Error>` back to `FlutterResult`
* Dates serialize as ISO 8601 strings across the bridge
* Errors map: native `ZSError` → `FlutterError(code:)` → Dart `PlatformException` → `ZSException` subtypes

## Cross-Framework API Compatibility
This plugin wraps `ZeroSettleKit`. When the source SDK's public API changes:
1. Update `ios/Classes/ZeroSettlePlugin.swift` — bridge methods, `toFlutterMap()` serializers
2. Update `lib/models/` — Dart model classes and `fromMap()`/`toMap()` to match new serialization
3. Update `lib/errors/` — if new error codes are added
4. Update `lib/zerosettle.dart` — facade methods and exports
5. Run `flutter test` to verify all tests pass
6. Run `flutter build ios --no-codesign` from `example/` to verify native compilation

### Version Sync
When `ZeroSettleKit` bumps its version:
* Update `ios/zerosettle.podspec` → `s.dependency 'ZeroSettleKit', '~> X.Y.Z'`
* Update `pubspec.yaml` → `version` (follow semver appropriate to the scope of changes)
* Update `ios/zerosettle.podspec` → `s.version` to match pubspec

## Development
* Run tests: `cd /path/to/ZeroSettle-Flutter && flutter test`
* Build iOS: `cd /path/to/ZeroSettle-Flutter/example && flutter build ios --no-codesign`
* Local SDK development: The example Podfile can point to a local ZeroSettleKit checkout via `pod 'ZeroSettleKit', :path => '/path/to/ZeroSettleKit'`

## Coding Standards
* Models use `fromMap()`/`toMap()` with `==`/`hashCode` overrides
* Enums use `rawValue` string mapping with `fromRawValue()` factory
* The facade layer (`zerosettle.dart`) handles all deserialization and error mapping — platform interface methods return raw `Map`/`List` types
* Neutral language: "External Purchase," "Web Checkout" — never "bypass" or "evade"
