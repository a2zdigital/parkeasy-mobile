import 'dart:math' as math;

import 'package:app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2 contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const c = AppColors.light;

  // Every pair the design system allows for text. If a token changes and a
  // pair drops below 4.5 to 1, this fails before a reviewer has to notice.
  final textPairs = <String, (Color, Color)>{
    'onPrimary on primary': (c.onPrimary, c.primary),
    'onPrimary on primaryPressed': (c.onPrimary, c.primaryPressed),
    'onNavy on brandNavy': (c.onNavy, c.brandNavy),
    'primary on surface': (c.primary, c.surface),
    'primary on canvas': (c.primary, c.canvas),
    'primaryPressed on primaryContainer': (
      c.primaryPressed,
      c.primaryContainer,
    ),
    'textPrimary on surface': (c.textPrimary, c.surface),
    'textPrimary on canvas': (c.textPrimary, c.canvas),
    'textSecondary on surface': (c.textSecondary, c.surface),
    'textSecondary on canvas': (c.textSecondary, c.canvas),
    'textSecondary on surfaceSubtle': (c.textSecondary, c.surfaceSubtle),
    'onPrimary on success': (c.onPrimary, c.success.solid),
    'onPrimary on danger': (c.onPrimary, c.danger.solid),
    for (final tone in StatusTone.values)
      '${tone.name} strong on container': (
        c.tone(tone).strong,
        c.tone(tone).container,
      ),
    for (final tone in [
      StatusTone.success,
      StatusTone.warning,
      StatusTone.danger,
      StatusTone.info,
      StatusTone.neutral,
    ])
      '${tone.name} solid on surface': (c.tone(tone).solid, c.surface),
  };

  for (final entry in textPairs.entries) {
    test('${entry.key} meets 4.5 to 1', () {
      final (foreground, background) = entry.value;

      expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
    });
  }

  test('a control outline meets 3 to 1 on a surface', () {
    expect(contrast(c.borderControl, c.surface), greaterThanOrEqualTo(3));
  });

  test('teal is documented as unfit for text on light surfaces', () {
    // If this ever passes 4.5 the rule in tokens.md can be relaxed.
    expect(contrast(c.accentTeal, c.surface), lessThan(4.5));
    expect(contrast(c.available.solid, c.surface), lessThan(4.5));
  });

  test('every tone resolves', () {
    for (final tone in StatusTone.values) {
      expect(c.tone(tone).container, isNot(c.tone(tone).strong));
    }
  });
}
