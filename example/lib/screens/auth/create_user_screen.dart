import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../app/routes.dart';
import '../../app_environment.dart';
import '../../data/identity_store.dart';
import '../../widgets/environment_picker.dart';

/// First-launch onboarding. Captures a display name, identifies the user
/// to ZeroSettle, persists it to [UserPrefs], and routes to [Routes.home].
///
/// The backend [AppEnvironment] is selectable here via a segmented control,
/// so the developer can point the app at local / staging / prod before the
/// first `identify()` call.
class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  bool _switchingEnv = false;
  String? _error;

  /// Loaded async; null while the persisted env is still resolving.
  AppEnvironment? _env;

  bool get _canSubmit =>
      !_submitting &&
      !_switchingEnv &&
      _env != null &&
      _env!.hasKey &&
      _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    final env = await AppEnvironment.load();
    if (mounted) setState(() => _env = env);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Switch the backend environment. Re-points the SDK so the subsequent
  /// `identify()` on "Continue" hits the chosen backend.
  Future<void> _onEnvChanged(AppEnvironment env) async {
    setState(() {
      _env = env;
      _switchingEnv = true;
      _error = null;
    });
    try {
      await applyEnvironment(env);
    } catch (e) {
      if (mounted) setState(() => _error = 'Environment switch failed: $e');
    } finally {
      if (mounted) setState(() => _switchingEnv = false);
    }
  }

  Future<void> _submit() async {
    final env = _env;
    final name = _controller.text.trim();
    if (name.isEmpty || env == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final id = 'u_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await ZeroSettle.instance.identify(
        Identity.user(id: id, name: name),
      );
      if (!mounted) return;
      // Persist the new user as a reusable, labeled identity for this env
      // and mark it active — so a later logout / re-onboard never strands it.
      final identityStore = InheritedJustOne.of(context).identityStore;
      final identity = SavedIdentity(userId: id, displayName: name);
      await identityStore.upsertIdentity(env.name, identity);
      await identityStore.setActive(env.name, id);
      if (!mounted) return;
      context.go(Routes.home);
    } catch (e) {
      setState(() {
        _error = 'Could not start: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = _env;
    final busy = _submitting || _switchingEnv;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('JustOne',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('What should we call you?',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    enabled: !busy,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _canSubmit ? _submit() : null,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Backend environment selector. Switching re-points the SDK
                  // so the `identify()` on Continue hits the chosen backend.
                  if (env != null)
                    EnvironmentPicker(
                      current: env,
                      enabled: !busy,
                      onChanged: _onEnvChanged,
                    ),
                  if (env != null && !env.hasKey) ...[
                    const SizedBox(height: 8),
                    Text(
                      'No publishable key configured for ${env.displayName} '
                      'yet — pick another environment to continue.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
