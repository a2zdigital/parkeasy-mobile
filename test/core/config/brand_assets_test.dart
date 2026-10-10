import 'dart:io';

import 'package:app/core/config/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every brand asset exists under its agreed name', () {
    for (final path in BrandAssets.all) {
      expect(File(path).existsSync(), isTrue, reason: '$path is missing');
    }
  });

  test('the asset folder is declared in pubspec.yaml', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/brand/'),
    );
  });
}
