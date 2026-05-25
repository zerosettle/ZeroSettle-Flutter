## 1.5.1 — 2026-05-25

Soft-deprecate the "Force ECL available" testing override in favor of the
single, end-to-end `setSwitchAndSaveTestMode` flag.

### Deprecated

- `ZeroSettle.instance.setEclAvailabilityOverride(bool?)` — emits a deprecation
  warning. The method only ever affected the offer-gate visibility on Android;
  tapping the resulting "Switch Now" CTA still queried Play Billing for ECL
  availability and errored with `SwitchAndSaveUnavailable` on non-enrolled
  devices. Use `setSwitchAndSaveTestMode(true)` instead — it surfaces the tip
  AND lets the entire flow run end-to-end on a non-ECL device. The bridge keeps
  forwarding so existing apps continue to work; the method will be removed in a
  future major.

### Example app

- Removed the "Force ECL available" toggle and its persisted `eclOverride`
  pref. The remaining "Switch & Save full test mode" toggle is the single
  end-to-end Switch & Save testing switch.

### Bumped

- `io.zerosettle:zerosettle-android` dependency to `1.1.1` (carries the matching
  SDK-side soft-deprecation). Local Flutter Android builds need
  `publishToMavenLocal` from the `ZeroSettle-Android` checkout until `1.1.1`
  publishes to Maven Central.

## 1.5.0 — 2026-05-22

Android-parity sweep — closes the seven remaining bridge gaps so a Flutter app gets the same surfaces a native Android app gets. Everything is additive; no existing public API was renamed or removed.

### Added

- `ZeroSettle.instance.getSdkVersion()` — returns the native SDK version string.
- `ZeroSettle.instance.getIsUcbEnabled()` + `isUcbEnabledUpdates` stream — User Choice Billing state. Android-only; iOS returns `false` and emits a single `false`.
- `ZeroSettle.instance.releasePendingCheckout()` — cancels an in-flight web checkout. Android-only; iOS is a no-op.
- `ZeroSettle.instance.getPendingActions()`, `pendingActionsUpdates` stream, and `dismissPendingAction({transactionId})` — backend-driven user prompts (post-migration info, manual Play cancel). Android-only; iOS returns empty lists / no-op.
- `PendingAction` Dart sealed model with `PendingActionMigrationCompletedInfo` and `PendingActionManualPlayCancel` variants.
- `ZeroSettlePendingActionBanner` widget — zero-config Flutter mount point for the native Android pending-action banner; the native side self-renders the current top pending action from the SDK stream. iOS renders nothing.
- `ZeroSettle.instance.fetchUserOffer()` returning a typed `UserOfferResponse` — the server-canonical offer decision (migration / upgrade eligibility). The recommended offer API on both platforms.
- `UserOffer*` Dart model tree (`UserOfferResponse`, `UserOfferSubscription`, `UserOfferData`, `UserOfferDisplay`, `UserOfferProration`, `UserOfferAppleSubscription`) plus `UserOfferActionType` and `UserOfferSourceStorefront` enums.
- `ZeroSettle.instance.events` — `Stream<ZeroSettleEvent>` of SDK analytics/lifecycle events (see the variant table below). New `ZeroSettleEvent` sealed model with 10 typed variants + `ZSEventUnknown` forward-compat fallback.
- `ZeroSettle.instance.setSwitchAndSaveTestMode(bool)` — testing override that runs the entire Switch & Save (Play→web ECL migration) flow on a device/account not enrolled in Google's External Content Link program: the Play ECL plumbing is faked while the backend session mint and the web checkout run for real. Also implies ECL-available, so the offer tip surfaces. Android-only; iOS is a no-op. Requires `zerosettle-android` 1.1.0.

### Changed

- **The offer-tip Flutter widget is now `OfferTipView`** (was `MigrationTipView`), matching the canonical name in iOS `ZeroSettleKit`. `MigrationTipView` and `ZSMigrateTipView` remain as `@Deprecated` typedef aliases, so existing code keeps compiling. The separate `ZeroSettleOfferTip` widget added earlier in this unreleased cycle (Android-only, no height-bridge) is removed — `OfferTipView` is the single, unified, cross-platform offer tip.

### Fixed

- **Android: `ZeroSettleMigrationManagerStatics` no longer throws `MissingPluginException`.** The `zerosettle/migration_manager_static` MethodChannel is now wired. `isPermanentlyDismissed`/`setDismissed` route to the unified `OfferDismissalStore`; `resetDismissedState` is a deliberate no-op (calling it would conflate the two iOS-distinct stores).
- **Android: the offer tip (`OfferTipView`) now renders and the "Switch now" CTA works.** Previously the embedded native offer tip never appeared on Android. Three stacked issues are fixed: a window-level `ViewTree*` lifecycle owner is installed on the activity content view so a `ComposeView` can compose inside a Flutter PlatformView (`FlutterView` provides none); the Android `AndroidView` is bootstrapped at 1px so Flutter instantiates the platform view; and the height bridge measures the tip's intrinsic height via an unbounded re-measure. The `ComposeView` is now built against the host `Activity`, so the "Switch now" CTA drives the SDK's Switch & Save checkout instead of silently no-op'ing (the SDK's offer-tip composable resolves the checkout Activity from `LocalContext`).

---

### `ZeroSettle.instance.events` — SDK analytics/lifecycle stream

A new `Stream<ZeroSettleEvent>` is available at `ZeroSettle.instance.events`. Subscribe to receive discrete analytics and lifecycle events from the SDK without polling entitlements or wiring delegate callbacks.

```dart
ZeroSettle.instance.events.listen((event) {
  switch (event) {
    case ZSEventPurchaseSucceeded(:final productId, :final transactionId):
      analytics.track('purchase', {
        'product': productId,
        'transaction': transactionId,
      });
    case ZSEventEntitlementsRefreshed(:final count):
      print('$count active entitlements');
    case ZSEventSyncFailed(:final terminal):
      if (terminal) notifyUser('Sync failed — please restore purchases.');
    default:
      break;
  }
});
```

**Event variants**

| Type | Fields | Platforms |
|---|---|---|
| `ZSEventPurchaseSucceeded` | `productId`, `transactionId` | Android + iOS |
| `ZSEventPurchaseFailed` | `productId`, `reason` | Android + iOS |
| `ZSEventEntitlementsRefreshed` | `count` (active-only) | Android + iOS |
| `ZSEventSyncFailed` | `purchaseToken`, `attempts`, `terminal` | Android (full); iOS (degraded: `purchaseToken=""`, `attempts=1`) |
| `ZSEventOfferShown` | `productId` | Android only |
| `ZSEventOfferAccepted` | `productId` | Android only |
| `ZSEventOfferDismissed` | `productId` | Android only |
| `ZSEventOfferEvaluationFailed` | `reason` | Android only |
| `ZSEventMigrationCompleted` | `productId` | Android only |
| `ZSEventPendingActionShown` | `actionType` | Android only |
| `ZSEventUnknown` | `type` (raw string) | Both (forward-compat fallback) |

Unknown event types decode to `ZSEventUnknown` rather than throwing, so apps built against an older SDK version remain compatible when new variants are introduced.

**Android:** backs directly off `ZeroSettle.events` (`SharedFlow<ZeroSettleEvent>`). All 10 variants are emitted natively.

**iOS:** backs off the `ZeroSettleDelegate` callbacks available in ZeroSettleKit. Events that have no delegate equivalent (`offerShown`, `offerAccepted`, `offerDismissed`, `offerEvaluationFailed`, `migrationCompleted`, `pendingActionShown`) are absent on iOS — they have no callback surface in the iOS SDK. iOS apps should observe offer-lifecycle events via `OfferManager.stateUpdates` instead.

### Android: `ZeroSettleMigrationManagerStatics` no longer throws `NotImplementedError`

The `zerosettle/migration_manager_static` MethodChannel is now wired on Android. Dart's deprecated `ZeroSettleMigrationManagerStatics.isPermanentlyDismissed` and `setDismissed` now resolve against the same `OfferDismissalStore` as `ZeroSettleOfferManagerStatics`. `resetDismissedState` is a deliberate no-op on Android (calling it would conflate the two iOS-distinct stores).

This is an internal fix — the `MigrationManager` Dart class is deprecated in favour of `OfferManager`. Existing apps using `ZeroSettleMigrationManagerStatics` calls will no longer crash on Android.

## 1.4.0

Tracks ZeroSettleKit 1.3.6. Two headline changes plus a Kit-level bug fix:

1. **Auto-bookkeeping for offer checkouts.** `ZeroSettle.instance.presentPaymentSheet(...)` and `ZeroSettle.instance.purchase(...)` now run the offer state machine automatically when the productId matches the active offer's `checkoutProductId`. Adopters using `OfferManager` no longer need to call `manager.present()` or `manager.markCheckoutSucceeded()` manually.
2. **Swift Package Manager support.** The plugin's iOS layer now supports SPM in addition to CocoaPods. Apps on Flutter 3.41+ with `flutter config --enable-swift-package-manager` get the SPM resolution path, which pulls ZeroSettleKit directly from `github.com/zerosettle/ZeroSettleKit` (bypassing the CocoaPods chain). CocoaPods adopters continue to work unchanged.

### Auto-bookkeeping (the headline change)

Adopters using `ZeroSettle.instance.presentPaymentSheet(...)` to accept a migration or upgrade offer no longer need to call `manager.present()` or `manager.markCheckoutSucceeded()`. The SDK detects active offer context and runs the state machine itself:

- Pre-checkout: state advances `.eligible → .presented`.
- Post-checkout success: state advances `.presented → .accepted` or `.presented → .completed` depending on `needsAppleCancel`. Migration conversion analytics fire automatically.
- Failure / cancellation: state stays `.presented`. User retries via the same CTA.

The `OfferManager.stateUpdates` stream surfaces every transition — reactive UI driven from this stream works identically before and after this release.

### Swift Package Manager support

Apps on Flutter 3.41+ can opt into SPM resolution with `flutter config --enable-swift-package-manager` (or via per-project pubspec config). The plugin's iOS layer at `ios/zerosettle/Sources/zerosettle/` is now SPM-conventional, and a new `ios/zerosettle/Package.swift` declares ZeroSettleKit as an SPM dependency (`~> 1.3.6`).

### Kit 1.3.6 fix: checkout sheet no longer shrinks mid-presentation

`CheckoutPreloaderPool.ensureReady` (in ZeroSettleKit) previously returned the moment `buttonsReady` fired, before `measureContentJS` had completed and `measuredContentHeight` was set. `CheckoutSheet`'s internal init then read `measuredContentHeight = 0`, the WebView fell back to a 300pt placeholder frame, and the live geometry observer later reported the real height — causing a visible sheet shrink during presentation. Kit 1.3.6 extends `ensureReady` to also wait for the `isReady` signal (which fires alongside `measuredContentHeight`). Flutter adopters using `presentPaymentSheet` benefit automatically by tracking Kit `~> 1.3.6`.

CocoaPods adopters: nothing changes. The podspec stays as the fallback resolution path; iOS sources just live at a different path internally (transparent to consumers).

### Adopter migration (auto-bookkeeping)

If your app calls `manager.present()` and `manager.markCheckoutSucceeded()` around `ZeroSettle.instance.presentPaymentSheet(...)`, delete both calls. The SDK now handles them. Compile-time deprecation warnings will guide you.

If your app uses `manager.startCheckout()` for raw URL flows, no change — that path stays manual and supported.

### Deprecations

* **`OfferManager.present()`** — `@Deprecated`. Bookkeeping is automatic. Removed in 2.0.
* **`OfferManager.markCheckoutSucceeded({transactionId})`** — `@Deprecated`. Bookkeeping is automatic. Body retained through 1.x for adopters using `startCheckout` (raw URL escape hatch).
* **`MigrationManager` (entire class)** — class-level `@Deprecated`. Mirrors Kit's existing class-level deprecation on `ZSMigrationManager`. Use `OfferManager` instead via `ZeroSettle.instance.offerManager()` — strict superset that handles migration + StoreKit→web upgrade + web→web upgrade.

### Not deprecated

* **`OfferManager.startCheckout({stripeCustomerId})`** — remains the sanctioned path for adopters who need custom WebView/transport. Docstring rewritten to clarify scope.

### Example app

`MigrationOfferCard` renamed to `OfferCard`, switched to `OfferManager`, and updated to demonstrate the canonical 1-call `_accept()` flow. The example now has zero deprecation warnings.

### Minimum requirements

* **Flutter:** `>=3.41.0` (required for SPM plugin tooling; apps on older Flutter pin to 1.3.4).
* **Dart SDK:** `^3.11.0`.
* **iOS deployment target:** `18.0` (matches ZeroSettleKit minimum).

### Bumps

* iOS pod dependency: `ZeroSettleKit ~> 1.3.6`.
* Plugin tracks Kit's 1.3.x line in lockstep.

## 1.3.4

Tracks ZeroSettleKit 1.3.4. Two adopter-visible changes plus a bridge cleanup.

### `ZSApplePaySetupRequiredException` gains `autoPresentedSetup` field

Mirrors Kit 1.3.4's payload addition on `ZeroSettleError.applePaySetupRequired(autoPresentedSetup:)`. When the SDK auto-presented the system Wallet (because `Configuration.applePaySetupBehavior == ApplePaySetupBehavior.presentBuiltInUI`, the default), `autoPresentedSetup` is `true`; your app should NOT stack additional setup UI. When `delegateToApp`, the flag is `false` and your app owns the setup affordance — call `ZeroSettle.instance.presentApplePaySetup()` when ready.

```dart
try {
  await ZeroSettle.instance.purchase(productId: 'pro_monthly');
} on ZSApplePaySetupRequiredException catch (e) {
  if (e.autoPresentedSetup) {
    // SDK already opened Wallet — no UI needed, maybe analytics
  } else {
    showCustomSetupSheet();
  }
}
```

Source-compatible — the new field has a default of `false`, so existing `catch (e)` blocks keep working.

### `OfferManager` factory: orphan-manager hazard fixed (Kit-side)

Kit 1.3.4's `offerManager(stripeCustomerId:)` is now non-throwing and eager — it returns the canonical shared instance regardless of `identify()` state. The Flutter bridge no longer wraps the call in `try/catch`. Adopters using `await ZeroSettle.instance.offerManager(...)` benefit automatically: handles obtained before `identify()` runs now stay live and re-evaluate eligibility in place once the user identifies.

### Internal: `@Observable` migration in ZeroSettleKit (no Flutter impact)

Kit 1.3.4 migrated `ApplePayAvailability` from `ObservableObject`/`@Published` to Swift's modern Observation framework. The Flutter bridge subscribes to the deprecated-but-still-supported `statePublisher` (Combine `AnyPublisher`) — no Flutter-visible behavior change. Will be revisited before Kit 2.0 removes the Combine bridge.

### Bumps

* iOS pod dependency: `ZeroSettleKit ~> 1.3.4`.
* Plugin tracks Kit's 1.3.x line in lockstep.

## 1.3.3

Tracks ZeroSettleKit 1.3.3. **No Flutter-visible API changes** — the Kit's 1.3.3 work (`OfferTipView` and `ZSOfferManager` direct-init no longer require `userId:`) only affects native Swift call sites. Flutter already uses the canonical `ZeroSettle.instance.offerManager(stripeCustomerId:)` factory, so all 1.3.3 fixes are absorbed transparently.

* iOS pod dependency: `ZeroSettleKit ~> 1.3.3`.

## 1.3.2

Tracks ZeroSettleKit 1.3.2. Pre-existing primitives that were missing in earlier 1.3.x Flutter releases are now bridged, plus the new Apple Pay availability + setup-behavior surface.

### New purchase primitives

* **`purchase({productId, presentation?})`** — unified purchase entry point. Routes web vs. StoreKit per jurisdiction. Returns a `CheckoutTransaction`.
* **`purchaseViaStoreKit({productId})`** — explicit native StoreKit 2 purchase. Returns a `CheckoutTransaction` populated from the StoreKit 2 `Transaction` (price/currency may be `null`).
* **`CheckoutType` enum** for the optional `presentation` argument on `purchase()`.

### New state queries

* **`getCurrentUserId() → Future<String?>`** — observable identity state.
* **`getIsBootstrapped() → Future<bool>`** — SDK readiness flag adopters can poll/listen for before calling user-scoped APIs.
* **`recommendedAppAccountToken() → Future<String>`** — UUID derivation helper for non-UUID user IDs (Firebase, Privy, Auth0, etc.).

### Pending claims (StoreKit ownership transfer UX)

* **`getPendingClaims() → Future<List<PendingClaim>>`** — read once.
* **`pendingClaimsUpdates` stream** — emits whenever the SDK observes a StoreKit purchase that belongs to another ZeroSettle account on this device. Power your "transfer this purchase?" UX from this stream, then call `transferStoreKitOwnershipToCurrentUser({productId})` when the user confirms.
* New `PendingClaim` model.

### Apple Pay surface (new in Kit 1.3.2)

* **`Configuration.applePaySetupBehavior`** — new optional `configure()` parameter. `ApplePaySetupBehavior.presentBuiltInUI` (default) opens system Wallet automatically when an Apple-Pay-only merchant has no Wallet card; `ApplePaySetupBehavior.delegateToApp` surfaces `ZSApplePaySetupRequiredException` so your app can handle the flow.
* **`presentApplePaySetup()`** — opens system Wallet to add a card.
* **`getIsApplePayOnly() → Future<bool>`** — true when the active merchant config is Apple-Pay-only.
* **`getApplePayState() → Future<ApplePayAvailabilityState>`** — read the current `.ready` / `.setupRequired` / `.unavailable` state.
* **`applePayStateUpdates` stream** — observe state transitions to drive your own banner / pre-flight UI.
* **2 new exceptions:** `ZSApplePayUnavailableException`, `ZSApplePaySetupRequiredException`.
* **`CheckoutConfig.paymentMethods`** + **`isApplePayOnly`** getter on the remote config.

### Bug fixes

* **`setBaseUrlOverride`** had no concrete `MethodChannel` override (regression introduced in 0.4.0). Fixed; any environment using `baseUrlOverride` (staging, internal/ngrok) now configures correctly.
* **MIME-type cleanups** in test mocks for `acceptSaveOffer` / `fetchUpgradeOfferConfig` so facade round-trips don't fail on empty maps.

### Bumps

* iOS pod dependency: `ZeroSettleKit ~> 1.3.2`.
* Plugin tracks Kit's 1.3.x line in lockstep.

## 1.3.0

* **Adds `identify()` as the canonical entry point.** Takes an `Identity` (sealed class with `Identity.user`, `Identity.anonymous`, `Identity.deferred`). Call once at launch (and again on sign-in/sign-out). Subsequent user-scoped calls read identity from internal state — no more passing `userId:` everywhere.
* **Adds 10 `userId`-less method overloads.** `restoreEntitlements()`, `fetchTransactionHistory()`, `acceptSaveOffer({productId})`, `presentCancelFlow({productId})`, `pauseSubscription({productId, pauseDurationDays})`, `resumeSubscription({productId})`, `cancelSubscription({productId, immediate})`, `presentUpgradeOffer({productId})`, `fetchUpgradeOfferConfig({productId})`, `trackMigrationConversion()`. Use these after calling `identify()`.
* **Deprecates the `userId:` parameter on every facade method, plus `bootstrap()`.** They still compile and work through the 1.x line, but the parameter is annotated `@Deprecated` and will be removed in `2.0`. Migrate by calling `identify()` once and dropping `userId:` from the rest.
* **Adds `appleMerchantId`, `preloadCheckout`, `maxPreloadedWebViews` to `configure()`.** Configuration parity with iOS Kit 1.3.0.
* **Fixes `pauseSubscription` signature.** The bridge now passes `pauseDurationDays` to ZeroSettleKit 1.3.0 (was `pauseOptionId`). Deprecated `pauseOptionId` parameter remains on the facade for source compatibility through 1.x.
* **Adds 5 new exception types** mapped from ZeroSettleKit 1.3.0 errors: `ZSInvalidPublishableKeyException`, `ZSCheckoutConfigExpiredException`, `ZSTransactionVerificationFailedException`, `ZSPurchasePendingException`, `ZSUserNotIdentifiedException`.
* **Fixes `CancelFlowOption.fromMap`** null-safety for `triggersOffer` / `triggersPause` (defaults to `false` when absent).
* Bumps iOS pod dependency to `ZeroSettleKit ~> 1.3.0`.
* See [`MIGRATING.md`](https://github.com/zerosettle/ZeroSettleKit/blob/main/MIGRATING.md) in the iOS Kit for the full 1.3.0 migration guide; the same renames and deprecations apply to the Flutter SDK Dart facade.

## 0.4.0

* Aligns bridge with ZeroSettleKit 1.2.5.
* Adds `setCustomer({name, email})` and `logout()`.
* Adds `transferStoreKitOwnershipToCurrentUser` (replaces removed `claimEntitlement`).
* Adds `hasActiveEntitlement(productId)`, `product(productId)`.
* Maps `ZeroSettleError.checkoutNotStarted` to `ZSCheckoutNotStartedException`.
* Surfaces previously-missing model fields:
  * `Entitlement.storekitOriginalTransactionId`, `originalPurchaseDate`
  * `Product.subscriptionGroupId`, `billingInterval`, `freeTrialDuration`, `isTrialEligible`
  * `CheckoutTransaction.storekitStatus`
* Stubs removed APIs (`openCustomerPortal`, `showManageSubscription`, `presentSaveTheSaleSheet`) with `not_implemented` errors; Dart facade kept for source-compat.
* Fixes bridge drift: `ZeroSettleKit.Product → ZSProduct`, `Price.cents → Price.amountCents`, `Entitlement.status` no longer optional.

## 0.3.4

* Update to ZeroSettleKit 1.2.3

## 0.3.3

* Maintenance release - no functional changes

## 0.3.2

* Add `ZSMigrateTipView` widget for encouraging StoreKit users to migrate to web billing
* Update to ZeroSettleKit 0.7.2

## 0.3.1

* **Breaking**: Add required `freeTrialDays` parameter to `bootstrap()`, `warmUpPaymentSheet()`, `preloadPaymentSheet()`, and `presentPaymentSheet()` methods
* Update to ZeroSettleKit 0.7.1+ with free trial support
* Update podspec to automatically use latest 0.7.x releases

## 0.3.0

* Add `remoteConfig` and `detectedJurisdiction` getters for jurisdiction-specific checkout behavior
* Add support for smart subscription management via `showManageSubscription()`
* Update to ZeroSettleKit 0.6.0+ API surface

## 0.2.0

* Update models and APIs to match ZeroSettleKit iOS SDK
* Add checkout events stream
* Improve error handling

## 0.1.0

* Initial release with core IAP functionality
* Support for product catalog, payment sheets, and entitlements
* iOS platform support via ZeroSettleKit
