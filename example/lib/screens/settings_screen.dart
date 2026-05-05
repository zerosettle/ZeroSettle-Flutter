import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';
import '../app_state.dart';
import '../debug/debug_account.dart';
import '../iap_environment.dart';
import '../identity_choice.dart';
import 'debug_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppState appState;
  final IAPEnvironmentNotifier envNotifier;
  final Future<void> Function(IAPEnvironment) onSwitchEnvironment;
  final Future<void> Function() onSwitchIdentity;
  final Future<void> Function() onSignOut;

  /// Debug-only callback: re-bootstrap the SDK in [env] and optionally
  /// re-identify as [restoreIdentity], skipping the user-facing identity
  /// sheet. Only consumed when [kDebugMode] is true.
  final Future<void> Function(IAPEnvironment env, {Identity? restoreIdentity})
      onApplyDebugEnv;

  /// Debug-only callback: logout, identify as [account], persist via
  /// [IdentityChoiceStore].
  final Future<void> Function(DebugAccount account) onSwitchToDebugAccount;

  /// Debug-only callback: logout + clear local identity without re-prompting.
  final Future<void> Function() onDebugClearIdentity;

  const SettingsScreen({
    super.key,
    required this.appState,
    required this.envNotifier,
    required this.onSwitchEnvironment,
    required this.onSwitchIdentity,
    required this.onSignOut,
    required this.onApplyDebugEnv,
    required this.onSwitchToDebugAccount,
    required this.onDebugClearIdentity,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSwitchingEnv = false;
  bool _isSwitchingIdentity = false;
  bool _isSigningOut = false;
  bool _isUpdatingProfile = false;
  bool _isRestoring = false;
  String? _restoreResult;

  AppState get _appState => widget.appState;

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
                        _buildSectionHeader(context, 'Environment'),
                        _buildEnvironmentCard(context),
                        if (_isSwitchingEnv)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          ),
                        const SizedBox(height: 24),

                        _buildSectionHeader(context, 'Identity'),
                        _buildIdentityCard(context),
                        const SizedBox(height: 24),

                        if (_appState.currentIdentity is IdentityUser) ...[
                          _buildSectionHeader(context, 'Profile'),
                          _buildProfileCard(context),
                          const SizedBox(height: 24),
                        ],

                        _buildSectionHeader(context, 'Restore Purchases'),
                        _buildRestoreCard(context),
                        const SizedBox(height: 24),

                        _buildSectionHeader(context, 'App Info'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _labeledRow(context, 'SDK', 'ZeroSettle Flutter'),
                                const SizedBox(height: 8),
                                _labeledRow(
                                    context, 'Example App', 'StoreFront Flutter'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Debug Tools — only visible in debug builds. The
                        // entire section disappears in release because
                        // kDebugMode is a const-folded compile-time bool.
                        if (kDebugMode) ...[
                          _buildSectionHeader(context, 'Developer'),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.bug_report_outlined),
                              title: const Text('Debug Tools'),
                              subtitle: const Text(
                                  'Test accounts, environment switching, claim entitlements'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DebugSettingsScreen(
                                    appState: _appState,
                                    envNotifier: widget.envNotifier,
                                    onApplyDebugEnv: widget.onApplyDebugEnv,
                                    onSwitchToDebugAccount:
                                        widget.onSwitchToDebugAccount,
                                    onDebugClearIdentity:
                                        widget.onDebugClearIdentity,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (_isSwitchingIdentity || _isSigningOut)
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
                              _isSigningOut
                                  ? 'Signing out...'
                                  : 'Switching identity...',
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

  // -- Environment --

  Widget _buildEnvironmentCard(BuildContext context) {
    return ValueListenableBuilder<IAPEnvironment>(
      valueListenable: widget.envNotifier,
      builder: (context, currentEnv, _) {
        return Card(
          child: Column(
            children: [
              IgnorePointer(
                ignoring: _isSwitchingEnv,
                child: RadioGroup<IAPEnvironment>(
                  groupValue: currentEnv,
                  onChanged: (value) {
                    if (value != null && value != currentEnv) {
                      _switchEnv(value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final env in IAPEnvironment.values)
                        RadioListTile<IAPEnvironment>(
                          value: env,
                          title: Text(env.displayName),
                          subtitle: Text(env.description),
                          dense: true,
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
                    _labeledRow(context, 'Key', currentEnv.truncatedKey),
                    const SizedBox(height: 4),
                    _labeledRow(context, 'URL', currentEnv.effectiveUrl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchEnv(IAPEnvironment env) async {
    setState(() => _isSwitchingEnv = true);
    try {
      await widget.onSwitchEnvironment(env);
    } finally {
      if (mounted) setState(() => _isSwitchingEnv = false);
    }
  }

  // -- Identity --

  Widget _buildIdentityCard(BuildContext context) {
    final identity = _appState.currentIdentity;
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labeledRow(
                  context,
                  'Mode',
                  identity?.modeLabel ?? 'Not set',
                ),
                const SizedBox(height: 8),
                _labeledRow(
                  context,
                  identity is IdentityUser ? 'User ID' : 'Detail',
                  identity?.displayLabel ?? '—',
                ),
                if (identity is IdentityUser && identity.email != null) ...[
                  const SizedBox(height: 8),
                  _labeledRow(context, 'Email', identity.email!),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Switch identity'),
            subtitle: const Text(
                'Sign in as a different user, continue as guest, or defer.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isSwitchingIdentity ? null : _switchIdentity,
          ),
          if (identity is IdentityDeferred)
            ListTile(
              leading: const Icon(Icons.upgrade),
              title: const Text('Upgrade to user identity'),
              subtitle: const Text('Provide a user ID, name, and email now.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isSwitchingIdentity ? null : _switchIdentity,
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            subtitle:
                const Text('Calls ZeroSettle.logout() and clears local state.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isSigningOut || identity == null ? null : _signOut,
          ),
        ],
      ),
    );
  }

  Future<void> _switchIdentity() async {
    setState(() => _isSwitchingIdentity = true);
    try {
      await widget.onSwitchIdentity();
    } finally {
      if (mounted) setState(() => _isSwitchingIdentity = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  // -- Profile --

  Widget _buildProfileCard(BuildContext context) {
    final identity = _appState.currentIdentity;
    if (identity is! IdentityUser) return const SizedBox.shrink();
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _labeledRow(context, 'Name', identity.name ?? '—'),
                const SizedBox(height: 8),
                _labeledRow(context, 'Email', identity.email ?? '—'),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: _isUpdatingProfile
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined),
            title: const Text('Update profile'),
            subtitle: const Text(
                'Sends new name/email to Stripe via setCustomer().'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isUpdatingProfile ? null : _updateProfile,
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    final identity = _appState.currentIdentity;
    if (identity is! IdentityUser) return;

    final result = await showDialog<_ProfileEdit>(
      context: context,
      builder: (ctx) => _ProfileEditDialog(
        initialName: identity.name ?? '',
        initialEmail: identity.email ?? '',
      ),
    );
    if (result == null) return;

    setState(() => _isUpdatingProfile = true);
    String? errorMessage;
    try {
      await ZeroSettle.instance.setCustomer(
        name: result.name.isEmpty ? null : result.name,
        email: result.email.isEmpty ? null : result.email,
      );
      // Reflect locally and re-persist so future launches use the new values.
      final updated = Identity.user(
        id: identity.id,
        name: result.name.isEmpty ? null : result.name,
        email: result.email.isEmpty ? null : result.email,
      );
      _appState.setIdentity(updated);
      await IdentityChoiceStore.save(updated);
    } on ZeroSettleException catch (e) {
      errorMessage = e.message;
    } finally {
      if (mounted) setState(() => _isUpdatingProfile = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage == null
            ? 'Profile updated'
            : 'Update failed: $errorMessage'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -- Restore --

  Widget _buildRestoreCard(BuildContext context) {
    final canRestore = _appState.currentIdentity != null &&
        _appState.currentIdentity is! IdentityDeferred;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: _isRestoring
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            title: const Text('Restore entitlements'),
            subtitle: Text(canRestore
                ? 'Pulls active entitlements for the current identity.'
                : 'Sign in or continue as guest to enable restore.'),
            onTap: _isRestoring || !canRestore ? null : _restorePurchases,
          ),
          if (_restoreResult != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _restoreResult!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isRestoring = true;
      _restoreResult = null;
    });
    try {
      final entitlements = await ZeroSettle.instance.restoreEntitlements();
      _appState.setEntitlements(entitlements);
      setState(() {
        _restoreResult = 'Restored ${entitlements.length} entitlement(s)';
      });
    } on ZeroSettleException catch (e) {
      setState(() => _restoreResult = 'Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // -- Helpers --

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
}

class _ProfileEdit {
  final String name;
  final String email;
  const _ProfileEdit(this.name, this.email);
}

class _ProfileEditDialog extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  const _ProfileEditDialog({
    required this.initialName,
    required this.initialEmail,
  });

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ProfileEdit(
            _nameController.text.trim(),
            _emailController.text.trim(),
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
