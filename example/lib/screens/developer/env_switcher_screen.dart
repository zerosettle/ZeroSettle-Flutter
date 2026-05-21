import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../app_environment.dart';
import '../../widgets/environment_picker.dart';

/// Developer tool: pick a backend environment and re-identify.
///
/// Mirrors [EnvSwitcherScreen.kt] from the JustOne Android sample.
/// State:
/// - current [AppEnvironment] selection (persisted)
/// - user-id / name text fields for re-identify
class EnvSwitcherScreen extends StatefulWidget {
  const EnvSwitcherScreen({super.key});

  @override
  State<EnvSwitcherScreen> createState() => _EnvSwitcherScreenState();
}

class _EnvSwitcherScreenState extends State<EnvSwitcherScreen> {
  // Loaded async; null means still loading.
  AppEnvironment? _currentEnv;

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
    final env = await AppEnvironment.load();
    if (mounted) setState(() => _currentEnv = env);
  }

  Future<void> _switchEnv(AppEnvironment env) async {
    // Capture the prefs ref before any awaits — used for auto-re-identify
    // after configure (mirrors main.dart's bootstrap sequence).
    final prefs = InheritedJustOne.of(context).prefs;
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
          _status = 'Switched to ${env.displayName}\n${env.baseUrl}\n'
              'Re-identified as "$persistedId" ✓';
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = 'Switched to ${env.displayName}\n${env.baseUrl}\n'
              're-identify failed: $e';
        });
        return;
      }
    }

    setState(() {
      _busy = false;
      _status = 'Switched to ${env.displayName}\n${env.baseUrl}\n(re-identify below)';
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
          else
            EnvironmentPicker(
              current: current,
              enabled: !_busy,
              onChanged: _switchEnv,
            ),

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
