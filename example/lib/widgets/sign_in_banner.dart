import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// A banner shown when the current [Identity] is `.deferred`, prompting the
/// user to sign in or continue as guest. Renders nothing in any other state.
///
/// Tapping the CTA calls [onSignIn], which should open the identity choice
/// sheet (the same one shown on first launch).
class SignInBanner extends StatelessWidget {
  /// The current identity. Banner only renders when this is [IdentityDeferred].
  final Identity? identity;
  final VoidCallback onSignIn;

  const SignInBanner({
    super.key,
    required this.identity,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    if (identity is! IdentityDeferred) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              child: const Icon(Icons.person_outline),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are not signed in',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sign in or continue as guest to load products, entitlements, and transactions.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
