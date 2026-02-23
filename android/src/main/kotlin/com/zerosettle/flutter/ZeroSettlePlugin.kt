package com.zerosettle.flutter

import android.app.Activity
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.ZeroSettleDelegate
import com.zerosettle.sdk.error.ZeroSettleError
import com.zerosettle.sdk.model.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class ZeroSettlePlugin : FlutterPlugin, MethodCallHandler, ActivityAware, ZeroSettleDelegate {

    private lateinit var methodChannel: MethodChannel
    private lateinit var entitlementEventChannel: EventChannel
    private lateinit var checkoutEventChannel: EventChannel

    private val entitlementStreamHandler = StreamHandler()
    private val checkoutStreamHandler = StreamHandler()

    private var activity: Activity? = null
    private var applicationContext: Context? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // -- FlutterPlugin --

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "zerosettle")
        methodChannel.setMethodCallHandler(this)

        entitlementEventChannel = EventChannel(binding.binaryMessenger, "zerosettle/entitlement_updates")
        entitlementEventChannel.setStreamHandler(entitlementStreamHandler)

        checkoutEventChannel = EventChannel(binding.binaryMessenger, "zerosettle/checkout_events")
        checkoutEventChannel.setStreamHandler(checkoutStreamHandler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        entitlementEventChannel.setStreamHandler(null)
        checkoutEventChannel.setStreamHandler(null)
        scope.cancel()
    }

    // -- ActivityAware --

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // -- MethodCallHandler --

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {

            // -- Configuration --

            "setBaseUrlOverride" -> {
                val url = call.argument<String>("url")
                ZeroSettle.baseUrlOverride = url
                result.success(null)
            }

            "configure" -> {
                val publishableKey = call.argument<String>("publishableKey")
                if (publishableKey == null) {
                    result.error("INVALID_ARGUMENTS", "publishableKey is required", null)
                    return
                }
                val syncPlayStore = call.argument<Boolean>("syncStoreKitTransactions") ?: true
                val context = applicationContext
                if (context == null) {
                    result.error("no_context", "No application context available", null)
                    return
                }
                val config = ZeroSettle.Configuration(
                    publishableKey = publishableKey,
                    syncPlayStoreTransactions = syncPlayStore,
                )
                ZeroSettle.configure(context, config)
                ZeroSettle.delegate = this
                result.success(null)
            }

            // -- Bootstrap --

            "bootstrap" -> {
                val userId = call.argument<String>("userId")
                if (userId == null) {
                    result.error("INVALID_ARGUMENTS", "userId is required", null)
                    return
                }
                scope.launch {
                    try {
                        val catalog = ZeroSettle.bootstrap(userId)
                        result.success(catalog.toFlutterMap())
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            // -- Products --

            "fetchProducts" -> {
                val userId = call.argument<String>("userId")
                scope.launch {
                    try {
                        val catalog = ZeroSettle.fetchProducts(userId)
                        result.success(catalog.toFlutterMap())
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            "getProducts" -> {
                result.success(ZeroSettle.products.value.map { it.toFlutterMap() })
            }

            // -- Payment Sheet --

            "presentPaymentSheet" -> {
                val productId = call.argument<String>("productId")
                if (productId == null) {
                    result.error("INVALID_ARGUMENTS", "productId is required", null)
                    return
                }
                val userId = call.argument<String>("userId")
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("no_activity", "No activity available", null)
                    return
                }
                scope.launch {
                    try {
                        val transaction = ZeroSettle.purchase(currentActivity, productId, userId)
                        result.success(transaction.toFlutterMap())
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            "preloadPaymentSheet" -> {
                // No-op on Android — payment sheet preloading is iOS-specific
                result.success(null)
            }

            "warmUpPaymentSheet" -> {
                // No-op on Android — payment sheet warm-up is iOS-specific
                result.success(null)
            }

            // -- Entitlements --

            "restoreEntitlements" -> {
                val userId = call.argument<String>("userId")
                if (userId == null) {
                    result.error("INVALID_ARGUMENTS", "userId is required", null)
                    return
                }
                scope.launch {
                    try {
                        val entitlements = ZeroSettle.restoreEntitlements(userId)
                        result.success(entitlements.map { it.toFlutterMap() })
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            "getEntitlements" -> {
                result.success(ZeroSettle.entitlements.value.map { it.toFlutterMap() })
            }

            // -- Subscription Management --

            "openCustomerPortal" -> {
                val userId = call.argument<String>("userId")
                if (userId == null) {
                    result.error("INVALID_ARGUMENTS", "userId is required", null)
                    return
                }
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("no_activity", "No activity available", null)
                    return
                }
                scope.launch {
                    try {
                        ZeroSettle.openCustomerPortal(currentActivity, userId)
                        result.success(null)
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            "showManageSubscription" -> {
                val userId = call.argument<String>("userId")
                if (userId == null) {
                    result.error("INVALID_ARGUMENTS", "userId is required", null)
                    return
                }
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("no_activity", "No activity available", null)
                    return
                }
                scope.launch {
                    try {
                        ZeroSettle.showManageSubscription(currentActivity, userId)
                        result.success(null)
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            // -- Cancel Flow --

            "presentCancelFlow" -> {
                val productId = call.argument<String>("productId")
                val userId = call.argument<String>("userId")
                if (productId == null || userId == null) {
                    result.error("INVALID_ARGUMENTS", "productId and userId are required", null)
                    return
                }
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("no_activity", "No activity available", null)
                    return
                }
                scope.launch {
                    try {
                        val cancelResult = ZeroSettle.presentCancelFlow(currentActivity, productId, userId)
                        when (cancelResult) {
                            is CancelFlowResult.Paused -> {
                                val resumesAt = cancelResult.resumesAt
                                if (resumesAt != null) {
                                    result.success("paused:$resumesAt")
                                } else {
                                    result.success("paused:")
                                }
                            }
                            is CancelFlowResult.Cancelled -> result.success("cancelled")
                            is CancelFlowResult.Retained -> result.success("retained")
                            is CancelFlowResult.Dismissed -> result.success("dismissed")
                        }
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            "fetchCancelFlowConfig" -> {
                scope.launch {
                    try {
                        val config = ZeroSettle.fetchCancelFlowConfig()
                        result.success(config.toFlutterMap())
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            "pauseSubscription" -> {
                val productId = call.argument<String>("productId")
                val userId = call.argument<String>("userId")
                val pauseOptionId = call.argument<Int>("pauseOptionId")
                if (productId == null || userId == null || pauseOptionId == null) {
                    result.error("INVALID_ARGUMENTS", "productId, userId, and pauseOptionId are required", null)
                    return
                }
                scope.launch {
                    try {
                        val resumesAt = ZeroSettle.pauseSubscription(productId, userId, pauseOptionId)
                        result.success(resumesAt)
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            "resumeSubscription" -> {
                val productId = call.argument<String>("productId")
                val userId = call.argument<String>("userId")
                if (productId == null || userId == null) {
                    result.error("INVALID_ARGUMENTS", "productId and userId are required", null)
                    return
                }
                scope.launch {
                    try {
                        ZeroSettle.resumeSubscription(productId, userId)
                        result.success(null)
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            "cancelSubscription" -> {
                val productId = call.argument<String>("productId")
                val userId = call.argument<String>("userId")
                if (productId == null || userId == null) {
                    result.error("INVALID_ARGUMENTS", "productId and userId are required", null)
                    return
                }
                scope.launch {
                    try {
                        ZeroSettle.cancelSubscription(productId, userId)
                        result.success(null)
                    } catch (e: Exception) {
                        result.sendError(e)
                    }
                }
            }

            // -- Deep Links --

            "handleUniversalLink" -> {
                val urlString = call.argument<String>("url")
                if (urlString == null) {
                    result.error("INVALID_ARGUMENTS", "Valid URL is required", null)
                    return
                }
                val uri = Uri.parse(urlString)
                val handled = ZeroSettle.handleDeepLink(uri)
                result.success(handled)
            }

            // -- State Queries --

            "getIsConfigured" -> {
                result.success(ZeroSettle.isConfigured.value)
            }

            "getPendingCheckout" -> {
                result.success(ZeroSettle.pendingCheckout.value)
            }

            "getRemoteConfig" -> {
                val config = ZeroSettle.remoteConfig.value
                result.success(config?.toFlutterMap())
            }

            "getDetectedJurisdiction" -> {
                result.success(ZeroSettle.detectedJurisdiction.value?.toRawValue())
            }

            else -> result.notImplemented()
        }
    }

    // -- ZeroSettleDelegate --

    override fun zeroSettleCheckoutDidBegin(productId: String) {
        checkoutStreamHandler.send(mapOf(
            "event" to "checkoutDidBegin",
            "productId" to productId,
        ))
    }

    override fun zeroSettleCheckoutDidComplete(transaction: CheckoutTransaction) {
        checkoutStreamHandler.send(mapOf(
            "event" to "checkoutDidComplete",
            "transaction" to transaction.toFlutterMap(),
        ))
    }

    override fun zeroSettleCheckoutDidCancel(productId: String) {
        checkoutStreamHandler.send(mapOf(
            "event" to "checkoutDidCancel",
            "productId" to productId,
        ))
    }

    override fun zeroSettleCheckoutDidFail(productId: String, error: Throwable) {
        checkoutStreamHandler.send(mapOf(
            "event" to "checkoutDidFail",
            "productId" to productId,
            "error" to (error.message ?: "Unknown error"),
        ))
    }

    override fun zeroSettleEntitlementsDidUpdate(entitlements: List<Entitlement>) {
        entitlementStreamHandler.send(entitlements.map { it.toFlutterMap() })
    }

    override fun zeroSettleDidSyncPlayStoreTransaction(productId: String, purchaseToken: String) {
        checkoutStreamHandler.send(mapOf(
            "event" to "playStoreTransactionSynced",
            "productId" to productId,
            "purchaseToken" to purchaseToken,
        ))
    }

    override fun zeroSettlePlayStoreSyncFailed(error: Throwable) {
        checkoutStreamHandler.send(mapOf(
            "event" to "playStoreSyncFailed",
            "error" to (error.message ?: "Unknown error"),
        ))
    }
}

// -- Event Stream Handler --

private class StreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun send(data: Any) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(data)
        }
    }
}

// -- Error Mapping --

private fun Result.sendError(e: Exception) {
    when (e) {
        is ZeroSettleError.NotConfigured ->
            error("not_configured", e.message, null)
        is ZeroSettleError.Cancelled ->
            error("cancelled", e.message, null)
        is ZeroSettleError.ProductNotFound ->
            error("product_not_found", e.message, e.productId)
        is ZeroSettleError.CheckoutFailed ->
            error("checkout_failed", e.message, null)
        is ZeroSettleError.ApiError ->
            error("api_error", e.message, null)
        is ZeroSettleError.UserIdRequired ->
            error("user_id_required", e.message, e.productId)
        is ZeroSettleError.WebCheckoutDisabledForJurisdiction ->
            error("web_checkout_disabled", e.message, e.jurisdiction.toRawValue())
        else ->
            error("api_error", e.message ?: "Unknown error", null)
    }
}

// -- Enum Serialization --

private fun Product.ProductType.toRawValue(): String = when (this) {
    Product.ProductType.AUTO_RENEWABLE_SUBSCRIPTION -> "auto_renewable_subscription"
    Product.ProductType.NON_RENEWING_SUBSCRIPTION -> "non_renewing_subscription"
    Product.ProductType.CONSUMABLE -> "consumable"
    Product.ProductType.NON_CONSUMABLE -> "non_consumable"
}

private fun Entitlement.Source.toRawValue(): String = when (this) {
    Entitlement.Source.STORE_KIT -> "store_kit"
    Entitlement.Source.PLAY_STORE -> "play_store"
    Entitlement.Source.WEB_CHECKOUT -> "web_checkout"
}

private fun CheckoutTransaction.Status.toRawValue(): String = when (this) {
    CheckoutTransaction.Status.COMPLETED -> "completed"
    CheckoutTransaction.Status.PENDING -> "pending"
    CheckoutTransaction.Status.PROCESSING -> "processing"
    CheckoutTransaction.Status.FAILED -> "failed"
    CheckoutTransaction.Status.REFUNDED -> "refunded"
}

private fun Promotion.Kind.toRawValue(): String = when (this) {
    Promotion.Kind.PERCENT_OFF -> "percent_off"
    Promotion.Kind.FIXED_AMOUNT -> "fixed_amount"
    Promotion.Kind.FREE_TRIAL -> "free_trial"
}

private fun CheckoutType.toRawValue(): String = when (this) {
    CheckoutType.WEB_VIEW -> "webview"
    CheckoutType.CUSTOM_TAB -> "safari_vc"
    CheckoutType.EXTERNAL_BROWSER -> "safari"
}

private fun Jurisdiction.toRawValue(): String = when (this) {
    Jurisdiction.US -> "us"
    Jurisdiction.EU -> "eu"
    Jurisdiction.ROW -> "row"
}

// -- Model Serialization --

private fun Price.toFlutterMap(): Map<String, Any> = mapOf(
    "amountCents" to amountCents,
    "currencyCode" to currencyCode,
)

private fun Promotion.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "displayName" to displayName,
        "promotionalPrice" to promotionalPrice.toFlutterMap(),
        "type" to type.toRawValue(),
    )
    expiresAt?.let { map["expiresAt"] = it }
    return map
}

private fun Product.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "displayName" to displayName,
        "productDescription" to productDescription,
        "type" to type.toRawValue(),
        "syncedToAppStoreConnect" to syncedToAppStoreConnect,
        "storeKitAvailable" to playStoreAvailable,
    )
    webPrice?.let { map["webPrice"] = it.toFlutterMap() }
    appStorePrice?.let { map["appStorePrice"] = it.toFlutterMap() }
    promotion?.let { map["promotion"] = it.toFlutterMap() }
    playStorePrice?.let { map["storeKitPrice"] = it.toFlutterMap() }
    savingsPercent?.let { map["savingsPercent"] = it }
    return map
}

private fun Entitlement.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "productId" to productId,
        "source" to source.toRawValue(),
        "isActive" to isActive,
        "purchasedAt" to purchasedAt,
    )
    expiresAt?.let { map["expiresAt"] = it }
    status?.let { map["status"] = it }
    pausedAt?.let { map["pausedAt"] = it }
    pauseResumesAt?.let { map["pauseResumesAt"] = it }
    return map
}

private fun CheckoutTransaction.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "productId" to productId,
        "status" to status.toRawValue(),
        "source" to source.toRawValue(),
        "purchasedAt" to purchasedAt,
    )
    expiresAt?.let { map["expiresAt"] = it }
    return map
}

private fun ProductCatalog.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "products" to products.map { it.toFlutterMap() },
    )
    config?.let { map["config"] = it.toFlutterMap() }
    return map
}

private fun JurisdictionCheckoutConfig.toFlutterMap(): Map<String, Any> = mapOf(
    "sheetType" to sheetType.toRawValue(),
    "isEnabled" to isEnabled,
)

private fun CheckoutConfig.toFlutterMap(): Map<String, Any> {
    val jurisdictionsMap = mutableMapOf<String, Any>()
    for ((key, value) in jurisdictions) {
        jurisdictionsMap[key.toRawValue()] = value.toFlutterMap()
    }
    return mapOf(
        "sheetType" to sheetType.toRawValue(),
        "isEnabled" to isEnabled,
        "jurisdictions" to jurisdictionsMap,
    )
}

private fun MigrationPrompt.toFlutterMap(): Map<String, Any> = mapOf(
    "productId" to productId,
    "discountPercent" to discountPercent,
    "title" to title,
    "message" to message,
)

private fun RemoteConfig.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "checkout" to checkout.toFlutterMap(),
    )
    migration?.let { map["migration"] = it.toFlutterMap() }
    return map
}

private fun CancelFlowConfig.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "enabled" to enabled,
        "questions" to questions.map { it.toFlutterMap() },
    )
    offer?.let { map["offer"] = it.toFlutterMap() }
    pause?.let { map["pause"] = it.toFlutterMap() }
    return map
}

private fun CancelFlowQuestion.toFlutterMap(): Map<String, Any> = mapOf(
    "id" to id,
    "order" to order,
    "questionText" to questionText,
    "questionType" to questionType.toRawValue(),
    "isRequired" to isRequired,
    "options" to options.map { it.toFlutterMap() },
)

private fun CancelFlowQuestionType.toRawValue(): String = when (this) {
    CancelFlowQuestionType.SINGLE_SELECT -> "single_select"
    CancelFlowQuestionType.FREE_TEXT -> "free_text"
}

private fun CancelFlowOption.toFlutterMap(): Map<String, Any> = mapOf(
    "id" to id,
    "order" to order,
    "label" to label,
    "triggersOffer" to triggersOffer,
    "triggersPause" to triggersPause,
)

private fun CancelFlowOffer.toFlutterMap(): Map<String, Any> = mapOf(
    "enabled" to enabled,
    "title" to title,
    "body" to body,
    "ctaText" to ctaText,
    "type" to type,
    "value" to value,
)

private fun CancelFlowPauseConfig.toFlutterMap(): Map<String, Any> = mapOf(
    "enabled" to enabled,
    "title" to title,
    "body" to body,
    "ctaText" to ctaText,
    "options" to options.map { it.toFlutterMap() },
)

private fun CancelFlowPauseOption.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "order" to order,
        "label" to label,
        "durationType" to durationType,
    )
    durationDays?.let { map["durationDays"] = it }
    resumeDate?.let { map["resumeDate"] = it }
    return map
}
