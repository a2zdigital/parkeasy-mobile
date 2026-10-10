// Runs every check CI runs: app name, format, code generation, analysis, tests.
//
//     dart run tool/check.dart
//
// Written in Dart so it works the same on Windows, macOS and Linux.

import 'dart:io';

Future<void> main() async {
  final steps = <(String, String, List<String>)>[
    ('App name', 'dart', ['run', 'tool/app_identity.dart', '--check']),
    (
      'Format',
      'dart',
      [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        'lib',
        'test',
        'tool',
      ],
    ),
    (
      'Generate',
      'dart',
      ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    ),
    ('Analyse', 'flutter', ['analyze', '--fatal-infos']),
    ('Test', 'flutter', ['test']),
  ];

  for (final (name, command, arguments) in steps) {
    stdout.writeln('\n== $name: $command ${arguments.join(' ')}');
    final process = await Process.start(
      command,
      arguments,
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );
    final code = await process.exitCode;
    if (code != 0) {
      stderr.writeln('\n$name failed.');
      exit(code);
    }
  }

  stdout.writeln('\nAll checks passed.');
}
