import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../entities/bookmark_entity.dart';

/// 书签仓库
class BookmarkRepository {
  static const String _boxName = 'bookmarks';
  static const _uuid = Uuid();

  Box<BookmarkEntity>? _box;

  /// 初始化
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(BookmarkEntityAdapter());
    }
    _box = await Hive.openBox<BookmarkEntity>(_boxName);
  }

  Box<BookmarkEntity> get _bookmarksBox {
    if (_box == null) {
      throw StateError('BookmarkRepository 未初始化，请先调用 init()');
    }
    return _box!;
  }

  /// 添加书签
  Future<BookmarkEntity> addBookmark({
    required String bookId,
    required String bookName,
    required String bookAuthor,
    required int chapterIndex,
    required String chapterTitle,
    int chapterPos = 0,
    String content = '',
  }) async {
    final bookmark = BookmarkEntity(
      id: _uuid.v4(),
      bookId: bookId,
      bookName: bookName,
      bookAuthor: bookAuthor,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      chapterPos: chapterPos,
      content: content,
    );

    await _bookmarksBox.put(bookmark.id, bookmark);
    return bookmark;
  }

  /// 删除书签
  Future<void> removeBookmark(String id) async {
    await _bookmarksBox.delete(id);
  }

  /// 获取书籍的所有书签
  List<BookmarkEntity> getBookmarksForBook(String bookId) {
    return _bookmarksBox.values.where((b) => b.bookId == bookId).toList()
      ..sort((a, b) => b.createdTime.compareTo(a.createdTime));
  }

  /// 获取所有书签
  List<BookmarkEntity> getAllBookmarks() {
    return _bookmarksBox.values.toList()
      ..sort((a, b) => b.createdTime.compareTo(a.createdTime));
  }

  /// 检查是否存在书签
  bool hasBookmark(String bookId, int chapterIndex, {int? chapterPos}) {
    return _bookmarksBox.values.any((b) =>
        b.bookId == bookId &&
        b.chapterIndex == chapterIndex &&
        (chapterPos == null || b.chapterPos == chapterPos));
  }

  /// 获取特定位置的书签
  BookmarkEntity? getBookmarkAt(
      String bookId, int chapterIndex, int chapterPos) {
    try {
      return _bookmarksBox.values.firstWhere((b) =>
          b.bookId == bookId &&
          b.chapterIndex == chapterIndex &&
          b.chapterPos == chapterPos);
    } catch (e) {
      return null;
    }
  }

  /// 删除书籍的所有书签
  Future<void> removeAllBookmarksForBook(String bookId) async {
    final keysToRemove = _bookmarksBox.values
        .where((b) => b.bookId == bookId)
        .map((b) => b.id)
        .toList();

    for (final key in keysToRemove) {
      await _bookmarksBox.delete(key);
    }
  }

  /// 书签数量
  int getBookmarkCount(String bookId) {
    return _bookmarksBox.values.where((b) => b.bookId == bookId).length;
  }
}
