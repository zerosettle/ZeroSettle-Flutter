package com.zerosettle.flutter.offermanager

import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.offers.OfferManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import java.util.concurrent.atomic.AtomicInteger

/**
 * Owns the per-handle channel allocation for `ZSOfferManager` Dart instances.
 *
 * One registry per plugin instance. Constructed in `ZeroSettlePlugin.onAttachedToEngine`,
 * disposed in `onDetachedFromEngine`. Every Dart-side `ZSOfferManager(stripeCustomerId)`
 * call hits the plugin's `resolveOfferManagerHandle` method-channel handler, which
 * calls [allocate] here.
 *
 * Each entry owns:
 *   - the SDK's `OfferManager` instance (via `ZeroSettle.offerManager(stripeCustomerId)`)
 *   - a child [CoroutineScope] for state-flow collection (cancelled on dispose)
 *   - a method channel `zerosettle/offer_manager_<id>` (handler wired by F20)
 *   - a state event channel `zerosettle/offer_manager_<id>_state` (sink wired by F20)
 *
 * Disposal teardown order: cancel the child scope (stops state collection),
 * detach the method-channel handler, detach the event-channel handler, drop
 * the entry from the map. Channels are kept alive briefly while pending
 * onCancel callbacks drain; explicit detach is the cleanest signal Flutter
 * needs to release its event-sink references.
 */
class OfferManagerHandleRegistry(private val messenger: BinaryMessenger) {

    /**
     * A single live handle. The method-channel handler + event-channel stream-handler
     * are wired by F20's `OfferManagerHandleBridge` — F18 just allocates the channels
     * and exposes them.
     */
    class Entry internal constructor(
        val id: Int,
        val manager: OfferManager,
        val methodChannel: MethodChannel,
        val stateChannel: EventChannel,
        val scope: CoroutineScope,
    )

    private val nextId = AtomicInteger(1)

    // Synchronized — both allocate and dispose can race against the plugin's
    // `onDetachedFromEngine` (which calls disposeAll). Plain HashMap with
    // synchronized access keeps the registry small + serialized.
    private val entries = mutableMapOf<Int, Entry>()
    private val lock = Any()

    /**
     * Allocate a fresh handle id, build the SDK OfferManager instance, allocate
     * the method + state channels. Returns the entry; the caller (F20 bridge)
     * wires the channel handlers.
     *
     * The return type is nullable to preserve room for a future
     * "registry already disposed" race signal — F18 itself never returns null.
     */
    fun allocate(stripeCustomerId: String?): Entry? = synchronized(lock) {
        val id = nextId.getAndIncrement()
        val manager = ZeroSettle.offerManager(stripeCustomerId)
        val methodChannel = MethodChannel(messenger, "zerosettle/offer_manager_$id")
        val stateChannel = EventChannel(messenger, "zerosettle/offer_manager_${id}_state")
        // Each handle gets its own SupervisorJob so a failure in one handle's
        // state collection doesn't poison others.
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        val entry = Entry(id, manager, methodChannel, stateChannel, scope)
        entries[id] = entry
        entry
    }

    /** Look up a live entry by handle id; null if already disposed or never allocated. */
    fun get(id: Int): Entry? = synchronized(lock) { entries[id] }

    /**
     * Dispose a single handle. Idempotent — disposing twice is a no-op. Called
     * by the per-handle method-channel handler when Dart invokes `dispose`.
     */
    fun dispose(id: Int) {
        val entry = synchronized(lock) { entries.remove(id) } ?: return
        entry.scope.cancel()
        entry.methodChannel.setMethodCallHandler(null)
        entry.stateChannel.setStreamHandler(null)
    }

    /**
     * Dispose every live handle. Called by the plugin's `onDetachedFromEngine`.
     */
    fun disposeAll() {
        val snapshot = synchronized(lock) {
            val current = entries.values.toList()
            entries.clear()
            current
        }
        for (entry in snapshot) {
            entry.scope.cancel()
            entry.methodChannel.setMethodCallHandler(null)
            entry.stateChannel.setStreamHandler(null)
        }
    }
}
