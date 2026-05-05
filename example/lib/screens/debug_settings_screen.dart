import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerosettle/zerosettle.dart';

import '../app_state.dart';
import '../debug/debug_account.dart';
import '../iap_environment.dart';

/// Debug-only settings screen — port of JustOne's `DebugSettingsView`.
///
/// Lets engineers swap environments at runtime, manage a roster of
/// per-environment synthetic accounts, and force-claim StoreKit
/// entitlements. The screen is gated by [kDebugMode] at the call site
/// (in [SettingsScreen]) and is not reachable in release builds.
///
/// All SDK / identity / env-switch calls are routed through callbacks so
/// the screen stays UI-only and the AppShell remains the source of truth
/// for SDK lifecycle.
class DebugSettingsScreen extends StatefulWidget {
  final AppState appState;
  final IAPEnvironmentNotifier envNotifier;

  /// Apply [env] and (optionally) re-identify as [restoreIdentity] in one
  /// shot. The AppShell must NOT auto-prompt for identity in this path.
  final Future<void> Function(IAPEnvironment env, {Identity? restoreIdentity})
      onApplyDebugEnv;

  /// Logout, identify as the user described by the supplied account, and
  /// persist the choice to [IdentityChoiceStore].
  final Future<void> Function(DebugAccount account) onSwitchToDebugAccount;

  /// Logout + clear local identity state without showing the identity sheet.
  final Future<void> Function() onDebugClearIdentity;

  const DebugSettingsScreen({
    super.key,
    required this.appState,
    required this.envNotifier,
    required this.onApplyDebugEnv,
    required this.onSwitchToDebugAccount,
    required this.onDebugClearIdentity,
  });

  @override
  State<DebugSettingsScreen> createState() => _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends State<DebugSettingsScreen> {
  // -- Environment picker state (separate from the active env until "Apply") --
  late IAPEnvironment _selectedEnv;

  // -- Accounts state --
  List<DebugAccount> _accountsForSelectedEnv = const [];
  final TextEditingController _newLabelController = TextEditingController();

  // -- Claim state --
  bool _claimInProgress = false;
  String? _claimResult;

  // -- Apply state --
  bool _isApplying = false;
  String? _statusMessage;
  bool _statusIsError = false;

  AppState get _appState => widget.appState;

  String get _selectedEnvKey => _selectedEnv.name;

  String? get _activeUserId {
    final identity = _appState.currentIdentity;
    return identity is IdentityUser ? identity.id : null;
  }

  @override
  void initState() {
    super.initState();
    _selectedEnv = widget.envNotifier.value;
    _refreshAccounts();
    widget.envNotifier.addListener(_onEnvChanged);
  }

  @override
  void dispose() {
    widget.envNotifier.removeListener(_onEnvChanged);
    _newLabelController.dispose();
    super.dispose();
  }

  void _onEnvChanged() {
    // The "live" env may diverge from the picker if Apply runs. Keep the
    // picker in sync when the AppShell switches under us.
    if (mounted) {
      setState(() => _selectedEnv = widget.envNotifier.value);
      _refreshAccounts();
    }
  }

  Future<void> _refreshAccounts() async {
    final list = await DebugAccountStore.accountsFor(_selectedEnvKey);
    if (!mounted) return;
    setState(() => _accountsForSelectedEnv = list);
  }

  // -- Handlers --

  Future<void> _createAccount() async {
    final label = _newLabelController.text.trim();
    if (label.isEmpty) return;
    final account = DebugAccount(
      id: DebugAccount.generateId(),
      label: label,
      createdAt: DateTime.now(),
      envKey: _selectedEnvKey,
    );
    await DebugAccountStore.add(account);
    _newLabelController.clear();
    await _refreshAccounts();
    // Auto-switch immediately so adopters can verify the flow.
    await _switchToAccount(account);
  }

  Future<void> _switchToAccount(DebugAccount account) async {
    setState(() {
      _statusMessage = 'Switching to ${account.label}…';
      _statusIsError = false;
    });
    try {
      await widget.onSwitchToDebugAccount(account);
      await DebugAccountStore.setLastActive(
        accountId: account.id,
        envKey: _selectedEnvKey,
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Active: ${account.label}';
        _statusIsError = false;
      });
    } on ZeroSettleException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error: ${e.message}';
        _statusIsError = true;
      });
    }
  }

  Future<void> _deleteAccount(DebugAccount account) async {
    await DebugAccountStore.remove(account.id);
    await _refreshAccounts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${account.label}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _applyEnvironment() async {
    setState(() {
      _isApplying = true;
      _statusMessage = null;
    });
    final oldEnvKey = widget.envNotifier.value.name;
    final newEnvKey = _selectedEnv.name;

    // 1. Save the current user as last-active for the OLD env.
    final activeId = _activeUserId;
    if (activeId != null) {
      await DebugAccountStore.setLastActive(
        accountId: activeId,
        envKey: oldEnvKey,
      );
    }

    // 2. Look up the candidate account to restore in the NEW env (before
    //    we re-bootstrap, since the bootstrap clears identity).
    final candidateId = await DebugAccountStore.lastActiveAccountId(newEnvKey);
    final candidates = await DebugAccountStore.accountsFor(newEnvKey);
    DebugAccount? restoreCandidate;
    if (candidateId != null) {
      for (final account in candidates) {
        if (account.id == candidateId) {
          restoreCandidate = account;
          break;
        }
      }
    }

    final restoreIdentity = restoreCandidate != null
        ? Identity.user(id: restoreCandidate.id, name: restoreCandidate.label)
        : null;

    String message;
    bool isError = false;
    try {
      // 3. Hand off to the AppShell — it logs out, switches env, and
      //    optionally re-identifies. No identity sheet is shown.
      await widget.onApplyDebugEnv(
        _selectedEnv,
        restoreIdentity: restoreIdentity,
      );
      if (restoreCandidate != null) {
        message =
            'Switched to ${_selectedEnv.displayName} — restored ${restoreCandidate.label}';
      } else {
        message =
            'Switched to ${_selectedEnv.displayName} — no last-active account';
      }
    } on ZeroSettleException catch (e) {
      message = 'Error: ${e.message}';
      isError = true;
    }

    await _refreshAccounts();
    if (!mounted) return;
    setState(() {
      _isApplying = false;
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _runClaim(Product product) async {
    setState(() {
      _claimInProgress = true;
      _claimResult = null;
    });
    try {
      await ZeroSettle.instance
          .transferStoreKitOwnershipToCurrentUser(productId: product.id);
      // Pull fresh entitlements so the OWNED badge appears immediately.
      final entitlements = await ZeroSettle.instance.restoreEntitlements();
      _appState.setEntitlements(entitlements);
      if (!mounted) return;
      setState(() {
        _claimResult = 'Claimed ${product.displayName}';
      });
    } on ZeroSettleException catch (e) {
      if (!mounted) return;
      setState(() => _claimResult = 'Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _claimInProgress = false);
    }
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        final identity = _appState.currentIdentity;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Debug Tools'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader(context, 'Environment'),
              _buildEnvironmentCard(context),
              const SizedBox(height: 24),
              _sectionHeader(context,
                  'Test Accounts — ${_selectedEnv.displayName}'),
              _buildAccountsCard(context),
              const SizedBox(height: 24),
              if (identity is IdentityUser) ...[
                _sectionHeader(context, 'Claim Entitlements'),
                _buildClaimCard(context),
                const SizedBox(height: 24),
                _sectionHeader(context, 'Active User'),
                _buildActiveUserCard(context, identity),
                const SizedBox(height: 24),
              ],
              _buildFooterNote(context),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // -- Environment section --

  Widget _buildEnvironmentCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          IgnorePointer(
            ignoring: _isApplying,
            child: RadioGroup<IAPEnvironment>(
              groupValue: _selectedEnv,
              onChanged: (value) {
                if (value != null && value.isEnabled) {
                  setState(() => _selectedEnv = value);
                  _refreshAccounts();
                }
              },
              child: Column(
                children: [
                  for (final env in IAPEnvironment.values)
                    IgnorePointer(
                      ignoring: !env.isEnabled,
                      child: Opacity(
                        opacity: env.isEnabled ? 1.0 : 0.4,
                        child: RadioListTile<IAPEnvironment>(
                          value: env,
                          title: Text(env.displayName),
                          subtitle: Text(env.isEnabled
                              ? env.description
                              : '${env.description} — disabled'),
                          dense: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _labeledRow(context, 'Key', _selectedEnv.truncatedKey),
                const SizedBox(height: 4),
                _labeledRow(context, 'URL', _selectedEnv.effectiveUrl),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _isApplying ? null : _applyEnvironment,
                  icon: _isApplying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt),
                  label: Text(_isApplying ? 'Applying…' : 'Apply'),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _statusIsError ? Icons.error : Icons.check_circle,
                        size: 18,
                        color: _statusIsError ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Accounts section --

  Widget _buildAccountsCard(BuildContext context) {
    final accounts = _accountsForSelectedEnv;
    return Card(
      child: Column(
        children: [
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No test accounts for this environment.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          for (final account in accounts) ...[
            Dismissible(
              key: ValueKey('debug_account_${account.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red.shade100,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              onDismissed: (_) => _deleteAccount(account),
              child: _buildAccountTile(context, account),
            ),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Account label',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _createAccount(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _createAccount,
                  icon: const Icon(Icons.add),
                  tooltip: 'Create account',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context, DebugAccount account) {
    final isActive = account.id == _activeUserId;
    return ListTile(
      title: Row(
        children: [
          Flexible(
            child: Text(
              account.label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 8),
            _badge(context, label: 'ACTIVE', color: Colors.green),
          ],
        ],
      ),
      subtitle: SelectableText(
        account.id,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: isActive
          ? null
          : OutlinedButton(
              onPressed: () => _switchToAccount(account),
              child: const Text('Switch'),
            ),
    );
  }

  // -- Claim section --

  Widget _buildClaimCard(BuildContext context) {
    final claimable = _appState.products.where((p) {
      return p.type == ZSProductType.autoRenewableSubscription ||
          p.type == ZSProductType.nonRenewingSubscription ||
          p.type == ZSProductType.nonConsumable;
    }).toList();

    if (claimable.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No claimable products. Bootstrap an identity first to fetch the catalog.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < claimable.length; i++) ...[
            _buildClaimRow(context, claimable[i]),
            if (i < claimable.length - 1) const Divider(height: 1),
          ],
          if (_claimResult != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _claimResult!.startsWith('Error')
                        ? Icons.error
                        : Icons.check_circle,
                    size: 18,
                    color: _claimResult!.startsWith('Error')
                        ? Colors.red
                        : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _claimResult!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Claim transfers any StoreKit purchase of this product on this device to the current ZeroSettle account. If no StoreKit purchase exists, the claim will fail with a clear error.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimRow(BuildContext context, Product product) {
    Entitlement? entitlement;
    for (final e in _appState.entitlements) {
      if (e.productId == product.id) {
        entitlement = e;
        break;
      }
    }

    final owned = entitlement != null;
    final isCancelled = entitlement?.cancelledAt != null;
    final source = entitlement?.source;

    return ListTile(
      title: Row(
        children: [
          Flexible(
            child: Text(
              product.displayName,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (owned) ...[
            const SizedBox(width: 8),
            _ownershipBadge(context, isCancelled: isCancelled, source: source),
          ],
        ],
      ),
      subtitle: Text(
        product.id,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: _claimTrailing(
        owned: owned,
        isCancelled: isCancelled,
        product: product,
      ),
    );
  }

  Widget? _claimTrailing({
    required bool owned,
    required bool isCancelled,
    required Product product,
  }) {
    if (owned && !isCancelled) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (owned && isCancelled) {
      return const Icon(Icons.history_toggle_off, color: Colors.orange);
    }
    return OutlinedButton(
      onPressed:
          _claimInProgress ? null : () => _runClaim(product),
      child: const Text('Claim'),
    );
  }

  Widget _ownershipBadge(
    BuildContext context, {
    required bool isCancelled,
    required EntitlementSource? source,
  }) {
    final base = isCancelled ? 'SUPERSEDED' : 'OWNED';
    final suffix = switch (source) {
      EntitlementSource.storeKit => ' (SK)',
      EntitlementSource.webCheckout => ' (Web)',
      EntitlementSource.playStore => ' (Play)',
      null => '',
    };
    final color = isCancelled ? Colors.orange : Colors.green;
    return _badge(context, label: '$base$suffix', color: color);
  }

  // -- Active user section --

  Widget _buildActiveUserCard(BuildContext context, IdentityUser identity) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _labeledRow(context, 'Mode', 'User'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User ID',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Flexible(
                  child: SelectableText(
                    identity.id,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy user id',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: identity.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User id copied'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
            if (identity.name != null) ...[
              const SizedBox(height: 8),
              _labeledRow(context, 'Name', identity.name!),
            ],
            if (identity.email != null) ...[
              const SizedBox(height: 8),
              _labeledRow(context, 'Email', identity.email!),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await widget.onDebugClearIdentity();
                final envKey = widget.envNotifier.value.name;
                await DebugAccountStore.clearLastActive(envKey);
                if (!mounted) return;
                setState(() {
                  _statusMessage = 'Signed out (no auto-prompt)';
                  _statusIsError = false;
                });
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out (debug)'),
            ),
          ],
        ),
      ),
    );
  }

  // -- Footer --

  Widget _buildFooterNote(BuildContext context) {
    return Text(
      'iOS-only debug toggles (Demo Mode, Forced Jurisdiction) are not '
      'exposed via the Flutter SDK in 1.3.0.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
      textAlign: TextAlign.center,
    );
  }

  // -- Shared helpers --

  Widget _sectionHeader(BuildContext context, String title) {
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

  Widget _badge(BuildContext context,
      {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
