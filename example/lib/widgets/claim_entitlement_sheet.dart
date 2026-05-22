import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Signature for the transfer action — mirrors
/// [ZeroSettle.transferPlayOwnershipToCurrentUser]. Injectable so widget
/// tests can exercise success / error paths without the MethodChannel.
typedef ClaimTransfer = Future<void> Function({required String productId});

/// Signature for resolving a product's display name from the catalog.
typedef ProductResolver = Future<Product?> Function(String productId);

/// Shows the [ClaimEntitlementSheet] as a modal bottom sheet.
///
/// Resolves once the sheet is dismissed — whether by a successful transfer or
/// by the user tapping "Not now". The caller decides whether to mark the
/// originating [PendingClaim] as dismissed for the session.
///
/// [onTransfer] and [resolveProduct] default to the live SDK facade; widget
/// tests pass fakes.
Future<void> showClaimEntitlementSheet(
  BuildContext context, {
  required PendingClaim claim,
  ClaimTransfer? onTransfer,
  ProductResolver? resolveProduct,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // The transfer is destructive; require a deliberate button tap rather
    // than letting a stray backdrop tap dismiss it.
    isDismissible: false,
    enableDrag: false,
    builder: (_) => ClaimEntitlementSheet(
      claim: claim,
      onTransfer: onTransfer ?? ZeroSettle.instance.transferPlayOwnershipToCurrentUser,
      resolveProduct:
          resolveProduct ?? ((id) => ZeroSettle.instance.product(productId: id)),
    ),
  );
}

/// The transfer-prompt sheet for a Play entitlement ownership conflict.
///
/// Surfaced when a Play sync detects a purchase the device's Google account
/// owns but a *different* ZeroSettle account holds the entitlement for.
/// Matches the design-spec §5.4 mockup:
///
/// > Subscription already in use
/// > "Premium (Weekly)" is linked to a different ZeroSettle account (••••a3f1).
/// > Transfer it to this account? The other account will lose access.
/// > [ Not now ]   [ Transfer ]
///
/// Transferring is destructive — the prior owner loses access — so the copy
/// states that plainly and the dismiss action ("Not now") leaves the
/// [PendingClaim] intact.
///
/// Errors from the transfer are shown **inline** and never swallowed: a failed
/// transfer keeps the sheet open with the error message and the Transfer
/// button still tappable for a retry.
class ClaimEntitlementSheet extends StatefulWidget {
  const ClaimEntitlementSheet({
    super.key,
    required this.claim,
    required this.onTransfer,
    required this.resolveProduct,
  });

  /// The conflict surfaced by `pendingClaimsUpdates`.
  final PendingClaim claim;

  /// Performs the transfer. Throws on failure (the error is shown inline).
  final ClaimTransfer onTransfer;

  /// Resolves the product's display name. Returns `null` if not in the
  /// catalog — the sheet then falls back to the raw product id.
  final ProductResolver resolveProduct;

  @override
  State<ClaimEntitlementSheet> createState() => _ClaimEntitlementSheetState();
}

class _ClaimEntitlementSheetState extends State<ClaimEntitlementSheet> {
  late final Future<Product?> _productFuture;

  /// True while [widget.onTransfer] is in flight — drives the poll-and-spin
  /// loading state.
  bool _transferring = false;

  /// The most recent transfer error, shown inline. `null` when there is none.
  String? _error;

  @override
  void initState() {
    super.initState();
    // Resolve the display name lazily — the buttons render immediately even
    // if the catalog lookup is slow or fails.
    _productFuture = widget.resolveProduct(widget.claim.productId);
  }

  Future<void> _onTransfer() async {
    setState(() {
      _transferring = true;
      _error = null;
    });
    try {
      await widget.onTransfer(productId: widget.claim.productId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Inline, never swallowed — the user can read it and retry or dismiss.
      if (mounted) {
        setState(() {
          _transferring = false;
          _error = _describeError(e);
        });
      }
    }
  }

  /// Renders a transfer error as a user-readable string.
  String _describeError(Object error) {
    if (error is ZeroSettleException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = widget.claim.existingOwnerHint;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title ─────────────────────────────────────────────────────
            Text(
              'Subscription already in use',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // ── Body — names the product + the other account ──────────────
            FutureBuilder<Product?>(
              future: _productFuture,
              builder: (context, snapshot) {
                // Fall back to the raw product id if the catalog lookup
                // returned null or errored.
                final productName = snapshot.data?.displayName ??
                    widget.claim.productId;
                return Text(
                  '"$productName" is linked to a different ZeroSettle '
                  'account (••••$hint).',
                  style: theme.textTheme.bodyMedium,
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Transfer it to this account? The other account will '
              'lose access.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // ── Inline error (never swallowed) ────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Couldn't transfer the subscription.\n$_error",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── Actions ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    // Disabled mid-transfer so the user can't dismiss while
                    // the destructive action is in flight.
                    onPressed: _transferring
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _transferring ? null : _onTransfer,
                    child: _transferring
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_error == null ? 'Transfer' : 'Try again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
