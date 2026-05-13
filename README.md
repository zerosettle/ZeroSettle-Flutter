# ZeroSettle for Flutter

The official Flutter plugin for [ZeroSettle](https://zerosettle.io) — Merchant of Record infrastructure for mobile developers.

ZeroSettle lets you process payments via web checkout while we handle sales tax, VAT, compliance, and liability as the Merchant of Record.

## Installation

### From pub.dev

```yaml
dependencies:
  zerosettle: ^0.0.1
```

### From Git

```yaml
dependencies:
  zerosettle:
    git:
      url: https://github.com/zerosettle/ZeroSettle-Flutter.git
```

## Requirements

- Flutter >= 3.3.0
- iOS 17.0+

## Quick Start

```dart
import 'package:zerosettle/zerosettle.dart';

final zeroSettle = ZeroSettle();

// Initialize with your API key
await zeroSettle.initialize('your-api-key');
```

## Widgets

### ZSMigrateTipView

A native iOS widget that encourages users with active StoreKit subscriptions to migrate to web billing for savings. The view is completely autonomous and self-contained:

- Automatically shows only when applicable (user has StoreKit subscription but no web entitlement)
- Handles its own checkout flow internally
- Manages expansion/collapse animations
- Dismisses itself when complete or cancelled
- Returns empty view on Android or when not applicable

**Usage:**

```dart
ZSMigrateTipView(
  backgroundColor: Theme.of(context).colorScheme.surface,
  userId: 'user123',
)
```

**Properties:**
- `backgroundColor` - Background color for the tip view
- `userId` - Your app's user identifier

**Note:** This widget requires no callbacks or state management. It's a "set it and forget it" component that handles everything internally.

## Platform Support

| Platform | Status |
|----------|--------|
| iOS      | Supported |
| Android  | Coming soon |

## How It Works

This plugin is a thin Dart wrapper around the native [ZeroSettleKit](https://github.com/zerosettle/ZeroSettleKit) (iOS) and [ZeroSettle-Android](https://github.com/zerosettle/ZeroSettle-Android) SDKs. On iOS, the plugin pulls ZeroSettleKit via Swift Package Manager. On Android, it declares an exact-pinned Maven coord (`io.zerosettle:zerosettle-android:1.0.0` + `…-ui:1.0.0`); adopter apps resolve from Maven Central at build time.

## Local development against an in-tree Android SDK

For plugin development against an unpublished ZeroSettle-Android checkout, use `mavenLocal()` publishing — the conventional Android multi-repo workflow.

From the ZeroSettle-Android checkout, after every SDK source change:

```bash
cd /path/to/ZeroSettle-Android
./gradlew :core:publishToMavenLocal :ui:publishToMavenLocal
```

This produces `~/.m2/repository/io/zerosettle/zerosettle-android/1.0.0/...` and `…-ui/1.0.0/...`. The plugin's `android/build.gradle` already lists `mavenLocal()` first in its repositories, so the in-tree build will pick up the locally-published artifacts.

When the SDK version on `main` differs from the published Maven Central version, the plugin's pinned coord (`1.0.0`) needs a matching local publish for resolution to succeed; otherwise builds fall through to Maven Central as normal.

**Why not composite-build / `includeBuild`?** Composite-build couples the AGP version across all repos (you'd need plugin / example / SDK all on the same AGP line). The plugin and the SDK ship on independent release cadences; mavenLocal keeps them decoupled. Production resolution is also identical to dev resolution (both go through the Maven coord), reducing "works in dev, fails in prod" surprises.

## Links

- [ZeroSettle](https://zerosettle.io)
- [Native iOS SDK (ZeroSettleKit)](https://github.com/zerosettle/ZeroSettleKit)
- [Documentation](https://zerosettle.io)
