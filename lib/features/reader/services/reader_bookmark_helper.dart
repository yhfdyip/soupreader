import 'package:flutter/foundation.dart';

import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../services/reader_bookmark_export_service.dart';

/// Dependencies the bookmark helper needs from the host reader.
class ReaderBookmarkContext {
  /// Book ID for bookmark queries.
  final String bookId;

  /// Book title for bookmark creation.
  final String Function() bookTitle;

  /// Book author for bookmark creation.
  final String Function() bookAuthor;

  /// Returns the current chapter index.
  final int Function() currentChapterIndex;

  /// Returns the current chapter title (post-processed).
  final String Function() currentTitle;

  /// Returns the total chapter count.
  final int Function() chapterCount;

  /// Returns the raw chapter title at a given index.
  final String Function(int index) chapterTitleAt;

  /// Returns the current chapter progress (0.0 - 1.0).
  final double Function() chapterProgress;

  /// Returns the current page text (from PageFactory).
  final String Function() currentPageText;

  /// Returns the current chapter content.
  final String Function() currentContent;

  const ReaderBookmarkContext({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.currentChapterIndex,
    required this.currentTitle,
    required this.chapterCount,
    required this.chapterTitleAt,
    required this.chapterProgress,
    required this.currentPageText,
    required this.currentContent,
  });
}

/// Draft for creating a new bookmark.
class BookmarkDraft {
  final String chapterTitle;
  final int chapterPos;
  final String pageText;

  const BookmarkDraft({
    required this.chapterTitle,
    required this.chapterPos,
    required this.pageText,
  });
}

/// Result from the bookmark editor dialog.
class BookmarkEditResult {
  final String bookText;
  final String note;

  const BookmarkEditResult({
    required this.bookText,
    required this.note,
  });
}

/// Manages bookmark state and CRUD operations for the reader.
///
/// The helper owns the [BookmarkRepository] lifecycle, bookmark status
/// tracking, and export logic. Dialog display and setState remain in
/// the host widget.
class ReaderBookmarkHelper extends ChangeNotifier {
  ReaderBookmarkHelper(this._context, {
    required BookmarkRepository bookmarkRepo,
    ReaderBookmarkExportService? exportService,
  })  : _bookmarkRepo = bookmarkRepo,
        _exportService = exportService ?? ReaderBookmarkExportService();

  final ReaderBookmarkContext _context;
  final BookmarkRepository _bookmarkRepo;
  final ReaderBookmarkExportService _exportService;

  // ── State ───────────────────────────────────────────────────

  bool _hasBookmarkAtCurrent = false;

  // ── Public getters ──────────────────────────────────────────

  bool get hasBookmarkAtCurrent => _hasBookmarkAtCurrent;

  BookmarkRepository get bookmarkRepo => _bookmarkRepo;

  // ── Bookmark status ─────────────────────────────────────────

  /// Checks whether a bookmark exists at the current chapter
  /// and updates the cached flag. Notifies listeners on change.
  void updateBookmarkStatus() {
    bool hasBookmark = false;
    try {
      hasBookmark = _bookmarkRepo.hasBookmark(
        _context.bookId,
        _context.currentChapterIndex(),
      );
    } catch (_) {
      hasBookmark = false;
    }
    if (_hasBookmarkAtCurrent == hasBookmark) return;
    _hasBookmarkAtCurrent = hasBookmark;
    notifyListeners();
  }

  // ── Bookmark draft building ─────────────────────────────────

  /// Builds a draft for adding a bookmark at the current position.
  BookmarkDraft? buildBookmarkDraft() {
    final chapterIndex = _context.currentChapterIndex();
    final chapterCount = _context.chapterCount();
    if (chapterCount == 0 ||
        chapterIndex < 0 ||
        chapterIndex >= chapterCount) {
      return null;
    }
    final fallbackTitle =
        _context.chapterTitleAt(chapterIndex).trim();
    final currentTitle = _context.currentTitle().trim();
    final chapterTitle = currentTitle.isNotEmpty
        ? currentTitle
        : fallbackTitle;
    return BookmarkDraft(
      chapterTitle: chapterTitle.isEmpty
          ? '第 ${chapterIndex + 1} 章'
          : chapterTitle,
      chapterPos: encodeCurrentChapterPos(),
      pageText: resolveCurrentBookmarkText(),
    );
  }

  /// Builds a draft for adding a bookmark from selected text.
  BookmarkDraft? buildBookmarkDraftFromSelectedText(
    String selectedText,
  ) {
    final baseDraft = buildBookmarkDraft();
    if (baseDraft == null) return null;
    return BookmarkDraft(
      chapterTitle: baseDraft.chapterTitle,
      chapterPos: baseDraft.chapterPos,
      pageText: selectedText.trim(),
    );
  }

  // ── Bookmark CRUD ───────────────────────────────────────────

  /// Saves a new bookmark from the given draft and editor result.
  Future<void> saveBookmark({
    required BookmarkDraft draft,
    required BookmarkEditResult result,
  }) async {
    await _bookmarkRepo.addBookmark(
      bookId: _context.bookId,
      bookName: _context.bookTitle(),
      bookAuthor: _context.bookAuthor(),
      chapterIndex: _context.currentChapterIndex(),
      chapterTitle: draft.chapterTitle,
      chapterPos: draft.chapterPos,
      content: composeBookmarkPreview(
        bookText: result.bookText,
        note: result.note,
      ),
    );
    updateBookmarkStatus();
  }

  /// Removes a bookmark by ID and refreshes the status.
  Future<void> removeBookmark(String bookmarkId) async {
    await _bookmarkRepo.removeBookmark(bookmarkId);
    updateBookmarkStatus();
  }

  /// Saves an edited bookmark (update by re-insert).
  Future<void> saveEditedBookmark({
    required BookmarkEntity bookmark,
    required String content,
  }) async {
    await _bookmarkRepo.addBookmark(
      bookId: bookmark.bookId,
      bookName: bookmark.bookName,
      bookAuthor: bookmark.bookAuthor,
      chapterIndex: bookmark.chapterIndex,
      chapterTitle: bookmark.chapterTitle,
      chapterPos: bookmark.chapterPos,
      content: content,
    );
    updateBookmarkStatus();
  }

  /// Returns all bookmarks for the current book.
  List<BookmarkEntity> getBookmarksForBook() {
    return _bookmarkRepo.getBookmarksForBook(_context.bookId);
  }

  // ── Export ──────────────────────────────────────────────────

  /// Exports bookmarks in the specified format.
  Future<ReaderBookmarkExportResult> exportBookmarks({
    required bool markdown,
  }) async {
    final bookmarks =
        _bookmarkRepo.getBookmarksForBook(_context.bookId);
    return markdown
        ? _exportService.exportMarkdown(
            bookTitle: _context.bookTitle(),
            bookAuthor: _context.bookAuthor(),
            bookmarks: bookmarks,
          )
        : _exportService.exportJson(
            bookTitle: _context.bookTitle(),
            bookAuthor: _context.bookAuthor(),
            bookmarks: bookmarks,
          );
  }

  // ── Encoding/decoding ──────────────────────────────────────

  /// Encodes the current chapter progress as an integer
  /// bookmark position (0-10000).
  int encodeCurrentChapterPos() {
    return (_context.chapterProgress().clamp(0.0, 1.0) * 10000)
        .round();
  }

  /// Decodes a bookmark chapterPos integer back to a progress
  /// value (0.0-1.0).
  double decodeBookmarkChapterProgress(int chapterPos) {
    return (chapterPos / 10000.0).clamp(0.0, 1.0).toDouble();
  }

  // ── Text resolution ────────────────────────────────────────

  /// Resolves the text to store for a bookmark at the current
  /// reading position.
  String resolveCurrentBookmarkText() {
    final pageText = _context.currentPageText().trim();
    if (pageText.isNotEmpty) {
      return pageText;
    }
    final content = _context.currentContent().trim();
    if (content.isEmpty) {
      return '';
    }
    final progress =
        _context.chapterProgress().clamp(0.0, 1.0).toDouble();
    final center = (content.length * progress)
        .round()
        .clamp(0, content.length)
        .toInt();
    final start = (center - 90).clamp(0, content.length).toInt();
    final end = (start + 180).clamp(0, content.length).toInt();
    return content.substring(start, end).trim();
  }

  /// Composes a preview string from book text and note.
  String composeBookmarkPreview({
    required String bookText,
    required String note,
  }) {
    final trimmedText = bookText.trim();
    final trimmedNote = note.trim();
    if (trimmedText.isEmpty) {
      return trimmedNote;
    }
    if (trimmedNote.isEmpty) {
      return trimmedText;
    }
    return '$trimmedText\n\n笔记：$trimmedNote';
  }
}
