import 'package:flutter/foundation.dart';

import '../../../core/database/repositories/book_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import '../utils/chapter_progress_utils.dart';
import '../models/reading_settings.dart';

/// Callback for saving scroll offset.
typedef ScrollOffsetProvider = double? Function();

/// Callback for loading a chapter at a specific index and progress.
typedef ChapterLoader = Future<void> Function(
  int chapterIndex, {
  bool restoreOffset,
  double? targetChapterProgress,
});

/// Callback for showing a confirmation dialog, returns true if
/// the user confirmed.
typedef ConfirmDialogCallback = Future<bool> Function({
  required String title,
  required String content,
});

/// Callback for normalizing error messages.
typedef ErrorMessageNormalizer = String Function(Object error);

/// Dependencies the progress helper needs from the host reader.
class ReaderProgressContext {
  /// Book ID for persistence.
  final String bookId;

  /// Widget-level book title (from constructor).
  final String widgetBookTitle;

  /// Whether the book is ephemeral (no persistence).
  final bool isEphemeral;

  /// Returns the current chapter index.
  final int Function() currentChapterIndex;

  /// Returns the current chapter title (post-processed).
  final String Function() currentTitle;

  /// Returns the effective readable chapter count.
  final int Function() readableChapterCount;

  /// Clamps a chapter index to the readable range.
  final int Function(int index) clampChapterIndex;

  /// Returns the current page turn mode.
  final PageTurnMode Function() pageTurnMode;

  /// Returns the current page index from PageFactory.
  final int Function() currentPageIndex;

  /// Returns the total page count from PageFactory.
  final int Function() totalPages;

  /// Returns the scroll chapter progress (0.0 - 1.0).
  final double Function() scrollChapterProgress;

  /// Returns the chapter content at a given index.
  final String Function(int index) chapterContentAt;

  /// Returns whether chapters are available.
  final bool Function() hasChapters;

  /// Returns the current scroll offset if available.
  final ScrollOffsetProvider scrollOffset;

  /// Returns whether the scroll controller has clients.
  final bool Function() scrollHasClients;

  /// Returns the current source URL.
  final String Function() currentSourceUrl;

  /// Returns the book author.
  final String Function() bookAuthor;

  const ReaderProgressContext({
    required this.bookId,
    required this.widgetBookTitle,
    required this.isEphemeral,
    required this.currentChapterIndex,
    required this.currentTitle,
    required this.readableChapterCount,
    required this.clampChapterIndex,
    required this.pageTurnMode,
    required this.currentPageIndex,
    required this.totalPages,
    required this.scrollChapterProgress,
    required this.chapterContentAt,
    required this.hasChapters,
    required this.scrollOffset,
    required this.scrollHasClients,
    required this.currentSourceUrl,
    required this.bookAuthor,
  });
}

/// Manages reading progress persistence, read-record duration
/// tracking, and WebDAV progress sync.
///
/// Owns the read-record accumulation state and WebDAV sync logic.
/// Scroll/page progress computation delegates to the host via
/// context callbacks.
class ReaderProgressHelper extends ChangeNotifier {
  ReaderProgressHelper(
    this._context, {
    required BookRepository bookRepo,
    required SettingsService settingsService,
    required WebDavService webDavService,
  })  : _bookRepo = bookRepo,
        _settingsService = settingsService,
        _webDavService = webDavService;

  final ReaderProgressContext _context;
  final BookRepository _bookRepo;
  final SettingsService _settingsService;
  final WebDavService _webDavService;

  // ── Read-record accumulation state ─────────────────────────

  static const int _readRecordPersistIntervalMs = 5000;
  static const int _readRecordPersistMinChunkMs = 1000;

  DateTime _lastReadRecordAccumulatedAt = DateTime.now();
  DateTime _lastReadRecordPersistAt =
      DateTime.fromMillisecondsSinceEpoch(0);
  int _pendingReadRecordDurationMs = 0;

  // ── Progress computation ───────────────────────────────────

  /// Computes the current chapter progress (0.0 - 1.0).
  double getChapterProgress() {
    if (_context.pageTurnMode() != PageTurnMode.scroll) {
      return ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: _context.currentPageIndex(),
        totalPages: _context.totalPages(),
      );
    }
    return _context.scrollChapterProgress().clamp(0.0, 1.0)
        .toDouble();
  }

  /// Computes the overall book progress (0.0 - 1.0).
  double getBookProgress() {
    final totalReadableChapters = _context.readableChapterCount();
    if (totalReadableChapters <= 0) return 0;
    final chapterProgress = getChapterProgress();
    final safeChapterIndex = _context
        .currentChapterIndex()
        .clamp(0, totalReadableChapters - 1)
        .toInt();
    return ((safeChapterIndex + chapterProgress) /
            totalReadableChapters)
        .clamp(0.0, 1.0);
  }

  // ── Read-record duration tracking ──────────────────────────

  /// Resets the read-record accumulation timers.
  void resetReadRecordTimers() {
    _lastReadRecordAccumulatedAt = DateTime.now();
    _lastReadRecordPersistAt =
        DateTime.fromMillisecondsSinceEpoch(0);
    _pendingReadRecordDurationMs = 0;
  }

  /// Collects the elapsed read duration since the last call
  /// and optionally persists it.
  Future<void> collectReadRecordDuration({
    required bool enableReadRecord,
    bool forcePersist = false,
  }) async {
    final now = DateTime.now();
    final elapsedMs =
        now.difference(_lastReadRecordAccumulatedAt).inMilliseconds;
    _lastReadRecordAccumulatedAt = now;
    if (enableReadRecord && elapsedMs > 0) {
      _pendingReadRecordDurationMs += elapsedMs;
    }

    if (_pendingReadRecordDurationMs <= 0) {
      return;
    }

    final reachedPersistInterval =
        now.difference(_lastReadRecordPersistAt).inMilliseconds >=
            _readRecordPersistIntervalMs;
    final reachedMinChunk =
        _pendingReadRecordDurationMs >= _readRecordPersistMinChunkMs;
    if (!forcePersist &&
        !(reachedPersistInterval && reachedMinChunk)) {
      return;
    }

    final durationToPersist = _pendingReadRecordDurationMs;
    _pendingReadRecordDurationMs = 0;
    _lastReadRecordPersistAt = now;
    await _settingsService.addBookReadRecordDurationMs(
      _context.bookId,
      durationToPersist,
    );
  }

  // ── Save progress ──────────────────────────────────────────

  /// Saves reading progress (chapter + offset) to the database.
  Future<void> saveProgress({
    bool forcePersistReadRecord = false,
  }) async {
    final enableReadRecord = _settingsService.enableReadRecord;
    await collectReadRecordDuration(
      enableReadRecord: enableReadRecord,
      forcePersist: forcePersistReadRecord,
    );

    final totalReadableChapters = _context.readableChapterCount();
    if (totalReadableChapters <= 0) return;

    final readableMaxIndex = totalReadableChapters - 1;
    final safeChapterIndex = _context
        .currentChapterIndex()
        .clamp(0, readableMaxIndex)
        .toInt();
    final progress = (safeChapterIndex + 1) / totalReadableChapters;
    final chapterProgress = getChapterProgress();

    await _bookRepo.updateReadProgress(
      _context.bookId,
      currentChapter: safeChapterIndex,
      readProgress: progress,
      updateLastReadTime: enableReadRecord,
    );

    if (_context.scrollHasClients()) {
      final offset = _context.scrollOffset();
      if (offset != null) {
        await _settingsService.saveScrollOffset(
          _context.bookId,
          offset,
          chapterIndex: safeChapterIndex,
        );
      }
    }

    await _settingsService.saveChapterPageProgress(
      _context.bookId,
      chapterIndex: safeChapterIndex,
      progress: chapterProgress,
    );
  }

  // ── WebDAV progress sync ───────────────────────────────────

  /// Whether a valid WebDAV progress config exists.
  bool hasWebDavProgressConfig() {
    final settings = _settingsService.appSettings;
    final rootUrl = _webDavService.buildRootUrl(settings).trim();
    final rootUri = Uri.tryParse(rootUrl);
    if (rootUri == null) return false;
    final scheme = rootUri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return _webDavService.hasValidConfig(settings);
  }

  /// Whether sync book progress is enabled in settings.
  bool isSyncBookProgressEnabled() {
    return _settingsService.appSettings.syncBookProgress;
  }

  /// Returns the book title for progress sync, preferring
  /// the repo version.
  String progressSyncBookTitle() {
    final bookTitleFromRepo =
        _bookRepo.getBookById(_context.bookId)?.title.trim() ?? '';
    if (bookTitleFromRepo.isNotEmpty) {
      return bookTitleFromRepo;
    }
    final title = _context.widgetBookTitle.trim();
    if (title.isNotEmpty) {
      return title;
    }
    return '未知书名';
  }

  /// Returns the book author for progress sync, preferring
  /// the repo version.
  String progressSyncBookAuthor() {
    final authorFromRepo =
        _bookRepo.getBookById(_context.bookId)?.author.trim() ?? '';
    if (authorFromRepo.isNotEmpty) {
      return authorFromRepo;
    }
    final author = _context.bookAuthor().trim();
    if (author.isNotEmpty) {
      return author;
    }
    return '未知作者';
  }

  /// Builds the local book progress payload for WebDAV upload.
  WebDavBookProgress buildLocalBookProgressPayload() {
    final chapterProgress =
        getChapterProgress().clamp(0.0, 1.0).toDouble();
    final readableChapterCount = _context.readableChapterCount();
    final safeChapterIndex = readableChapterCount > 0
        ? _context
            .currentChapterIndex()
            .clamp(0, readableChapterCount - 1)
            .toInt()
        : 0;
    return WebDavBookProgress(
      name: progressSyncBookTitle(),
      author: progressSyncBookAuthor(),
      durChapterIndex: safeChapterIndex,
      durChapterPos: (chapterProgress * 10000).round(),
      durChapterTime: DateTime.now().millisecondsSinceEpoch,
      durChapterTitle: _context.currentTitle(),
      chapterProgress: chapterProgress,
      readProgress:
          getBookProgress().clamp(0.0, 1.0).toDouble(),
      totalChapters: readableChapterCount,
    );
  }

  /// Decodes a remote chapter progress from a
  /// [WebDavBookProgress].
  double decodeRemoteChapterProgress(WebDavBookProgress remote) {
    final explicit = remote.chapterProgress;
    if (explicit != null) {
      return explicit.clamp(0.0, 1.0).toDouble();
    }
    final pos = remote.durChapterPos;
    if (pos <= 0) return 0.0;
    if (pos <= 10000) {
      return (pos / 10000.0).clamp(0.0, 1.0).toDouble();
    }
    return 0.0;
  }

  /// Uploads local reading progress to WebDAV.
  ///
  /// Returns a [WebDavSyncResult] indicating success or failure.
  Future<WebDavSyncResult> pushBookProgressToWebDav() async {
    if (!isSyncBookProgressEnabled()) {
      return const WebDavSyncResult.skipped();
    }
    if (!hasWebDavProgressConfig()) {
      return const WebDavSyncResult.skipped();
    }
    if (!_context.hasChapters()) {
      return const WebDavSyncResult.skipped();
    }
    final bookTitle = progressSyncBookTitle();
    final bookAuthor = progressSyncBookAuthor();
    try {
      await saveProgress();
      final progress = buildLocalBookProgressPayload();
      await _webDavService.uploadBookProgress(
        progress: progress,
        settings: _settingsService.appSettings,
      );
      return const WebDavSyncResult.success();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.cover_progress.failed',
        message: '上传阅读进度失败《$bookTitle》\n$error',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': _context.bookId,
          'bookTitle': bookTitle,
          'bookAuthor': bookAuthor,
          'syncBookProgress':
              _settingsService.appSettings.syncBookProgress,
          'sourceUrl': _context.currentSourceUrl(),
        },
      );
      return WebDavSyncResult.failure(error);
    }
  }

  /// Pulls reading progress from WebDAV.
  ///
  /// Returns the remote progress and comparison result, or null
  /// if no remote progress was found or the operation was
  /// skipped.
  Future<WebDavPullResult?> pullBookProgressFromWebDav() async {
    if (!isSyncBookProgressEnabled()) {
      return null;
    }
    if (!hasWebDavProgressConfig()) {
      return null;
    }
    if (!_context.hasChapters()) {
      return null;
    }
    final bookTitle = progressSyncBookTitle();
    final bookAuthor = progressSyncBookAuthor();
    try {
      final remote = await _webDavService.getBookProgress(
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
        settings: _settingsService.appSettings,
      );
      if (remote == null) return null;
      return _analyzeRemoteBookProgress(
        remote,
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.get_progress.failed',
        message: '拉取阅读进度失败《$bookTitle》\n$error',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': _context.bookId,
          'bookTitle': _context.widgetBookTitle,
          'bookAuthor': _context.bookAuthor(),
          'syncBookProgress':
              _settingsService.appSettings.syncBookProgress,
          'sourceUrl': _context.currentSourceUrl(),
        },
      );
      return null;
    }
  }

  /// Analyzes a remote progress payload against the local state
  /// and returns a result describing what action is needed.
  WebDavPullResult? _analyzeRemoteBookProgress(
    WebDavBookProgress remote, {
    required String bookTitle,
    required String bookAuthor,
  }) {
    final readableChapterCount = _context.readableChapterCount();
    if (readableChapterCount <= 0) return null;
    final maxIndex = readableChapterCount - 1;
    final targetChapterIndex = remote.durChapterIndex;
    if (targetChapterIndex < 0 || targetChapterIndex > maxIndex) {
      return null;
    }
    var targetChapterProgress =
        decodeRemoteChapterProgress(remote);
    final remotePos = remote.durChapterPos;
    final hasLegacyRawPos =
        remote.chapterProgress == null && remotePos > 10000;
    if (hasLegacyRawPos && targetChapterProgress <= 0) {
      final chapterContent =
          _context.chapterContentAt(targetChapterIndex).trim();
      if (chapterContent.isNotEmpty) {
        targetChapterProgress =
            (remotePos / chapterContent.length)
                .clamp(0.0, 1.0)
                .toDouble();
      }
    }
    final localChapterIndex = _context
        .currentChapterIndex()
        .clamp(0, maxIndex)
        .toInt();
    final localChapterProgress =
        getChapterProgress().clamp(0.0, 1.0).toDouble();
    final remoteBehindLocal =
        targetChapterIndex < localChapterIndex ||
            (targetChapterIndex == localChapterIndex &&
                targetChapterProgress < localChapterProgress);
    final chapterProgressDelta =
        (targetChapterProgress - localChapterProgress).abs();
    final remoteEqualsLocal =
        targetChapterIndex == localChapterIndex &&
            chapterProgressDelta <= 0.0001;

    return WebDavPullResult(
      remote: remote,
      targetChapterIndex: targetChapterIndex,
      targetChapterProgress: targetChapterProgress,
      remoteBehindLocal: remoteBehindLocal,
      remoteEqualsLocal: remoteEqualsLocal,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
    );
  }

  /// Logs a successful progress sync event.
  void logProgressSynced({
    required WebDavPullResult pullResult,
  }) {
    final syncedTitle =
        (pullResult.remote.durChapterTitle ?? '').trim();
    final suffix = syncedTitle.isEmpty ? '' : ' $syncedTitle';
    ExceptionLogService().record(
      node: 'reader.menu.get_progress.synced',
      message:
          '自动同步阅读进度成功《${pullResult.bookTitle}》$suffix',
      context: <String, dynamic>{
        'bookId': _context.bookId,
        'bookTitle': pullResult.bookTitle,
        'bookAuthor': pullResult.bookAuthor,
        'chapterIndex': pullResult.targetChapterIndex,
        'chapterTitle': pullResult.remote.durChapterTitle,
        'sourceUrl': _context.currentSourceUrl(),
      },
    );
  }
}

/// Result of a WebDAV push operation.
class WebDavSyncResult {
  final bool success;
  final bool skipped;
  final Object? error;

  const WebDavSyncResult._({
    required this.success,
    required this.skipped,
    this.error,
  });

  const WebDavSyncResult.success()
      : this._(success: true, skipped: false);

  const WebDavSyncResult.skipped()
      : this._(success: false, skipped: true);

  const WebDavSyncResult.failure(Object error)
      : this._(success: false, skipped: false, error: error);
}

/// Result of a WebDAV pull operation with analysis.
class WebDavPullResult {
  final WebDavBookProgress remote;
  final int targetChapterIndex;
  final double targetChapterProgress;
  final bool remoteBehindLocal;
  final bool remoteEqualsLocal;
  final String bookTitle;
  final String bookAuthor;

  const WebDavPullResult({
    required this.remote,
    required this.targetChapterIndex,
    required this.targetChapterProgress,
    required this.remoteBehindLocal,
    required this.remoteEqualsLocal,
    required this.bookTitle,
    required this.bookAuthor,
  });
}
