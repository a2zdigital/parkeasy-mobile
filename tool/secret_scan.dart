// Fails when something that looks like a key, a credential or signing
// material is in a file git tracks (or is about to track).
//
//     dart run tool/secret_scan.dart
//
// It is a safety net, not a guarantee: rules are in
// docs/conventions/security.md. A key that was ever committed must be
// revoked, not just deleted.

import 'dart:io';

/// File names that must never be tracked, whatever they contain.
final _forbiddenNames = <RegExp>[
  RegExp(r'(^|/)google-services\.json$'),
  RegExp(r'(^|/)GoogleService-Info\.plist$'),
  RegExp(r'(^|/)firebase_options\.dart$'),
  RegExp(r'(^|/)(key|secrets)\.properties$'),
  RegExp(r'(^|/)Secrets\.xcconfig$'),
  RegExp(r'(^|/)service-account[^/]*\.json$'),
  RegExp(r'(^|/)\.env(\..+)?$'),
  RegExp(r'\.(jks|keystore|p8|p12|pem|mobileprovision)$'),
  RegExp(r'(^|/)env/(?!.*\.example\.json$)[^/]+\.json$'),
];

/// Text that looks like a real credential.
final _patterns = <String, RegExp>{
  'Google API key': RegExp(r'AIza[0-9A-Za-z_\-]{35}'),
  'Razorpay key': RegExp(r'rzp_(live|test)_[0-9A-Za-z]{12,}'),
  'private key block': RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
  'service-account private key': RegExp(r'"private_key"\s*:\s*"'),
  'AWS access key': RegExp(r'AKIA[0-9A-Z]{16}'),
  'Stripe-style live secret': RegExp(r'sk_live_[0-9A-Za-z]{16,}'),
  'GitHub token': RegExp(r'gh[pousr]_[0-9A-Za-z]{36,}'),
  'Slack token': RegExp(r'xox[abprs]-[0-9A-Za-z\-]{10,}'),
  'Firebase server key': RegExp(r'AAAA[0-9A-Za-z_\-]{7}:[0-9A-Za-z_\-]{140}'),
  'password in a Gradle or properties file': RegExp(
    r'''(storePassword|keyPassword)\s*[=:]\s*["']?[^\s"'$]{4,}''',
  ),
};

const _binary = {
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'ico',
  'ttf',
  'otf',
  'jar',
};

void main() {
  // Tracked files plus new files that are not git-ignored.
  final listing = Process.runSync('git', [
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
  ]);
  if (listing.exitCode != 0) {
    stderr.writeln('secret_scan: not a git repository.');
    exit(2);
  }

  final problems = <String>[];
  final files = (listing.stdout as String)
      .split('\n')
      .where((path) => path.isNotEmpty);

  for (final path in files) {
    if (_forbiddenNames.any((name) => name.hasMatch(path))) {
      problems.add('$path: this kind of file must never be committed.');
      continue;
    }
    if (path == 'tool/secret_scan.dart') continue;
    if (_binary.contains(path.split('.').last.toLowerCase())) continue;

    final file = File(path);
    if (!file.existsSync() || file.lengthSync() > 2 * 1024 * 1024) continue;

    final String content;
    try {
      content = file.readAsStringSync();
    } on FileSystemException {
      continue; // Not text.
    }

    _patterns.forEach((label, pattern) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final line = '\n'.allMatches(content.substring(0, match.start)).length;
        // The value itself is never printed.
        problems.add('$path:${line + 1}: looks like a $label.');
      }
    });
  }

  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    stderr.writeln(
      '\nRemove it, and revoke the key if it was ever pushed. '
      'See docs/conventions/security.md.',
    );
    exit(1);
  }
  stdout.writeln('No keys or credentials found in tracked files.');
}
