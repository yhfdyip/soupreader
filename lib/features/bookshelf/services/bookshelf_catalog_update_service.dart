import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/book.dart';

enum BookshelfCatalogUpdateItemStatus {
  success,
  skipped,
  failed,
}

class BookshelfCatalogUpdateItemResult {
  final BookshelfCatalogUpdateItemStatus status;
  final String? message;

  const BookshelfCatalogUpdateItemResult._({
    required this.status,
    this.message,
  });

  factory BookshelfCatalogUpdateItemResult.success() {
    return const BookshelfCatalogUpdateItemResult._(
      status: BookshelfCatalogUpdateItemStatus.success,
    );
  }

  factory BookshelfCatalogUpdateItemResult.skipped(String message) {
    return BookshelfCatalogUpdateItemResult._(
      status: BookshelfCatalogUpdateItemStatus.skipped,
      message: message,
    );
  }

  factory BookshelfCatalogUpdateItemResult.failed(String message) {
    return BookshelfCatalogUpdateItemResult._(
      status: BookshelfCatalogUpdateItemStatus.failed,
      message: message,
    );
  }
}

class BookshelfCatalogUpdateSummary {
  final int totalRequestedCount;
  final int updateCandidateCount;
  final int successCount;
  final int skippedCount;
  final int failedCount;
  final List<String> failedDetails;

  const BookshelfCatalogUpdateSummary({
    required this.totalRequestedCount,
    required this.updateCandidateCount,
    required this.successCount,
    required this.skippedCount,
    required this.failedCount,
    required this.failedDetails,
  });
}

typedef BookshelfCatalogSingleBookUpdater
    = Future<BookshelfCatalogUpdateItemResult> Function(
  Book book,
);

class BookshelfCatalogUpdateService {
  static const _uuid = Uuid();

  final RuleParserEngine? _engine;
  final SourceRepository? _sourceRepo;
  final BookRepository? _bookRepo;
  final ChapterRepository? _chapterRepo;
  final BookshelfCatalogSingleBookUpdater? _singleBookUpdaterOverride;

  BookshelfCatalogUpdateService({
    DatabaseService? database,
    RuleParserEngine? engine,
    SourceRepository? sourceRepo,
    BookRepository? bookRepo,
    ChapterRepository? chapterRepo,
    BookshelfCatalogSingleBookUpdater? singleBookUpdaterOverride,
  }) : this._(
          database ?? DatabaseService(),
          engine: engine,
          sourceRepo: sourceRepo,
          bookRepo: bookRepo,
          chapterRepo: chapterRepo,
          singleBookUpdaterOverride: singleBookUpdaterOverride,
        );

  BookshelfCatalogUpdateService._(
    DatabaseService db, {
    RuleParserEngine? engine,
    SourceRepository? sourceRepo,
    BookRepository? bookRepo,
    ChapterRepository? chapterRepo,
    BookshelfCatalogSingleBookUpdater? singleBookUpdaterOverride,
  })  : _singleBookUpdaterOverride = singleBookUpdaterOverride,
        _engine = engine ?? RuleParserEngine(),
        _sourceRepo = sourceRepo ?? SourceRepository(db),
        _bookRepo = bookRepo ?? BookRepository(db),
        _chapterRepo = chapterRepo ?? ChapterRepository(db);

  /// 仅用于 orchestration 测试：绕过真实网络/仓储依赖。
  const BookshelfCatalogUpdateService.forTest({
    required BookshelfCatalogSingleBookUpdater singleBookUpdater,
  })  : _singleBookUpdaterOverride = singleBookUpdater,
        _engine = null,
        _sourceRepo = null,
        _bookRepo = null,
        _chapterRepo = null;

  String _compactReason(String text, {int maxLength = 96}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  String _normalizeForCompare(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  SearchResult? _pickBestUpdateTarget({
    required Book book,
    required List<SearchResult> results,
  }) {
    final titleKey = _normalizeForCompare(book.title);
    final authorKey = _normalizeForCompare(book.author);

    SearchResult? authorMatched;
    SearchResult? fallback;

    for (final item in results) {
      final itemTitleKey = _normalizeForCompare(item.name);
      if (itemTitleKey != titleKey) continue;
      fallback ??= item;
      final itemAuthorKey = _normalizeForCompare(item.author);
      if (authorKey.isNotEmpty &&
          itemAuthorKey.isNotEmpty &&
          itemAuthorKey == authorKey) {
        authorMatched = item;
        break;
      }
    }

    return authorMatched ?? fallback;
  }

  String? _pickFirstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  Future<List<TocItem>> _fetchTocWithFallback({
    required RuleParserEngine engine,
    required BookSource source,
    required String primaryTocUrl,
    required String fallbackTocUrl,
  }) async {
    var toc = await engine.getToc(
      source,
      primaryTocUrl,
      clearRuntimeVariables: false,
    );
    if (toc.isNotEmpty) return toc;

    final normalizedPrimary = primaryTocUrl.trim();
    final normalizedFallback = fallbackTocUrl.trim();
    if (normalizedFallback.isEmpty || normalizedFallback == normalizedPrimary) {
      return toc;
    }

    toc = await engine.getToc(
      source,
      normalizedFallback,
      clearRuntimeVariables: false,
    );
    return toc;
  }

  List<Chapter> _buildStoredChapters({
    required ChapterRepository chapterRepo,
    required String bookId,
    required List<TocItem> toc,
  }) {
    final previousByUrl = <String, Chapter>{};
    for (final chapter in chapterRepo.getChaptersForBook(bookId)) {
      final url = (chapter.url ?? '').trim();
      if (url.isEmpty) continue;
      previousByUrl[url] = chapter;
    }

    final chapters = <Chapter>[];
    final seen = <String>{};
    for (final item in toc) {
      final title = item.name.trim();
      final url = item.url.trim();
      if (title.isEmpty || url.isEmpty) continue;
      if (!seen.add(url)) continue;

      final previous = previousByUrl[url];
      final index = chapters.length;
      chapters.add(
        Chapter(
          id: _uuid.v5(Namespace.url.value, '$bookId|$index|$url'),
          bookId: bookId,
          title: title,
          url: url,
          index: index,
          isDownloaded: previous?.isDownloaded ?? false,
          content: previous?.content,
        ),
      );
    }
    return chapters;
  }

  Future<BookshelfCatalogUpdateItemResult> _updateSingleBook(Book book) async {
    final engine = _engine;
    final sourceRepo = _sourceRepo;
    final bookRepo = _bookRepo;
    final chapterRepo = _chapterRepo;
    if (engine == null ||
        sourceRepo == null ||
        bookRepo == null ||
        chapterRepo == null) {
      return BookshelfCatalogUpdateItemResult.failed('更新服务未初始化');
    }

    if (book.isLocal) {
      return BookshelfCatalogUpdateItemResult.skipped('本地书籍不支持更新目录');
    }

    final latestBook = bookRepo.getBookById(book.id) ?? book;
    final sourceUrl =
        (latestBook.sourceUrl ?? latestBook.sourceId ?? '').trim();
    if (sourceUrl.isEmpty) {
      return BookshelfCatalogUpdateItemResult.failed('缺少书源信息，无法更新目录');
    }

    final source = sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) {
      return BookshelfCatalogUpdateItemResult.failed('书源不存在或已被删除');
    }

    String targetBookUrl = (latestBook.bookUrl ?? '').trim();
    if (targetBookUrl.isEmpty) {
      final keyword = latestBook.title.trim();
      if (keyword.isEmpty) {
        return BookshelfCatalogUpdateItemResult.failed('书名为空，无法更新目录');
      }

      final results = await engine.search(source, keyword);
      final target = _pickBestUpdateTarget(book: latestBook, results: results);
      if (target == null) {
        return BookshelfCatalogUpdateItemResult.failed('未在当前书源搜索到匹配书籍');
      }
      targetBookUrl = target.bookUrl.trim();
    }
    if (targetBookUrl.isEmpty) {
      return BookshelfCatalogUpdateItemResult.failed('详情链接为空，无法更新目录');
    }

    BookDetail? detail;
    try {
      detail = await engine.getBookInfo(
        source,
        targetBookUrl,
        clearRuntimeVariables: true,
      );
    } catch (_) {
      // legacy 语义：详情刷新失败不阻断目录刷新，继续使用 targetBookUrl 拉取目录。
    }

    final primaryTocUrl = detail?.tocUrl.trim().isNotEmpty == true
        ? detail!.tocUrl.trim()
        : targetBookUrl;
    if (primaryTocUrl.isEmpty) {
      return BookshelfCatalogUpdateItemResult.failed('目录地址为空，无法更新目录');
    }

    List<TocItem> remoteToc;
    try {
      remoteToc = await _fetchTocWithFallback(
        engine: engine,
        source: source,
        primaryTocUrl: primaryTocUrl,
        fallbackTocUrl: targetBookUrl,
      );
    } catch (e) {
      return BookshelfCatalogUpdateItemResult.failed(
        '目录解析失败：${_compactReason(e.toString())}',
      );
    }

    if (remoteToc.isEmpty) {
      return BookshelfCatalogUpdateItemResult.failed('目录为空（可能是 ruleToc 不匹配）');
    }

    final chapters = _buildStoredChapters(
      chapterRepo: chapterRepo,
      bookId: latestBook.id,
      toc: remoteToc,
    );
    if (chapters.isEmpty) {
      return BookshelfCatalogUpdateItemResult.failed('目录解析失败：章节名或章节链接为空');
    }

    try {
      await chapterRepo.clearChaptersForBook(latestBook.id);
      await chapterRepo.addChapters(chapters);

      final storedBook = bookRepo.getBookById(latestBook.id) ?? latestBook;
      final maxChapter = chapters.length - 1;
      await bookRepo.updateBook(
        storedBook.copyWith(
          title: _pickFirstNonEmpty([detail?.name, storedBook.title]) ??
              storedBook.title,
          author: _pickFirstNonEmpty([detail?.author, storedBook.author]) ??
              storedBook.author,
          coverUrl: _pickFirstNonEmpty([
                detail?.coverUrl,
                storedBook.coverUrl,
              ]) ??
              storedBook.coverUrl,
          intro: _pickFirstNonEmpty([
                detail?.intro,
                storedBook.intro,
              ]) ??
              storedBook.intro,
          sourceId: source.bookSourceUrl,
          sourceUrl: source.bookSourceUrl,
          bookUrl: _pickFirstNonEmpty([
                detail?.bookUrl,
                targetBookUrl,
                storedBook.bookUrl,
              ]) ??
              storedBook.bookUrl,
          latestChapter: _pickFirstNonEmpty([
                detail?.lastChapter,
                remoteToc.last.name,
                storedBook.latestChapter,
              ]) ??
              storedBook.latestChapter,
          totalChapters: chapters.length,
          currentChapter:
              storedBook.currentChapter.clamp(0, maxChapter).toInt(),
        ),
      );
      return BookshelfCatalogUpdateItemResult.success();
    } catch (e) {
      return BookshelfCatalogUpdateItemResult.failed(
        '目录写入失败：${_compactReason(e.toString())}',
      );
    }
  }

  Future<BookshelfCatalogUpdateSummary> updateBooks(
    Iterable<Book> books, {
    void Function(String bookId, bool updating)? onBookUpdatingChanged,
  }) async {
    final requested = books.toList(growable: false);
    final candidates =
        requested.where((book) => !book.isLocal).toList(growable: false);

    var successCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    final failedDetails = <String>[];

    for (final book in candidates) {
      onBookUpdatingChanged?.call(book.id, true);
      BookshelfCatalogUpdateItemResult result;
      try {
        final override = _singleBookUpdaterOverride;
        result = override != null
            ? await override(book)
            : await _updateSingleBook(book);
      } catch (e) {
        result = BookshelfCatalogUpdateItemResult.failed(
          '更新异常：${_compactReason(e.toString())}',
        );
      } finally {
        onBookUpdatingChanged?.call(book.id, false);
      }

      switch (result.status) {
        case BookshelfCatalogUpdateItemStatus.success:
          successCount++;
          break;
        case BookshelfCatalogUpdateItemStatus.skipped:
          skippedCount++;
          break;
        case BookshelfCatalogUpdateItemStatus.failed:
          failedCount++;
          final reason = (result.message ?? '未知错误').trim();
          failedDetails.add('${book.title}：$reason');
          break;
      }
    }

    return BookshelfCatalogUpdateSummary(
      totalRequestedCount: requested.length,
      updateCandidateCount: candidates.length,
      successCount: successCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      failedDetails: failedDetails,
    );
  }
}
