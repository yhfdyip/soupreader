import 'dart:convert';

import '../../../features/bookshelf/models/book.dart';
import '../database_service.dart';
import '../entities/book_entity.dart';

/// 书籍存储仓库
class BookRepository {
  final DatabaseService _db;

  BookRepository(this._db);

  /// 获取所有书籍
  List<Book> getAllBooks() {
    return _db.booksBox.values.map(_entityToBook).toList();
  }

  /// 根据ID获取书籍
  Book? getBookById(String id) {
    final entity = _db.booksBox.get(id);
    return entity != null ? _entityToBook(entity) : null;
  }

  /// 添加书籍
  Future<void> addBook(Book book) async {
    await _db.booksBox.put(book.id, _bookToEntity(book));
  }

  /// 更新书籍
  Future<void> updateBook(Book book) async {
    await _db.booksBox.put(book.id, _bookToEntity(book));
  }

  /// 删除书籍
  Future<void> deleteBook(String id) async {
    await _db.booksBox.delete(id);
    // 同时删除相关章节
    final chaptersToDelete = _db.chaptersBox.values
        .where((c) => c.bookId == id)
        .map((c) => c.id)
        .toList();
    await _db.chaptersBox.deleteAll(chaptersToDelete);
  }

  /// 更新阅读进度
  Future<void> updateReadProgress(
    String bookId, {
    required int currentChapter,
    required double readProgress,
  }) async {
    final entity = _db.booksBox.get(bookId);
    if (entity != null) {
      final updated = BookEntity(
        id: entity.id,
        title: entity.title,
        author: entity.author,
        coverUrl: entity.coverUrl,
        intro: entity.intro,
        sourceId: entity.sourceId,
        sourceUrl: entity.sourceUrl,
        latestChapter: entity.latestChapter,
        totalChapters: entity.totalChapters,
        currentChapter: currentChapter,
        readProgress: readProgress,
        lastReadTime: DateTime.now(),
        addedTime: entity.addedTime,
        isLocal: entity.isLocal,
        localPath: entity.localPath,
      );
      await _db.booksBox.put(bookId, updated);
    }
  }

  /// 清除阅读记录（不删除书籍/章节）
  ///
  /// 对标“阅读记录列表 -> 删除阅读记录”的基础语义：清空上次阅读时间与进度。
  Future<void> clearReadingRecord(String bookId) async {
    final entity = _db.booksBox.get(bookId);
    if (entity == null) return;
    final updated = BookEntity(
      id: entity.id,
      title: entity.title,
      author: entity.author,
      coverUrl: entity.coverUrl,
      intro: entity.intro,
      sourceId: entity.sourceId,
      sourceUrl: entity.sourceUrl,
      latestChapter: entity.latestChapter,
      totalChapters: entity.totalChapters,
      currentChapter: 0,
      readProgress: 0.0,
      lastReadTime: null,
      addedTime: entity.addedTime,
      isLocal: entity.isLocal,
      localPath: entity.localPath,
    );
    await _db.booksBox.put(bookId, updated);
  }

  /// 检查书籍是否存在
  bool hasBook(String id) => _db.booksBox.containsKey(id);

  /// 获取书籍数量
  int get bookCount => _db.booksBox.length;

  /// 清空所有书籍
  Future<void> clearAll() async {
    await _db.booksBox.clear();
    await _db.chaptersBox.clear();
  }

  // === 转换方法 ===

  Book _entityToBook(BookEntity entity) {
    return Book(
      id: entity.id,
      title: entity.title,
      author: entity.author,
      coverUrl: entity.coverUrl,
      intro: entity.intro,
      sourceId: entity.sourceId,
      sourceUrl: entity.sourceUrl,
      latestChapter: entity.latestChapter,
      totalChapters: entity.totalChapters,
      currentChapter: entity.currentChapter,
      readProgress: entity.readProgress,
      lastReadTime: entity.lastReadTime,
      addedTime: entity.addedTime,
      isLocal: entity.isLocal,
      localPath: entity.localPath,
    );
  }

  BookEntity _bookToEntity(Book book) {
    return BookEntity(
      id: book.id,
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
      intro: book.intro,
      sourceId: book.sourceId,
      sourceUrl: book.sourceUrl,
      latestChapter: book.latestChapter,
      totalChapters: book.totalChapters,
      currentChapter: book.currentChapter,
      readProgress: book.readProgress,
      lastReadTime: book.lastReadTime,
      addedTime: book.addedTime,
      isLocal: book.isLocal,
      localPath: book.localPath,
    );
  }
}

/// 章节存储仓库
class ChapterRepository {
  final DatabaseService _db;

  ChapterRepository(this._db);

  ChapterCacheInfo getDownloadedCacheInfo({Set<String> protectBookIds = const {}}) {
    var bytes = 0;
    var chapters = 0;
    for (final entity in _db.chaptersBox.values) {
      if (protectBookIds.contains(entity.bookId)) continue;
      final content = entity.content;
      if (!entity.isDownloaded || content == null || content.isEmpty) continue;
      chapters++;
      bytes += utf8.encode(content).length;
    }
    return ChapterCacheInfo(bytes: bytes, chapters: chapters);
  }

  /// 清除已下载章节的缓存内容（不删除章节条目，以保留目录/进度）
  ///
  /// - `protectBookIds`：需要保护的书籍（例如本地导入书籍），不清理其章节内容
  Future<ChapterCacheInfo> clearDownloadedCache({
    Set<String> protectBookIds = const {},
  }) async {
    var bytes = 0;
    var chapters = 0;

    for (final entity in _db.chaptersBox.values) {
      if (protectBookIds.contains(entity.bookId)) continue;
      final content = entity.content;
      if (!entity.isDownloaded || content == null || content.isEmpty) continue;

      chapters++;
      bytes += utf8.encode(content).length;

      final updated = ChapterEntity(
        id: entity.id,
        bookId: entity.bookId,
        title: entity.title,
        url: entity.url,
        index: entity.index,
        isDownloaded: false,
        content: null,
      );
      await _db.chaptersBox.put(entity.id, updated);
    }

    return ChapterCacheInfo(bytes: bytes, chapters: chapters);
  }

  /// 获取书籍的所有章节
  List<Chapter> getChaptersForBook(String bookId) {
    return _db.chaptersBox.values
        .where((c) => c.bookId == bookId)
        .map(_entityToChapter)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  /// 添加章节列表
  Future<void> addChapters(List<Chapter> chapters) async {
    for (final chapter in chapters) {
      await _db.chaptersBox.put(chapter.id, _chapterToEntity(chapter));
    }
  }

  /// 更新章节内容（缓存）
  Future<void> cacheChapterContent(String chapterId, String content) async {
    final entity = _db.chaptersBox.get(chapterId);
    if (entity != null) {
      final updated = ChapterEntity(
        id: entity.id,
        bookId: entity.bookId,
        title: entity.title,
        url: entity.url,
        index: entity.index,
        isDownloaded: true,
        content: content,
      );
      await _db.chaptersBox.put(chapterId, updated);
    }
  }

  /// 清除书籍的所有章节缓存
  Future<void> clearChaptersForBook(String bookId) async {
    final keys = _db.chaptersBox.values
        .where((c) => c.bookId == bookId)
        .map((c) => c.id)
        .toList();
    await _db.chaptersBox.deleteAll(keys);
  }

  Chapter _entityToChapter(ChapterEntity entity) {
    return Chapter(
      id: entity.id,
      bookId: entity.bookId,
      title: entity.title,
      url: entity.url,
      index: entity.index,
      isDownloaded: entity.isDownloaded,
      content: entity.content,
    );
  }

  ChapterEntity _chapterToEntity(Chapter chapter) {
    return ChapterEntity(
      id: chapter.id,
      bookId: chapter.bookId,
      title: chapter.title,
      url: chapter.url,
      index: chapter.index,
      isDownloaded: chapter.isDownloaded,
      content: chapter.content,
    );
  }
}

class ChapterCacheInfo {
  final int bytes;
  final int chapters;

  const ChapterCacheInfo({required this.bytes, required this.chapters});
}
