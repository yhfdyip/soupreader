import 'settings_service_context.dart';

mixin SettingsServiceReaderProgressMixin on SettingsServiceContext {
  String _scrollOffsetKey(String bookId, {int? chapterIndex}) {
    if (chapterIndex == null) {
      return 'scroll_offset_$bookId';
    }
    return 'scroll_offset_${bookId}_c$chapterIndex';
  }

  String _chapterPageProgressKey(String bookId, int chapterIndex) {
    return 'page_progress_${bookId}_c$chapterIndex';
  }

  /// 保存特定书籍的滚动偏移量（当前落盘到 SharedPreferences）
  Future<void> saveScrollOffset(
    String bookId,
    double offset, {
    int? chapterIndex,
  }) async {
    if (chapterIndex == null) {
      await prefsStoreState.setDouble(_scrollOffsetKey(bookId), offset);
      return;
    }
    await prefsStoreState.setDouble(
      _scrollOffsetKey(bookId, chapterIndex: chapterIndex),
      offset,
    );
    // 向前兼容：章节级偏移写入时，同步更新书籍级偏移。
    await prefsStoreState.setDouble(_scrollOffsetKey(bookId), offset);
  }

  double getScrollOffset(String bookId, {int? chapterIndex}) {
    if (chapterIndex == null) {
      return prefsStoreState.getDouble(_scrollOffsetKey(bookId)) ?? 0.0;
    }
    final chapterOffset =
        prefsStoreState.getDouble(_scrollOffsetKey(bookId, chapterIndex: chapterIndex));
    if (chapterOffset != null) {
      return chapterOffset;
    }
    // 兼容旧键与未命中章节：回退到书籍级偏移。
    return prefsStoreState.getDouble(_scrollOffsetKey(bookId)) ?? 0.0;
  }

  Future<void> saveChapterPageProgress(
    String bookId, {
    required int chapterIndex,
    required double progress,
  }) async {
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    await prefsStoreState.setDouble(
      _chapterPageProgressKey(bookId, chapterIndex),
      normalized,
    );
  }

  double getChapterPageProgress(
    String bookId, {
    required int chapterIndex,
  }) {
    final value =
        prefsStoreState.getDouble(_chapterPageProgressKey(bookId, chapterIndex));
    if (value == null) return 0.0;
    return value.clamp(0.0, 1.0).toDouble();
  }
}
