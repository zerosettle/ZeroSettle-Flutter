import 'dart:async';

import 'package:flutter/services.dart';

import '../errors/zs_exception.dart';
import '../models/checkout_failure.dart';
import '../models/migration_offer.dart';

/// Handle for ZeroSettleKit's `ZSMigrationManager`. Adopters obtain a handle
/// via [ZeroSettle.migrationManager] and use it to drive a fully custom
/// migration UI.
///
/// State changes from the iOS-side `@Published` properties are delivered via
/// [stateUpdates]. Imperative methods ([present], [dismiss], [startCheckout],
/// etc.) drive the iOS Kit manager. Adopters should call [dispose] when the
/// owning widget tears down to release the per-handle channel subscriptions
/// — the iOS-side manager is cached per `(userId, stripeCustomerId)` and
/// outlives the handle.
class MigrationManager {
  /// Opaque handle ID issued by the iOS bridge.
  final String _handleId;
  final MethodChannel _methodChannel;
  final EventChannel _stateEventChannel;
  final EventChannel _failuresEventChannel;

  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<dynamic>? _failuresSub;

  final StreamController<MigrationManagerState> _stateController =
      StreamController<MigrationManagerState>.broadcast();
  final StreamController<CheckoutFailure> _failuresController =
      StreamController<CheckoutFailure>.broadcast();

  bool _disposed = false;

  MigrationManager.fromHandleId(this._handleId)
      : _methodChannel =
            MethodChannel('zerosettle/migration_manager_$_handleId'),
        _stateEventChannel =
            EventChannel('zerosettle/migration_manager_${_handleId}_state'),
        _failuresEventChannel = EventChannel(
            'zerosettle/migration_manager_${_handleId}_failures') {
    _wireStreams();
  }

  void _wireStreams() {
    _stateSub = _stateEventChannel.receiveBroadcastStream().listen((event) {
      try {
        final map = Map<String, dynamic>.from(event as Map);
        _stateController.add(MigrationManagerState.fromMap(map));
      } catch (e) {
        _stateController.addError(e);
      }
    }, onError: _stateController.addError);

    _failuresSub =
        _failuresEventChannel.receiveBroadcastStream().listen((event) {
      try {
        final map = Map<String, dynamic>.from(event as Map);
        _failuresController.add(CheckoutFailure.fromMap(map));
      } catch (e) {
        _failuresController.addError(e);
      }
    }, onError: _failuresController.addError);
  }

  /// Hot stream of state updates. Emits a coherent snapshot of all five
  /// `@Published` properties on every change. Late subscribers receive the
  /// current state on subscribe.
  Stream<MigrationManagerState> get stateUpdates => _stateController.stream;

  /// Hot stream of checkout failures. Replaces ZSMigrationManager's
  /// `onCheckoutFailure` closure callback.
  Stream<CheckoutFailure> get checkoutFailures => _failuresController.stream;

  /// Read the current state once.
  Future<MigrationManagerState> getState() async {
    _ensureNotDisposed();
    final result =
        await _methodChannel.invokeMethod<Map<Object?, Object?>>('getState');
    return MigrationManagerState.fromMap(Map<String, dynamic>.from(result!));
  }

  /// Transition the offer into the `presented` state.
  Future<void> present() async {
    _ensureNotDisposed();
    await _methodChannel.invokeMethod<void>('present');
  }

  /// Dismiss the offer (persists to UserDefaults on iOS).
  Future<void> dismiss() async {
    _ensureNotDisposed();
    await _methodChannel.invokeMethod<void>('dismiss');
  }

  /// Start the web checkout flow. Returns the checkout URL or null on failure.
  /// Errors are delivered via [checkoutFailures] when available.
  Future<Uri?> startCheckout({String? stripeCustomerId}) async {
    _ensureNotDisposed();
    final result =
        await _methodChannel.invokeMethod<String?>('startCheckout', {
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
    });
    return result == null ? null : Uri.parse(result);
  }

  /// Mark the checkout as succeeded; transitions state toward `accepted`.
  Future<void> markCheckoutSucceeded({String? transactionId}) async {
    _ensureNotDisposed();
    await _methodChannel.invokeMethod<void>('markCheckoutSucceeded', {
      if (transactionId != null) 'transactionId': transactionId,
    });
  }

  /// Open Apple's subscription management UI for the user to cancel their
  /// StoreKit auto-renew. Transitions state toward `completed`.
  Future<void> showAppleSubscriptionManagement() async {
    _ensureNotDisposed();
    await _methodChannel.invokeMethod<void>('showAppleSubscriptionManagement');
  }

  /// The opaque handle ID issued by the iOS bridge. Exposed for diagnostics
  /// (e.g. logging which handle a state event came from).
  String get handleId => _handleId;

  /// Tear down per-handle channel subscriptions. The iOS-side manager
  /// instance is NOT released — it's cached per
  /// `(userId, stripeCustomerId)` and survives across handle disposals.
  /// Calling [ZeroSettle.migrationManager] again returns a new handle bound
  /// to the same underlying state.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateSub?.cancel();
    await _failuresSub?.cancel();
    await _stateController.close();
    await _failuresController.close();
    // Tell iOS to drop the handle's Combine subscriptions. The cached
    // ZSMigrationManager instance stays alive for re-use.
    try {
      await _methodChannel.invokeMethod<void>('disposeHandle');
    } catch (_) {
      // Channel might already be torn down on the iOS side; non-fatal.
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const ZSApiException(
        'MigrationManager handle has been disposed. Obtain a fresh handle via ZeroSettle.instance.migrationManager().',
      );
    }
  }

  // -- Static helpers (UserDefaults-backed dismissed-state persistence) --

  /// Whether the user has permanently dismissed the offer (UserDefaults).
  static Future<bool> isPermanentlyDismissed({required String userId}) async {
    return await ZeroSettleMigrationManagerStatics._channel
            .invokeMethod<bool>('isPermanentlyDismissed', {'userId': userId}) ??
        false;
  }

  /// Set the dismissed flag for [userId].
  static Future<void> setDismissed(
    bool dismissed, {
    required String userId,
  }) async {
    await ZeroSettleMigrationManagerStatics._channel
        .invokeMethod<void>('setDismissed', {
      'userId': userId,
      'dismissed': dismissed,
    });
  }

  /// Reset dismissed state for ALL users (debug-only).
  static Future<void> resetDismissedState() async {
    await ZeroSettleMigrationManagerStatics._channel
        .invokeMethod<void>('resetDismissedState');
  }
}

/// Internal: shared MethodChannel for static helpers (no per-handle scoping).
class ZeroSettleMigrationManagerStatics {
  ZeroSettleMigrationManagerStatics._();
  static const _channel =
      MethodChannel('zerosettle/migration_manager_static');
}
