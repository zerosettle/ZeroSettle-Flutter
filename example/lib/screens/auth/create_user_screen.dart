import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../app/routes.dart';

/// First-launch onboarding. Captures a display name, identifies the user
/// to ZeroSettle, persists it to [UserPrefs], and routes to [Routes.home].
class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      !_submitting && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
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
      final prefs = InheritedJustOne.of(context).prefs;
      await prefs.setUserId(id);
      await prefs.setDisplayName(name);
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
                    enabled: !_submitting,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _canSubmit ? _submit() : null,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: _submitting
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
