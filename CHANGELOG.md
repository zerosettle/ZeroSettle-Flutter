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
