import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../drift/source_drift_database.dart';
import '../drift/source_drift_service.dart';
import '../entities/bookmark_entity.dart';

/// 书签仓库（drift）
class BookmarkRepository {
  static const _uuid = Uuid();

  final SourceDriftService _driftService = SourceDriftService();

  static final StreamController<List<BookmarkEntity>> _watchController =
      StreamController<List<BookmarkEntity>>.broadcast();
  static StreamSubscription<List<BookmarkRecord>>? _watchSub;
  static final Map<String, BookmarkEntity> _cacheById =
      <String, BookmarkEntity>{};
  static bool _cacheReady = false;

  SourceDriftDatabase get _db => _driftService.db;

  /// 初始化
  Future<void> init() async {
    await _driftService.init();
    _ensureWatchStarted();
    if (!_cacheReady) {
      await _reloadCacheFromDb();
    }
  }

  void _ensureWatchStarted() {
    if (_watchSub != null) return;
    _watchSub = _db.select(_db.bookmarkRecords).watch().listen((rows) {
      _updateCacheFromRows(rows);
    });
  }

  Future<void> _reloadCacheFromDb() async {
    final rows = await _db.select(_db.bookmarkRecords).get();
    _updateCacheFromRows(rows);
  }

  static void _updateCacheFromRows(List<BookmarkRecord> rows) {
    _cacheById
      ..clear()
      ..addEntries(rows.map((row) {
        final model = _rowToEntity(row);
        return MapEntry(model.id, model);
      }));
    _cacheReady = true;
    _watchController.add(_cacheById.values.toList(growable: false));
  }

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
    await _db.into(_db.bookmarkRecords).insertOnConflictUpdate(
          _entityToCompanion(bookmark),
        );
    return bookmark;
  }

  Future<void> removeBookmark(String id) async {
    await (_db.delete(_db.bookmarkRecords)..where((b) => b.id.equals(id))).go();
  }

  List<BookmarkEntity> getBookmarksForBook(String bookId) {
    final list = _cacheById.values
        .where((b) => b.bookId == bookId)
        .toList(growable: false);
    list.sort((a, b) => b.createdTime.compareTo(a.createdTime));
    return list;
  }

  List<BookmarkEntity> getAllBookmarks() {
    final list = _cacheById.values.toList(growable: false);
    list.sort((a, b) => b.createdTime.compareTo(a.createdTime));
    return list;
  }

  bool hasBookmark(String bookId, int chapterIndex, {int? chapterPos}) {
    return _cacheById.values.any((b) =>
        b.bookId == bookId &&
        b.chapterIndex == chapterIndex &&
        (chapterPos == null || b.chapterPos == chapterPos));
  }

  BookmarkEntity? getBookmarkAt(String bookId, int chapterIndex, int chapterPos) {
    for (final item in _cacheById.values) {
      if (item.bookId == bookId &&
          item.chapterIndex == chapterIndex &&
          item.chapterPos == chapterPos) {
        return item;
      }
    }
    return null;
  }

  Future<void> removeAllBookmarksForBook(String bookId) async {
    await (_db.delete(_db.bookmarkRecords)
          ..where((b) => b.bookId.equals(bookId)))
        .go();
  }

  int getBookmarkCount(String bookId) {
    return _cacheById.values.where((b) => b.bookId == bookId).length;
  }

  BookmarkRecordsCompanion _entityToCompanion(BookmarkEntity entity) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return BookmarkRecordsCompanion.insert(
      id: entity.id,
      bookId: entity.bookId,
      bookName: Value(entity.bookName),
      bookAuthor: Value(entity.bookAuthor),
      chapterIndex: Value(entity.chapterIndex),
      chapterTitle: Value(entity.chapterTitle),
      chapterPos: Value(entity.chapterPos),
      content: Value(entity.content),
      createdTime: Value(entity.createdTime.millisecondsSinceEpoch),
      updatedAt: Value(now),
    );
  }

  static BookmarkEntity _rowToEntity(BookmarkRecord row) {
    return BookmarkEntity(
      id: row.id,
      bookId: row.bookId,
      bookName: row.bookName,
      bookAuthor: row.bookAuthor,
      chapterIndex: row.chapterIndex,
      chapterTitle: row.chapterTitle,
      chapterPos: row.chapterPos,
      content: row.content,
      createdTime: DateTime.fromMillisecondsSinceEpoch(row.createdTime),
    );
  }
}
