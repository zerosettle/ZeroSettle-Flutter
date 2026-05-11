import 'dart:async';

import 'package:flutter/services.dart';

import '../errors/zs_exception.dart';
import '../models/offer.dart';

/// Handle for ZeroSettleKit's `ZSOfferManager`. Adopters obtain a handle
/// via [ZeroSettle.offerManager] and use it to drive a fully custom
/// offer UI for both migration and upgrade flows.
///
/// State changes from the iOS-side `@Published` properties are delivered
/// via [stateUpdates]. Imperative methods ([dismiss], [startCheckout],
/// [preloadCheckout], etc.) drive the iOS Kit manager. Adopters should
/// call [dispose] when the owning widget tears down to release the
/// per-handle channel subscriptions — the iOS-side manager is cached
/// per `(userId, stripeCustomerId)` and outlives the handle.
///
/// Unlike `MigrationManager`, `ZSOfferManager` has no
/// `onCheckoutFailure` closure — checkout errors surface via
/// [OfferManagerState.checkoutErrorMessage] on the state stream.
class OfferManager {
  /// Opaque handle ID issued by the iOS bridge.
  final String _handleId;
  final MethodChannel _methodChannel;
  final EventChannel _stateEventChannel;

  StreamSubscription<dynamic>? _stateSub;

  final StreamController<OfferManagerState> _stateController =
      StreamController<OfferManagerState>.broadcast();

  bool _disposed = false;

  OfferManager.fromHandleId(this._handleId)
      : _methodChannel =
            MethodChannel('zerosettle/offer_manager_$_handleId'),
        _stateEventChannel =
            EventChannel('zerosettle/offer_manager_${_handleId}_state') {
    _wireStreams();
  }

  void _wireStreams() {
    _stateSub = _stateEventChannel.receiveBroadcastStream().listen((event) {
      try {
        final map = Map<String, dynamic>.from(event as Map);
        _stateController.add(OfferManagerState.fromMap(map));
      } catch (e) {
        _stateController.addError(e);
      }
    }, onError: _stateController.addError);
  }

  /// Hot stream of state updates. Emits a coherent snapshot of all five
  /// `@Published` properties on every change. Late subscribers receive
  /// the current state on subscribe.
  Stream<OfferManagerState> get stateUpdates => _stateController.stream;

  /// Read the current state once.
  Future<OfferManagerState> getState() async {
    _ensureNotDisposed();
    final result =
        await _methodChannel.invokeMethod<Map<Object?, Object?>>('getState');
    return OfferManagerState.fromMap(Map<String, dynamic>.from(result!));
  }

  /// Transition the offer into the `presented` state.
  @Deprecated('Bookkeeping is automatic when you call ZeroSettle.instance.presentPaymentSheet or ZeroSettle.instance.purchase. Will be removed in 2.0.')
  Future<void> present() async {
    _ensureNotDisposed();
    await _methodChannel.invokeMethod<void>('present');
  }

  /// Dismiss the offer (persists to UserDefaults on iOS).
  Future<void> dismiss() async {
    _ensureNotDisposed();
    await _methodChannel.invokeMethod<void>('dismiss');
  }

  /// **Advanced — raw URL escape hatch.** For ordinary use, prefer
  /// `ZeroSettle.instance.presentPaymentSheet(productId:)` or
  /// `ZeroSettle.instance.purchase(productId:)`. Those handle offer
  /// bookkeeping automatically — you don't need to call `present()` or
  /// `markCheckoutSucceeded()` yourself.
  ///
  /// Use this method only when you need full control over presentation or
  /// transport: a custom WebView with bespoke chrome, a third-party
  /// browser SDK, or a context where there's no view hierarchy at all.
  ///
  /// When you go down this path, you are responsible for calling
  /// `markCheckoutSucceeded(transactionId:)` after your out-of-band
  /// checkout completes. The auto-bookkeeping path doesn't apply to URLs
  /// you handle yourself.
  ///
  /// - [stripeCustomerId]: Optional existing Stripe customer ID for unified
  ///   billing portal.
  /// - Returns the checkout URL for WebView, or `null` for web-to-web upgrades
  ///   (handled internally).
  Future<Uri?> startCheckout({String? stripeCustomerId}) async {
    _ensureNotDisposed();
    final result =
        await _methodChannel.invokeMethod<String?>('startCheckout', {
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
    });
    return result == null ? null : Uri.parse(result);
  }

  /// Preload a checkout session for faster presentation.
  /// Returns the checkout URL on success, or null when the offer is a
  /// `web_to_web` upgrade (no WebView needed) or preloading failed.
  Future<Uri?> preloadCheckout({String? stripeCustomerId}) async {
    _ensureNotDisposed();
    final result =
        await _methodChannel.invokeMethod<String?>('preloadCheckout', {
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
    });
    return result == null ? null : Uri.parse(result);
  }

  /// Mark the checkout as succeeded; transitions state toward `accepted`
  /// (when [OfferOfferData.needsAppleCancel] is true) or `completed`.
  @Deprecated('Bookkeeping is automatic when you call ZeroSettle.instance.presentPaymentSheet or ZeroSettle.instance.purchase. The body of this method is preserved through 1.x for adopters using `startCheckout` (raw URL escape hatch) who need to call it manually after their out-of-band checkout completes. Will be removed in 2.0.')
  Future<void> markCheckoutSucceeded({String? transactionId}) async {
    _ensureNotDisposed();
    await _methodChannel.invokeMethod<void>('markCheckoutSucceeded', {
      if (transactionId != null) 'transactionId': transactionId,
    });
  }

  /// Open Apple's subscription management UI for the user to cancel
  /// their StoreKit auto-renew. Transitions state toward `completed`
  /// once the system detects the cancellation.
  Future<void> showAppleSubscriptionManagement() async {
    _ensureNotDisposed();
    await _methodChannel.invokeMethod<void>('showAppleSubscriptionManagement');
  }

  /// The opaque handle ID issued by the iOS bridge. Exposed for
  /// diagnostics (e.g. logging which handle a state event came from).
  String get handleId => _handleId;

  /// Tear down per-handle channel subscriptions. The iOS-side manager
  /// instance is NOT released — it's cached per
  /// `(userId, stripeCustomerId)` and survives across handle disposals.
  /// Calling [ZeroSettle.offerManager] again returns a new handle bound
  /// to the same underlying state.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateSub?.cancel();
    await _stateController.close();
    // Tell iOS to drop the handle's Combine subscriptions. The cached
    // ZSOfferManager instance stays alive for re-use.
    try {
      await _methodChannel.invokeMethod<void>('disposeHandle');
    } catch (_) {
      // Channel might already be torn down on the iOS side; non-fatal.
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const ZSApiException(
        'OfferManager handle has been disposed. Obtain a fresh handle via ZeroSettle.instance.offerManager().',
      );
    }
  }

  // -- Static helpers (UserDefaults-backed dismissed-state persistence) --

  /// Whether the user has permanently dismissed the offer (UserDefaults).
  static Future<bool> isPermanentlyDismissed({required String userId}) async {
    return await ZeroSettleOfferManagerStatics._channel
            .invokeMethod<bool>('isPermanentlyDismissed', {'userId': userId}) ??
        false;
  }

  /// Set the dismissed flag for [userId].
  static Future<void> setDismissed(
    bool dismissed, {
    required String userId,
  }) async {
    await ZeroSettleOfferManagerStatics._channel
        .invokeMethod<void>('setDismissed', {
      'userId': userId,
      'dismissed': dismissed,
    });
  }

  /// Reset dismissed state for ALL users (debug-only).
  static Future<void> resetDismissedState() async {
    await ZeroSettleOfferManagerStatics._channel
        .invokeMethod<void>('resetDismissedState');
  }
}

/// Internal: shared MethodChannel for static helpers (no per-handle scoping).
class ZeroSettleOfferManagerStatics {
  ZeroSettleOfferManagerStatics._();
  static const _channel = MethodChannel('zerosettle/offer_manager_static');
}
