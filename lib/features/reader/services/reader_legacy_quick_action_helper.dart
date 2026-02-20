import '../../../app/theme/colors.dart';

enum ReaderLegacyQuickAction {
  searchContent,
  autoPage,
  replaceRule,
  toggleDayNightTheme,
}

class ReaderLegacyQuickActionHelper {
  const ReaderLegacyQuickActionHelper._();

  static const List<ReaderLegacyQuickAction> legacyOrder = [
    ReaderLegacyQuickAction.searchContent,
    ReaderLegacyQuickAction.autoPage,
    ReaderLegacyQuickAction.replaceRule,
    ReaderLegacyQuickAction.toggleDayNightTheme,
  ];

  static int resolveToggleThemeIndex({
    required int currentIndex,
    required List<ReadingThemeColors> themes,
  }) {
    if (themes.isEmpty) return currentIndex;
    final safeCurrentIndex =
        currentIndex >= 0 && currentIndex < themes.length ? currentIndex : 0;
    final currentIsDark = themes[safeCurrentIndex].isDark;
    final targetIndex = themes.indexWhere(
      (theme) => currentIsDark ? !theme.isDark : theme.isDark,
    );
    if (targetIndex >= 0) {
      return targetIndex;
    }
    return safeCurrentIndex;
  }
}
