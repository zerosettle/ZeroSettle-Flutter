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

## Platform Support

| Platform | Status |
|----------|--------|
| iOS      | Supported |
| Android  | Coming soon |

## How It Works

This plugin is a thin Dart wrapper around the native [ZeroSettleKit](https://github.com/zerosettle/ZeroSettleKit) SDK. On iOS, it pulls ZeroSettleKit via CocoaPods — no xcframework is bundled in this repo.

## Links

- [ZeroSettle](https://zerosettle.io)
- [Native iOS SDK (ZeroSettleKit)](https://github.com/zerosettle/ZeroSettleKit)
- [Documentation](https://zerosettle.io)
