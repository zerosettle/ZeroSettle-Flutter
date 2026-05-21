import 'package:flutter/material.dart';

import '../app_environment.dart';

/// A segmented control for choosing the backend [AppEnvironment].
///
/// Shared by the create-user screen and the developer environment screen so
/// there is a single env picker, not two. Stateless — the parent owns the
/// current selection and reacts to [onChanged].
class EnvironmentPicker extends StatelessWidget {
  const EnvironmentPicker({
    super.key,
    required this.current,
    required this.onChanged,
    this.enabled = true,
  });

  /// The currently selected environment.
  final AppEnvironment current;

  /// Called when the user picks a different environment.
  final ValueChanged<AppEnvironment> onChanged;

  /// When `false`, the control is shown but not interactive (e.g. while a
  /// switch is already in flight).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppEnvironment>(
      segments: [
        for (final env in AppEnvironment.values)
          ButtonSegment<AppEnvironment>(
            value: env,
            label: Text(env.displayName),
          ),
      ],
      selected: {current},
      showSelectedIcon: false,
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
    );
  }
}
