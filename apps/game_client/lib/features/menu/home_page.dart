import 'package:flutter/material.dart';
import 'package:game_client/features/match/render/palette.dart';
import 'package:game_data/game_data.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _classes = loadGameConfig().classes.take(3).toList();
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BATTLE GAME',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final c in _classes)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: _selected == c.id,
                        selectedColor: classAccent(c.id).withValues(alpha: 0.5),
                        onSelected: (_) => setState(() => _selected = c.id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_describe(_selected),
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      context.go('/match?mode=arena&class=$_selected'),
                  child: const Text('Arena: you vs 3 bots'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () =>
                      context.go('/match?mode=training&class=$_selected'),
                  child: const Text('Training arena'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'WASD move  Space attack  Q / E abilities  Shift dash\n'
                  'F3 debug  F4 verify replay',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      );

  String _describe(int id) {
    final c = _classes[id];
    return '${c.maxHp} HP  -  ${c.abilities.map((a) => a.id).join(', ')}';
  }
}
