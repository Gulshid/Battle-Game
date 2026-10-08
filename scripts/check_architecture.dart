// Fails CI if a package imports something it must not.
import 'dart:io';

const forbiddenImports = <String, List<String>>{
  'packages/game_core': [
    'package:flutter',
    'dart:ui',
    'dart:io',
    'dart:isolate',
    'package:flame',
    'package:game_server',
    'package:protocol',
  ],
  'packages/protocol': ['package:flutter', 'dart:ui', 'package:flame'],
  'packages/game_data': ['package:flutter', 'dart:ui', 'package:flame'],
  'apps/game_server': ['package:flutter', 'dart:ui', 'package:flame'],
};

// Nondeterministic APIs banned inside the simulation package.
const forbiddenInCore = ['DateTime.now', 'Stopwatch(', 'Random()'];

void main() {
  var violations = 0;
  forbiddenImports.forEach((dir, bad) {
    final d = Directory(dir);
    if (!d.existsSync()) return;
    for (final f in d.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].trim();
        final isImport = l.startsWith('import') || l.startsWith('export');
        if (isImport) {
          for (final b in bad) {
            if (l.contains(b)) {
              stderr.writeln('${f.path}:${i + 1} forbidden import: $b');
              violations++;
            }
          }
        }
        if (dir == 'packages/game_core' && !l.startsWith('//')) {
          for (final b in forbiddenInCore) {
            if (l.contains(b)) {
              stderr.writeln('${f.path}:${i + 1} nondeterministic API: $b');
              violations++;
            }
          }
        }
      }
    }
  });
  if (violations > 0) exit(1);
  stdout.writeln('Architecture OK');
}
