import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../widgets/offer_tip_card.dart';

/// Developer inspector for the user-offer API.
///
/// A "Fetch user offer" button calls [ZeroSettle.instance.fetchUserOffer] and
/// renders the resulting [UserOfferResponse] as labeled key/value rows.
/// Also embeds [OfferTipCard], the cross-platform offer tip view
/// (renders on both iOS and Android).
///
/// Mirrors [OffersScreen.kt] from the JustOne Android sample.
class DevOffersScreen extends StatefulWidget {
  const DevOffersScreen({super.key});

  @override
  State<DevOffersScreen> createState() => _DevOffersScreenState();
}

class _DevOffersScreenState extends State<DevOffersScreen> {
  bool _busy = false;
  UserOfferResponse? _result;
  String? _error;
  bool _forceEcl = false;
  bool _switchTestMode = false;
  bool _eclSeeded = false;

  /// Bumped to re-key [OfferTipCard] after clearing the offer-dismissal
  /// flag, forcing the native offer tip to re-evaluate immediately.
  int _tipNonce = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed the toggle from the persisted value once. `main()` already
    // re-applied it to the SDK on startup — this just reflects it in the UI.
    if (_eclSeeded) return;
    _eclSeeded = true;
    final prefs = InheritedJustOne.of(context).prefs;
    _forceEcl = prefs.eclOverride;
    _switchTestMode = prefs.switchAndSaveTestMode;
  }

  /// Flips the Switch & Save ECL availability gate for testing. `true` forces
  /// ECL "available"; `false` clears the override (real Play query). The value
  /// is persisted (re-applied on every launch by `main()`); re-keying
  /// [OfferTipCard] on [_forceEcl] re-creates the native offer tip so it
  /// re-evaluates against the new override immediately.
  Future<void> _setForceEcl(bool value) async {
    await ZeroSettle.instance.setEclAvailabilityOverride(value ? true : null);
    if (!mounted) return;
    await InheritedJustOne.of(context).prefs.setEclOverride(value);
    if (mounted) setState(() => _forceEcl = value);
  }

  /// Flips full Switch & Save test mode. When `true`, the entire flow runs on
  /// a non-ECL device — the "Switch Now" CTA mints a real backend session and
  /// opens the real web checkout. Implies "Force ECL available", so the offer
  /// tip surfaces too. Persisted (re-applied on every launch by `main()`);
  /// re-keying [OfferTipCard] on [_switchTestMode] re-creates the native tip
  /// so it re-evaluates immediately.
  Future<void> _setSwitchTestMode(bool value) async {
    await ZeroSettle.instance.setSwitchAndSaveTestMode(value);
    if (!mounted) return;
    await InheritedJustOne.of(context).prefs.setSwitchAndSaveTestMode(value);
    if (mounted) setState(() => _switchTestMode = value);
  }

  /// Clears the per-user offer-dismissal flag so the Switch & Save tip can
  /// re-surface. `OfferDismissalStore` keys dismissal by user, not by offer —
  /// declining any offer (an upgrade prompt, a cancel-flow offer) sets one
  /// flag that also suppresses the migrate tip. `resetMigrateTipState` is a
  /// no-op on Android; `OfferManager.resetDismissedState()` is the real reset.
  Future<void> _resetOfferDismissal() async {
    await OfferManager.resetDismissedState();
    if (mounted) setState(() => _tipNonce++);
  }

  Future<void> _fetch(BuildContext ctx) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final response = await ZeroSettle.instance.fetchUserOffer();
      if (!ctx.mounted) return;
      setState(() => _result = response);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Switch & Save ECL gate testing toggle — see [_setForceEcl].
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Force ECL available'),
            subtitle: const Text(
              'Bypasses the Play ECL gate so the Switch & Save tip can '
              'surface on devices not enrolled in Google ECL. Android-only; testing.',
            ),
            value: _forceEcl,
            onChanged: _setForceEcl,
          ),
          // Full Switch & Save test mode — see [_setSwitchTestMode].
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Switch & Save full test mode'),
            subtitle: const Text(
              'Runs the entire Switch & Save flow on a non-ECL device — the '
              '"Switch Now" CTA mints a real backend session and opens the '
              'real web checkout. Implies "Force ECL available". Android-only; '
              'testing.',
            ),
            value: _switchTestMode,
            onChanged: _setSwitchTestMode,
          ),
          // Clears the per-user offer-dismissal flag — see [_resetOfferDismissal].
          OutlinedButton.icon(
            onPressed: _resetOfferDismissal,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset offer dismissal'),
          ),
          const SizedBox(height: 8),
          // Cross-platform migration tip view (renders on iOS and Android).
          OfferTipCard(key: ValueKey('$_forceEcl|$_switchTestMode|$_tipNonce')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : () => _fetch(context),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Fetch user offer'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _row(context, 'error', _error!),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Text('Response', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _row(context, 'userId', result.userId),
            _row(context, 'appId', result.appId),
            _row(context, 'isSandbox', '${result.isSandbox}'),
            _row(context, 'serverTime', result.serverTime),
            const SizedBox(height: 12),
            Text('Subscription', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _row(context, 'type', result.subscription.type),
            _row(context, 'productId', result.subscription.productId ?? 'n/a'),
            const SizedBox(height: 12),
            Text('Offer', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _row(context, 'actionType', result.offer.actionType.name),
            _row(context, 'isEligible', '${result.offer.isEligible}'),
            _row(context, 'savingsPercent', '${result.offer.savingsPercent}%'),
            _row(context, 'checkoutProductId', result.offer.checkoutProductId ?? 'n/a'),
            _row(context, 'fromProductId', result.offer.fromProductId ?? 'n/a'),
            _row(context, 'freeTrialDays', '${result.offer.freeTrialDays}'),
            _row(context, 'source', result.offer.source?.name ?? 'n/a'),
            _row(context, 'requiresAppleCancel', '${result.offer.requiresAppleCancel}'),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final baseStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
