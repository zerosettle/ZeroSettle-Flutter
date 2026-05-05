import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Bottom sheet shown on first launch (and from Settings) to let the user pick
/// an identity mode. Mirrors the three [Identity] variants supported by 1.3.0:
///
/// - [Identity.user] — sign in with an explicit ID (and optional name/email).
/// - [Identity.anonymous] — generates a stable session UUID.
/// - [Identity.deferred] — defers identification until later.
///
/// Returns the chosen [Identity], or `null` if the user dismisses the sheet.
class IdentityChoiceSheet extends StatefulWidget {
  /// Show as a modal bottom sheet. The sheet is dismissible only when an
  /// existing identity is being changed (i.e., from Settings). On first
  /// launch the caller passes `dismissible: false` to force a choice.
  static Future<Identity?> show(
    BuildContext context, {
    bool dismissible = true,
    Identity? current,
  }) {
    return showModalBottomSheet<Identity>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      showDragHandle: dismissible,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: IdentityChoiceSheet(current: current),
      ),
    );
  }

  /// The identity currently in use, if any. Used to label the sheet.
  final Identity? current;

  const IdentityChoiceSheet({super.key, this.current});

  @override
  State<IdentityChoiceSheet> createState() => _IdentityChoiceSheetState();
}

class _IdentityChoiceSheetState extends State<IdentityChoiceSheet> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _showSignInForm = false;

  @override
  void initState() {
    super.initState();
    if (widget.current is IdentityUser) {
      final user = widget.current as IdentityUser;
      _idController.text = user.id;
      _nameController.text = user.name ?? '';
      _emailController.text = user.email ?? '';
      _showSignInForm = true;
    }
    _idController.addListener(_onIdChanged);
  }

  void _onIdChanged() => setState(() {});

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.current == null ? 'Welcome to ZeroSettle' : 'Switch Identity',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how you would like to identify with the SDK. You can change this any time in Settings.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (_showSignInForm) ..._buildSignInForm(context) else ..._buildChoices(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChoices(BuildContext context) {
    return [
      _OptionCard(
        icon: Icons.person_outline,
        title: 'Sign In',
        subtitle: 'Identify with your app user ID. Required for purchase history and transfers.',
        onTap: () => setState(() => _showSignInForm = true),
      ),
      const SizedBox(height: 12),
      _OptionCard(
        icon: Icons.visibility_off_outlined,
        title: 'Continue as Guest',
        subtitle: 'The SDK generates a stable anonymous session ID. You can sign in later.',
        onTap: () => Navigator.of(context).pop(const Identity.anonymous()),
      ),
      const SizedBox(height: 12),
      _OptionCard(
        icon: Icons.schedule_outlined,
        title: 'Decide Later',
        subtitle: 'Defer identification. The SDK suppresses the "no user" warning until you choose.',
        onTap: () => Navigator.of(context).pop(const Identity.deferred()),
      ),
    ];
  }

  List<Widget> _buildSignInForm(BuildContext context) {
    return [
      TextField(
        controller: _idController,
        decoration: const InputDecoration(
          labelText: 'User ID *',
          hintText: 'e.g. user_abc123',
          border: OutlineInputBorder(),
        ),
        autocorrect: false,
        textCapitalization: TextCapitalization.none,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Name (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: 'Email (optional)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textCapitalization: TextCapitalization.none,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _showSignInForm = false),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _idController.text.trim().isEmpty
                  ? null
                  : () {
                      final id = _idController.text.trim();
                      final name = _nameController.text.trim();
                      final email = _emailController.text.trim();
                      Navigator.of(context).pop(Identity.user(
                        id: id,
                        name: name.isEmpty ? null : name,
                        email: email.isEmpty ? null : email,
                      ));
                    },
              child: const Text('Sign In'),
            ),
          ),
        ],
      ),
    ];
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
