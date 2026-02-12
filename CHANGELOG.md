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
