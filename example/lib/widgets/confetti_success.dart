import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A self-contained animated confetti celebration shown when a subscription is
/// successfully cancelled. Mirrors the Android `ConfettiSuccess` composable in
/// the JustOne sample.
///
/// Drives 28 falling colored circles via [CustomPaint] over a 1.5 s
/// [AnimationController]. The caller is responsible for any navigation after
/// the animation completes — this widget is purely visual.
class ConfettiSuccess extends StatefulWidget {
  const ConfettiSuccess({super.key});

  @override
  State<ConfettiSuccess> createState() => _ConfettiSuccessState();
}

class _ConfettiSuccessState extends State<ConfettiSuccess>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  static const _colors = [
    Color(0xFF6CA358),
    Color(0xFFD97706),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
  ];

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _pieces = List.generate(28, (_) {
      return _ConfettiPiece(
        startX: rng.nextDouble(),
        drift: (rng.nextDouble() - 0.5) * 0.3,
        color: _colors[rng.nextInt(_colors.length)],
        size: 8 + rng.nextDouble() * 8,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Confetti layer
            Positioned.fill(
              child: CustomPaint(
                painter: _ConfettiPainter(
                  pieces: _pieces,
                  progress: _controller.value,
                ),
              ),
            ),
            // Success message
            child!,
          ],
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: _colors.first,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Subscription cancelled',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You're all set",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  final double startX;
  final double drift;
  final Color color;
  final double size;

  const _ConfettiPiece({
    required this.startX,
    required this.drift,
    required this.color,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  const _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final piece in pieces) {
      final x = (piece.startX + piece.drift * progress) * size.width;
      final y = progress * size.height;
      paint.color = piece.color;
      canvas.drawCircle(Offset(x, y), piece.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
