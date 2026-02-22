import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/bookshelf/models/book.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';

/// 书籍存储仓库（drift）
class BookRepository {
  final SourceDriftDatabase _driftDb;

  static final StreamController<List<Book>> _watchController =
      StreamController<List<Book>>.broadcast();
  static StreamSubscription<List<BookRecord>>? _watchSub;
  static final Map<String, Book> _cacheById = <String, Book>{};
  static bool _cacheReady = false;

  BookRepository(DatabaseService db) : _driftDb = db.driftDb {
    _ensureWatchStarted();
  }

  static Future<void> bootstrap(DatabaseService db) async {
    final repo = BookRepository(db);
    await repo._reloadCacheFromDb();
    repo._ensureWatchStarted();
  }

  void _ensureWatchStarted() {
    if (_watchSub != null) return;
    _watchSub = _driftDb.select(_driftDb.bookRecords).watch().listen((rows) {
      _updateCacheFromRows(rows);
    });
  }

  Future<void> _reloadCacheFromDb() async {
    final rows = await _driftDb.select(_driftDb.bookRecords).get();
    _updateCacheFromRows(rows);
  }

  static void _emitCacheSnapshot() {
    _cacheReady = true;
    _watchController.add(_cacheById.values.toList(growable: false));
  }

  static void _updateCacheFromRows(List<BookRecord> rows) {
    _cacheById
      ..clear()
      ..addEntries(rows.map((row) {
        final model = _rowToBook(row);
        return MapEntry(model.id, model);
      }));
    _emitCacheSnapshot();
  }

  List<Book> getAllBooks() {
    if (!_cacheReady) return const <Book>[];
    return _cacheById.values.toList(growable: false);
  }

  Stream<List<Book>> watchAllBooks() async* {
    if (!_cacheReady) {
      await _reloadCacheFromDb();
    }
    yield getAllBooks();
    yield* _watchController.stream;
  }

  Book? getBookById(String id) {
    if (!_cacheReady) return null;
    return _cacheById[id];
  }

  Future<void> addBook(Book book) async {
    await _driftDb
        .into(_driftDb.bookRecords)
        .insertOnConflictUpdate(_bookToCompanion(book));
    _cacheById[book.id] = book;
    _emitCacheSnapshot();
  }

  Future<void> updateBook(Book book) async {
    await addBook(book);
  }

  Future<void> deleteBook(String id) async {
    await _driftDb.transaction(() async {
      await (_driftDb.delete(_driftDb.bookRecords)
            ..where((tbl) => tbl.id.equals(id)))
          .go();
      await (_driftDb.delete(_driftDb.chapterRecords)
            ..where((tbl) => tbl.bookId.equals(id)))
          .go();
    });
    _cacheById.remove(id);
    _emitCacheSnapshot();
    ChapterRepository._removeCacheByBookId(id);
  }

  Future<void> updateReadProgress(
    String bookId, {
    required int currentChapter,
    required double readProgress,
    bool updateLastReadTime = true,
  }) async {
    final entity = getBookById(bookId);
    if (entity == null) return;
    final updated = entity.copyWith(
      currentChapter: currentChapter,
      readProgress: readProgress,
      lastReadTime: updateLastReadTime ? DateTime.now() : entity.lastReadTime,
    );
    await addBook(updated);
  }

  Future<void> clearReadingRecord(String bookId) async {
    final entity = getBookById(bookId);
    if (entity == null) return;
    final updated = entity.copyWith(
      currentChapter: 0,
      readProgress: 0.0,
      lastReadTime: null,
    );
    await addBook(updated);
  }

  bool hasBook(String id) => _cacheById.containsKey(id);

  int get bookCount => _cacheById.length;

  Future<void> clearAll() async {
    await _driftDb.transaction(() async {
      await _driftDb.delete(_driftDb.bookRecords).go();
      await _driftDb.delete(_driftDb.chapterRecords).go();
    });
    _cacheById.clear();
    _emitCacheSnapshot();
    ChapterRepository._clearAllCache();
  }

  BookRecordsCompanion _bookToCompanion(Book book) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return BookRecordsCompanion.insert(
      id: book.id,
      title: Value(book.title),
      author: Value(book.author),
      coverUrl: Value(book.coverUrl),
      intro: Value(book.intro),
      sourceId: Value(book.sourceId),
      sourceUrl: Value(book.sourceUrl),
      bookUrl: Value(book.bookUrl),
      latestChapter: Value(book.latestChapter),
      totalChapters: Value(book.totalChapters),
      currentChapter: Value(book.currentChapter),
      readProgress: Value(book.readProgress),
      lastReadTime: Value(book.lastReadTime?.millisecondsSinceEpoch),
      addedTime: Value(book.addedTime?.millisecondsSinceEpoch),
      isLocal: Value(book.isLocal),
      localPath: Value(book.localPath),
      updatedAt: Value(now),
    );
  }

  static Book _rowToBook(BookRecord row) {
    return Book(
      id: row.id,
      title: row.title,
      author: row.author,
      coverUrl: row.coverUrl,
      intro: row.intro,
      sourceId: row.sourceId,
      sourceUrl: row.sourceUrl,
      bookUrl: row.bookUrl,
      latestChapter: row.latestChapter,
      totalChapters: row.totalChapters,
      currentChapter: row.currentChapter,
      readProgress: row.readProgress,
      lastReadTime: row.lastReadTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastReadTime!),
      addedTime: row.addedTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.addedTime!),
      isLocal: row.isLocal,
      localPath: row.localPath,
    );
  }
}

/// 章节存储仓库（drift）
class ChapterRepository {
  final SourceDriftDatabase _driftDb;

  static final StreamController<List<Chapter>> _watchController =
      StreamController<List<Chapter>>.broadcast();
  static StreamSubscription<List<ChapterRecord>>? _watchSub;
  static final Map<String, Chapter> _cacheById = <String, Chapter>{};
  static bool _cacheReady = false;

  ChapterRepository(DatabaseService db) : _driftDb = db.driftDb {
    _ensureWatchStarted();
  }

  static Future<void> bootstrap(DatabaseService db) async {
    final repo = ChapterRepository(db);
    await repo._reloadCacheFromDb();
    repo._ensureWatchStarted();
  }

  void _ensureWatchStarted() {
    if (_watchSub != null) return;
    _watchSub = _driftDb.select(_driftDb.chapterRecords).watch().listen((rows) {
      _updateCacheFromRows(rows);
    });
  }

  Future<void> _reloadCacheFromDb() async {
    final rows = await _driftDb.select(_driftDb.chapterRecords).get();
    _updateCacheFromRows(rows);
  }

  static void _emitCacheSnapshot() {
    _cacheReady = true;
    _watchController.add(_cacheById.values.toList(growable: false));
  }

  static void _updateCacheFromRows(List<ChapterRecord> rows) {
    _cacheById
      ..clear()
      ..addEntries(rows.map((row) {
        final model = _rowToChapter(row);
        return MapEntry(model.id, model);
      }));
    _emitCacheSnapshot();
  }

  static void _removeCacheByBookId(String bookId) {
    _cacheById.removeWhere((_, chapter) => chapter.bookId == bookId);
    _emitCacheSnapshot();
  }

  static void _clearAllCache() {
    _cacheById.clear();
    _emitCacheSnapshot();
  }

  List<Chapter> getAllChapters() {
    if (!_cacheReady) return const <Chapter>[];
    return _cacheById.values.toList(growable: false);
  }

  ChapterCacheInfo getDownloadedCacheInfo({
    Set<String> protectBookIds = const {},
  }) {
    var bytes = 0;
    var chapters = 0;
    for (final entity in _cacheById.values) {
      if (protectBookIds.contains(entity.bookId)) continue;
      final content = entity.content;
      if (!entity.isDownloaded || content == null || content.isEmpty) continue;
      chapters++;
      bytes += utf8.encode(content).length;
    }
    return ChapterCacheInfo(bytes: bytes, chapters: chapters);
  }

  ChapterCacheInfo getDownloadedCacheInfoForBook(String bookId) {
    var bytes = 0;
    var chapters = 0;
    for (final entity in _cacheById.values) {
      if (entity.bookId != bookId) continue;
      final content = entity.content;
      if (!entity.isDownloaded || content == null || content.isEmpty) continue;
      chapters++;
      bytes += utf8.encode(content).length;
    }
    return ChapterCacheInfo(bytes: bytes, chapters: chapters);
  }

  Future<ChapterCacheInfo> clearDownloadedCache({
    Set<String> protectBookIds = const {},
  }) async {
    if (!_cacheReady) {
      await _reloadCacheFromDb();
    }

    var bytes = 0;
    var chapters = 0;

    final targets = _cacheById.values.where((entity) {
      if (protectBookIds.contains(entity.bookId)) return false;
      final content = entity.content;
      return entity.isDownloaded && content != null && content.isNotEmpty;
    }).toList(growable: false);

    if (targets.isEmpty) {
      return const ChapterCacheInfo(bytes: 0, chapters: 0);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final companions = <ChapterRecordsCompanion>[];
    for (final entity in targets) {
      final content = entity.content ?? '';
      chapters++;
      bytes += utf8.encode(content).length;
      companions.add(
        ChapterRecordsCompanion(
          id: Value(entity.id),
          bookId: Value(entity.bookId),
          title: Value(entity.title),
          url: Value(entity.url),
          chapterIndex: Value(entity.index),
          isDownloaded: const Value(false),
          content: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }

    await _driftDb.batch((batch) {
      batch.insertAllOnConflictUpdate(_driftDb.chapterRecords, companions);
    });

    for (final entity in targets) {
      final current = _cacheById[entity.id];
      if (current == null) continue;
      _cacheById[entity.id] = current.copyWith(
        isDownloaded: false,
        content: null,
      );
    }
    _emitCacheSnapshot();

    return ChapterCacheInfo(bytes: bytes, chapters: chapters);
  }

  Future<ChapterCacheInfo> clearDownloadedCacheForBook(String bookId) async {
    if (!_cacheReady) {
      await _reloadCacheFromDb();
    }
    return clearDownloadedCache(
      protectBookIds: _cacheById.values
          .where((entity) => entity.bookId != bookId)
          .map((entity) => entity.bookId)
          .toSet(),
    );
  }

  List<Chapter> getChaptersForBook(String bookId) {
    return _cacheById.values
        .where((c) => c.bookId == bookId)
        .toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  Future<int> countChaptersForBook(String bookId) async {
    final rows = await (_driftDb.select(_driftDb.chapterRecords)
          ..where((tbl) => tbl.bookId.equals(bookId)))
        .get();
    return rows.length;
  }

  Future<void> addChapters(List<Chapter> chapters) async {
    if (chapters.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final companions = chapters
        .map((chapter) => ChapterRecordsCompanion.insert(
              id: chapter.id,
              bookId: chapter.bookId,
              title: Value(chapter.title),
              url: Value(chapter.url),
              chapterIndex: Value(chapter.index),
              isDownloaded: Value(chapter.isDownloaded),
              content: Value(chapter.content),
              updatedAt: Value(now),
            ))
        .toList(growable: false);
    await _driftDb.batch((batch) {
      batch.insertAllOnConflictUpdate(_driftDb.chapterRecords, companions);
    });
    if (!_cacheReady) {
      await _reloadCacheFromDb();
      return;
    }
    for (final chapter in chapters) {
      _cacheById[chapter.id] = chapter;
    }
    _emitCacheSnapshot();
  }

  Future<void> cacheChapterContent(String chapterId, String content) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_driftDb.update(_driftDb.chapterRecords)
          ..where((tbl) => tbl.id.equals(chapterId)))
        .write(
      ChapterRecordsCompanion(
        isDownloaded: const Value(true),
        content: Value(content),
        updatedAt: Value(now),
      ),
    );
    if (!_cacheReady) return;
    final entity = _cacheById[chapterId];
    if (entity == null) return;
    _cacheById[chapterId] = entity.copyWith(
      isDownloaded: true,
      content: content,
    );
    _emitCacheSnapshot();
  }

  Future<void> clearChaptersForBook(String bookId) async {
    await (_driftDb.delete(_driftDb.chapterRecords)
          ..where((c) => c.bookId.equals(bookId)))
        .go();
    if (!_cacheReady) return;
    _removeCacheByBookId(bookId);
  }

  static Chapter _rowToChapter(ChapterRecord row) {
    return Chapter(
      id: row.id,
      bookId: row.bookId,
      title: row.title,
      url: row.url,
      index: row.chapterIndex,
      isDownloaded: row.isDownloaded,
      content: row.content,
    );
  }
}

class ChapterCacheInfo {
  final int bytes;
  final int chapters;

  const ChapterCacheInfo({required this.bytes, required this.chapters});
}
