import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../models/book.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';

class BookAddResult {
  final bool success;
  final bool alreadyExists;
  final String message;
  final String? bookId;

  const BookAddResult({
    required this.success,
    required this.alreadyExists,
    required this.message,
    required this.bookId,
  });

  factory BookAddResult.success(String bookId) {
    return BookAddResult(
      success: true,
      alreadyExists: false,
      message: '已加入书架',
      bookId: bookId,
    );
  }

  factory BookAddResult.alreadyExists(String bookId) {
    return BookAddResult(
      success: false,
      alreadyExists: true,
      message: '已在书架中',
      bookId: bookId,
    );
  }

  factory BookAddResult.error(String message) {
    return BookAddResult(
      success: false,
      alreadyExists: false,
      message: message,
      bookId: null,
    );
  }
}

/// 统一“从搜索结果加入书架”的逻辑，供搜索页/书单导入等复用。
class BookAddService {
  static const _uuid = Uuid();

  final RuleParserEngine _engine;
  final SourceRepository _sourceRepo;
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;

  BookAddService({
    DatabaseService? database,
    RuleParserEngine? engine,
  }) : this._(
          database ?? DatabaseService(),
          engine ?? RuleParserEngine(),
        );

  BookAddService._(DatabaseService db, this._engine)
      : _sourceRepo = SourceRepository(db),
        _bookRepo = BookRepository(db),
        _chapterRepo = ChapterRepository(db);

  String _compactMessage(String text, {int maxLength = 96}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}…';
  }

  bool _isSameUrl(String a, String b) {
    return a.trim() == b.trim();
  }

  String _buildBookshelfMatchKey(String name, String author) {
    final normalizedName = name.trim();
    final normalizedAuthor = author.trim();
    if (normalizedAuthor.isNotEmpty) {
      return '$normalizedName-$normalizedAuthor';
    }
    return normalizedName;
  }

  Set<String> buildSearchBookshelfKeys() {
    final keys = <String>{};
    final books = _bookRepo.getAllBooks();
    for (final book in books) {
      final name = book.title.trim();
      final author = book.author.trim();
      final bookUrl = (book.bookUrl ?? '').trim();
      if (name.isNotEmpty) {
        keys.add(name);
        keys.add(_buildBookshelfMatchKey(name, author));
      }
      if (bookUrl.isNotEmpty) {
        keys.add(bookUrl);
      }
    }
    return keys;
  }

  /// 复用与导入一致的 ID 生成规则，保证“是否已在书架”的判断稳定。
  String? buildBookId(SearchResult result) {
    final source = _sourceRepo.getSourceByUrl(result.sourceUrl);
    if (source == null) return null;
    return _uuid.v5(
      Namespace.url.value,
      '${source.bookSourceUrl}|${result.bookUrl}',
    );
  }

  bool isInBookshelf(
    SearchResult result, {
    Set<String>? bookshelfKeys,
  }) {
    final name = result.name.trim();
    final author = result.author.trim();
    final bookUrl = result.bookUrl.trim();
    if (name.isEmpty && bookUrl.isEmpty) return false;
    final keys = bookshelfKeys ?? buildSearchBookshelfKeys();
    if (name.isNotEmpty) {
      final key = _buildBookshelfMatchKey(name, author);
      if (keys.contains(key) || keys.contains(name)) {
        return true;
      }
    }
    if (bookUrl.isNotEmpty && keys.contains(bookUrl)) {
      return true;
    }
    return false;
  }

  List<Chapter> _buildChapters(String bookId, List<TocItem> tocItems) {
    final chapters = <Chapter>[];
    final seenUrls = <String>{};

    for (final item in tocItems) {
      final title = item.name.trim();
      final url = item.url.trim();
      if (title.isEmpty || url.isEmpty) continue;
      if (!seenUrls.add(url)) continue;

      final index = chapters.length;
      chapters.add(
        Chapter(
          id: _uuid.v5(
            Namespace.url.value,
            '$bookId|$index|$url',
          ),
          bookId: bookId,
          title: title,
          url: url,
          index: index,
          isDownloaded: false,
          content: null,
        ),
      );
    }

    return chapters;
  }

  Future<String> _buildTocFailureHint({
    required BookSource source,
    required String tocUrl,
  }) async {
    try {
      final debug = await _engine.getTocDebug(source, tocUrl);

      final explicitError = (debug.error ?? '').trim();
      if (explicitError.isNotEmpty) {
        return _compactMessage(explicitError);
      }

      final statusCode = debug.fetch.statusCode;
      if (statusCode != null && statusCode >= 400) {
        return '请求失败（HTTP $statusCode）';
      }

      if (debug.fetch.body != null &&
          debug.listCount > 0 &&
          debug.toc.isEmpty) {
        return '解析到目录列表 ${debug.listCount} 项，但章节名或章节链接为空';
      }
    } catch (_) {
      // ignore debug hint failure
    }

    return '';
  }

  Future<BookAddResult> addFromSearchResult(SearchResult result) async {
    String? persistedBookId;

    try {
      final source = _sourceRepo.getSourceByUrl(result.sourceUrl);
      if (source == null) {
        return BookAddResult.error('书源不存在或已被删除');
      }

      final bookId = buildBookId(result);
      if (bookId == null) {
        return BookAddResult.error('书源不存在或已被删除');
      }

      if (_bookRepo.hasBook(bookId)) {
        return BookAddResult.alreadyExists(bookId);
      }

      final detail = await _engine.getBookInfo(
        source,
        result.bookUrl,
        clearRuntimeVariables: true,
      );

      final primaryTocUrl =
          detail?.tocUrl.isNotEmpty == true ? detail!.tocUrl : result.bookUrl;
      var requestedTocUrl = primaryTocUrl;
      var tocItems = await _engine.getToc(
        source,
        requestedTocUrl,
        clearRuntimeVariables: false,
      );

      final fallbackTocUrl = result.bookUrl.trim();
      final canFallback = fallbackTocUrl.isNotEmpty &&
          !_isSameUrl(requestedTocUrl, fallbackTocUrl);

      var hasTriedBookUrlFallback = false;
      if (tocItems.isEmpty && canFallback) {
        hasTriedBookUrlFallback = true;
        requestedTocUrl = fallbackTocUrl;
        tocItems = await _engine.getToc(
          source,
          requestedTocUrl,
          clearRuntimeVariables: false,
        );
      }

      if (tocItems.isEmpty) {
        final hint = await _buildTocFailureHint(
          source: source,
          tocUrl: requestedTocUrl,
        );
        final baseMessage = hasTriedBookUrlFallback
            ? '目录解析失败：已尝试详情目录地址与书籍地址，仍未获取到有效章节'
            : '目录解析失败：未获取到有效章节';

        if (hint.isNotEmpty) {
          return BookAddResult.error('$baseMessage（$hint）');
        }
        return BookAddResult.error('$baseMessage（可能是 ruleToc 不匹配）');
      }

      final chapters = _buildChapters(bookId, tocItems);
      if (chapters.isEmpty) {
        return BookAddResult.error('目录解析失败：章节名或章节链接为空（可能是 ruleToc 不匹配）');
      }

      final book = Book(
        id: bookId,
        title: detail?.name ?? result.name,
        author: detail?.author ?? result.author,
        coverUrl: detail?.coverUrl.isNotEmpty == true
            ? detail!.coverUrl
            : result.coverUrl,
        intro: detail?.intro ?? result.intro,
        sourceId: source.bookSourceUrl,
        sourceUrl: source.bookSourceUrl,
        bookUrl: detail?.bookUrl.trim().isNotEmpty == true
            ? detail!.bookUrl.trim()
            : result.bookUrl.trim(),
        latestChapter: detail?.lastChapter ?? result.lastChapter,
        totalChapters: chapters.length,
        currentChapter: 0,
        readProgress: 0,
        lastReadTime: null,
        addedTime: DateTime.now(),
        isLocal: false,
        localPath: null,
      );

      await _bookRepo.addBook(book);
      persistedBookId = bookId;
      await _chapterRepo.addChapters(chapters);

      final storedChapterCount =
          await _chapterRepo.countChaptersForBook(bookId);
      if (storedChapterCount <= 0) {
        await _bookRepo.deleteBook(bookId);
        persistedBookId = null;
        return BookAddResult.error(
          '加入失败：章节写入失败（$storedChapterCount/${chapters.length}），请检查目录规则',
        );
      }

      if (storedChapterCount != book.totalChapters) {
        await _bookRepo.updateBook(
          book.copyWith(totalChapters: storedChapterCount),
        );
      }

      return BookAddResult.success(bookId);
    } catch (e) {
      if (persistedBookId != null) {
        try {
          await _bookRepo.deleteBook(persistedBookId);
        } catch (_) {
          // ignore rollback failure
        }
      }
      return BookAddResult.error('导入失败: ${_compactMessage(e.toString())}');
    }
  }
}
