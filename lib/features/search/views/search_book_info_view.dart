import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../bookshelf/models/book.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../reader/services/reader_source_switch_helper.dart';
import '../../reader/views/simple_reader_view.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';

/// 搜索/发现结果详情页（对标 legado：点击结果先进入详情，再决定阅读/加书架/目录）。
/// 也可从书架进入：若历史数据缺少 bookUrl，则降级展示缓存信息。
class SearchBookInfoView extends StatefulWidget {
  final SearchResult result;
  final Book? bookshelfBook;

  const SearchBookInfoView({
    super.key,
    required this.result,
  }) : bookshelfBook = null;

  const SearchBookInfoView._({
    super.key,
    required this.result,
    required this.bookshelfBook,
  });

  factory SearchBookInfoView.fromBookshelf({
    Key? key,
    required Book book,
  }) {
    final sourceUrl = (book.sourceUrl ?? book.sourceId ?? '').trim();
    return SearchBookInfoView._(
      key: key,
      bookshelfBook: book,
      result: SearchResult(
        name: book.title,
        author: book.author,
        coverUrl: (book.coverUrl ?? '').trim(),
        intro: (book.intro ?? '').trim(),
        kind: '',
        lastChapter: (book.latestChapter ?? '').trim(),
        updateTime: '',
        wordCount: '',
        bookUrl: (book.bookUrl ?? '').trim(),
        sourceUrl: sourceUrl,
        sourceName: sourceUrl,
      ),
    );
  }

  @override
  State<SearchBookInfoView> createState() => _SearchBookInfoViewState();
}

class _SearchBookInfoViewState extends State<SearchBookInfoView> {
  static const _uuid = Uuid();

  late final RuleParserEngine _engine;
  late final SourceRepository _sourceRepo;
  late final BookRepository _bookRepo;
  late final ChapterRepository _chapterRepo;
  late final BookAddService _addService;

  late SearchResult _activeResult;
  BookSource? _source;
  BookDetail? _detail;
  List<TocItem> _toc = const <TocItem>[];

  String? _bookId;
  bool _inBookshelf = false;
  bool _loading = true;
  bool _loadingToc = false;
  bool _shelfBusy = false;
  bool _switchingSource = false;
  bool _introExpanded = false;
  String? _error;
  String? _tocError;

  bool get _isBookshelfEntry => widget.bookshelfBook != null;

  bool get _canFetchOnlineDetail {
    return _activeResult.sourceUrl.trim().isNotEmpty &&
        _activeResult.bookUrl.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _engine = RuleParserEngine();
    _sourceRepo = SourceRepository(db);
    _bookRepo = BookRepository(db);
    _chapterRepo = ChapterRepository(db);
    _addService = BookAddService(database: db, engine: _engine);
    _activeResult = widget.result;
    _loadContext();
  }

  String _compactReason(String text, {int maxLength = 120}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  String _normalize(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _buildEphemeralSessionId() {
    return _uuid.v5(
      Namespace.url.value,
      'ephemeral|${_activeResult.sourceUrl.trim()}|${_activeResult.bookUrl.trim()}',
    );
  }

  List<Chapter> _buildEphemeralChapters(String sessionId) {
    final seen = <String>{};
    final chapters = <Chapter>[];
    for (final item in _toc) {
      final title = item.name.trim();
      final url = item.url.trim();
      if (title.isEmpty || url.isEmpty) continue;
      if (!seen.add(url)) continue;
      final id =
          _uuid.v5(Namespace.url.value, '$sessionId|${chapters.length}|$url');
      chapters.add(
        Chapter(
          id: id,
          bookId: sessionId,
          title: title,
          url: url,
          index: chapters.length,
        ),
      );
    }
    return chapters;
  }

  List<TocItem> _loadStoredToc(String bookId) {
    final chapters = _chapterRepo.getChaptersForBook(bookId)
      ..sort((a, b) => a.index.compareTo(b.index));
    return chapters
        .map(
          (chapter) => TocItem(
            index: chapter.index,
            name: chapter.title,
            url: (chapter.url ?? '').trim(),
          ),
        )
        .toList(growable: false);
  }

  List<Chapter> _buildStoredChapters({
    required String bookId,
    required List<TocItem> toc,
  }) {
    final previousByUrl = <String, Chapter>{};
    for (final chapter in _chapterRepo.getChaptersForBook(bookId)) {
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

  BookDetail _buildFallbackDetail(Book book) {
    return BookDetail(
      name: book.title,
      author: book.author,
      coverUrl: (book.coverUrl ?? '').trim(),
      intro: (book.intro ?? '').trim(),
      kind: '',
      lastChapter: (book.latestChapter ?? '').trim(),
      updateTime: '',
      wordCount: '',
      tocUrl: '',
      bookUrl: (book.bookUrl ?? '').trim(),
    );
  }

  Future<List<TocItem>> _fetchTocWithFallback({
    required BookSource source,
    required String primaryTocUrl,
    required String fallbackTocUrl,
  }) async {
    var toc = await _engine.getToc(
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

    toc = await _engine.getToc(
      source,
      normalizedFallback,
      clearRuntimeVariables: false,
    );
    return toc;
  }

  void _refreshBookshelfState() {
    if (_isBookshelfEntry) {
      final id = widget.bookshelfBook!.id;
      _bookId = id;
      _inBookshelf = _bookRepo.hasBook(id);
      return;
    }

    _bookId = _addService.buildBookId(_activeResult);
    _inBookshelf = _addService.isInBookshelf(_activeResult);
  }

  Future<bool> _loadContext({bool silent = false}) async {
    _refreshBookshelfState();

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadingToc = true;
        _error = null;
        _tocError = null;
        _introExpanded = false;
      });
    }

    final shelfBook = widget.bookshelfBook;

    if (shelfBook != null && !_canFetchOnlineDetail) {
      final sourceUrl =
          (shelfBook.sourceUrl ?? shelfBook.sourceId ?? '').trim();
      final source =
          sourceUrl.isEmpty ? null : _sourceRepo.getSourceByUrl(sourceUrl);
      final toc = _loadStoredToc(shelfBook.id);

      if (!mounted) return false;
      _refreshBookshelfState();
      setState(() {
        _source = source;
        _detail = _buildFallbackDetail(shelfBook);
        _toc = toc;
        _loading = false;
        _loadingToc = false;
        _error = '该书缺少详情链接，已降级为书架缓存信息模式';
        _tocError = toc.isEmpty ? '目录为空（书架缓存中无章节）' : null;
      });
      return false;
    }

    final source = _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
    if (source == null) {
      if (!mounted) return false;
      _refreshBookshelfState();

      final fallbackBookId = _bookId?.trim() ?? '';
      final fallbackDetail =
          shelfBook != null ? _buildFallbackDetail(shelfBook) : null;
      final fallbackToc = shelfBook != null
          ? _loadStoredToc(shelfBook.id)
          : (_inBookshelf && fallbackBookId.isNotEmpty)
              ? _loadStoredToc(fallbackBookId)
              : const <TocItem>[];
      setState(() {
        _source = null;
        _detail = fallbackDetail;
        _toc = fallbackToc;
        _loading = false;
        _loadingToc = false;
        _error = shelfBook != null ? '书源不存在或已被删除，已展示书架缓存信息' : '书源不存在或已被删除';
        _tocError = fallbackToc.isEmpty ? '无法获取目录' : null;
      });
      return false;
    }

    BookDetail? detail;
    String? detailError;
    try {
      detail = await _engine.getBookInfo(
        source,
        _activeResult.bookUrl,
        clearRuntimeVariables: true,
      );
      if (detail == null) {
        detailError = '详情解析失败：未获取到可用字段';
      }
    } catch (e) {
      detailError = '详情解析失败：${_compactReason(e.toString())}';
    }

    final primaryTocUrl = (detail?.tocUrl.trim().isNotEmpty == true)
        ? detail!.tocUrl.trim()
        : _activeResult.bookUrl.trim();

    List<TocItem> toc = const <TocItem>[];
    String? tocError;
    try {
      toc = await _fetchTocWithFallback(
        source: source,
        primaryTocUrl: primaryTocUrl,
        fallbackTocUrl: _activeResult.bookUrl,
      );
      if (toc.isEmpty) {
        tocError = '目录为空（可能是 ruleToc 不匹配）';
      }
    } catch (e) {
      tocError = '目录解析失败：${_compactReason(e.toString())}';
    }

    if (!mounted) return false;

    _refreshBookshelfState();
    final useBookshelfToc =
        _inBookshelf && _bookId != null && _bookId!.trim().isNotEmpty;
    final localToc =
        useBookshelfToc ? _loadStoredToc(_bookId!.trim()) : const <TocItem>[];
    setState(() {
      _source = source;
      _detail = detail ??
          (shelfBook != null ? _buildFallbackDetail(shelfBook) : null);
      _toc = useBookshelfToc ? localToc : toc;
      _loading = false;
      _loadingToc = false;
      _error = detailError;
      _tocError = useBookshelfToc
          ? (localToc.isEmpty ? '目录为空（书架缓存中无章节，请先刷新目录）' : null)
          : tocError;
    });

    return detailError == null;
  }

  String get _displayName {
    final fromDetail = _detail?.name.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    return _activeResult.name.trim();
  }

  String get _displayAuthor {
    final fromDetail = _detail?.author.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    final fromResult = _activeResult.author.trim();
    return fromResult.isNotEmpty ? fromResult : '未知作者';
  }

  String get _displayCoverUrl {
    final fromDetail = _detail?.coverUrl.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    return _activeResult.coverUrl.trim();
  }

  String get _displayIntro {
    final fromDetail = _detail?.intro.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    final fromResult = _activeResult.intro.trim();
    return fromResult.isNotEmpty ? fromResult : '暂无简介';
  }

  String get _displaySourceName {
    final fromSource = _source?.bookSourceName.trim() ?? '';
    if (fromSource.isNotEmpty) return fromSource;

    final fromResult = _activeResult.sourceName.trim();
    if (fromResult.isNotEmpty) return fromResult;

    final sourceUrl = (widget.bookshelfBook?.sourceUrl ??
            widget.bookshelfBook?.sourceId ??
            _activeResult.sourceUrl)
        .trim();
    return sourceUrl.isNotEmpty ? sourceUrl : '未知来源';
  }

  String? _pickFirstNonEmpty(List<String> candidates) {
    for (final raw in candidates) {
      final value = raw.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _toggleShelf() async {
    if (_shelfBusy) return;
    setState(() => _shelfBusy = true);
    try {
      if (_inBookshelf) {
        final id = _bookId;
        if (id == null || id.trim().isEmpty) {
          _showMessage('当前书籍 ID 无效，无法移出书架');
          return;
        }
        await _bookRepo.deleteBook(id);
        if (!mounted) return;
        setState(() {
          _inBookshelf = false;
        });
        _showMessage('已移出书架');
        return;
      }

      if (!_canFetchOnlineDetail) {
        _showMessage('当前书籍缺少详情链接，无法加入书架');
        return;
      }

      final addResult = await _addService.addFromSearchResult(_activeResult);
      if (!mounted) return;
      setState(() {
        _inBookshelf = addResult.success || addResult.alreadyExists;
        if (addResult.bookId != null && addResult.bookId!.trim().isNotEmpty) {
          _bookId = addResult.bookId;
        }
      });
      _showMessage(addResult.message);
    } finally {
      if (mounted) {
        setState(() => _shelfBusy = false);
      }
    }
  }

  Future<void> _openReader({int initialChapter = 0}) async {
    if (_inBookshelf) {
      final id = _bookId;
      if (id != null && id.trim().isNotEmpty) {
        final stored = _bookRepo.getBookById(id);
        if (stored != null) {
          final localChapters = _chapterRepo.getChaptersForBook(stored.id)
            ..sort((a, b) => a.index.compareTo(b.index));
          if (localChapters.isEmpty) {
            if (!mounted) return;
            setState(() {
              _toc = const <TocItem>[];
              _tocError = '目录为空（书架缓存中无章节，请先刷新目录）';
            });
            _showMessage('目录为空，请先刷新目录');
            return;
          }
          final maxChapter = localChapters.length - 1;
          if (stored.totalChapters != localChapters.length ||
              stored.currentChapter > maxChapter) {
            await _bookRepo.updateBook(
              stored.copyWith(
                totalChapters: localChapters.length,
                currentChapter:
                    stored.currentChapter.clamp(0, maxChapter).toInt(),
              ),
            );
          }
          if (!mounted) return;
          await Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              builder: (_) => SimpleReaderView(
                bookId: stored.id,
                bookTitle: stored.title,
                initialChapter: initialChapter.clamp(0, maxChapter),
              ),
            ),
          );
          if (!mounted) return;
          setState(_refreshBookshelfState);
          return;
        }
      }
      if (!mounted) return;
      setState(() => _inBookshelf = false);
    }

    if (_toc.isEmpty) {
      final tip = _loadingToc ? '目录还在加载中，请稍后' : (_tocError ?? '目录为空，无法开始阅读');
      _showMessage(tip);
      return;
    }

    final sessionId = _buildEphemeralSessionId();
    final chapters = _buildEphemeralChapters(sessionId);
    if (chapters.isEmpty) {
      _showMessage('目录为空，无法开始阅读');
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => SimpleReaderView.ephemeral(
          sessionId: sessionId,
          bookTitle: _displayName,
          initialChapter: initialChapter.clamp(0, chapters.length - 1),
          initialBookAuthor: _displayAuthor,
          initialBookCoverUrl: _displayCoverUrl,
          initialSourceUrl: _activeResult.sourceUrl,
          initialSourceName: _displaySourceName,
          initialChapters: chapters,
        ),
      ),
    );

    if (!mounted) return;
    setState(_refreshBookshelfState);
  }

  Future<void> _openToc() async {
    var tocToOpen = _toc;
    if (_inBookshelf && _bookId != null) {
      final localToc = _loadStoredToc(_bookId!.trim());
      tocToOpen = localToc;
      if (mounted) {
        setState(() {
          _toc = localToc;
          _tocError = localToc.isEmpty ? '目录为空（书架缓存中无章节，请先刷新目录）' : null;
        });
      }
    }

    if (tocToOpen.isEmpty) {
      final tip = _loadingToc ? '目录还在加载中，请稍后' : (_tocError ?? '目录为空，无法打开目录');
      _showMessage(tip);
      return;
    }

    final selected = await Navigator.of(context, rootNavigator: true).push<int>(
      CupertinoPageRoute(
        builder: (_) => _SearchBookTocView(
          bookTitle: _displayName,
          toc: tocToOpen,
          sourceName: _displaySourceName,
        ),
      ),
    );
    if (selected == null) return;
    await _openReader(initialChapter: selected);
  }

  Future<void> _refreshBookshelfToc() async {
    if (_loadingToc) return;
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) {
      await _loadContext();
      return;
    }
    if (!_canFetchOnlineDetail) {
      _showMessage('当前书籍缺少详情链接，无法刷新目录');
      return;
    }

    final source =
        _source ?? _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
    if (source == null) {
      _showMessage('书源不存在或已被删除，无法刷新目录');
      return;
    }

    if (mounted) {
      setState(() {
        _loadingToc = true;
        _tocError = null;
      });
    }

    BookDetail? detail = _detail;
    List<TocItem> remoteToc = const <TocItem>[];
    String? tocRefreshError;

    try {
      final refreshedDetail = await _engine.getBookInfo(
        source,
        _activeResult.bookUrl,
        clearRuntimeVariables: true,
      );
      if (refreshedDetail != null) {
        detail = refreshedDetail;
      }
    } catch (_) {
      // 详情刷新失败不阻断目录刷新流程，保持已有详情字段。
    }

    final primaryTocUrl = (detail?.tocUrl.trim().isNotEmpty == true)
        ? detail!.tocUrl.trim()
        : _activeResult.bookUrl.trim();
    if (primaryTocUrl.isEmpty) {
      tocRefreshError = '目录地址为空，无法刷新目录';
    } else {
      try {
        remoteToc = await _fetchTocWithFallback(
          source: source,
          primaryTocUrl: primaryTocUrl,
          fallbackTocUrl: _activeResult.bookUrl,
        );
        if (remoteToc.isEmpty) {
          tocRefreshError = '目录为空（可能是 ruleToc 不匹配）';
        }
      } catch (e) {
        tocRefreshError = '目录解析失败：${_compactReason(e.toString())}';
      }
    }

    if (remoteToc.isNotEmpty) {
      final chapters = _buildStoredChapters(bookId: id, toc: remoteToc);
      if (chapters.isEmpty) {
        tocRefreshError = '目录解析失败：章节名或章节链接为空';
      } else {
        try {
          await _chapterRepo.clearChaptersForBook(id);
          await _chapterRepo.addChapters(chapters);

          final storedBook = _bookRepo.getBookById(id);
          if (storedBook != null) {
            final maxChapter = chapters.length - 1;
            await _bookRepo.updateBook(
              storedBook.copyWith(
                title: _pickFirstNonEmpty(
                        [detail?.name ?? '', storedBook.title]) ??
                    storedBook.title,
                author: _pickFirstNonEmpty(
                        [detail?.author ?? '', storedBook.author]) ??
                    storedBook.author,
                coverUrl: _pickFirstNonEmpty(
                      [detail?.coverUrl ?? '', storedBook.coverUrl ?? ''],
                    ) ??
                    storedBook.coverUrl,
                intro: _pickFirstNonEmpty(
                      [detail?.intro ?? '', storedBook.intro ?? ''],
                    ) ??
                    storedBook.intro,
                sourceId: source.bookSourceUrl,
                sourceUrl: source.bookSourceUrl,
                bookUrl: _pickFirstNonEmpty([
                      detail?.bookUrl ?? '',
                      _activeResult.bookUrl,
                      storedBook.bookUrl ?? '',
                    ]) ??
                    storedBook.bookUrl,
                latestChapter: _pickFirstNonEmpty([
                      detail?.lastChapter ?? '',
                      remoteToc.last.name,
                      storedBook.latestChapter ?? '',
                    ]) ??
                    storedBook.latestChapter,
                totalChapters: chapters.length,
                currentChapter:
                    storedBook.currentChapter.clamp(0, maxChapter).toInt(),
              ),
            );
          }
        } catch (e) {
          tocRefreshError = '目录写入失败：${_compactReason(e.toString())}';
        }
      }
    }

    final localToc = _loadStoredToc(id);
    if (!mounted) return;
    setState(() {
      _source = source;
      if (detail != null) {
        _detail = detail;
      }
      _toc = localToc;
      _loadingToc = false;
      _tocError = localToc.isEmpty
          ? (tocRefreshError ?? '目录为空（书架缓存中无章节，请先刷新目录）')
          : null;
    });

    if (localToc.isNotEmpty && tocRefreshError == null) {
      _showMessage('目录已刷新（共 ${localToc.length} 章）');
    } else if (tocRefreshError != null) {
      _showMessage(tocRefreshError);
    }
  }

  Future<void> _showMoreActions() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(_displayName),
        actions: [
          if (_inBookshelf)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _refreshBookshelfToc();
              },
              child: const Text('刷新目录'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              if (!_canFetchOnlineDetail) {
                _showMessage('当前书籍缺少详情链接，无法刷新详情');
                return;
              }
              _loadContext();
            },
            child: const Text('刷新详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              if (_switchingSource) return;
              Navigator.pop(sheetContext);
              _switchSource();
            },
            child: const Text('换源'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  SearchResult _copyResultWithSource(SearchResult value, BookSource source) {
    return SearchResult(
      name: value.name,
      author: value.author,
      coverUrl: value.coverUrl,
      intro: value.intro,
      kind: value.kind,
      lastChapter: value.lastChapter,
      updateTime: value.updateTime,
      wordCount: value.wordCount,
      bookUrl: value.bookUrl,
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
    );
  }

  Future<void> _switchSource() async {
    if (_switchingSource) return;

    if (!_canFetchOnlineDetail) {
      _showMessage('当前书籍缺少详情链接，无法换源');
      return;
    }

    final keyword = _displayName.trim();
    final authorKeyword = _displayAuthor.trim();
    if (keyword.isEmpty) {
      _showMessage('书名为空，无法换源');
      return;
    }

    final enabledSources = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled)
        .toList(growable: false);
    if (enabledSources.isEmpty) {
      _showMessage('没有可用书源');
      return;
    }
    final orderedSources = enabledSources
        .asMap()
        .entries
        .toList(growable: false)
      ..sort((a, b) {
        final orderCompare = a.value.customOrder.compareTo(b.value.customOrder);
        if (orderCompare != 0) return orderCompare;
        return a.key.compareTo(b.key);
      });
    final sortedEnabledSources =
        orderedSources.map((entry) => entry.value).toList(growable: false);

    setState(() => _switchingSource = true);
    final searchResults = <SearchResult>[];
    for (final source in sortedEnabledSources) {
      try {
        final list = await _engine.search(
          source,
          keyword,
          filter: (name, author) {
            if (name != keyword) return false;
            if (authorKeyword.isEmpty) return true;
            return author.contains(authorKeyword);
          },
        );
        for (final item in list) {
          searchResults.add(_copyResultWithSource(item, source));
        }
      } catch (_) {
        // 单源失败隔离，不中断全局候选搜集。
      }
    }

    final currentBook = Book(
      id: _bookId ?? _buildEphemeralSessionId(),
      title: _displayName,
      author: _displayAuthor,
      sourceId: _activeResult.sourceUrl,
      sourceUrl: _activeResult.sourceUrl,
      bookUrl: _activeResult.bookUrl,
      latestChapter: _pickFirstNonEmpty([
        _detail?.lastChapter ?? '',
        _activeResult.lastChapter,
      ]),
      totalChapters: _toc.length,
      currentChapter: 0,
      readProgress: 0,
      isLocal: false,
    );

    final candidates = ReaderSourceSwitchHelper.buildCandidates(
      currentBook: currentBook,
      enabledSources: sortedEnabledSources,
      searchResults: searchResults,
    );

    if (!mounted) return;
    setState(() => _switchingSource = false);

    if (candidates.isEmpty) {
      _showMessage('未找到可切换的匹配书源');
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text('换源（$keyword）'),
        message: const Text('按“书名匹配 + 作者优先”筛选候选'),
        actions: [
          for (final candidate in candidates.take(16))
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _applySourceCandidate(candidate);
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${candidate.source.bookSourceName} · ${candidate.book.author}',
                  textAlign: TextAlign.left,
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _applySourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final previousResult = _activeResult;
    final nextResult = _copyResultWithSource(candidate.book, candidate.source);

    if (_normalize(nextResult.sourceUrl) ==
            _normalize(previousResult.sourceUrl) &&
        _normalize(nextResult.bookUrl) == _normalize(previousResult.bookUrl)) {
      _showMessage('已是当前书源');
      return;
    }

    setState(() {
      _activeResult = nextResult;
      _detail = null;
      _toc = const <TocItem>[];
      _error = null;
      _tocError = null;
      _loading = true;
      _loadingToc = true;
    });

    final loaded = await _loadContext(silent: true);
    if (!loaded) {
      if (!mounted) return;
      setState(() {
        _activeResult = previousResult;
      });
      await _loadContext();
      _showMessage('换源失败，已回退到原书源');
      return;
    }

    if (!mounted) return;
    _showMessage('已切换到：${candidate.source.bookSourceName}');
  }

  void _showMessage(String message) {
    showShadDialog<void>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('提示'),
        description: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(message),
        ),
        actions: [
          ShadButton(
            child: const Text('好'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final warningColor = CupertinoColors.systemOrange.resolveFrom(context);
    final coverUrl = _displayCoverUrl;

    final kind = _pickFirstNonEmpty([
      _detail?.kind ?? '',
      _activeResult.kind,
    ]);
    final updateTime = _pickFirstNonEmpty([
      _detail?.updateTime ?? '',
      _activeResult.updateTime,
    ]);
    final wordCount = _pickFirstNonEmpty([
      _detail?.wordCount ?? '',
      _activeResult.wordCount,
    ]);
    final lastChapter = _pickFirstNonEmpty([
      _detail?.lastChapter ?? '',
      _activeResult.lastChapter,
    ]);

    return AppCupertinoPageScaffold(
      title: '书籍详情',
      includeTopSafeArea: false,
      includeBottomSafeArea: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: (_loading || !_canFetchOnlineDetail)
                ? null
                : () {
                    if (_inBookshelf) {
                      _refreshBookshelfToc();
                    } else {
                      _loadContext();
                    }
                  },
            child: const Icon(CupertinoIcons.refresh),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showMoreActions,
            child: _switchingSource
                ? const CupertinoActivityIndicator(radius: 9)
                : const Icon(CupertinoIcons.ellipsis_circle),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: 286,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _HeroBackground(
                          coverUrl: coverUrl,
                          title: _displayName,
                          author: _displayAuthor,
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                CupertinoColors.black.withValues(alpha: 0.32),
                                CupertinoColors.black.withValues(alpha: 0.12),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: scheme.background,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.elliptical(320, 72),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 34,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: scheme.background,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.black.withValues(
                                    alpha: 0.24,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: AppCoverImage(
                              urlOrPath: coverUrl,
                              title: _displayName,
                              author: _displayAuthor,
                              width: 110,
                              height: 160,
                              borderRadius: 8,
                              showTextOnPlaceholder: false,
                            ),
                          ),
                        ),
                      ),
                      if (_loading)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: ShadCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CupertinoActivityIndicator(radius: 7),
                                const SizedBox(width: 6),
                                Text(
                                  '加载中',
                                  style: theme.textTheme.small,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.h3.copyWith(
                          color: scheme.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (kind != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: _StatusChip(
                            label: kind,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ShadCard(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          children: [
                            _MetaLine(
                              icon: CupertinoIcons.person,
                              text: '作者：$_displayAuthor',
                            ),
                            _MetaLine(
                              icon: CupertinoIcons.globe,
                              text: '来源：$_displaySourceName',
                              trailing: _canFetchOnlineDetail
                                  ? CupertinoButton(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      minimumSize: const Size(28, 28),
                                      onPressed: _switchingSource
                                          ? null
                                          : _switchSource,
                                      child: const Text('换源'),
                                    )
                                  : null,
                            ),
                            _MetaLine(
                              icon: CupertinoIcons.book,
                              text: '最新：${lastChapter ?? '暂无'}',
                            ),
                            _MetaLine(
                              icon: CupertinoIcons.collections,
                              text: '目录：${_toc.length} 章',
                              trailing: CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                minimumSize: const Size(28, 28),
                                onPressed: _loadingToc ? null : _openToc,
                                child: Text(_loadingToc ? '加载中' : '查看'),
                              ),
                            ),
                            if (updateTime != null)
                              _MetaLine(
                                icon: CupertinoIcons.clock,
                                text: '更新：$updateTime',
                              ),
                            if (wordCount != null)
                              _MetaLine(
                                icon: CupertinoIcons.doc_text,
                                text: '字数：$wordCount',
                                isLast: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ShadCard(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '简介',
                              style: theme.textTheme.p.copyWith(
                                color: scheme.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _displayIntro,
                              maxLines: _introExpanded ? null : 4,
                              overflow: _introExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                color: scheme.foreground,
                              ),
                            ),
                            if (_displayIntro.trim().length > 90) ...[
                              const SizedBox(height: 6),
                              ShadButton.link(
                                onPressed: () {
                                  setState(() {
                                    _introExpanded = !_introExpanded;
                                  });
                                },
                                child: Text(_introExpanded ? '收起简介' : '展开简介'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_inBookshelf || _switchingSource) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (_inBookshelf)
                              _StatusChip(
                                label: '已在书架',
                                color: scheme.primary,
                              ),
                            if (_switchingSource)
                              _StatusChip(
                                label: '换源中',
                                color: warningColor,
                              ),
                          ],
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        ShadCard(
                          border: ShadBorder.all(
                              color: scheme.destructive, width: 1),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Text(
                            _error!,
                            style: theme.textTheme.small.copyWith(
                              color: scheme.destructive,
                            ),
                          ),
                        ),
                      ],
                      if (_tocError != null) ...[
                        const SizedBox(height: 10),
                        ShadCard(
                          border: ShadBorder.all(color: warningColor, width: 1),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Text(
                            _tocError!,
                            style: theme.textTheme.small.copyWith(
                              color: warningColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: scheme.background,
              border: Border(
                top: BorderSide(
                  color: scheme.border,
                  width: 0.6,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              math.max(8, MediaQuery.paddingOf(context).bottom),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ShadButton.ghost(
                    onPressed: _shelfBusy ? null : _toggleShelf,
                    leading: _shelfBusy
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CupertinoActivityIndicator(radius: 7),
                          )
                        : null,
                    child: Text(_inBookshelf ? '移出书架' : '加入书架'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShadButton(
                    onPressed: (_loading || _loadingToc)
                        ? null
                        : () => _openReader(initialChapter: 0),
                    child: const Text('开始阅读'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  final String coverUrl;
  final String title;
  final String author;

  const _HeroBackground({
    required this.coverUrl,
    required this.title,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    return AppCoverImage(
      urlOrPath: coverUrl,
      title: title,
      author: author,
      width: double.infinity,
      height: double.infinity,
      borderRadius: 0,
      fit: BoxFit.cover,
      showTextOnPlaceholder: false,
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;
  final bool isLast;

  const _MetaLine({
    required this.icon,
    required this.text,
    this.trailing,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.border.withValues(alpha: 0.6),
                  width: 0.5,
                ),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.small.copyWith(
                color: scheme.foreground,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.small.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchBookTocView extends StatefulWidget {
  final String bookTitle;
  final String sourceName;
  final List<TocItem> toc;

  const _SearchBookTocView({
    required this.bookTitle,
    required this.sourceName,
    required this.toc,
  });

  @override
  State<_SearchBookTocView> createState() => _SearchBookTocViewState();
}

class _SearchBookTocViewState extends State<_SearchBookTocView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _reversed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<int, TocItem>> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    var entries = widget.toc.asMap().entries.toList(growable: false);
    if (q.isNotEmpty) {
      entries = entries
          .where((e) => e.value.name.toLowerCase().contains(q))
          .toList(growable: false);
    }
    if (_reversed) {
      entries = entries.reversed.toList(growable: false);
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _filtered;

    return AppCupertinoPageScaffold(
      title: '目录',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.bookTitle} · ${widget.sourceName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  color: scheme.mutedForeground,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ShadInput(
                    controller: _searchController,
                    placeholder: const Text('搜索章节'),
                    leading: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(LucideIcons.search, size: 14),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.ghost(
                  onPressed: () => setState(() => _reversed = !_reversed),
                  child: Icon(
                    _reversed
                        ? LucideIcons.arrowDownWideNarrow
                        : LucideIcons.arrowUpWideNarrow,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchQuery.trim().isEmpty
                    ? '共 ${widget.toc.length} 章'
                    : '匹配 ${filtered.length} 章',
                style: theme.textTheme.small.copyWith(
                  color: scheme.mutedForeground,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                final chapter = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(entry.key),
                    child: ShadCard(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: scheme.mutedForeground,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${entry.key + 1}',
                              style: theme.textTheme.small.copyWith(
                                color: scheme.mutedForeground,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              chapter.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.p.copyWith(
                                color: scheme.foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
