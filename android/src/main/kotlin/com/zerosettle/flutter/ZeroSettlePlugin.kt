package com.zerosettle.flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * **STUB — work in progress on `feat/1.3.0-parity`.**
 *
 * The 0.15.0-era plugin was wholesale rewritten against the v1.0.0 SDK during
 * Phase 2 of the Flutter Android parity work (see plan at
 * `docs/superpowers/plans/2026-05-12-flutter-android-parity-plan.md`).
 *
 * Phase 2 ships incrementally: ext encoders (F3, F4), host activity (F5),
 * platform views (F22–F24), offer-manager handle layer (F18–F20), then the
 * real plugin scaffold (F7) that wires it all together, then per-domain
 * handlers (F8–F17).
 *
 * This stub exists only so the plugin module compiles in the interim. Every
 * method-channel call returns `notImplemented()`; adopters who try to consume
 * this build will see no functionality. The real plugin lands in F7 — do not
 * release this stub.
 */
class ZeroSettlePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "zerosettle")
        methodChannel.setMethodCallHandler(this)
        // Loud logcat marker so a misconfigured release is immediately visible
        // during integration testing. Real plugin scaffold lands in F7.
        android.util.Log.w(
            "ZeroSettle",
            "[Phase 2 WIP stub] Android plugin is under construction on " +
                "feat/1.3.0-parity. Every method-channel call will fail with " +
                "zerosettle_phase2_wip. See plan F7 for the real scaffold."
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = Unit
    override fun onDetachedFromActivityForConfigChanges() = Unit
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = Unit
    override fun onDetachedFromActivity() = Unit

    override fun onMethodCall(call: MethodCall, result: Result) {
        // All handlers land in F8–F17. The stub fails loudly with a tagged
        // error code rather than notImplemented() so the failure surfaces in
        // adopter logs — `MissingPluginException` is often swallowed as
        // "platform not supported" and goes unnoticed.
        result.error(
            "zerosettle_phase2_wip",
            "Android plugin is under construction on feat/1.3.0-parity. " +
                "Method '${call.method}' is not yet implemented. " +
                "See docs/superpowers/plans/2026-05-12-flutter-android-parity-plan.md F7.",
            null,
        )
    }
}
