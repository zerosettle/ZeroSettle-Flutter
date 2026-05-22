import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../app_environment.dart';
import '../../data/identity_store.dart';
import '../../widgets/environment_picker.dart';

/// Developer tool: pick a backend environment and switch between the saved
/// test identities for that environment.
///
/// Mirrors [EnvSwitcherScreen.kt] from the JustOne Android sample.
///
/// Identities are partitioned per environment by [IdentityStore]: switching
/// environments swaps the visible identity list (and auto-identifies that
/// env's active user). Tapping an identity, or adding a new one, identifies
/// against the SDK and marks it active — so logging out never strands a user.
class EnvSwitcherScreen extends StatefulWidget {
  const EnvSwitcherScreen({super.key});

  @override
  State<EnvSwitcherScreen> createState() => _EnvSwitcherScreenState();
}

class _EnvSwitcherScreenState extends State<EnvSwitcherScreen> {
  // Loaded async; null means still loading.
  AppEnvironment? _currentEnv;

  final _userIdController = TextEditingController();
  final _nameController = TextEditingController();

  String _status = '';
  bool _busy = false;

  IdentityStore get _identityStore =>
      InheritedJustOne.of(context).identityStore;

  @override
  void initState() {
    super.initState();
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    final env = await AppEnvironment.load();
    if (mounted) setState(() => _currentEnv = env);
  }

  /// Switch the backend environment, then auto-identify with that env's
  /// active identity (if any). Mirrors main.dart's bootstrap sequence.
  Future<void> _switchEnv(AppEnvironment env) async {
    final identityStore = _identityStore;
    setState(() {
      _currentEnv = env;
      _busy = true;
      _status = 'Switching to ${env.displayName}…';
    });
    // Shared helper: save + logout + setBaseUrlOverride + configure.
    try {
      await applyEnvironment(env);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Switch to ${env.displayName} failed: $e';
      });
      return;
    }
    if (!mounted) return;

    // Envs whose publishable key has not been issued yet (staging iOS, prod)
    // can't be configured — applyEnvironment skipped configure(). Stop here
    // rather than attempting a re-identify that cannot succeed.
    if (!env.hasKey) {
      setState(() {
        _busy = false;
        _status = 'Switched to ${env.displayName}\n${env.baseUrl}\n'
            'No publishable key for this environment yet — pick another.';
      });
      return;
    }

    // Re-identify with this env's active identity so the SDK is bootstrapped
    // against the new env without forcing a manual re-identify.
    final active = identityStore.activeIdentityFor(env.name);
    if (active == null) {
      setState(() {
        _busy = false;
        _status = 'Switched to ${env.displayName}\n${env.baseUrl}\n'
            'No saved identity for this environment yet — add one below.';
      });
      return;
    }
    try {
      await ZeroSettle.instance.identify(
        Identity.user(id: active.userId, name: active.displayName),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Switched to ${env.displayName}\n${env.baseUrl}\n'
            'Identified as "${active.userId}" ✓';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Switched to ${env.displayName}\n${env.baseUrl}\n'
            're-identify failed: $e';
      });
    }
  }

  /// Identify as a saved identity and mark it active for the current env.
  Future<void> _selectIdentity(SavedIdentity identity) async {
    final env = _currentEnv;
    if (env == null) return;
    final identityStore = _identityStore;
    setState(() {
      _busy = true;
      _status = 'Identifying as "${identity.userId}"…';
    });
    try {
      await ZeroSettle.instance.identify(
        Identity.user(id: identity.userId, name: identity.displayName),
      );
      await identityStore.setActive(env.name, identity.userId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Identified as "${identity.userId}" ✓';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'identify() failed: $e';
      });
    }
  }

  /// Add (or update) an identity from the text fields, identify as it, and
  /// mark it active for the current env.
  Future<void> _addIdentity() async {
    final env = _currentEnv;
    final id = _userIdController.text.trim();
    if (env == null || id.isEmpty) return;
    final name = _nameController.text.trim();
    final displayName = name.isNotEmpty ? name : id;
    final identityStore = _identityStore;
    setState(() {
      _busy = true;
      _status = 'Adding "$id"…';
    });
    try {
      await ZeroSettle.instance.identify(
        Identity.user(id: id, name: displayName),
      );
      await identityStore.upsertIdentity(
        env.name,
        SavedIdentity(userId: id, displayName: displayName),
      );
      await identityStore.setActive(env.name, id);
      if (!mounted) return;
      _userIdController.clear();
      _nameController.clear();
      setState(() {
        _busy = false;
        _status = 'Added & identified as "$id" ✓';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'identify() failed: $e';
      });
    }
  }

  /// Remove a saved identity from the current env's picker.
  Future<void> _removeIdentity(SavedIdentity identity) async {
    final env = _currentEnv;
    if (env == null) return;
    await _identityStore.removeIdentity(env.name, identity.userId);
    if (!mounted) return;
    setState(() => _status = 'Removed "${identity.userId}".');
  }

  /// Clear the active identity for the current env (but keep it saved, so it
  /// can be re-selected). Also logs out of the SDK.
  Future<void> _logout() async {
    final env = _currentEnv;
    setState(() {
      _busy = true;
      _status = 'Logging out…';
    });
    await ZeroSettle.instance.logout();
    if (!mounted) return;
    if (env != null) await _identityStore.clearActive(env.name);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = 'Logged out — saved identities kept.';
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _currentEnv;
    final identities =
        current == null ? const <SavedIdentity>[] : _identityStore.identitiesFor(current.name);
    final active =
        current == null ? null : _identityStore.activeIdentityFor(current.name);

    return Scaffold(
      appBar: AppBar(title: const Text('Environment')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // --- Info ---
          Text(
            'Use this screen to test against different backends. Each '
            'environment keeps its own set of saved test users.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // --- Environment selector ---
          Text('Backend Environment', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (current == null)
            const CircularProgressIndicator()
          else
            EnvironmentPicker(
              current: current,
              enabled: !_busy,
              onChanged: _switchEnv,
            ),

          const Divider(height: 32),

          // --- Identity picker ---
          Text('Identity', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Current user_id: ${active?.userId ?? '— (not identified)'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          if (current != null && identities.isEmpty)
            Text(
              'No saved identities for ${current.displayName} yet — add one below.',
              style: theme.textTheme.bodySmall,
            )
          else
            ...identities.map((identity) {
              final isActive = identity.userId == active?.userId;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    isActive
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isActive ? theme.colorScheme.primary : null,
                  ),
                  title: Text(identity.displayName),
                  subtitle: Text(identity.userId),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove identity',
                    onPressed:
                        _busy ? null : () => _removeIdentity(identity),
                  ),
                  onTap: _busy ? null : () => _selectIdentity(identity),
                ),
              );
            }),

          const SizedBox(height: 8),

          // --- Add identity ---
          Text('Add Identity', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _userIdController,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'User ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Display name (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _addIdentity,
            child: const Text('Add & Identify'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _logout,
            child: const Text('Logout (keep saved identities)'),
          ),

          // --- Status ---
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_status, style: theme.textTheme.bodySmall),
          ],

          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
