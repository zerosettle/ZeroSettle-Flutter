import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/inherited_just_one.dart';
import '../../data/database.dart';

const _emojiChoices = <String>[
  '📖', '🚶', '💧', '🧘', '🏋️', '✍️', '🥦', '😴', '🎯', '🦷', '💊', '🌱',
];

const _colorChoices = <int>[
  0xFF6CA358, // brand green
  0xFF3B82F6, // blue
  0xFFEF4444, // red
  0xFFF59E0B, // amber
  0xFFA855F7, // purple
  0xFF14B8A6, // teal
];

/// Form to create a new habit — name, emoji, and colour. On save, inserts
/// via [HabitDao.insertHabit] and pops back to the previous screen.
class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});
  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _controller = TextEditingController();
  String _emoji = _emojiChoices.first;
  int _color = _colorChoices.first;
  bool _saving = false;

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

  bool get _canSave => !_saving && _controller.text.trim().isNotEmpty;

  Future<void> _save() async {
    final dao = InheritedJustOne.of(context).db.habitDao;
    setState(() => _saving = true);
    try {
      await dao.insertHabit(HabitsCompanion.insert(
        name: _controller.text.trim(),
        emoji: _emoji,
        colorValue: _color,
      ));
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New habit')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Emoji', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _emojiChoices.map((e) {
                  final selected = e == _emoji;
                  return ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 20)),
                    selected: selected,
                    onSelected: (_) => setState(() => _emoji = e),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Colour', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorChoices.map((c) {
                  final selected = c == _color;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
