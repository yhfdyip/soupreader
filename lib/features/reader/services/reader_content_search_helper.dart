import 'package:flutter/foundation.dart';

import '../../../core/services/exception_log_service.dart';
import '../models/reader_view_types.dart';
import '../services/reader_search_navigation_helper.dart';

/// Callback that applies replace rules and Chinese conversion
/// to raw chapter content for search matching.
typedef ContentSearchContentResolver = Future<String> Function(
  String rawContent, {
  required int taskToken,
});

/// Callback that resolves a search hit's page index in paged mode.
typedef SearchHitPageIndexResolver = int? Function({
  required int contentOffset,
  required int occurrenceIndex,
  required String query,
});

/// Dependencies the search helper needs from the host reader.
class ReaderContentSearchContext {
  /// Book ID for error logging.
  final String bookId;

  /// Returns the current chapter index.
  final int Function() currentChapterIndex;

  /// Returns the current chapter title.
  final String Function() currentTitle;

  /// Returns the list of searchable chapters.
  /// Each element must expose `.title` and `.content`.
  final List<SearchableChapter> Function() readableChapters;

  /// Returns the effective readable chapter count for progress
  /// snapshot.
  final int Function() readableChapterCount;

  /// Clamps a chapter index to the readable range.
  final int Function(int index) clampChapterIndex;

  /// Returns the current chapter reading progress (0.0 - 1.0).
  final double Function() chapterProgress;

  /// Post-processes a raw chapter title (e.g. Chinese conversion).
  final String Function(String title) postProcessTitle;

  /// Returns the current page turn mode.
  /// Non-scroll modes use page-index resolution; scroll mode uses
  /// offset-based resolution.
  final bool Function() isScrollMode;

  /// Returns the current page texts for page-index resolution.
  final List<String> Function() currentPageTexts;

  /// Whether the title mode hides the title prefix on the first
  /// page (titleMode != 2).
  final bool Function() trimFirstPageTitlePrefix;

  /// Resolves searchable content from raw content, applying
  /// replace rules and Chinese conversion as configured.
  final ContentSearchContentResolver resolveSearchableContent;

  const ReaderContentSearchContext({
    required this.bookId,
    required this.currentChapterIndex,
    required this.currentTitle,
    required this.readableChapters,
    required this.readableChapterCount,
    required this.clampChapterIndex,
    required this.chapterProgress,
    required this.postProcessTitle,
    required this.isScrollMode,
    required this.currentPageTexts,
    required this.trimFirstPageTitlePrefix,
    required this.resolveSearchableContent,
  });
}

/// A minimal view of a chapter for content searching.
class SearchableChapter {
  final String title;
  final String? content;

  const SearchableChapter({
    required this.title,
    this.content,
  });
}

/// Manages the state and logic for full-text content search
/// within the reader.
///
/// The helper owns all search state (query, hits, progress) and
/// exposes methods for searching, navigating hits, and exiting.
/// UI building and scroll/page navigation remain in the host.
class ReaderContentSearchHelper extends ChangeNotifier {
  ReaderContentSearchHelper(this._context);

  final ReaderContentSearchContext _context;

  // ── Search state ──────────────────────────────────────────

  String _query = '';
  List<ReaderSearchHit> _hits = const <ReaderSearchHit>[];
  int _currentHitIndex = -1;
  bool _isSearching = false;
  bool _useReplace = false;
  ReaderSearchProgressSnapshot? _progressSnapshot;
  int _taskToken = 0;

  // ── Public getters ────────────────────────────────────────

  String get query => _query;
  List<ReaderSearchHit> get hits => _hits;
  int get currentHitIndex => _currentHitIndex;
  bool get isSearching => _isSearching;
  bool get useReplace => _useReplace;
  ReaderSearchProgressSnapshot? get progressSnapshot =>
      _progressSnapshot;
  int get taskToken => _taskToken;
  bool get hasHits => _hits.isNotEmpty;

  /// Returns the current hit, or null if no valid index.
  ReaderSearchHit? get currentHit {
    if (_currentHitIndex >= 0 &&
        _currentHitIndex < _hits.length) {
      return _hits[_currentHitIndex];
    }
    return null;
  }

  /// The query string to highlight in the reader content,
  /// or null if search is inactive or has no results.
  String? get activeHighlightQuery {
    if (_hits.isEmpty) return null;
    final q = _query.trim();
    return q.isEmpty ? null : q;
  }

  // ── Actions ───────────────────────────────────────────────

  /// Starts a full-text content search with the given [query].
  ///
  /// Returns the list of hits found. The caller should call
  /// [notifyListeners] indirectly via setState after jumping to
  /// the first hit.
  Future<List<ReaderSearchHit>> applySearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const <ReaderSearchHit>[];
    }
    captureProgressSnapshotIfNeeded();

    final token = ++_taskToken;
    _query = normalized;
    _isSearching = true;
    _hits = const <ReaderSearchHit>[];
    _currentHitIndex = -1;
    notifyListeners();

    debugPrint(
      '[reader][content-search] start token=$token '
      'queryLength=${normalized.length}',
    );

    late final List<ReaderSearchHit> results;
    try {
      results = await _collectBookSearchHits(
        normalized,
        taskToken: token,
      );
    } catch (error, stackTrace) {
      if (token != _taskToken) {
        return const <ReaderSearchHit>[];
      }
      ExceptionLogService().record(
        node: 'reader.menu.search_content.collect',
        message: '全文搜索失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': _context.bookId,
          'chapterIndex': _context.currentChapterIndex(),
          'queryLength': normalized.length,
          'searchableChapterCount':
              _context.readableChapters().length,
        },
      );
      _isSearching = false;
      _hits = const <ReaderSearchHit>[];
      _currentHitIndex = -1;
      notifyListeners();
      return const <ReaderSearchHit>[];
    }

    if (token != _taskToken) {
      return const <ReaderSearchHit>[];
    }

    _isSearching = false;
    _hits = results;
    _currentHitIndex = results.isEmpty ? -1 : 0;
    notifyListeners();

    debugPrint(
      '[reader][content-search] done token=$token '
      'hits=${results.length}',
    );
    return results;
  }

  /// Navigates to the next or previous hit by [delta] (-1 or 1).
  /// Returns the target hit, or null if navigation is not
  /// possible.
  ReaderSearchHit? navigateHit(int delta) {
    if (_hits.isEmpty) return null;
    final nextIndex =
        ReaderSearchNavigationHelper.resolveNextHitIndex(
      currentIndex: _currentHitIndex,
      delta: delta,
      totalHits: _hits.length,
    );
    if (nextIndex < 0) return null;
    _currentHitIndex = nextIndex;
    notifyListeners();
    return _hits[nextIndex];
  }

  /// Toggles the "use replace rule" flag.
  void toggleUseReplace() {
    _useReplace = !_useReplace;
    notifyListeners();
  }

  /// Captures the current reading position before navigating
  /// away for search, so it can be restored later.
  void captureProgressSnapshotIfNeeded() {
    if (_progressSnapshot != null) return;
    final readableCount = _context.readableChapterCount();
    if (readableCount <= 0) return;
    _progressSnapshot = ReaderSearchProgressSnapshot(
      chapterIndex: _context.clampChapterIndex(
        _context.currentChapterIndex(),
      ),
      chapterProgress:
          _context.chapterProgress().clamp(0.0, 1.0).toDouble(),
    );
  }

  /// Resets all search state to exit the search mode.
  ///
  /// When [clearProgressSnapshot] is false, the snapshot is
  /// preserved so the caller can restore progress afterwards.
  void resetSearch({bool clearProgressSnapshot = true}) {
    debugPrint(
      '[reader][content-search] exit '
      'queryLength=${_query.length} '
      'hits=${_hits.length}',
    );
    _taskToken += 1;
    _isSearching = false;
    _hits = const <ReaderSearchHit>[];
    _currentHitIndex = -1;
    _query = '';
    _useReplace = false;
    if (clearProgressSnapshot) {
      _progressSnapshot = null;
    }
    notifyListeners();
  }

  /// Clears the progress snapshot after a successful restore.
  void clearProgressSnapshot() {
    _progressSnapshot = null;
  }

  /// Resolves the page index for a search hit in paged mode.
  int? resolveHitPageIndex({
    required int contentOffset,
    required int occurrenceIndex,
    required String query,
  }) {
    final byOccurrence =
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
      pages: _context.currentPageTexts(),
      query: query,
      occurrenceIndex: occurrenceIndex,
      chapterTitle: _context.currentTitle(),
      trimFirstPageTitlePrefix:
          _context.trimFirstPageTitlePrefix(),
    );
    if (byOccurrence != null) return byOccurrence;
    return ReaderSearchNavigationHelper.resolvePageIndexByOffset(
      pages: _context.currentPageTexts(),
      contentOffset: contentOffset,
    );
  }

  // ── Internal search collection ────────────────────────────

  Future<List<ReaderSearchHit>> _collectBookSearchHits(
    String query, {
    required int taskToken,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <ReaderSearchHit>[];
    }
    final chapters = _context.readableChapters();
    if (chapters.isEmpty) return const <ReaderSearchHit>[];

    final allHits = <ReaderSearchHit>[];
    for (var i = 0; i < chapters.length; i++) {
      if (taskToken != _taskToken) {
        return const <ReaderSearchHit>[];
      }

      final chapter = chapters[i];
      final rawContent = (chapter.content ?? '')
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      if (rawContent.trim().isEmpty) continue;

      final searchable =
          await _context.resolveSearchableContent(
        rawContent,
        taskToken: taskToken,
      );
      if (taskToken != _taskToken) {
        return const <ReaderSearchHit>[];
      }
      if (searchable.isEmpty) continue;

      final title = _context.postProcessTitle(chapter.title);
      allHits.addAll(
        _collectChapterHits(
          chapterIndex: i,
          chapterTitle: title,
          content: searchable,
          query: normalizedQuery,
        ),
      );

      // Yield every 8 chapters to keep the UI responsive.
      if ((i & 7) == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return allHits;
  }

  List<ReaderSearchHit> _collectChapterHits({
    required int chapterIndex,
    required String chapterTitle,
    required String content,
    required String query,
  }) {
    final results = <ReaderSearchHit>[];
    var from = 0;
    var occurrenceIndex = 0;
    while (from < content.length) {
      final found = content.indexOf(query, from);
      if (found == -1) break;
      final end = found + query.length;
      final previewStart =
          (found - 20).clamp(0, content.length).toInt();
      final previewEnd =
          (end + 24).clamp(0, content.length).toInt();
      final previewRaw = content
          .substring(previewStart, previewEnd)
          .replaceAll('\n', ' ');
      final localStart =
          (found - previewStart).clamp(0, previewRaw.length).toInt();
      final localEnd = (localStart + query.length)
          .clamp(localStart, previewRaw.length)
          .toInt();
      final previewBefore = previewRaw.substring(0, localStart);
      final previewMatch =
          previewRaw.substring(localStart, localEnd);
      final previewAfter = previewRaw.substring(localEnd);

      final pageIndex = chapterIndex ==
                  _context.currentChapterIndex() &&
              !_context.isScrollMode()
          ? resolveHitPageIndex(
              contentOffset: found,
              occurrenceIndex: occurrenceIndex,
              query: query,
            )
          : null;

      results.add(
        ReaderSearchHit(
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          chapterContentLength: content.length,
          start: found,
          end: end,
          query: query,
          occurrenceIndex: occurrenceIndex,
          previewBefore: previewBefore,
          previewMatch: previewMatch,
          previewAfter: previewAfter,
          pageIndex: pageIndex,
        ),
      );
      occurrenceIndex += 1;
      from = found + query.length;
    }
    return results;
  }
}
