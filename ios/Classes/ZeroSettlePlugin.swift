import Flutter
import UIKit
import ZeroSettleKit
import SwiftUI

public class ZeroSettlePlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate {

    private var methodChannel: FlutterMethodChannel?
    private var entitlementEventChannel: FlutterEventChannel?
    private var checkoutEventChannel: FlutterEventChannel?

    private let entitlementStreamHandler = EntitlementStreamHandler()
    private let checkoutStreamHandler = CheckoutStreamHandler()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "zerosettle", binaryMessenger: registrar.messenger())
        let instance = ZeroSettlePlugin()
        instance.methodChannel = channel

        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)

        let entitlementEC = FlutterEventChannel(name: "zerosettle/entitlement_updates", binaryMessenger: registrar.messenger())
        entitlementEC.setStreamHandler(instance.entitlementStreamHandler)
        instance.entitlementEventChannel = entitlementEC

        let checkoutEC = FlutterEventChannel(name: "zerosettle/checkout_events", binaryMessenger: registrar.messenger())
        checkoutEC.setStreamHandler(instance.checkoutStreamHandler)
        instance.checkoutEventChannel = checkoutEC

        // Register MigrationTipView PlatformView factory
        let migrateTipFactory = ZSMigrateTipViewFactory(messenger: registrar.messenger())
        registrar.register(migrateTipFactory, withId: "zerosettle/migrate_tip_view")
    }

    // MARK: - Universal Link Handling

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([Any]) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        return MainActor.assumeIsolated {
            ZeroSettle.shared.handleUniversalLink(url)
        }
    }

    // MARK: - Method Channel Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Task { @MainActor in
            self.handleOnMainActor(call, result: result)
        }
    }

    @MainActor
    private func handleOnMainActor(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {

        // -- Configuration --

        case "setBaseUrlOverride":
            let urlString = args?["url"] as? String
            #if DEBUG
            if let urlString, let url = URL(string: urlString) {
                ZeroSettle.baseURLOverride = url
            } else {
                ZeroSettle.baseURLOverride = nil
            }
            #endif
            result(nil)

        case "configure":
            guard let publishableKey = args?["publishableKey"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "publishableKey is required", details: nil))
                return
            }
            let syncStoreKit = args?["syncStoreKitTransactions"] as? Bool ?? true
            let config = ZeroSettle.Configuration(
                publishableKey: publishableKey,
                syncStoreKitTransactions: syncStoreKit
            )
            ZeroSettle.shared.configure(config)
            ZeroSettle.shared.delegate = self
            result(nil)

        // -- Bootstrap --

        case "bootstrap":
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let catalog = try await ZeroSettle.shared.bootstrap(userId: userId)
                    result(catalog.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Products --

        case "fetchProducts":
            let userId = args?["userId"] as? String
            Task { @MainActor in
                do {
                    let catalog = try await ZeroSettle.shared.fetchProducts(userId: userId)
                    result(catalog.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "getProducts":
            let products = ZeroSettle.shared.products.map { $0.toFlutterMap() }
            result(products)

        // -- Payment Sheet --

        case "presentPaymentSheet":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let userId = args?["userId"] as? String
            let dismissible = args?["dismissible"] as? Bool ?? true

            guard let product = ZeroSettle.shared.products.first(where: { $0.id == productId }) else {
                result(FlutterError(code: "product_not_found", message: "Product not found: \(productId)", details: nil))
                return
            }

            guard let viewController = Self.topViewController() else {
                result(FlutterError(code: "no_view_controller", message: "Could not find root view controller", details: nil))
                return
            }

            CheckoutSheet<PaymentSheetHeader>.present(
                from: viewController,
                product: product,
                userId: userId,
                dismissible: dismissible,
                header: { PaymentSheetHeader(product: product) },
                onComplete: { completionResult in
                    switch completionResult {
                    case .success(let transaction):
                        result(transaction.toFlutterMap())
                    case .failure(let error):
                        if let zsError = error as? ZeroSettleError {
                            switch zsError {
                            case .cancelled:
                                result(FlutterError(code: "cancelled", message: "User cancelled checkout", details: nil))
                            default:
                                result(zsError.toFlutterError())
                            }
                        } else {
                            result(FlutterError(code: "checkout_failed", message: error.localizedDescription, details: nil))
                        }
                    }
                }
            )

        case "preloadPaymentSheet":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let userId = args?["userId"] as? String
            Task { @MainActor in
                _ = await CheckoutSheet<EmptyView>.preload(productId: productId, userId: userId)
                result(nil)
            }

        case "warmUpPaymentSheet":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let userId = args?["userId"] as? String
            Task { @MainActor in
                await CheckoutSheet<EmptyView>.warmUp(productId: productId, userId: userId)
                result(nil)
            }

        // -- Entitlements --

        case "restoreEntitlements":
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let entitlements = try await ZeroSettle.shared.restoreEntitlements(userId: userId)
                    result(entitlements.map { $0.toFlutterMap() })
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "getEntitlements":
            let entitlements = ZeroSettle.shared.entitlements.map { $0.toFlutterMap() }
            result(entitlements)

        // -- Subscription Management --

        case "openCustomerPortal":
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    try await ZeroSettle.shared.openCustomerPortal(userId: userId)
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "showManageSubscription":
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    try await ZeroSettle.shared.showManageSubscription(userId: userId)
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Universal Links --

        case "handleUniversalLink":
            guard let urlString = args?["url"] as? String,
                  let url = URL(string: urlString) else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Valid URL is required", details: nil))
                return
            }
            let handled = ZeroSettle.shared.handleUniversalLink(url)
            result(handled)

        // -- Transaction History --

        case "fetchTransactionHistory":
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let transactions = try await ZeroSettle.shared.fetchTransactionHistory(userId: userId)
                    result(transactions.map { $0.toFlutterMap() })
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Cancel Flow --

        case "presentCancelFlow":
            guard let productId = args?["productId"] as? String,
                  let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId and userId are required", details: nil))
                return
            }
            Task { @MainActor in
                let cancelResult = await ZeroSettle.shared.presentCancelFlow(
                    productId: productId,
                    userId: userId
                )
                switch cancelResult {
                case .cancelled: result("cancelled")
                case .retained: result("retained")
                case .dismissed: result("dismissed")
                case .paused(let resumesAt):
                    if let resumesAt {
                        result("paused:" + iso8601Formatter.string(from: resumesAt))
                    } else {
                        result("paused:")
                    }
                }
            }

        case "fetchCancelFlowConfig":
            let userId = args?["userId"] as? String
            Task { @MainActor in
                do {
                    let config = try await ZeroSettle.shared.fetchCancelFlowConfig(userId: userId)
                    result(config.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "pauseSubscription":
            guard let productId = args?["productId"] as? String,
                  let userId = args?["userId"] as? String,
                  let pauseOptionId = args?["pauseOptionId"] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId, userId, and pauseOptionId are required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let resumesAt = try await ZeroSettle.shared.pauseSubscription(
                        productId: productId,
                        userId: userId,
                        pauseOptionId: pauseOptionId
                    )
                    if let resumesAt {
                        result(iso8601Formatter.string(from: resumesAt))
                    } else {
                        result(nil)
                    }
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "resumeSubscription":
            guard let productId = args?["productId"] as? String,
                  let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId and userId are required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    try await ZeroSettle.shared.resumeSubscription(
                        productId: productId,
                        userId: userId
                    )
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Cancel Flow (Headless) --

        case "acceptSaveOffer":
            guard let productId = args?["productId"] as? String,
                  let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId and userId are required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let offerResult = try await ZeroSettle.shared.acceptSaveOffer(productId: productId, userId: userId)
                    result([
                        "message": offerResult.message,
                        "discountPercent": offerResult.discountPercent,
                        "durationMonths": offerResult.durationMonths,
                    ] as [String: Any])
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "submitCancelFlowResponse":
            guard let responseMap = args else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "response is required", details: nil))
                return
            }
            let answers = (responseMap["answers"] as? [[String: Any]])?.map { answerMap in
                CancelFlow.Answer(
                    questionId: answerMap["questionId"] as! Int,
                    selectedOptionId: answerMap["selectedOptionId"] as! Int,
                    freeText: answerMap["freeText"] as? String
                )
            } ?? []
            let outcome: CancelFlow.Outcome
            switch responseMap["outcome"] as? String {
            case "cancelled": outcome = .cancelled
            case "retained": outcome = .retained
            case "paused": outcome = .paused
            case "dismissed": outcome = .dismissed
            default: outcome = .cancelled
            }
            let response = CancelFlow.Response(
                productId: responseMap["productId"] as! String,
                userId: responseMap["userId"] as! String,
                outcome: outcome,
                answers: answers,
                offerShown: responseMap["offerShown"] as? Bool ?? false,
                offerAccepted: responseMap["offerAccepted"] as? Bool ?? false,
                pauseShown: responseMap["pauseShown"] as? Bool ?? false,
                pauseAccepted: responseMap["pauseAccepted"] as? Bool ?? false,
                pauseDurationDays: responseMap["pauseDurationDays"] as? Int
            )
            Task { @MainActor in
                do {
                    try await ZeroSettle.shared.submitCancelFlowResponse(response)
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "getCancelFlowConfig":
            if let config = ZeroSettle.shared.cancelFlowConfig {
                result(config.toFlutterMap())
            } else {
                result(nil)
            }

        case "cancelSubscription":
            guard let productId = args?["productId"] as? String,
                  let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId and userId are required", details: nil))
                return
            }
            let immediate = args?["immediate"] as? Bool ?? false
            Task { @MainActor in
                do {
                    try await ZeroSettle.shared.cancelSubscription(productId: productId, userId: userId, immediate: immediate)
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Funnel Analytics --

        case "trackEvent":
            guard let eventType = args?["eventType"] as? String,
                  let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "eventType and productId are required", details: nil))
                return
            }
            let screenName = args?["screenName"] as? String
            let metadata = args?["metadata"] as? [String: String]

            guard let funnelType = FunnelEventType(rawValue: eventType) else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Unknown event type: \(eventType)", details: nil))
                return
            }

            ZeroSettle.trackEvent(funnelType, productId: productId, screenName: screenName, metadata: metadata)
            result(nil)

        // -- Migration Tracking --

        case "trackMigrationConversion":
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    try await ZeroSettle.shared.trackMigrationConversion(userId: userId)
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Migration Tip --

        case "resetMigrateTipState":
            MigrationManager.resetDismissedState()
            result(nil)

        // -- State Queries --

        case "getIsConfigured":
            result(ZeroSettle.shared.isConfigured)

        case "getPendingCheckout":
            result(ZeroSettle.shared.pendingCheckout)

        case "getRemoteConfig":
            if let config = ZeroSettle.shared.remoteConfig {
                result(config.toFlutterMap())
            } else {
                result(nil)
            }

        case "getDetectedJurisdiction":
            result(ZeroSettle.shared.detectedJurisdiction?.rawValue)

        // -- Upgrade Offer --

        case "presentUpgradeOffer":
            let productId = args?["productId"] as? String
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                let upgradeResult = await ZeroSettle.shared.presentUpgradeOffer(
                    productId: productId,
                    userId: userId
                )
                switch upgradeResult {
                case .upgraded: result("upgraded")
                case .declined: result("declined")
                case .dismissed: result("dismissed")
                }
            }

        case "fetchUpgradeOfferConfig":
            let productId = args?["productId"] as? String
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let config = try await ZeroSettle.shared.fetchUpgradeOfferConfig(
                        productId: productId,
                        userId: userId
                    )
                    result(config.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Save the Sale --

        case "presentSaveTheSaleSheet":
            guard let viewController = Self.topViewController() else {
                result(FlutterError(code: "no_view_controller", message: "Could not find root view controller", details: nil))
                return
            }

            ZSSaveTheSaleSheet.present(from: viewController) { saveResult in
                switch saveResult {
                case .pauseAccount:
                    result("pauseAccount")
                case .stayWithDiscount:
                    result("stayWithDiscount")
                case .dismissed:
                    result("dismissed")
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Root View Controller

    @MainActor
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - ZeroSettleDelegate

extension ZeroSettlePlugin: ZeroSettleDelegate {

    public func zeroSettleCheckoutDidBegin(productId: String) {
        checkoutStreamHandler.send([
            "event": "checkoutDidBegin",
            "productId": productId,
        ])
    }

    public func zeroSettleCheckoutDidComplete(transaction: CheckoutTransaction) {
        checkoutStreamHandler.send([
            "event": "checkoutDidComplete",
            "transaction": transaction.toFlutterMap(),
        ])
    }

    public func zeroSettleCheckoutDidCancel(productId: String) {
        checkoutStreamHandler.send([
            "event": "checkoutDidCancel",
            "productId": productId,
        ])
    }

    public func zeroSettleCheckoutDidFail(productId: String, error: Error) {
        checkoutStreamHandler.send([
            "event": "checkoutDidFail",
            "productId": productId,
            "error": error.localizedDescription,
        ])
    }

    public func zeroSettleEntitlementsDidUpdate(_ entitlements: [Entitlement]) {
        entitlementStreamHandler.send(entitlements.map { $0.toFlutterMap() })
    }

    public func zeroSettleDidSyncStoreKitTransaction(productId: String, transactionId: UInt64) {
        checkoutStreamHandler.send([
            "event": "storeKitTransactionSynced",
            "productId": productId,
            "transactionId": transactionId,
        ])
    }

    public func zeroSettleStoreKitSyncFailed(error: Error) {
        checkoutStreamHandler.send([
            "event": "storeKitSyncFailed",
            "error": error.localizedDescription,
        ])
    }
}

// MARK: - Event Stream Handlers

private class EntitlementStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ data: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

private class CheckoutStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ data: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

// MARK: - Serialization Helpers

private let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

extension Price {
    func toFlutterMap() -> [String: Any] {
        return [
            "amountCents": amountCents,
            "currencyCode": currencyCode,
        ]
    }
}

extension Promotion {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "promotionalPrice": promotionalPrice.toFlutterMap(),
            "type": type.rawValue,
        ]
        if let expiresAt {
            map["expiresAt"] = iso8601Formatter.string(from: expiresAt)
        }
        return map
    }
}

extension ZeroSettleKit.Product {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "productDescription": productDescription,
            "type": type.rawValue,
            "syncedToAppStoreConnect": syncedToAppStoreConnect,
            "storeKitAvailable": storeKitAvailable,
        ]
        if let webPrice {
            map["webPrice"] = webPrice.toFlutterMap()
        }
        if let appStorePrice {
            map["appStorePrice"] = appStorePrice.toFlutterMap()
        }
        if let promotion {
            map["promotion"] = promotion.toFlutterMap()
        }
        if let storeKitPrice {
            map["storeKitPrice"] = storeKitPrice.toFlutterMap()
        }
        if let savingsPercent {
            map["savingsPercent"] = savingsPercent
        }
        return map
    }
}

extension Entitlement {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "productId": productId,
            "source": source.rawValue,
            "isActive": isActive,
            "purchasedAt": iso8601Formatter.string(from: purchasedAt),
        ]
        if let expiresAt {
            map["expiresAt"] = iso8601Formatter.string(from: expiresAt)
        }
        if let status {
            map["status"] = status.rawString
        }
        if let pausedAt {
            map["pausedAt"] = iso8601Formatter.string(from: pausedAt)
        }
        if let pauseResumesAt {
            map["pauseResumesAt"] = iso8601Formatter.string(from: pauseResumesAt)
        }
        map["willRenew"] = willRenew
        map["isTrial"] = isTrial
        if let trialEndsAt {
            map["trialEndsAt"] = iso8601Formatter.string(from: trialEndsAt)
        }
        if let cancelledAt {
            map["cancelledAt"] = iso8601Formatter.string(from: cancelledAt)
        }
        return map
    }
}

extension CheckoutTransaction {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "productId": productId,
            "status": status.rawValue,
            "source": source.rawValue,
            "purchasedAt": iso8601Formatter.string(from: purchasedAt),
        ]
        if let expiresAt {
            map["expiresAt"] = iso8601Formatter.string(from: expiresAt)
        }
        if let productName {
            map["productName"] = productName
        }
        if let amountCents {
            map["amountCents"] = amountCents
        }
        if let currency {
            map["currency"] = currency
        }
        return map
    }
}

extension ProductCatalog {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "products": products.map { $0.toFlutterMap() },
        ]
        if let config {
            map["config"] = config.toFlutterMap()
        }
        return map
    }
}

extension JurisdictionCheckoutConfig {
    func toFlutterMap() -> [String: Any] {
        return [
            "sheetType": sheetType.rawValue,
            "isEnabled": isEnabled,
        ]
    }
}

extension CheckoutConfig {
    func toFlutterMap() -> [String: Any] {
        var jurisdictionsMap: [String: Any] = [:]
        for (key, value) in jurisdictions {
            jurisdictionsMap[key.rawValue] = value.toFlutterMap()
        }
        return [
            "sheetType": sheetType.rawValue,
            "isEnabled": isEnabled,
            "jurisdictions": jurisdictionsMap,
        ]
    }
}

extension MigrationPrompt {
    func toFlutterMap() -> [String: Any] {
        return [
            "productId": productId,
            "discountPercent": discountPercent,
            "title": title,
            "message": message,
            "ctaText": ctaText,
        ]
    }
}

extension RemoteConfig {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "checkout": checkout.toFlutterMap(),
        ]
        if let migration {
            map["migration"] = migration.toFlutterMap()
        }
        return map
    }
}

extension CancelFlow.Config {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "enabled": enabled,
            "questions": questions.map { $0.toFlutterMap() },
        ]
        if let offer {
            map["offer"] = offer.toFlutterMap()
        }
        if let pause {
            map["pause"] = pause.toFlutterMap()
        }
        if let variantId {
            map["variantId"] = variantId
        }
        return map
    }
}

extension CancelFlow.Question {
    func toFlutterMap() -> [String: Any] {
        return [
            "id": id,
            "order": order,
            "questionText": questionText,
            "questionType": questionType.rawValue,
            "isRequired": isRequired,
            "options": options.map { $0.toFlutterMap() },
        ]
    }
}

extension CancelFlow.Option {
    func toFlutterMap() -> [String: Any] {
        return [
            "id": id,
            "order": order,
            "label": label,
            "triggersOffer": triggersOffer,
            "triggersPause": triggersPause,
        ]
    }
}

extension CancelFlow.Offer {
    func toFlutterMap() -> [String: Any] {
        return [
            "enabled": enabled,
            "title": title,
            "body": body,
            "ctaText": ctaText,
            "type": type,
            "value": value,
        ]
    }
}

extension CancelFlow.PauseConfig {
    func toFlutterMap() -> [String: Any] {
        return [
            "enabled": enabled,
            "title": title,
            "body": body,
            "ctaText": ctaText,
            "options": options.map { $0.toFlutterMap() },
        ]
    }
}

extension CancelFlow.PauseOption {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "order": order,
            "label": label,
            "durationType": durationType,
        ]
        if let durationDays {
            map["durationDays"] = durationDays
        }
        if let resumeDate {
            map["resumeDate"] = iso8601Formatter.string(from: resumeDate)
        }
        return map
    }
}

// MARK: - Upgrade Offer Flutter Map

extension UpgradeOffer.Config {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = ["available": available]
        if let reason { map["reason"] = reason.rawString }
        if let currentProduct { map["currentProduct"] = currentProduct.toFlutterMap() }
        if let targetProduct { map["targetProduct"] = targetProduct.toFlutterMap() }
        if let savingsPercent { map["savingsPercent"] = savingsPercent }
        if let upgradeType { map["upgradeType"] = upgradeType.rawValue }
        if let proration { map["proration"] = proration.toFlutterMap() }
        if let display { map["display"] = display.toFlutterMap() }
        if let variantId { map["variantId"] = variantId }
        return map
    }
}

extension UpgradeOffer.ProductInfo {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "referenceId": referenceId,
            "name": name,
            "priceCents": price.cents,
            "currency": price.currency,
            "durationDays": 0, // Not directly available on iOS ProductInfo
            "billingLabel": billingLabel,
        ]
        if let monthlyEquivalent {
            map["monthlyEquivalentCents"] = monthlyEquivalent.cents
        }
        return map
    }
}

extension UpgradeOffer.Proration {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "prorationAmountCents": amountCents,
            "currency": currency,
        ]
        if let nextBillingDate {
            map["nextBillingDate"] = Int(nextBillingDate.timeIntervalSince1970)
        }
        return map
    }
}

extension UpgradeOffer.Display {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "title": title,
            "body": body,
            "ctaText": ctaText,
            "dismissText": dismissText,
        ]
        if let storekitMigrationBody { map["storekitMigrationBody"] = storekitMigrationBody }
        if let storekitCancelInstructions { map["cancelInstructions"] = storekitCancelInstructions }
        return map
    }
}

// MARK: - Error Mapping

extension Error {
    func toFlutterError() -> FlutterError {
        if let zsError = self as? ZeroSettleError {
            return zsError.toFlutterError()
        }
        return FlutterError(code: "api_error", message: localizedDescription, details: nil)
    }
}

extension ZeroSettleError {
    func toFlutterError() -> FlutterError {
        switch self {
        case .notConfigured:
            return FlutterError(code: "not_configured", message: errorDescription, details: nil)
        case .cancelled:
            return FlutterError(code: "cancelled", message: errorDescription, details: nil)
        case .productNotFound(let productId):
            return FlutterError(code: "product_not_found", message: errorDescription, details: productId)
        case .checkoutFailed:
            return FlutterError(code: "checkout_failed", message: errorDescription, details: nil)
        case .apiError:
            return FlutterError(code: "api_error", message: errorDescription, details: nil)
        case .userIdRequired(let productId):
            return FlutterError(code: "user_id_required", message: errorDescription, details: productId)
        case .webCheckoutDisabledForJurisdiction(let jurisdiction):
            return FlutterError(code: "web_checkout_disabled", message: errorDescription, details: jurisdiction.rawValue)
        default:
            return FlutterError(code: "api_error", message: errorDescription, details: nil)
        }
    }
}

// MARK: - Payment Sheet Header

/// Custom native header displayed above the payment WebView in the sheet.
struct PaymentSheetHeader: View {
    let product: ZeroSettleKit.Product

    var body: some View {
        VStack(spacing: 0) {
            // Product name
            Text(product.displayName)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Description
            if !product.productDescription.isEmpty {
                Text(product.productDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }

            // Price comparison
            HStack(spacing: 12) {
                // Web price
                VStack(alignment: .leading, spacing: 2) {
                    Text("Web Price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(product.webPrice?.formatted ?? "—")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }

                // App Store price + savings
                if let skPrice = product.storeKitPrice {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Store")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(skPrice.formatted)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .strikethrough(color: .secondary.opacity(0.6))
                    }

                    if let pct = product.savingsPercent {
                        Text("Save \(pct)%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green, in: Capsule())
                    }
                }

                Spacer()
            }
            .padding(.top, 10)

            // Promotion banner
            if let promo = product.promotion {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.caption)
                    Text(promo.displayName)
                        .font(.caption.weight(.medium))
                    Text(promo.promotionalPrice.formatted)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
