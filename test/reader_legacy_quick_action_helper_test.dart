import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/app/theme/colors.dart';
import 'package:soupreader/features/reader/services/reader_legacy_quick_action_helper.dart';

void main() {
  group('ReaderLegacyQuickActionHelper', () {
    test('legacyOrder 与 legado 四按钮顺序一致', () {
      expect(
        ReaderLegacyQuickActionHelper.legacyOrder,
        const [
          ReaderLegacyQuickAction.searchContent,
          ReaderLegacyQuickAction.autoPage,
          ReaderLegacyQuickAction.replaceRule,
          ReaderLegacyQuickAction.toggleDayNightTheme,
        ],
      );
    });

    test('resolveToggleThemeIndex 会切换到相反明暗主题', () {
      final themes = AppColors.readingThemes;
      final lightIndex = themes.indexWhere((theme) => !theme.isDark);
      final darkIndex = themes.indexWhere((theme) => theme.isDark);
      expect(lightIndex, isNonNegative);
      expect(darkIndex, isNonNegative);

      final toDark = ReaderLegacyQuickActionHelper.resolveToggleThemeIndex(
        currentIndex: lightIndex,
        themes: themes,
      );
      expect(themes[toDark].isDark, isTrue);

      final toLight = ReaderLegacyQuickActionHelper.resolveToggleThemeIndex(
        currentIndex: darkIndex,
        themes: themes,
      );
      expect(themes[toLight].isDark, isFalse);
    });

    test('resolveToggleThemeIndex 可处理越界与空主题列表', () {
      final themes = AppColors.readingThemes;
      final resolvedFromOutOfRange =
          ReaderLegacyQuickActionHelper.resolveToggleThemeIndex(
        currentIndex: 999,
        themes: themes,
      );
      expect(resolvedFromOutOfRange, inInclusiveRange(0, themes.length - 1));

      final keepCurrentWhenEmpty =
          ReaderLegacyQuickActionHelper.resolveToggleThemeIndex(
        currentIndex: 3,
        themes: const [],
      );
      expect(keepCurrentWhenEmpty, 3);
    });
  });
}
