import 'package:flutter/material.dart';
import '../app_state.dart';

class SubscriptionStatusCard extends StatelessWidget {
  final SubscriptionStatus status;
  final String? planName;
  final DateTime? expiryDate;
  final VoidCallback onTapStore;

  const SubscriptionStatusCard({
    super.key,
    required this.status,
    this.planName,
    this.expiryDate,
    required this.onTapStore,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == SubscriptionStatus.active;
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.15),
                    Colors.amber.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : cs.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isActive ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                  size: 32,
                  color: isActive ? Colors.orange : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive && planName != null ? planName! : 'Premium',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      _subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (isActive && planName != null) ...[
              // Active subscription benefits
              ..._activeBenefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(b, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )),
              if (expiryDate != null) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Text(
                      'Renews: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      _formatDate(expiryDate!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Inactive — CTA
              Text(
                'Get Premium Access',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ..._promotionalBenefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(b, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTapStore,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'View Plans',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active Subscription';
      case SubscriptionStatus.inactive:
        return 'Not subscribed';
      case SubscriptionStatus.expired:
        return 'Subscription expired';
    }
  }

  List<String> get _activeBenefits =>
      ['Unlimited access', 'Ad-free experience', 'Priority support'];

  List<String> get _promotionalBenefits =>
      ['Unlock all premium features', 'Remove all ads', 'Priority customer support'];

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
