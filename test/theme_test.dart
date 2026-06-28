import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sanket/theme/app_theme.dart';

void main() {
  test('buildTheme creates a Material 3 theme for Sanket', () {
    final theme = AppTheme.buildTheme();

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, isNotNull);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F9FC));
  });
}
