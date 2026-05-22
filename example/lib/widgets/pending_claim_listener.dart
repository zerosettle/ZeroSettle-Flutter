import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import 'claim_entitlement_sheet.dart';

/// App-level listener that surfaces a [ClaimEntitlementSheet] whenever
/// `pendingClaimsUpdates` emits a non-empty list.
///
/// Wraps the app's content (via `MaterialApp.router`'s `builder:`) so a claim
/// surfaces wherever the user happens to be — not tied to a single screen.
///
/// Behaviour:
/// * **One sheet at a time.** Multiple claims are handled one-by-one — only
///   `firstOrNull` of the emitted list is shown; the rest wait for the next
///   emission after the current one resolves.
/// * **No re-prompt loop.** A claim the user dismissed with "Not now" is not
///   re-shown for the rest of the session (the [PendingClaim] persists in the
///   SDK and would otherwise re-emit). Dismissed claims are tracked by a
///   stable key.
/// * A claim resolved by a successful transfer naturally stops emitting (the
///   SDK clears it), so it needs no dismiss-tracking.
class PendingClaimListener extends StatefulWidget {
  const PendingClaimListener({
    super.key,
    required this.child,
    this.claimsStream,
  });

  /// The app content to render beneath the listener.
  final Widget child;

  /// Stream of pending-claim batches. Defaults to the live SDK stream;
  /// overridable for tests.
  final Stream<List<PendingClaim>>? claimsStream;

  @override
  State<PendingClaimListener> createState() => _PendingClaimListenerState();
}

class _PendingClaimListenerState extends State<PendingClaimListener> {
  StreamSubscription<List<PendingClaim>>? _sub;

  /// Stable keys of claims the user dismissed this session — never re-shown.
  final Set<String> _dismissed = <String>{};

  /// True while a sheet is on screen — guards against stacking sheets.
  bool _sheetOpen = false;

  /// The most recent batch emitted by the stream — used to drain a queue of
  /// multiple claims once the current sheet closes.
  List<PendingClaim>? _latestBatch;

  /// A stable identity for a claim — keyed on the fields that distinguish a
  /// conflict (the Play token, when present, is the strongest discriminator).
  String _keyFor(PendingClaim c) =>
      '${c.productId}|${c.originalTransactionId}|${c.purchaseToken ?? ''}';

  @override
  void initState() {
    super.initState();
    final stream =
        widget.claimsStream ?? ZeroSettle.instance.pendingClaimsUpdates;
    _sub = stream.listen(_onClaims);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onClaims(List<PendingClaim> claims) {
    _latestBatch = claims;
    if (_sheetOpen || !mounted) return;

    // Handle one at a time: the first claim not already dismissed this session.
    PendingClaim? next;
    for (final claim in claims) {
      if (!_dismissed.contains(_keyFor(claim))) {
        next = claim;
        break;
      }
    }
    if (next == null) return;

    _showSheet(next);
  }

  Future<void> _showSheet(PendingClaim claim) async {
    _sheetOpen = true;
    // Snapshot the latest batch so a second claim can be drained immediately
    // once this sheet closes — without waiting for a fresh stream emission.
    try {
      await showClaimEntitlementSheet(context, claim: claim);
    } finally {
      _sheetOpen = false;
    }
    // The sheet resolves on both a successful transfer and a "Not now"
    // dismiss. Either way, record the key so a re-emission of the same
    // (still-pending) claim doesn't immediately re-prompt. A successfully
    // transferred claim simply stops emitting.
    _dismissed.add(_keyFor(claim));

    // Drain the queue: if the most recent batch held more claims, show the
    // next one now rather than waiting for the SDK to re-emit.
    if (mounted && _latestBatch != null) {
      _onClaims(_latestBatch!);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
