// Embeds packages/game_data/data/*.json into a Dart file so every platform
// (Flutter client, Dart server, web, tests) reads exactly the same data.
//
//   dart run scripts/gen_game_data.dart          rewrite the generated file
//   dart run scripts/gen_game_data.dart --check  fail if it is out of date
import 'dart:convert';
import 'dart:io';

const _dataDir = 'packages/game_data/data';
const _outFile = 'packages/game_data/lib/src/generated/game_data_json.dart';

String _embed(String constName, String file) {
  final text = File('$_dataDir/$file').readAsStringSync();
  jsonDecode(text); // fail early on invalid JSON
  if (text.contains("'''")) {
    throw StateError("$file must not contain the sequence '''");
  }
  return "const String $constName = r'''\n${text.trimRight()}\n''';\n";
}

void main(List<String> args) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT.')
    ..writeln('// Source: packages/game_data/data/*.json')
    ..writeln('// Regenerate: dart run scripts/gen_game_data.dart')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln(_embed('kAbilitiesJson', 'abilities.json'))
    ..write(_embed('kClassesJson', 'classes.json'));
  final text = out.toString();
  final file = File(_outFile);
  if (args.contains('--check')) {
    final current = file.existsSync() ? file.readAsStringSync() : '';
    if (current != text) {
      stderr.writeln('$_outFile is out of date. Run: '
          'dart run scripts/gen_game_data.dart');
      exit(1);
    }
    stdout.writeln('game data up to date');
    return;
  }
  file.createSync(recursive: true);
  file.writeAsStringSync(text);
  stdout.writeln('wrote $_outFile');
}
