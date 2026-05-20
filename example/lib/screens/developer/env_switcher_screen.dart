import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../iap_environment.dart';

/// Developer tool: pick a backend environment and re-identify.
///
/// Mirrors [EnvSwitcherScreen.kt] from the JustOne Android sample.
/// State:
/// - current [IAPEnvironment] selection (persisted)
/// - user-id / name text fields for re-identify
class EnvSwitcherScreen extends StatefulWidget {
  const EnvSwitcherScreen({super.key});

  @override
  State<EnvSwitcherScreen> createState() => _EnvSwitcherScreenState();
}

class _EnvSwitcherScreenState extends State<EnvSwitcherScreen> {
  // Loaded async; null means still loading.
  IAPEnvironment? _currentEnv;

  final _userIdController = TextEditingController();
  final _nameController = TextEditingController(text: 'Sample User');

  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    final env = await IAPEnvironment.load();
    if (mounted) setState(() => _currentEnv = env);
  }

  Future<void> _switchEnv(IAPEnvironment env) async {
    // Capture the prefs ref before any awaits — used for auto-re-identify
    // after configure (mirrors main.dart's bootstrap sequence).
    final prefs = InheritedJustOne.of(context).prefs;
    setState(() {
      _currentEnv = env;
      _busy = true;
      _status = 'Switching to ${env.displayName}…';
    });
    await IAPEnvironment.save(env);
    await ZeroSettle.instance.logout();
    if (!mounted) return;
    await ZeroSettle.instance.setBaseUrlOverride(env.baseUrlOverride);
    if (!mounted) return;
    await ZeroSettle.instance.configure(publishableKey: env.publishableKey);
    if (!mounted) return;

    // Re-identify from persisted prefs so the SDK is bootstrapped against the
    // new env without forcing a manual re-identify — mirrors main.dart.
    final persistedId = prefs.userId;
    final persistedName = prefs.displayName;
    if (persistedId != null && persistedId.isNotEmpty) {
      try {
        await ZeroSettle.instance.identify(
          Identity.user(id: persistedId, name: persistedName),
        );
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = 'Switched to ${env.displayName}\n${env.effectiveUrl}\n'
              'Re-identified as "$persistedId" ✓';
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = 'Switched to ${env.displayName}\n${env.effectiveUrl}\n'
              're-identify failed: $e';
        });
        return;
      }
    }

    setState(() {
      _busy = false;
      _status = 'Switched to ${env.displayName}\n${env.effectiveUrl}\n(re-identify below)';
    });
  }

  Future<void> _identify() async {
    final id = _userIdController.text.trim();
    if (id.isEmpty) return;
    final name = _nameController.text.trim();
    setState(() {
      _busy = true;
      _status = 'Identifying…';
    });
    try {
      await ZeroSettle.instance.identify(
        Identity.user(id: id, name: name.isNotEmpty ? name : null),
      );
      if (!mounted) return;
      final prefs = InheritedJustOne.of(context).prefs;
      await prefs.setUserId(id);
      if (!mounted) return;
      if (name.isNotEmpty) await prefs.setDisplayName(name);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Identified as "$id" ✓';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'identify() failed: $e';
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _busy = true;
      _status = 'Logging out…';
    });
    await ZeroSettle.instance.logout();
    if (!mounted) return;
    final prefs = InheritedJustOne.of(context).prefs;
    await prefs.clearAll();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = 'Logged out.';
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
    final envs = IAPEnvironment.values.where((e) => e.isEnabled).toList();
    final current = _currentEnv;

    return Scaffold(
      appBar: AppBar(title: const Text('Environment')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // --- Info ---
          Text(
            'Use this screen to test against different backends. '
            'Switching environment logs out the current user.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),

          // --- Environment selector ---
          Text('Backend Environment',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (current == null)
            const CircularProgressIndicator()
          else ...[
            ...envs.map(
              (env) => ListTile(
                leading: Icon(
                  env == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: env == current
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(env.displayName),
                subtitle: Text(env.effectiveUrl,
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: _busy ? null : () => _switchEnv(env),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],

          const Divider(height: 32),

          // --- Identify form ---
          Text('Identify User',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'User ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _identify,
            child: const Text('Identify as User'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _logout,
            child: const Text('Logout (clear identity)'),
          ),

          // --- Status ---
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
