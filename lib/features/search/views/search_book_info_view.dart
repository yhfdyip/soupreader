import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_cover_image.dart';
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
class SearchBookInfoView extends StatefulWidget {
  final SearchResult result;

  const SearchBookInfoView({
    super.key,
    required this.result,
  });

  @override
  State<SearchBookInfoView> createState() => _SearchBookInfoViewState();
}

class _SearchBookInfoViewState extends State<SearchBookInfoView> {
  static const _uuid = Uuid();

  late final RuleParserEngine _engine;
  late final SourceRepository _sourceRepo;
  late final BookRepository _bookRepo;
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

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _engine = RuleParserEngine();
    _sourceRepo = SourceRepository(db);
    _bookRepo = BookRepository(db);
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
    _bookId = _addService.buildBookId(_activeResult);
    _inBookshelf = _addService.isInBookshelf(_activeResult);
  }

  Future<bool> _loadContext({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadingToc = true;
        _error = null;
        _tocError = null;
        _introExpanded = false;
      });
    }

    final source = _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
    if (source == null) {
      if (!mounted) return false;
      _refreshBookshelfState();
      setState(() {
        _source = null;
        _detail = null;
        _toc = const <TocItem>[];
        _loading = false;
        _loadingToc = false;
        _error = '书源不存在或已被删除';
        _tocError = '无法获取目录';
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
    setState(() {
      _source = source;
      _detail = detail;
      _toc = toc;
      _loading = false;
      _loadingToc = false;
      _error = detailError;
      _tocError = tocError;
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
    return _activeResult.sourceName;
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
    if (_toc.isEmpty) {
      final tip = _loadingToc ? '目录还在加载中，请稍后' : (_tocError ?? '目录为空，无法开始阅读');
      _showMessage(tip);
      return;
    }

    if (_inBookshelf) {
      final id = _bookId;
      if (id != null && id.trim().isNotEmpty) {
        final stored = _bookRepo.getBookById(id);
        if (stored != null) {
          final maxChapter =
              stored.totalChapters > 0 ? stored.totalChapters - 1 : 0;
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
    if (_toc.isEmpty) {
      final tip = _loadingToc ? '目录还在加载中，请稍后' : (_tocError ?? '目录为空，无法打开目录');
      _showMessage(tip);
      return;
    }

    final selected = await Navigator.of(context, rootNavigator: true).push<int>(
      CupertinoPageRoute(
        builder: (_) => _SearchBookTocView(
          bookTitle: _displayName,
          toc: _toc,
          sourceName: _displaySourceName,
        ),
      ),
    );
    if (selected == null) return;
    await _openReader(initialChapter: selected);
  }

  Future<void> _showMoreActions() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(_displayName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
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

    final keyword = _displayName.trim();
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

    setState(() => _switchingSource = true);
    final searchResults = <SearchResult>[];
    for (final source in enabledSources) {
      try {
        final list = await _engine.search(source, keyword);
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
      enabledSources: enabledSources,
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
    final tocUrl = _pickFirstNonEmpty([
      _detail?.tocUrl ?? '',
    ]);

    return AppCupertinoPageScaffold(
      title: '书籍详情',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _loading ? null : () => _loadContext(),
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
          if (_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: ShadCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const CupertinoActivityIndicator(radius: 8),
                    const SizedBox(width: 8),
                    Text(
                      '正在加载详情与目录...',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                ShadCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCoverImage(
                        urlOrPath: coverUrl,
                        title: _displayName,
                        author: _displayAuthor,
                        width: 76,
                        height: 106,
                        borderRadius: 10,
                        showTextOnPlaceholder: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              style: theme.textTheme.h4.copyWith(
                                color: scheme.foreground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '作者：$_displayAuthor',
                              style: theme.textTheme.small.copyWith(
                                color: scheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '来源：$_displaySourceName',
                              style: theme.textTheme.small.copyWith(
                                color: scheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '目录：${_toc.length} 章',
                              style: theme.textTheme.small.copyWith(
                                color: scheme.mutedForeground,
                              ),
                            ),
                            if (lastChapter != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '最新：$lastChapter',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  color: scheme.mutedForeground,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
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
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ShadCard(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShadButton(
                          onPressed: (_loading || _loadingToc)
                              ? null
                              : () => _openReader(initialChapter: 0),
                          child: const Text('阅读'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ShadButton.ghost(
                          onPressed:
                              (_loading || _loadingToc) ? null : _openToc,
                          child: Text(_loadingToc ? '目录加载中' : '目录'),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                        '基础信息',
                        style: theme.textTheme.p.copyWith(
                          color: scheme.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (kind != null) _InfoRow(label: '分类', value: kind),
                      if (wordCount != null)
                        _InfoRow(label: '字数', value: wordCount),
                      if (updateTime != null)
                        _InfoRow(label: '更新', value: updateTime),
                      if (lastChapter != null)
                        _InfoRow(label: '最新章节', value: lastChapter),
                      _InfoRow(label: '详情链接', value: _activeResult.bookUrl),
                      if (tocUrl != null)
                        _InfoRow(label: '目录链接', value: tocUrl),
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
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  ShadCard(
                    border: ShadBorder.all(color: scheme.destructive, width: 1),
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
              ],
            ),
          ),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.small.copyWith(
                color: scheme.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.small.copyWith(
                color: scheme.foreground,
              ),
            ),
          ),
        ],
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
