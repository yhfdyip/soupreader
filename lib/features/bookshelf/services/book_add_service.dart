import 'package:uuid/uuid.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../models/book.dart';
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

  Future<BookAddResult> addFromSearchResult(SearchResult result) async {
    try {
      final source = _sourceRepo.getSourceByUrl(result.sourceUrl);
      if (source == null) {
        return BookAddResult.error('书源不存在或已被删除');
      }

      final bookId = _uuid.v5(
        Namespace.url.value,
        '${source.bookSourceUrl}|${result.bookUrl}',
      );

      if (_bookRepo.hasBook(bookId)) {
        return BookAddResult.alreadyExists(bookId);
      }

      final detail = await _engine.getBookInfo(
        source,
        result.bookUrl,
        clearRuntimeVariables: true,
      );
      final tocUrl =
          detail?.tocUrl.isNotEmpty == true ? detail!.tocUrl : result.bookUrl;
      final tocItems = await _engine.getToc(
        source,
        tocUrl,
        clearRuntimeVariables: false,
      );
      if (tocItems.isEmpty) {
        return BookAddResult.error('目录解析失败');
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
        latestChapter: detail?.lastChapter ?? result.lastChapter,
        totalChapters: tocItems.length,
        currentChapter: 0,
        readProgress: 0,
        lastReadTime: null,
        addedTime: DateTime.now(),
        isLocal: false,
        localPath: null,
      );

      final chapters = tocItems.map((item) {
        return Chapter(
          id: _uuid.v5(
            Namespace.url.value,
            '$bookId|${item.index}|${item.url}',
          ),
          bookId: bookId,
          title: item.name,
          url: item.url,
          index: item.index,
          isDownloaded: false,
          content: null,
        );
      }).toList();

      await _bookRepo.addBook(book);
      await _chapterRepo.addChapters(chapters);

      return BookAddResult.success(bookId);
    } catch (e) {
      return BookAddResult.error('导入失败: $e');
    }
  }
}
