import 'settings_service_context.dart';
import 'settings_service_keys.dart';

mixin SettingsServiceBookPrimaryMixin on SettingsServiceContext {
  bool getBookCanUpdate(String bookId, {bool fallback = true}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return bookCanUpdateState[key] ?? fallback;
  }

  Future<void> saveBooksCanUpdate(
      Iterable<String> bookIds, bool canUpdate) async {
    if (!isInitializedState) return;
    final normalizedIds = <String>{};
    for (final rawId in bookIds) {
      final key = rawId.trim();
      if (key.isEmpty) continue;
      normalizedIds.add(key);
    }
    if (normalizedIds.isEmpty) return;
    final nextMap = Map<String, bool>.from(bookCanUpdateState);
    for (final id in normalizedIds) {
      nextMap[id] = canUpdate;
    }
    bookCanUpdateState = nextMap;
    await persistBoolMap(settingsKeyBookCanUpdateMap, bookCanUpdateState);
  }

  Future<void> saveBookCanUpdate(String bookId, bool canUpdate) async {
    await saveBooksCanUpdate(<String>[bookId], canUpdate);
  }

  bool getBookSplitLongChapter(String bookId, {bool fallback = true}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return bookSplitLongChapterState[key] ?? fallback;
  }

  Future<void> saveBookSplitLongChapter(
    String bookId,
    bool splitLongChapter,
  ) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    bookSplitLongChapterState = Map<String, bool>.from(bookSplitLongChapterState)
      ..[key] = splitLongChapter;
    await persistBoolMap(
      settingsKeyBookSplitLongChapterMap,
      bookSplitLongChapterState,
    );
  }

  String? getBookTxtTocRule(String bookId) {
    if (!isInitializedState) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = bookTxtTocRuleState[key];
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  Future<void> saveBookTxtTocRule(String bookId, String? tocRuleRegex) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final normalized = (tocRuleRegex ?? '').trim();
    final nextMap = Map<String, String>.from(bookTxtTocRuleState);
    if (normalized.isEmpty) {
      nextMap.remove(key);
    } else {
      nextMap[key] = normalized;
    }
    bookTxtTocRuleState = nextMap;
    await persistStringMap(settingsKeyBookTxtTocRuleMap, bookTxtTocRuleState);
  }

  bool getBookUseReplaceRule(String bookId, {bool fallback = true}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return bookUseReplaceRuleState[key] ?? fallback;
  }

  Future<void> saveBookUseReplaceRule(
    String bookId,
    bool useReplaceRule,
  ) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    bookUseReplaceRuleState = Map<String, bool>.from(bookUseReplaceRuleState)
      ..[key] = useReplaceRule;
    await persistBoolMap(
      settingsKeyBookUseReplaceRuleMap,
      bookUseReplaceRuleState,
    );
  }

  int? getBookPageAnim(String bookId) {
    if (!isInitializedState) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = bookPageAnimState[key];
    if (value == null) return null;
    if (value < 0 || value > 4) return null;
    return value;
  }

  Future<void> saveBookPageAnim(String bookId, int? pageAnim) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final nextMap = Map<String, int>.from(bookPageAnimState);
    if (pageAnim == null) {
      nextMap.remove(key);
    } else {
      final normalized = pageAnim.clamp(0, 4).toInt();
      nextMap[key] = normalized;
    }
    bookPageAnimState = nextMap;
    await persistIntMap(settingsKeyBookPageAnimMap, bookPageAnimState);
  }

  bool getBookReSegment(String bookId, {bool fallback = false}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return bookReSegmentState[key] ?? fallback;
  }

  Future<void> saveBookReSegment(String bookId, bool enabled) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    bookReSegmentState = Map<String, bool>.from(bookReSegmentState)
      ..[key] = enabled;
    await persistBoolMap(settingsKeyBookReSegmentMap, bookReSegmentState);
  }

  String getBookImageStyle(
    String bookId, {
    String fallback = settingsDefaultImageStyle,
  }) {
    if (!isInitializedState) return _normalizeImageStyle(fallback);
    final key = bookId.trim();
    if (key.isEmpty) return _normalizeImageStyle(fallback);
    final value = bookImageStyleState[key];
    if (value == null || value.trim().isEmpty) {
      return _normalizeImageStyle(fallback);
    }
    return _normalizeImageStyle(value);
  }

  Future<void> saveBookImageStyle(String bookId, String style) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final normalized = _normalizeImageStyle(style);
    bookImageStyleState = Map<String, String>.from(bookImageStyleState)
      ..[key] = normalized;
    await persistStringMap(settingsKeyBookImageStyleMap, bookImageStyleState);
  }

  String _normalizeImageStyle(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (settingsValidImageStyles.contains(normalized)) {
      return normalized;
    }
    return settingsDefaultImageStyle;
  }

  String? _chapterSameTitleRemovedKey(String bookId, String chapterId) {
    final safeBookId = bookId.trim();
    final safeChapterId = chapterId.trim();
    if (safeBookId.isEmpty || safeChapterId.isEmpty) return null;
    return '$safeBookId::$safeChapterId';
  }

  bool getChapterSameTitleRemoved(
    String bookId,
    String chapterId, {
    bool fallback = false,
  }) {
    if (!isInitializedState) return fallback;
    final key = _chapterSameTitleRemovedKey(bookId, chapterId);
    if (key == null) return fallback;
    return chapterSameTitleRemovedState[key] ?? fallback;
  }

  Future<void> saveChapterSameTitleRemoved(
    String bookId,
    String chapterId,
    bool removed,
  ) async {
    if (!isInitializedState) return;
    final key = _chapterSameTitleRemovedKey(bookId, chapterId);
    if (key == null) return;
    chapterSameTitleRemovedState = Map<String, bool>.from(
      chapterSameTitleRemovedState,
    )..[key] = removed;
    await persistBoolMap(
      settingsKeyChapterSameTitleRemovedMap,
      chapterSameTitleRemovedState,
    );
  }

  bool getBookDelRubyTag(String bookId, {bool fallback = false}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return bookDelRubyTagState[key] ?? fallback;
  }

  Future<void> saveBookDelRubyTag(String bookId, bool enabled) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    bookDelRubyTagState = Map<String, bool>.from(bookDelRubyTagState)
      ..[key] = enabled;
    await persistBoolMap(settingsKeyBookDelRubyTagMap, bookDelRubyTagState);
  }

  bool getBookDelHTag(String bookId, {bool fallback = false}) {
    if (!isInitializedState) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return bookDelHTagState[key] ?? fallback;
  }

  Future<void> saveBookDelHTag(String bookId, bool enabled) async {
    if (!isInitializedState) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    bookDelHTagState = Map<String, bool>.from(bookDelHTagState)..[key] = enabled;
    await persistBoolMap(settingsKeyBookDelHTagMap, bookDelHTagState);
  }
}
