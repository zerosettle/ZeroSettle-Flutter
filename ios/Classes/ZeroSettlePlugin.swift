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

        // Register ZSMigrateTipView PlatformView factory
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
            let freeTrialDays = args?["freeTrialDays"] as? Int ?? 0
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

            ZSPaymentSheet<PaymentSheetHeader>.present(
                from: viewController,
                product: product,
                userId: userId,
                freeTrialDays: freeTrialDays,
                dismissible: dismissible,
                header: { PaymentSheetHeader(product: product) },
                onComplete: { completionResult in
                    switch completionResult {
                    case .success(let transaction):
                        result(transaction.toFlutterMap())
                    case .failure(let error):
                        if let zsError = error as? ZSError {
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
            let freeTrialDays = args?["freeTrialDays"] as? Int ?? 0
            let userId = args?["userId"] as? String
            Task { @MainActor in
                _ = await ZSPaymentSheet<EmptyView>.preload(productId: productId, userId: userId, freeTrialDays: freeTrialDays)
                result(nil)
            }

        case "warmUpPaymentSheet":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let freeTrialDays = args?["freeTrialDays"] as? Int ?? 0
            let userId = args?["userId"] as? String
            Task { @MainActor in
                await ZSPaymentSheet<EmptyView>.warmUp(productId: productId, userId: userId, freeTrialDays: freeTrialDays)
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

    public func zeroSettleCheckoutDidComplete(transaction: ZSTransaction) {
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
            "amountMicros": amountMicros,
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

extension ZSProduct {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "productDescription": productDescription,
            "type": type.rawValue,
            "syncedToASC": syncedToASC,
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
        return map
    }
}

extension ZSTransaction {
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

// MARK: - Error Mapping

extension Error {
    func toFlutterError() -> FlutterError {
        if let zsError = self as? ZSError {
            return zsError.toFlutterError()
        }
        return FlutterError(code: "api_error", message: localizedDescription, details: nil)
    }
}

extension ZSError {
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
    let product: ZSProduct

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
