import '../../bookshelf/models/book.dart';

/// 搜索输入帮助（书架匹配 + 历史词过滤）语义辅助。
class SearchInputHintHelper {
  const SearchInputHintHelper._();

  static String normalizeKeyword(String raw) {
    return raw.trim();
  }

  /// legado `SearchActivity.receiptIntent` 语义：
  /// - 传入 key 非空时，`setQuery(key, true)` 自动提交搜索；
  /// - 不依赖额外开关参数。
  static bool shouldAutoSubmitInitialKeyword({
    required String initialKeyword,
  }) {
    return normalizeKeyword(initialKeyword).isNotEmpty;
  }

  /// legado `SearchActivity.receiptIntent` 语义：
  /// - 传入 key 为空时，请求输入框焦点，进入可直接输入状态。
  static bool shouldRequestFocusOnOpen({
    required String initialKeyword,
  }) {
    return normalizeKeyword(initialKeyword).isEmpty;
  }

  static List<Book> filterBookshelfBooks(
    List<Book> books,
    String rawKeyword,
  ) {
    final keyword = normalizeKeyword(rawKeyword).toLowerCase();
    if (keyword.isEmpty) {
      return const <Book>[];
    }
    return books.where((book) {
      final title = book.title.toLowerCase();
      final author = book.author.toLowerCase();
      return title.contains(keyword) || author.contains(keyword);
    }).toList(growable: false);
  }

  static List<String> filterHistoryKeywords(
    List<String> historyKeywords,
    String rawKeyword,
  ) {
    final keyword = normalizeKeyword(rawKeyword).toLowerCase();
    if (keyword.isEmpty) {
      return historyKeywords;
    }
    return historyKeywords.where((item) {
      return item.toLowerCase().contains(keyword);
    }).toList(growable: false);
  }

  static bool hasExactBookTitle(
    List<Book> books,
    String rawKeyword,
  ) {
    final keyword = normalizeKeyword(rawKeyword);
    if (keyword.isEmpty) {
      return false;
    }
    for (final book in books) {
      if (book.title.trim() == keyword) {
        return true;
      }
    }
    return false;
  }

  static bool shouldSubmitHistoryKeyword({
    required String currentKeyword,
    required String selectedKeyword,
    required bool hasExactBookshelfTitle,
  }) {
    final current = normalizeKeyword(currentKeyword);
    final selected = normalizeKeyword(selectedKeyword);
    if (selected.isEmpty) {
      return false;
    }
    if (current == selected) {
      return true;
    }
    return !hasExactBookshelfTitle;
  }

  /// legado `SearchActivity.visibleInputHelp` 同义判定：
  /// - 搜索中始终隐藏；
  /// - 非搜索中，输入框有焦点时显示；
  /// - 无焦点时，仅当“已有结果且输入非空”才隐藏；
  /// - 其余场景显示（空输入、空结果等）。
  static bool shouldShowInputHelpPanel({
    required bool isSearching,
    required bool hasInputFocus,
    required int resultCount,
    required String currentKeyword,
  }) {
    if (isSearching) {
      return false;
    }
    if (hasInputFocus) {
      return true;
    }
    final keyword = normalizeKeyword(currentKeyword);
    return !(resultCount > 0 && keyword.isNotEmpty);
  }

  /// legado `SearchActivity` 在搜索范围变更后，仅当输入帮助层隐藏时才自动重搜：
  /// - `searchScope.stateLiveData` 回调里通过 `!llInputHelp.isVisible` 决定是否 `setQuery(..., true)`。
  /// - 因此这里复用同一输入帮助判定，保证触发时机同义。
  static bool shouldAutoSearchOnScopeChanged({
    required bool isSearching,
    required bool hasInputFocus,
    required int resultCount,
    required String currentKeyword,
  }) {
    final keyword = normalizeKeyword(currentKeyword);
    if (keyword.isEmpty) {
      return false;
    }
    return !shouldShowInputHelpPanel(
      isSearching: isSearching,
      hasInputFocus: hasInputFocus,
      resultCount: resultCount,
      currentKeyword: keyword,
    );
  }

  /// legado `SearchActivity.finish` 语义：
  /// - 返回时若搜索输入框仍有焦点，则先清除焦点并阻止页面退出；
  /// - 仅在无焦点时允许真正返回。
  static bool shouldConsumeBackToClearFocus({
    required bool hasInputFocus,
  }) {
    return hasInputFocus;
  }
}
