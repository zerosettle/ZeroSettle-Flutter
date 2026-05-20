import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/routes.dart';
import '../../widgets/confetti_success.dart';

/// A headless cancel / retention flow for the JustOne sample app.
///
/// **Note**: The native Android sample delegates to the `:ui`
/// `ZeroSettleCancelFlow` composable which renders the full server-driven
/// questionnaire as a native sheet. Flutter has no equivalent first-party
/// widget, so this screen fetches [CancelFlowConfig] via the headless API and
/// renders the config fields directly. The behavior mirrors the Android
/// composable's terminal outcomes — cancel, save-offer, pause, dismiss — but
/// the intermediate questionnaire UI is simplified.
///
/// When the server reports [CancelFlowConfig.enabled] == false the retention
/// flow is off — the screen renders a cancel-only body (no offer / pause /
/// questions).
///
/// Mirrors: `CancelFlowScreen.kt` in the JustOne Android sample.
class CancelFlowScreen extends StatefulWidget {
  final String productId;

  const CancelFlowScreen({required this.productId, super.key});

  @override
  State<CancelFlowScreen> createState() => _CancelFlowScreenState();
}

class _CancelFlowScreenState extends State<CancelFlowScreen> {
  /// Future holding the in-flight [fetchCancelFlowConfig] result.
  late final Future<CancelFlowConfig> _configFuture;

  /// When true, the body is replaced by [ConfettiSuccess].
  bool _showConfetti = false;

  /// True while an SDK action call is in-flight — disables every action
  /// button so a double-tap can't fire the same call twice.
  bool _busy = false;

  /// Auto-navigation timer — cancelled in [dispose] if the widget unmounts
  /// before the 2.5 s confetti window elapses.
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _configFuture = ZeroSettle.instance.fetchCancelFlowConfig();
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Action handlers
  //
  // Each handler sets [_busy] for the duration of its SDK call so the action
  // buttons disable, blocking a double-tap from firing the same call twice.
  // ---------------------------------------------------------------------------

  /// Cancels the subscription. On genuine success, swaps the body to
  /// [ConfettiSuccess]; on failure, surfaces an error SnackBar and stays put —
  /// confetti is never shown for a call that didn't succeed.
  Future<void> _onCancel(BuildContext ctx, {bool immediate = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ZeroSettle.instance.cancelSubscription(
        productId: widget.productId,
        immediate: immediate,
      );
      if (!ctx.mounted) return;
      _triggerConfetti(ctx);
    } catch (_) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text("Couldn't cancel your subscription. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onAcceptOffer(BuildContext ctx) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ZeroSettle.instance.acceptSaveOffer(productId: widget.productId);
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Offer applied — thanks for staying!')),
      );
      ctx.pop();
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Could not apply offer: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onPause(BuildContext ctx, int? durationDays) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final resumeDate = await ZeroSettle.instance.pauseSubscription(
        productId: widget.productId,
        pauseDurationDays: durationDays,
      );
      if (!ctx.mounted) return;
      final msg = resumeDate != null
          ? 'Paused until ${_formatDate(resumeDate)}'
          : 'Subscription paused';
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
      ctx.pop();
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Could not pause: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Swaps the body to [ConfettiSuccess] and schedules auto-navigation home
  /// after 2.5 s.
  void _triggerConfetti(BuildContext ctx) {
    setState(() => _showConfetti = true);
    _navTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) ctx.go(Routes.home);
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showConfetti
          ? null
          : AppBar(
              title: const Text('Cancel subscription'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Keep my subscription',
                onPressed: () => context.pop(),
              ),
            ),
      body: _showConfetti
          ? const ConfettiSuccess()
          : FutureBuilder<CancelFlowConfig>(
              future: _configFuture,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return _buildErrorFallback(ctx);
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildConfigBody(ctx, snap.data!);
              },
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-builders
  // ---------------------------------------------------------------------------

  /// Shown when [fetchCancelFlowConfig] fails — mirrors the Android
  /// `loadFailed` branch.
  Widget _buildErrorFallback(BuildContext ctx) {
    final theme = Theme.of(ctx);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Couldn't load retention options.",
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can still cancel your subscription below.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : () => _onCancel(ctx),
                  child: const Text('Cancel anyway'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ctx.pop(),
                  child: const Text('Keep my subscription'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Renders the loaded [CancelFlowConfig].
  ///
  /// When [CancelFlowConfig.enabled] is false the server has turned the
  /// retention flow off — render a cancel-only body. Otherwise render the
  /// full retention UI: questions summary, save offer, pause option.
  Widget _buildConfigBody(BuildContext ctx, CancelFlowConfig config) {
    final theme = Theme.of(ctx);

    if (!config.enabled) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCancelCta(ctx),
            const SizedBox(height: 12),
            _buildKeepEscape(ctx),
          ],
        ),
      );
    }

    final offer = config.offer;
    final pause = config.pause;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Questionnaire summary (if questions exist) ---
          if (config.questions.isNotEmpty) ...[
            Text(
              'Before you go…',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...config.questions.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${q.questionText}',
                    style: theme.textTheme.bodyMedium,
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // --- Save offer ---
          if (offer != null && offer.enabled) ...[
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      offer.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : () => _onAcceptOffer(ctx),
                      child: Text(offer.ctaText),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // --- Pause option ---
          if (pause != null && pause.enabled) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(pause.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(pause.body, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              // Use the first available duration option; if the
                              // list is empty or durationDays is null, pass null
                              // and let the backend choose the default.
                              final days = pause.options.isNotEmpty
                                  ? pause.options.first.durationDays
                                  : null;
                              _onPause(ctx, days);
                            },
                      child: Text(pause.ctaText),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // --- Cancel CTA ---
          _buildCancelCta(ctx),
          const SizedBox(height: 12),

          // --- Keep escape ---
          _buildKeepEscape(ctx),
        ],
      ),
    );
  }

  /// The primary "Cancel my subscription" destructive CTA.
  Widget _buildCancelCta(BuildContext ctx) {
    final theme = Theme.of(ctx);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.error,
        foregroundColor: theme.colorScheme.onError,
      ),
      onPressed: _busy ? null : () => _onCancel(ctx),
      child: const Text('Cancel my subscription'),
    );
  }

  /// The "Keep my subscription" escape control.
  Widget _buildKeepEscape(BuildContext ctx) {
    return TextButton(
      onPressed: () => ctx.pop(),
      child: const Text('Keep my subscription'),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
