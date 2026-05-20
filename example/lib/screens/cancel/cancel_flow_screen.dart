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
  // ---------------------------------------------------------------------------

  Future<void> _onCancelAnyway(BuildContext ctx) async {
    try {
      await ZeroSettle.instance.cancelSubscription(productId: widget.productId);
    } catch (_) {
      // Ignore — we still show confetti so the user knows it was requested.
    }
    if (!ctx.mounted) return;
    _triggerConfetti(ctx);
  }

  Future<void> _onAcceptOffer(BuildContext ctx) async {
    try {
      await ZeroSettle.instance.acceptSaveOffer(productId: widget.productId);
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Offer applied — thanks for staying!')),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Could not apply offer: $e')),
      );
    }
    if (ctx.mounted) ctx.pop();
  }

  Future<void> _onPause(BuildContext ctx, int? durationDays) async {
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
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Could not pause: $e')),
      );
    }
    if (ctx.mounted) ctx.pop();
  }

  Future<void> _onCancelConfirmed(BuildContext ctx) async {
    try {
      await ZeroSettle.instance
          .cancelSubscription(productId: widget.productId, immediate: false);
    } catch (_) {
      // Proceed to confetti regardless.
    }
    if (!ctx.mounted) return;
    _triggerConfetti(ctx);
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
                  onPressed: () => _onCancelAnyway(ctx),
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

  /// Renders the loaded [CancelFlowConfig] — questions summary, save offer,
  /// pause option, cancel CTA, and keep-subscription escape.
  Widget _buildConfigBody(BuildContext ctx, CancelFlowConfig config) {
    final theme = Theme.of(ctx);
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
                      onPressed: () => _onAcceptOffer(ctx),
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
                      onPressed: () {
                        // Use the first available duration option; if the list
                        // is empty or durationDays is null, pass null and let
                        // the backend choose the default.
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => _onCancelConfirmed(ctx),
            child: const Text('Cancel my subscription'),
          ),
          const SizedBox(height: 12),

          // --- Keep escape ---
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Keep my subscription'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
