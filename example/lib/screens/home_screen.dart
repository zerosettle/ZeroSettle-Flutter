import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/gem_balance_card.dart';
import '../widgets/subscription_status_card.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback onNavigateToStore;

  const HomeScreen({
    super.key,
    required this.appState,
    required this.onNavigateToStore,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(title: const Text('Home')),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    // Profile header
                    _buildHeader(context),
                    const SizedBox(height: 24),

                    // Gem Balance
                    GemBalanceCard(
                      gemCount: appState.gemCount,
                      onTapStore: onNavigateToStore,
                    ),
                    const SizedBox(height: 16),

                    // Subscription Status
                    SubscriptionStatusCard(
                      status: appState.subscriptionStatus,
                      planName: appState.subscriptionPlan,
                      expiryDate: appState.subscriptionExpiryDate,
                      onTapStore: onNavigateToStore,
                    ),
                    const SizedBox(height: 24),

                    // Recent Purchases
                    if (appState.purchaseHistory.isNotEmpty) ...[
                      _buildRecentPurchases(context),
                      const SizedBox(height: 24),
                    ],

                    // Quick Stats
                    _buildQuickStats(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.account_circle,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome!',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          appState.email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Member since ${_formatDate(appState.memberSince)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildRecentPurchases(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Purchases',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...appState.recentPurchases.map(
          (purchase) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purchase.productName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        purchase.formattedDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      purchase.formattedAmount,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      purchase.paymentMethod.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            StatCard(
              title: 'Purchases',
              value: '${appState.totalPurchases}',
              icon: Icons.shopping_cart,
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            StatCard(
              title: 'Total Spent',
              value: '\$${appState.totalSpent.toStringAsFixed(2)}',
              icon: Icons.attach_money,
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            StatCard(
              title: 'Days',
              value: '${appState.daysSinceMember}',
              icon: Icons.calendar_today,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
