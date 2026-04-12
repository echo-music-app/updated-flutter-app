import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/core/themes/app_colors.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';
import 'package:mobile/ui/core/themes/app_theme.dart';
import 'package:mobile/ui/core/themes/app_typography.dart';

void main() {
  test('AppTheme.light has non-null primaryColor', () {
    expect(AppTheme.light.primaryColor, isNotNull);
  });

  test('AppTheme.dark has non-null primaryColor', () {
    expect(AppTheme.dark.primaryColor, isNotNull);
  });

  test('AppColors constants are defined and non-null', () {
    expect(AppColors.primary, isNotNull);
    expect(AppColors.onPrimary, isNotNull);
    expect(AppColors.surface, isNotNull);
    expect(AppColors.onSurface, isNotNull);
    expect(AppColors.error, isNotNull);
    expect(AppColors.onError, isNotNull);
  });

  test('AppTypography constants are defined and non-null', () {
    expect(AppTypography.headlineLarge, isNotNull);
    expect(AppTypography.headlineMedium, isNotNull);
    expect(AppTypography.bodyLarge, isNotNull);
    expect(AppTypography.bodyMedium, isNotNull);
    expect(AppTypography.labelLarge, isNotNull);
  });

  test('AppSpacing constants are defined and non-null', () {
    expect(AppSpacing.xs, isNotNull);
    expect(AppSpacing.sm, isNotNull);
    expect(AppSpacing.md, isNotNull);
    expect(AppSpacing.lg, isNotNull);
    expect(AppSpacing.xl, isNotNull);
  });
}
