import 'package:flutter_test/flutter_test.dart';

import 'package:ilm_mode/core/theme/app_theme.dart';

void main() {
  // The full app boots Supabase and downloads fonts, neither of which is
  // available in unit tests, so this covers what can run offline.
  test('AppColors follow the dark flag', () {
    AppColors.isDark = false;
    final lightSurface = AppColors.surface;
    final lightText = AppColors.textPrimary;
    final lightSoft = AppColors.orangeSoft;

    AppColors.isDark = true;
    expect(AppColors.surface, isNot(lightSurface));
    expect(AppColors.textPrimary, isNot(lightText));
    expect(AppColors.orangeSoft, isNot(lightSoft));

    AppColors.isDark = false;
    expect(AppColors.surface, lightSurface);
  });
}
