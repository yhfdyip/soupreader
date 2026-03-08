enum ReaderLegacyQuickAction {
  searchContent,
  autoPage,
  replaceRule,
  toggleDayNightTheme,
  addBookmark,
  readAloud,
}

class ReaderLegacyQuickActionHelper {
  const ReaderLegacyQuickActionHelper._();

  static const List<ReaderLegacyQuickAction> legacyOrder = [
    ReaderLegacyQuickAction.searchContent,
    ReaderLegacyQuickAction.autoPage,
    ReaderLegacyQuickAction.replaceRule,
    ReaderLegacyQuickAction.toggleDayNightTheme,
    ReaderLegacyQuickAction.addBookmark,
    ReaderLegacyQuickAction.readAloud,
  ];
}
