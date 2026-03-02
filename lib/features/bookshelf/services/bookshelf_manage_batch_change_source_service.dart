import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/services/reader_source_switch_helper.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/book.dart';

class BookshelfManageBatchChangeSourceProgress {
  final int current;
  final int total;
  final Book book;

  const BookshelfManageBatchChangeSourceProgress({
    required this.current,
    required this.total,
    required this.book,
  });

  String get progressText => '$current / $total';
}

enum BookshelfManageBatchChangeSourceItemStatus {
  success,
  skipped,
  failed,
}

class BookshelfManageBatchChangeSourceSummary {
  final int totalCount;
  final int successCount;
  final int skippedCount;
  final int failedCount;
  final bool cancelled;
  final List<String> failedDetails;

  const BookshelfManageBatchChangeSourceSummary({
    required this.totalCount,
    required this.successCount,
    required this.skippedCount,
    required this.failedCount,
    required this.cancelled,
    required this.failedDetails,
  });
}

class BookshelfManageBatchChangeSourceService {
  static const _uuid = Uuid();

  BookshelfManageBatchChangeSourceService({
    required BookRepository bookRepository,
    required SourceRepository sourceRepository,
    required ChapterRepository chapterRepository,
    required RuleParserEngine ruleEngine,
    required SettingsService settingsService,
    ExceptionLogService? exceptionLogService,
  })  : _bookRepository = bookRepository,
        _sourceRepository = sourceRepository,
        _chapterRepository = chapterRepository,
        _ruleEngine = ruleEngine,
        _settingsService = settingsService,
        _exceptionLogService = exceptionLogService ?? ExceptionLogService();

  final BookRepository _bookRepository;
  final SourceRepository _sourceRepository;
  final ChapterRepository _chapterRepository;
  final RuleParserEngine _ruleEngine;
  final SettingsService _settingsService;
  final ExceptionLogService _exceptionLogService;

  Future<BookshelfManageBatchChangeSourceSummary> changeSource({
    required List<Book> books,
    required BookSource targetSource,
    CancelToken? cancelToken,
    void Function(BookshelfManageBatchChangeSourceProgress progress)?
        onProgress,
  }) async {
    if (books.isEmpty) {
      return const BookshelfManageBatchChangeSourceSummary(
        totalCount: 0,
        successCount: 0,
        skippedCount: 0,
        failedCount: 0,
        cancelled: false,
        failedDetails: <String>[],
      );
    }

    final resolvedTargetSource =
        _sourceRepository.getSourceByUrl(targetSource.bookSourceUrl) ??
            targetSource;
    final delaySeconds = _normalizeDelaySeconds(
      _settingsService.getBatchChangeSourceDelay(),
    );

    var successCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    var cancelled = false;
    final failedDetails = <String>[];

    for (var index = 0; index < books.length; index++) {
      final book = books[index];
      if (_isCancelled(cancelToken)) {
        cancelled = true;
        break;
      }

      onProgress?.call(
        BookshelfManageBatchChangeSourceProgress(
          current: index + 1,
          total: books.length,
          book: book,
        ),
      );

      final result = await _changeSingleBookSource(
        book: book,
        targetSource: resolvedTargetSource,
        cancelToken: cancelToken,
      );

      if (result.cancelled) {
        cancelled = true;
        break;
      }

      switch (result.status) {
        case BookshelfManageBatchChangeSourceItemStatus.success:
          successCount++;
          break;
        case BookshelfManageBatchChangeSourceItemStatus.skipped:
          skippedCount++;
          break;
        case BookshelfManageBatchChangeSourceItemStatus.failed:
          failedCount++;
          failedDetails.add('${book.title}：${result.message}');
          break;
      }

      if (index < books.length - 1 && delaySeconds > 0 && result.applyDelay) {
        final keepRunning = await _waitDelayWithCancel(
          seconds: delaySeconds,
          cancelToken: cancelToken,
        );
        if (!keepRunning) {
          cancelled = true;
          break;
        }
      }
    }

    return BookshelfManageBatchChangeSourceSummary(
      totalCount: books.length,
      successCount: successCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      cancelled: cancelled,
      failedDetails: failedDetails,
    );
  }

  Future<_BatchChangeSourceItemResult> _changeSingleBookSource({
    required Book book,
    required BookSource targetSource,
    required CancelToken? cancelToken,
  }) async {
    if (_isCancelled(cancelToken)) {
      return const _BatchChangeSourceItemResult.cancelled();
    }

    if (book.isLocal) {
      return const _BatchChangeSourceItemResult.skipped('本地书籍不参与批量换源');
    }

    final currentSourceUrl = (book.sourceUrl ?? book.sourceId ?? '').trim();
    final targetSourceUrl = targetSource.bookSourceUrl.trim();
    if (_normalizeForCompare(currentSourceUrl) ==
        _normalizeForCompare(targetSourceUrl)) {
      return const _BatchChangeSourceItemResult.skipped('当前书籍已使用目标书源');
    }

    final keyword = book.title.trim();
    if (keyword.isEmpty) {
      return const _BatchChangeSourceItemResult.failed('书名为空，无法换源');
    }

    SearchResult? matchedResult;
    try {
      final list = await _ruleEngine.search(
        targetSource,
        keyword,
        filter: (name, author) {
          return name == keyword && author == book.author;
        },
        shouldBreak: (size) => size > 0,
        cancelToken: cancelToken,
      );
      if (_isCancelled(cancelToken)) {
        return const _BatchChangeSourceItemResult.cancelled();
      }
      if (list.isNotEmpty) {
        matchedResult = list.first;
      }
      if (matchedResult == null) {
        return const _BatchChangeSourceItemResult.skipped('目标书源未匹配到书籍');
      }
    } catch (error, stackTrace) {
      _recordFailure(
        node: 'bookshelf_manage.menu_change_source.search',
        message: '批量换源搜索失败',
        error: error,
        stackTrace: stackTrace,
        book: book,
        targetSource: targetSource,
      );
      return _BatchChangeSourceItemResult.failed(
        '搜索失败：${_compactReason(error.toString())}',
      );
    }

    BookDetail? detail;
    try {
      detail = await _ruleEngine.getBookInfo(
        targetSource,
        matchedResult.bookUrl,
        clearRuntimeVariables: true,
        cancelToken: cancelToken,
      );
      if (_isCancelled(cancelToken)) {
        return const _BatchChangeSourceItemResult.cancelled();
      }
    } catch (error, stackTrace) {
      _recordFailure(
        node: 'bookshelf_manage.menu_change_source.book_info',
        message: '批量换源获取详情失败',
        error: error,
        stackTrace: stackTrace,
        book: book,
        targetSource: targetSource,
      );
      return _BatchChangeSourceItemResult.failed(
        '获取详情失败：${_compactReason(error.toString())}',
      );
    }

    final primaryTocUrl =
        detail?.tocUrl.trim().isNotEmpty == true ? detail!.tocUrl.trim() : '';
    final fallbackTocUrl = matchedResult.bookUrl.trim();
    if (primaryTocUrl.isEmpty && fallbackTocUrl.isEmpty) {
      return const _BatchChangeSourceItemResult.failed('详情链接为空，无法换源');
    }

    List<TocItem> toc;
    try {
      toc = await _fetchTocWithFallback(
        source: targetSource,
        primaryTocUrl: primaryTocUrl,
        fallbackTocUrl: fallbackTocUrl,
        cancelToken: cancelToken,
      );
      if (_isCancelled(cancelToken)) {
        return const _BatchChangeSourceItemResult.cancelled();
      }
      if (toc.isEmpty) {
        return const _BatchChangeSourceItemResult.failed(
          '目录为空（可能是 ruleToc 不匹配）',
          applyDelay: true,
        );
      }
    } catch (error, stackTrace) {
      _recordFailure(
        node: 'bookshelf_manage.menu_change_source.toc',
        message: '批量换源获取目录失败',
        error: error,
        stackTrace: stackTrace,
        book: book,
        targetSource: targetSource,
      );
      return _BatchChangeSourceItemResult.failed(
        '获取目录失败：${_compactReason(error.toString())}',
        applyDelay: true,
      );
    }

    final nextChapters = _buildChapters(
      bookId: book.id,
      toc: toc,
    );
    if (nextChapters.isEmpty) {
      return const _BatchChangeSourceItemResult.failed('目录解析失败：章节为空');
    }

    final storedBook = _bookRepository.getBookById(book.id) ?? book;
    final previousChapters = _chapterRepository.getChaptersForBook(book.id)
      ..sort((a, b) => a.index.compareTo(b.index));
    final previousTitle = _resolveCurrentChapterTitle(
      storedBook: storedBook,
      chapters: previousChapters,
    );
    final previousChapterCount = previousChapters.isEmpty
        ? storedBook.totalChapters
        : previousChapters.length;

    final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: nextChapters,
      currentChapterTitle: previousTitle,
      currentChapterIndex: storedBook.currentChapter,
      oldChapterCount: previousChapterCount,
    ).clamp(0, nextChapters.length - 1).toInt();

    try {
      await _chapterRepository.clearChaptersForBook(storedBook.id);
      await _chapterRepository.addChapters(nextChapters);
      await _bookRepository.updateBook(
        storedBook.copyWith(
          title: _pickFirstNonEmpty([
                detail?.name,
                matchedResult.name,
                storedBook.title,
              ]) ??
              storedBook.title,
          author: _pickFirstNonEmpty([
                detail?.author,
                matchedResult.author,
                storedBook.author,
              ]) ??
              storedBook.author,
          coverUrl: _pickFirstNonEmpty([
                detail?.coverUrl,
                matchedResult.coverUrl,
                storedBook.coverUrl,
              ]) ??
              storedBook.coverUrl,
          intro: _pickFirstNonEmpty([
                detail?.intro,
                matchedResult.intro,
                storedBook.intro,
              ]) ??
              storedBook.intro,
          sourceId: targetSource.bookSourceUrl,
          sourceUrl: targetSource.bookSourceUrl,
          bookUrl: _pickFirstNonEmpty([
                detail?.bookUrl,
                matchedResult.bookUrl,
                storedBook.bookUrl,
              ]) ??
              storedBook.bookUrl,
          latestChapter: _pickFirstNonEmpty([
                detail?.lastChapter,
                nextChapters.last.title,
                storedBook.latestChapter,
              ]) ??
              storedBook.latestChapter,
          totalChapters: nextChapters.length,
          currentChapter: targetIndex,
        ),
      );
      return const _BatchChangeSourceItemResult.success();
    } catch (error, stackTrace) {
      _recordFailure(
        node: 'bookshelf_manage.menu_change_source.persist',
        message: '批量换源写入失败',
        error: error,
        stackTrace: stackTrace,
        book: book,
        targetSource: targetSource,
      );
      return _BatchChangeSourceItemResult.failed(
        '换源写入失败：${_compactReason(error.toString())}',
        applyDelay: true,
      );
    }
  }

  Future<List<TocItem>> _fetchTocWithFallback({
    required BookSource source,
    required String primaryTocUrl,
    required String fallbackTocUrl,
    required CancelToken? cancelToken,
  }) async {
    final normalizedPrimary = primaryTocUrl.trim();
    final normalizedFallback = fallbackTocUrl.trim();

    if (normalizedPrimary.isNotEmpty) {
      final primary = await _ruleEngine.getToc(
        source,
        normalizedPrimary,
        clearRuntimeVariables: false,
        cancelToken: cancelToken,
      );
      if (primary.isNotEmpty) return primary;
    }

    if (normalizedFallback.isEmpty || normalizedFallback == normalizedPrimary) {
      return const <TocItem>[];
    }

    return _ruleEngine.getToc(
      source,
      normalizedFallback,
      clearRuntimeVariables: false,
      cancelToken: cancelToken,
    );
  }

  List<Chapter> _buildChapters({
    required String bookId,
    required List<TocItem> toc,
  }) {
    final chapters = <Chapter>[];
    final seenUrls = <String>{};

    for (final item in toc) {
      final title = item.name.trim();
      final url = item.url.trim();
      if (title.isEmpty || url.isEmpty) continue;
      if (!seenUrls.add(url)) continue;

      final index = chapters.length;
      chapters.add(
        Chapter(
          id: _uuid.v5(Namespace.url.value, '$bookId|$index|$url'),
          bookId: bookId,
          title: title,
          url: url,
          index: index,
        ),
      );
    }

    return chapters;
  }

  String _resolveCurrentChapterTitle({
    required Book storedBook,
    required List<Chapter> chapters,
  }) {
    if (chapters.isEmpty) {
      return (storedBook.latestChapter ?? '').trim();
    }
    final safeIndex = storedBook.currentChapter.clamp(0, chapters.length - 1);
    return chapters[safeIndex].title;
  }

  String _normalizeForCompare(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  int _normalizeDelaySeconds(int seconds) {
    return seconds.clamp(0, 9999).toInt();
  }

  bool _isCancelled(CancelToken? token) {
    return token?.isCancelled == true;
  }

  Future<bool> _waitDelayWithCancel({
    required int seconds,
    required CancelToken? cancelToken,
  }) async {
    if (seconds <= 0) return true;
    final totalMs = seconds * 1000;
    var elapsedMs = 0;
    while (elapsedMs < totalMs) {
      if (_isCancelled(cancelToken)) {
        return false;
      }
      final remainingMs = totalMs - elapsedMs;
      final stepMs = remainingMs > 200 ? 200 : remainingMs;
      await Future<void>.delayed(Duration(milliseconds: stepMs));
      elapsedMs += stepMs;
    }
    return !_isCancelled(cancelToken);
  }

  String _compactReason(String text, {int maxLength = 120}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  String? _pickFirstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  void _recordFailure({
    required String node,
    required String message,
    required Object error,
    required StackTrace stackTrace,
    required Book book,
    required BookSource targetSource,
  }) {
    _exceptionLogService.record(
      node: node,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'bookId': book.id,
        'bookTitle': book.title,
        'bookAuthor': book.author,
        'targetSourceUrl': targetSource.bookSourceUrl,
        'targetSourceName': targetSource.bookSourceName,
      },
    );
  }
}

class _BatchChangeSourceItemResult {
  final BookshelfManageBatchChangeSourceItemStatus status;
  final String message;
  final bool cancelled;
  final bool applyDelay;

  const _BatchChangeSourceItemResult._({
    required this.status,
    required this.message,
    required this.cancelled,
    required this.applyDelay,
  });

  const _BatchChangeSourceItemResult.success({
    bool applyDelay = true,
  }) : this._(
          status: BookshelfManageBatchChangeSourceItemStatus.success,
          message: '',
          cancelled: false,
          applyDelay: applyDelay,
        );

  const _BatchChangeSourceItemResult.skipped(
    String message, {
    bool applyDelay = false,
  }) : this._(
          status: BookshelfManageBatchChangeSourceItemStatus.skipped,
          message: message,
          cancelled: false,
          applyDelay: applyDelay,
        );

  const _BatchChangeSourceItemResult.failed(
    String message, {
    bool applyDelay = false,
  }) : this._(
          status: BookshelfManageBatchChangeSourceItemStatus.failed,
          message: message,
          cancelled: false,
          applyDelay: applyDelay,
        );

  const _BatchChangeSourceItemResult.cancelled()
      : this._(
          status: BookshelfManageBatchChangeSourceItemStatus.skipped,
          message: '已取消',
          cancelled: true,
          applyDelay: false,
        );
}
