import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';
import '../app_state.dart';

class SettingsScreen extends StatefulWidget {
  final AppState appState;

  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _userIdController = TextEditingController();
  bool _isSwitchingUser = false;
  bool _isRestoring = false;
  String? _restoreResult;

  AppState get _appState => widget.appState;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar.large(title: const Text('Settings')),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.list(
                      children: [
                        // User ID section
                        _buildSectionHeader(context, 'User Identity'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _labeledRow(
                                  context,
                                  'Current User ID',
                                  _appState.userId,
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _userIdController,
                                        decoration: const InputDecoration(
                                          hintText: 'Custom User ID',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        autocorrect: false,
                                        textCapitalization:
                                            TextCapitalization.none,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _isSwitchingUser ||
                                              _userIdController.text.isEmpty
                                          ? null
                                          : () => _switchUser(
                                              _userIdController.text),
                                      child: const Text('Set'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ActionChip(
                                      label: const Text('Demo User'),
                                      onPressed: () =>
                                          _switchUser('flutter_example_user'),
                                    ),
                                    ActionChip(
                                      label: const Text('Test User 2'),
                                      onPressed: () =>
                                          _switchUser('user_test_2'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Switch between user IDs to test purchase persistence across users.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),

                        const SizedBox(height: 24),

                        // Account section
                        _buildSectionHeader(context, 'Account'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _labeledRow(context, 'Email', _appState.email),
                                const SizedBox(height: 8),
                                _labeledRow(
                                  context,
                                  'Member Since',
                                  _formatDate(_appState.memberSince),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Subscription Management
                        _buildSectionHeader(context, 'Subscription'),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.credit_card),
                            title: const Text('Manage Subscription'),
                            subtitle: const Text(
                                'Opens Stripe portal or Apple subscription management'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _manageSubscription,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Restore Purchases
                        _buildSectionHeader(context, 'Restore Purchases'),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: _isRestoring
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh),
                                title: const Text('Restore by User ID'),
                                subtitle: const Text(
                                    'Fetches entitlements for the current user'),
                                onTap: _isRestoring ? null : _restorePurchases,
                              ),
                              if (_restoreResult != null) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _restoreResult!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // App Info
                        _buildSectionHeader(context, 'App Info'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _labeledRow(context, 'SDK', 'ZeroSettle Flutter'),
                                const SizedBox(height: 8),
                                _labeledRow(context, 'Example App', 'StoreFront Flutter'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),

              // Switching user overlay
              if (_isSwitchingUser)
                Container(
                  color: Colors.black38,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Switching user...',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _labeledRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
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

  Future<void> _switchUser(String newUserId) async {
    if (newUserId.isEmpty) return;
    setState(() => _isSwitchingUser = true);

    _appState.resetForUser(newUserId);

    try {
      // Re-bootstrap with new user
      final catalog =
          await ZeroSettle.instance.bootstrap(userId: newUserId);
      _appState.setProducts(catalog.products);
      _appState.setRemoteConfig(catalog.config);

      // Restore entitlements
      final entitlements =
          await ZeroSettle.instance.restoreEntitlements(userId: newUserId);
      _appState.setEntitlements(entitlements);
    } on ZSException {
      // Silently handle errors
    }

    _userIdController.clear();
    setState(() => _isSwitchingUser = false);
  }

  Future<void> _manageSubscription() async {
    try {
      await ZeroSettle.instance
          .showManageSubscription(userId: _appState.userId);
    } on ZSException {
      // Silently handle errors
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isRestoring = true;
      _restoreResult = null;
    });

    try {
      final entitlements =
          await ZeroSettle.instance.restoreEntitlements(userId: _appState.userId);
      _appState.setEntitlements(entitlements);

      setState(() {
        _restoreResult = 'Restored ${entitlements.length} entitlement(s)';
      });
    } on ZSException {
      // Silently handle errors
    } finally {
      setState(() => _isRestoring = false);
    }
  }
}
