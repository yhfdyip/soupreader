import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/book_variable_store.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/services/webdav_service.dart';
import '../../bookshelf/models/book.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../import/txt_parser.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/services/reader_bookmark_export_service.dart';
import '../../reader/services/reader_charset_service.dart';
import '../../reader/services/chapter_title_display_helper.dart';
import '../../reader/services/reader_source_switch_helper.dart';
import '../../reader/views/simple_reader_view.dart';
import '../../reader/widgets/source_switch_candidate_sheet.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../settings/views/app_log_dialog.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../source/services/source_login_ui_helper.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_web_verify_view.dart';
import '../services/search_book_info_edit_helper.dart';
import '../services/search_book_info_menu_helper.dart';
import '../services/search_book_info_refresh_helper.dart';
import '../services/search_book_info_share_helper.dart';
import '../services/search_book_info_top_helper.dart';
import '../services/search_book_toc_filter_helper.dart';
import 'search_book_info_edit_view.dart';

/// 搜索/发现结果详情页（对标 legado：点击结果先进入详情，再决定阅读/加书架/目录）。
/// 也可从书架进入：若历史数据缺少 bookUrl，则降级展示缓存信息。
class SearchBookInfoView extends StatefulWidget {
  final SearchResult result;
  final Book? bookshelfBook;
  final ReaderBookmarkExportService? bookmarkExportService;

  const SearchBookInfoView({
    super.key,
    required this.result,
    this.bookmarkExportService,
  }) : bookshelfBook = null;

  const SearchBookInfoView._({
    super.key,
    required this.result,
    required this.bookshelfBook,
    required this.bookmarkExportService,
  });

  factory SearchBookInfoView.fromBookshelf({
    Key? key,
    required Book book,
    ReaderBookmarkExportService? bookmarkExportService,
  }) {
    final sourceUrl = (book.sourceUrl ?? book.sourceId ?? '').trim();
    return SearchBookInfoView._(
      key: key,
      bookshelfBook: book,
      bookmarkExportService: bookmarkExportService,
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
  late final BookmarkRepository _bookmarkRepo;
  late final ChapterRepository _chapterRepo;
  late final BookAddService _addService;
  late final SettingsService _settingsService;
  late final WebDavService _webDavService;
  late final ReaderCharsetService _readerCharsetService;
  late final ReaderBookmarkExportService _bookmarkExportService;
  late final ChapterTitleDisplayHelper _chapterTitleDisplayHelper;

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
  bool _allowUpdate = true;
  bool _splitLongChapter = true;
  bool _tocUiUseReplace = false;
  bool _tocUiLoadWordCount = true;
  bool _deleteAlertEnabled = true;
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
    _bookmarkRepo = BookmarkRepository();
    _chapterRepo = ChapterRepository(db);
    _addService = BookAddService(database: db, engine: _engine);
    _settingsService = SettingsService();
    _webDavService = WebDavService();
    _readerCharsetService = ReaderCharsetService();
    _bookmarkExportService =
        widget.bookmarkExportService ?? ReaderBookmarkExportService();
    _deleteAlertEnabled = _resolveBookInfoDeleteAlertSetting();
    _chapterTitleDisplayHelper = ChapterTitleDisplayHelper(
      replaceRuleService: ReplaceRuleService(db),
    );
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
            wordCount: _resolveStoredChapterWordCount(chapter.content),
          ),
        )
        .toList(growable: false);
  }

  String? _resolveStoredChapterWordCount(String? content) {
    final words = (content ?? '').length;
    if (words <= 0) return null;
    if (words > 10000) {
      final value = (words / 10000.0)
          .toStringAsFixed(1)
          .replaceFirst(RegExp(r'\.0$'), '');
      return '$value万字';
    }
    return '$words字';
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

  void _restoreBookMenuSwitches() {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) return;
    _allowUpdate = _settingsService.getBookCanUpdate(id);
    _splitLongChapter = _settingsService.getBookSplitLongChapter(id);
  }

  Future<bool> _loadContext({bool silent = false}) async {
    _refreshBookshelfState();
    _restoreBookMenuSwitches();
    _tocUiUseReplace = _settingsService.getTocUiUseReplace();
    _tocUiLoadWordCount = _settingsService.getTocUiLoadWordCount();

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

  int _resolveChineseConverterType() {
    try {
      final rawType = _settingsService.readingSettings.chineseConverterType;
      if (ChineseConverterType.values.contains(rawType)) {
        return rawType;
      }
    } catch (_) {
      // 启动异常或测试环境下回退为关闭。
    }
    return ChineseConverterType.off;
  }

  Future<List<String>> _buildTocDisplayTitles(List<TocItem> toc) async {
    if (toc.isEmpty) return const <String>[];
    final sourceUrl = _activeResult.sourceUrl.trim();
    return _chapterTitleDisplayHelper.buildDisplayTitles(
      rawTitles: toc.map((item) => item.name).toList(growable: false),
      bookName: _displayName,
      sourceUrl: sourceUrl.isEmpty ? null : sourceUrl,
      chineseConverterType: _resolveChineseConverterType(),
      useReplaceRule: _tocUiUseReplace && _resolveBookUseReplaceRule(),
    );
  }

  bool _resolveBookUseReplaceRule() {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) return true;
    return _settingsService.getBookUseReplaceRule(id, fallback: true);
  }

  String? _pickFirstNonEmpty(List<String> candidates) {
    for (final raw in candidates) {
      final value = raw.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Book? _resolveStoredBook() {
    final id = _bookId?.trim() ?? '';
    if (id.isEmpty) return widget.bookshelfBook;
    return _bookRepo.getBookById(id) ?? widget.bookshelfBook;
  }

  bool _isLocalBook() {
    return _resolveStoredBook()?.isLocal ?? false;
  }

  bool _isLocalTxtBook() {
    final book = _resolveStoredBook();
    if (book == null || !book.isLocal) return false;
    final lower = ((book.localPath ?? book.bookUrl ?? '')).toLowerCase();
    return lower.endsWith('.txt');
  }

  String? _resolveBookTxtTocRuleRegex(String bookId) {
    final regex = _settingsService.getBookTxtTocRule(bookId);
    if (regex == null) return null;
    final normalized = regex.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  Future<String?> _pickTxtTocRuleRegex({
    required String currentRegex,
  }) {
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (sheetContext) {
        final normalizedCurrent = currentRegex.trim();
        return CupertinoActionSheet(
          title: const Text('TXT 目录规则'),
          message: const Text('选择后会立即重建本地 TXT 目录。'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext, ''),
              child: Text(
                normalizedCurrent.isEmpty ? '✓ 自动识别（默认）' : '自动识别（默认）',
              ),
            ),
            for (final option in TxtParser.defaultTocRuleOptions)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, option.rule),
                child: Text(
                  normalizedCurrent == option.rule
                      ? '✓ ${option.name}'
                      : option.name,
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<_SearchBookTocRuleUpdateResult?> _handleEditTxtTocRuleFromToc() async {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty || !_isLocalTxtBook()) {
      _showMessage('当前书籍未接入 TXT 目录规则配置');
      return null;
    }
    final storedBook = _bookRepo.getBookById(id);
    if (storedBook == null || !storedBook.isLocal) {
      _showMessage('书籍信息不存在，无法配置 TXT 目录规则');
      return null;
    }

    final selectedRegex = await _pickTxtTocRuleRegex(
      currentRegex: _resolveBookTxtTocRuleRegex(id) ?? '',
    );
    if (selectedRegex == null) return null;
    final normalizedRegex = selectedRegex.trim();
    await _settingsService.saveBookTxtTocRule(
      id,
      normalizedRegex.isEmpty ? null : normalizedRegex,
    );

    final refreshed = await _refreshLocalBookshelfBook(
      force: true,
      showSuccessToast: false,
      txtTocRuleRegex: normalizedRegex.isEmpty ? null : normalizedRegex,
    );
    if (!refreshed) return null;

    final updatedToc = _loadStoredToc(id);
    final updatedDisplayTitles = await _buildTocDisplayTitles(updatedToc);
    if (mounted) {
      _showMessage('TXT 目录规则已应用');
    }
    return _SearchBookTocRuleUpdateResult(
      toc: updatedToc,
      displayTitles: updatedDisplayTitles,
      splitLongChapterEnabled: _splitLongChapter,
      useReplaceEnabled: _tocUiUseReplace,
      loadWordCountEnabled: _tocUiLoadWordCount,
    );
  }

  Future<_SearchBookTocRuleUpdateResult?>
      _handleToggleSplitLongChapterFromToc() async {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty || !_isLocalTxtBook()) {
      _showMessage('当前书籍未接入拆分超长章节配置');
      return null;
    }
    final storedBook = _bookRepo.getBookById(id);
    if (storedBook == null || !storedBook.isLocal) {
      _showMessage('书籍信息不存在，无法调整拆分超长章节');
      return null;
    }

    final next = !_splitLongChapter;
    if (mounted) {
      setState(() => _splitLongChapter = next);
    }
    await _settingsService.saveBookSplitLongChapter(id, next);
    await _refreshLocalBookshelfBook(
      force: true,
      showSuccessToast: false,
      splitLongChapter: next,
    );

    final updatedToc = _loadStoredToc(id);
    List<String> updatedDisplayTitles;
    try {
      updatedDisplayTitles = await _buildTocDisplayTitles(updatedToc);
    } catch (_) {
      updatedDisplayTitles =
          updatedToc.map((item) => item.name).toList(growable: false);
    }
    return _SearchBookTocRuleUpdateResult(
      toc: updatedToc,
      displayTitles: updatedDisplayTitles,
      splitLongChapterEnabled: next,
      useReplaceEnabled: _tocUiUseReplace,
      loadWordCountEnabled: _tocUiLoadWordCount,
    );
  }

  Future<_SearchBookTocRuleUpdateResult?>
      _handleToggleUseReplaceFromToc() async {
    final next = !_tocUiUseReplace;
    if (mounted) {
      setState(() => _tocUiUseReplace = next);
    }
    await _settingsService.saveTocUiUseReplace(next);

    final id = _bookId?.trim() ?? '';
    final updatedToc =
        _inBookshelf && id.isNotEmpty ? _loadStoredToc(id) : _toc;
    List<String> updatedDisplayTitles;
    try {
      updatedDisplayTitles = await _buildTocDisplayTitles(updatedToc);
    } catch (_) {
      updatedDisplayTitles =
          updatedToc.map((item) => item.name).toList(growable: false);
    }

    return _SearchBookTocRuleUpdateResult(
      toc: updatedToc,
      displayTitles: updatedDisplayTitles,
      splitLongChapterEnabled: _splitLongChapter,
      useReplaceEnabled: next,
      loadWordCountEnabled: _tocUiLoadWordCount,
    );
  }

  Future<_SearchBookTocRuleUpdateResult?>
      _handleToggleLoadWordCountFromToc() async {
    final next = !_tocUiLoadWordCount;
    if (mounted) {
      setState(() => _tocUiLoadWordCount = next);
    }
    await _settingsService.saveTocUiLoadWordCount(next);

    final id = _bookId?.trim() ?? '';
    final updatedToc =
        _inBookshelf && id.isNotEmpty ? _loadStoredToc(id) : _toc;
    List<String> updatedDisplayTitles;
    try {
      updatedDisplayTitles = await _buildTocDisplayTitles(updatedToc);
    } catch (_) {
      updatedDisplayTitles =
          updatedToc.map((item) => item.name).toList(growable: false);
    }

    return _SearchBookTocRuleUpdateResult(
      toc: updatedToc,
      displayTitles: updatedDisplayTitles,
      splitLongChapterEnabled: _splitLongChapter,
      useReplaceEnabled: _tocUiUseReplace,
      loadWordCountEnabled: next,
    );
  }

  bool _resolveBookInfoDeleteAlertSetting() {
    try {
      return _settingsService.appSettings.bookInfoDeleteAlert;
    } catch (_) {
      return true;
    }
  }

  String _resolveBookUrl() {
    return _pickFirstNonEmpty(<String>[
          _detail?.bookUrl ?? '',
          _activeResult.bookUrl,
          widget.bookshelfBook?.bookUrl ?? '',
        ]) ??
        '';
  }

  String _resolveTocUrl() {
    return _pickFirstNonEmpty(<String>[
          _detail?.tocUrl ?? '',
          _detail?.bookUrl ?? '',
          _activeResult.bookUrl,
          widget.bookshelfBook?.bookUrl ?? '',
        ]) ??
        '';
  }

  String _displaySourceVariableComment(BookSource source) {
    const defaultComment = '源变量可在js中通过source.getVariable()获取';
    final custom = (source.variableComment ?? '').trim();
    if (custom.isEmpty) return defaultComment;
    return '$custom\n$defaultComment';
  }

  String _displayBookVariableComment(BookSource source) {
    const defaultComment = '书籍变量可在js中通过book.getVariable("custom")获取';
    final custom = (source.variableComment ?? '').trim();
    if (custom.isEmpty) return defaultComment;
    return '$custom\n$defaultComment';
  }

  void _syncDisplayFromStoredBook(Book book) {
    final previousDetail = _detail;
    final resolvedBookUrl = _pickFirstNonEmpty(<String>[
          book.bookUrl ?? '',
          previousDetail?.bookUrl ?? '',
          _activeResult.bookUrl,
        ]) ??
        '';
    final resolvedTocUrl = _pickFirstNonEmpty(<String>[
          previousDetail?.tocUrl ?? '',
          resolvedBookUrl,
        ]) ??
        '';
    final resolvedLastChapter = _pickFirstNonEmpty(<String>[
          book.latestChapter ?? '',
          previousDetail?.lastChapter ?? '',
          _activeResult.lastChapter,
        ]) ??
        '';
    final resolvedSourceUrl = _pickFirstNonEmpty(<String>[
          book.sourceUrl ?? '',
          book.sourceId ?? '',
          _activeResult.sourceUrl,
        ]) ??
        '';

    _activeResult = SearchResult(
      name: book.title,
      author: book.author,
      coverUrl: (book.coverUrl ?? '').trim(),
      intro: (book.intro ?? '').trim(),
      kind: _activeResult.kind,
      lastChapter: resolvedLastChapter,
      updateTime: _activeResult.updateTime,
      wordCount: _activeResult.wordCount,
      bookUrl: resolvedBookUrl,
      sourceUrl: resolvedSourceUrl,
      sourceName: _activeResult.sourceName,
    );
    _detail = BookDetail(
      name: book.title,
      author: book.author,
      coverUrl: (book.coverUrl ?? '').trim(),
      intro: (book.intro ?? '').trim(),
      kind: previousDetail?.kind ?? _activeResult.kind,
      lastChapter: resolvedLastChapter,
      updateTime: previousDetail?.updateTime ?? _activeResult.updateTime,
      wordCount: previousDetail?.wordCount ?? _activeResult.wordCount,
      tocUrl: resolvedTocUrl,
      bookUrl: resolvedBookUrl,
    );
  }

  Book _buildShareBookSnapshot() {
    final stored = _resolveStoredBook();
    final resolvedName = _pickFirstNonEmpty(<String>[
          _detail?.name ?? '',
          _activeResult.name,
          stored?.title ?? '',
        ]) ??
        '';
    final resolvedAuthor = _pickFirstNonEmpty(<String>[
          _detail?.author ?? '',
          _activeResult.author,
          stored?.author ?? '',
        ]) ??
        '';
    final resolvedCoverUrl = _pickFirstNonEmpty(<String>[
          _detail?.coverUrl ?? '',
          _activeResult.coverUrl,
          stored?.coverUrl ?? '',
        ]) ??
        '';
    final resolvedIntro = _pickFirstNonEmpty(<String>[
          _detail?.intro ?? '',
          _activeResult.intro,
          stored?.intro ?? '',
        ]) ??
        '';
    final resolvedSourceUrl = _pickFirstNonEmpty(<String>[
          _source?.bookSourceUrl ?? '',
          _activeResult.sourceUrl,
          stored?.sourceUrl ?? '',
          stored?.sourceId ?? '',
        ]) ??
        '';
    final resolvedBookUrl = _resolveBookUrl();
    final resolvedLastChapter = _pickFirstNonEmpty(<String>[
          _detail?.lastChapter ?? '',
          _activeResult.lastChapter,
          stored?.latestChapter ?? '',
        ]) ??
        '';
    final resolvedTotalChapters =
        _toc.isEmpty ? stored?.totalChapters ?? 0 : _toc.length;
    if (stored != null) {
      return stored.copyWith(
        title: resolvedName,
        author: resolvedAuthor,
        coverUrl: resolvedCoverUrl,
        intro: resolvedIntro,
        sourceId: resolvedSourceUrl,
        sourceUrl: resolvedSourceUrl,
        bookUrl: resolvedBookUrl,
        latestChapter: resolvedLastChapter,
        totalChapters: resolvedTotalChapters,
      );
    }
    return Book(
      id: (_bookId?.trim().isNotEmpty ?? false)
          ? _bookId!.trim()
          : _buildEphemeralSessionId(),
      title: resolvedName,
      author: resolvedAuthor,
      coverUrl: resolvedCoverUrl.isEmpty ? null : resolvedCoverUrl,
      intro: resolvedIntro.isEmpty ? null : resolvedIntro,
      sourceId: resolvedSourceUrl.isEmpty ? null : resolvedSourceUrl,
      sourceUrl: resolvedSourceUrl.isEmpty ? null : resolvedSourceUrl,
      bookUrl: resolvedBookUrl.isEmpty ? null : resolvedBookUrl,
      latestChapter: resolvedLastChapter.isEmpty ? null : resolvedLastChapter,
      totalChapters: resolvedTotalChapters,
    );
  }

  Future<File?> _buildShareQrPngFile(String payload) async {
    if (kIsWeb) return null;
    try {
      final painter = QrPainter(
        data: payload,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: CupertinoColors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: CupertinoColors.black,
        ),
      );
      final imageData = await painter.toImageData(
        1024,
        format: ui.ImageByteFormat.png,
      );
      final bytes = imageData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'book_info_share_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _copyText(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showMessage(successMessage);
    });
  }

  Future<void> _shareBook() async {
    final snapshot = _buildShareBookSnapshot();
    final payload = SearchBookInfoShareHelper.buildPayload(snapshot);
    final subject =
        snapshot.title.trim().isEmpty ? '分享' : snapshot.title.trim();
    final qrFile = await _buildShareQrPngFile(payload);
    if (qrFile == null) {
      _showMessage('文字太多，生成二维码失败');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(qrFile.path, mimeType: 'image/png'),
          ],
          subject: subject,
          text: subject,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('分享失败：${_compactReason(e.toString())}');
    }
  }

  Future<void> _openBookEdit() async {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) {
      _showMessage('当前书籍不在书架，无法编辑');
      return;
    }
    final stored = _bookRepo.getBookById(id);
    if (stored == null) {
      _showMessage('书架记录不存在，无法编辑');
      return;
    }

    final edited = await Navigator.of(context).push<SearchBookInfoEditDraft>(
      CupertinoPageRoute<SearchBookInfoEditDraft>(
        builder: (_) => SearchBookInfoEditView(
          initialDraft: SearchBookInfoEditHelper.fromBook(stored),
        ),
      ),
    );
    if (edited == null) return;

    final updated = SearchBookInfoEditHelper.applyDraft(
      original: stored,
      draft: edited,
    );
    try {
      await _bookRepo.updateBook(updated);
    } catch (e) {
      if (!mounted) return;
      _showMessage('保存失败\n${_compactReason(e.toString())}');
      return;
    }
    if (!mounted) return;

    setState(() {
      _syncDisplayFromStoredBook(updated);
      _introExpanded = false;
    });
  }

  Future<void> _openSourceLogin() async {
    final source = _source;
    if (source == null) {
      _showMessage('当前书籍未匹配到书源');
      return;
    }

    if (SourceLoginUiHelper.hasLoginUi(source.loginUi)) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SourceLoginFormView(source: source),
        ),
      );
      return;
    }

    final resolvedUrl = SourceLoginUrlResolver.resolve(
      baseUrl: source.bookSourceUrl,
      loginUrl: source.loginUrl ?? '',
    );
    if (resolvedUrl.isEmpty) {
      _showMessage('当前书源未配置登录地址');
      return;
    }
    final uri = Uri.tryParse(resolvedUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      _showMessage('登录地址不是有效网页地址');
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(initialUrl: resolvedUrl),
      ),
    );
  }

  Future<void> _pinBookToTop() async {
    final id = _bookId?.trim() ?? '';
    if (id.isEmpty) return;

    final stored = _bookRepo.getBookById(id) ??
        ((_isBookshelfEntry && widget.bookshelfBook?.id == id)
            ? widget.bookshelfBook
            : null);
    if (stored == null) return;

    final pinned = SearchBookInfoTopHelper.buildPinnedBook(
      book: stored,
      now: DateTime.now(),
    );
    await _bookRepo.updateBook(pinned);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setSourceVariable() async {
    final source = _source;
    if (source == null) {
      _showMessage('书源不存在');
      return;
    }
    final sourceKey = source.bookSourceUrl;

    final note = _displaySourceVariableComment(source);
    final current = await SourceVariableStore.getVariable(sourceKey) ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: current);
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置源变量'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                maxLines: 6,
                placeholder: '输入变量 JSON 或文本',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    await SourceVariableStore.putVariable(sourceKey, result);
  }

  Future<void> _setBookVariable() async {
    final source = _source;
    if (source == null) {
      _showMessage('书源不存在');
      return;
    }
    final bookKey = _resolveBookUrl();
    if (bookKey.isEmpty) {
      return;
    }

    final note = _displayBookVariableComment(source);
    final current = await BookVariableStore.getVariable(bookKey) ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: current);
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置书籍变量'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                maxLines: 6,
                placeholder: '输入变量 JSON 或文本',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    await BookVariableStore.putVariable(bookKey, result);
  }

  Future<void> _uploadToRemote() async {
    final book = _resolveStoredBook();
    if (book == null || !book.isLocal) {
      _showMessage('当前书籍不是本地书籍，无法上传');
      return;
    }
    if ((book.localPath ?? '').trim().isEmpty) {
      _showMessage('本地文件路径缺失，暂无法上传');
      return;
    }

    final settings = _settingsService.appSettings;
    final bookId = book.id.trim();
    final existingRemoteUrl =
        bookId.isEmpty ? null : _settingsService.getBookRemoteUploadUrl(bookId);
    if (existingRemoteUrl != null) {
      final confirmed = await showCupertinoDialog<bool>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: const Text('提醒'),
              content: const Text('远程webDav链接已存在，是否继续'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('确定'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }

    OverlayEntry? loadingOverlay;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState != null) {
      loadingOverlay = OverlayEntry(
        builder: (overlayContext) => ColoredBox(
          color: const Color(0x33000000),
          child: Center(
            child: CupertinoPopupSurface(
              isSurfacePainted: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(),
                    SizedBox(width: 12),
                    Text('上传中.....'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      overlayState.insert(loadingOverlay);
    }

    String feedback = '上传成功';
    try {
      final result = await _webDavService.uploadLocalBook(
        book: book,
        settings: settings,
      );
      if (bookId.isNotEmpty) {
        await _settingsService.saveBookRemoteUploadUrl(
            bookId, result.remoteUrl);
      }
    } catch (error) {
      feedback = _compactReason(error.toString(), maxLength: 180);
    } finally {
      loadingOverlay?.remove();
    }

    if (!mounted) return;
    _showMessage(feedback);
  }

  Future<void> _copyBookUrl() async {
    final bookUrl = _resolveBookUrl();
    await _copyText(bookUrl, '复制完成');
  }

  Future<void> _copyTocUrl() async {
    final tocUrl = _resolveTocUrl();
    await _copyText(tocUrl, '复制完成');
  }

  Future<void> _toggleAllowUpdate() async {
    final next = !_allowUpdate;
    setState(() => _allowUpdate = next);
    final id = _bookId?.trim() ?? '';
    if (_inBookshelf && id.isNotEmpty) {
      await _settingsService.saveBookCanUpdate(id, next);
    }
  }

  Widget _buildCheckableActionLabel({
    required String title,
    required bool checked,
  }) {
    if (!checked) {
      return Text(title);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.check_mark, size: 18),
        const SizedBox(width: 6),
        Text(title),
      ],
    );
  }

  Future<void> _toggleSplitLongChapter() async {
    final next = !_splitLongChapter;
    if (!mounted) return;
    setState(() => _splitLongChapter = next);
    final id = _bookId?.trim() ?? '';
    if (_inBookshelf && id.isNotEmpty) {
      await _settingsService.saveBookSplitLongChapter(id, next);
    }
    var refreshSuccess = true;
    if (_inBookshelf && id.isNotEmpty && _isLocalTxtBook()) {
      refreshSuccess = await _refreshLocalBookshelfBook(
        force: true,
        splitLongChapter: next,
        showSuccessToast: false,
      );
    } else {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _loadingToc = true;
      });
      await _loadContext(silent: true);
    }
    if (!mounted || !refreshSuccess) return;
    if (!next) {
      _showMessage('已关闭“分割长章节”，重新加载正文可能需要更长时间');
      return;
    }
    _showMessage('已开启“分割长章节”');
  }

  Future<void> _toggleDeleteAlertEnabled() async {
    setState(() {
      _deleteAlertEnabled = !_deleteAlertEnabled;
    });
    try {
      await _settingsService.saveAppSettings(
        _settingsService.appSettings.copyWith(
          bookInfoDeleteAlert: _deleteAlertEnabled,
        ),
      );
    } catch (_) {
      // SettingsService 未初始化时仅保持本页会话内状态。
    }
  }

  Future<void> _clearBookCache() async {
    final id = (_bookId?.trim().isNotEmpty ?? false)
        ? _bookId!.trim()
        : _buildEphemeralSessionId();
    try {
      await _chapterRepo.clearDownloadedCacheForBook(id);
      if (!mounted) return;
      _showMessage('成功清理缓存');
    } catch (e) {
      if (!mounted) return;
      _showMessage('清理缓存出错\n${_compactReason(e.toString())}');
    }
  }

  Future<void> _openAppLogDialog() async {
    await showAppLogDialog(context);
  }

  Future<void> _triggerRefresh() async {
    if (_inBookshelf) {
      if (_isLocalBook()) {
        await _refreshLocalBookshelfBook();
        return;
      }
      await _refreshBookshelfToc();
      return;
    }
    await _loadContext();
  }

  Future<bool> _refreshLocalBookshelfBook({
    bool force = false,
    bool? splitLongChapter,
    bool showSuccessToast = true,
    String? txtTocRuleRegex,
  }) async {
    if (_loadingToc && !force) return false;
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) {
      await _loadContext();
      return true;
    }

    final storedBook = _bookRepo.getBookById(id);
    if (storedBook == null || !storedBook.isLocal) {
      await _refreshBookshelfToc();
      return true;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _loadingToc = true;
        _error = null;
        _tocError = null;
      });
    }

    String? refreshError;
    try {
      final preferredTxtCharset =
          await _readerCharsetService.getBookCharset(id);
      final refreshResult = await SearchBookInfoRefreshHelper.refreshLocalBook(
        book: storedBook,
        preferredTxtCharset: preferredTxtCharset,
        splitLongChapter:
            splitLongChapter ?? _settingsService.getBookSplitLongChapter(id),
        txtTocRuleRegex: txtTocRuleRegex ?? _resolveBookTxtTocRuleRegex(id),
      );
      await _chapterRepo.clearChaptersForBook(id);
      await _chapterRepo.addChapters(refreshResult.chapters);
      await _bookRepo.updateBook(refreshResult.book);
      final charset = (refreshResult.charset ?? '').trim();
      if (charset.isNotEmpty) {
        await _readerCharsetService.setBookCharset(id, charset);
      }
    } catch (error) {
      refreshError = _compactReason(error.toString(), maxLength: 180);
    }

    final latestBook = _bookRepo.getBookById(id) ?? storedBook;
    final localToc = _loadStoredToc(id);
    if (!mounted) return refreshError == null;

    setState(() {
      _syncDisplayFromStoredBook(latestBook);
      _source = null;
      _toc = localToc;
      _loading = false;
      _loadingToc = false;
      _error = null;
      _tocError =
          localToc.isEmpty ? (refreshError ?? '目录为空（书架缓存中无章节，请先刷新目录）') : null;
    });

    if (localToc.isNotEmpty && refreshError == null && showSuccessToast) {
      _showMessage('目录已刷新（共 ${localToc.length} 章）');
    } else if (refreshError != null) {
      _showMessage(refreshError);
    }
    return refreshError == null;
  }

  Future<bool> _confirmRemoveFromShelf() async {
    if (!_deleteAlertEnabled) return true;
    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('移出书架'),
            content: Text('\n确定将《$_displayName》移出书架吗？'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('移出'),
              ),
            ],
          ),
        ) ??
        false;
    return confirmed;
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
        final confirmed = await _confirmRemoveFromShelf();
        if (!confirmed) return;
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
        if (_inBookshelf) {
          final id = _bookId?.trim() ?? '';
          if (id.isNotEmpty) {
            _allowUpdate = _settingsService.getBookCanUpdate(id);
            _splitLongChapter = _settingsService.getBookSplitLongChapter(id);
          }
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

    List<String> displayTitles;
    try {
      displayTitles = await _buildTocDisplayTitles(tocToOpen);
    } catch (_) {
      displayTitles =
          tocToOpen.map((item) => item.name).toList(growable: false);
    }
    if (!mounted) return;
    final showTxtTocRuleAction = _inBookshelf && _isLocalTxtBook();
    final showSplitLongChapterAction = showTxtTocRuleAction;
    const showUseReplaceAction = true;
    const showLoadWordCountAction = true;
    final showExportBookmarkAction =
        _inBookshelf && (_bookId?.trim().isNotEmpty ?? false);

    final selected = await Navigator.of(context, rootNavigator: true).push<int>(
      CupertinoPageRoute(
        builder: (_) => _SearchBookTocView(
          bookTitle: _displayName,
          toc: tocToOpen,
          displayTitles: displayTitles,
          sourceName: _displaySourceName,
          showTxtTocRuleAction: showTxtTocRuleAction,
          showSplitLongChapterAction: showSplitLongChapterAction,
          splitLongChapterEnabled: _splitLongChapter,
          showUseReplaceAction: showUseReplaceAction,
          useReplaceEnabled: _tocUiUseReplace,
          showLoadWordCountAction: showLoadWordCountAction,
          loadWordCountEnabled: _tocUiLoadWordCount,
          showExportBookmarkAction: showExportBookmarkAction,
          onEditTocRule:
              showTxtTocRuleAction ? _handleEditTxtTocRuleFromToc : null,
          onToggleSplitLongChapter: showSplitLongChapterAction
              ? _handleToggleSplitLongChapterFromToc
              : null,
          onToggleUseReplace:
              showUseReplaceAction ? _handleToggleUseReplaceFromToc : null,
          onToggleLoadWordCount: showLoadWordCountAction
              ? _handleToggleLoadWordCountFromToc
              : null,
          onExportBookmark:
              showExportBookmarkAction ? _handleExportBookmarkFromToc : null,
          onExportBookmarkMarkdown: showExportBookmarkAction
              ? _handleExportBookmarkMarkdownFromToc
              : null,
        ),
      ),
    );
    if (selected == null) return;
    await _openReader(initialChapter: selected);
  }

  Future<void> _handleExportBookmarkFromToc() async {
    final feedback = await _exportBookmarksFromToc(markdown: false);
    if (!mounted || feedback == null) return;
    final message = feedback.trim();
    if (message.isEmpty) return;
    _showMessage(message);
  }

  Future<void> _handleExportBookmarkMarkdownFromToc() async {
    final feedback = await _exportBookmarksFromToc(markdown: true);
    if (!mounted || feedback == null) return;
    final message = feedback.trim();
    if (message.isEmpty) return;
    _showMessage(message);
  }

  Future<String?> _exportBookmarksFromToc({required bool markdown}) async {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) {
      return '当前书籍不支持导出书签';
    }

    try {
      await _bookmarkRepo.init();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.toc.export_bookmark.init',
        message: '导出失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': id,
          'bookTitle': _displayName,
          'format': markdown ? 'md' : 'json',
        },
      );
      return '导出失败：${_compactReason(error.toString())}';
    }

    final bookmarks = _bookmarkRepo.getBookmarksForBook(id);
    final result = markdown
        ? await _bookmarkExportService.exportMarkdown(
            bookTitle: _displayName,
            bookAuthor: _displayAuthor,
            bookmarks: bookmarks,
          )
        : await _bookmarkExportService.exportJson(
            bookTitle: _displayName,
            bookAuthor: _displayAuthor,
            bookmarks: bookmarks,
          );
    if (result.cancelled) return null;
    if (result.success) {
      if (kIsWeb) {
        final webMessage = result.message?.trim() ?? '';
        if (webMessage.isNotEmpty) return webMessage;
      }
      return '导出成功';
    }
    final message = (result.message ?? '导出失败').trim();
    ExceptionLogService().record(
      node: 'search_book_info.toc.export_bookmark',
      message: '导出失败',
      error: message,
      context: <String, dynamic>{
        'bookId': id,
        'bookTitle': _displayName,
        'format': markdown ? 'md' : 'json',
      },
    );
    return message;
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
    final source = _source;
    final hasLogin = SearchBookInfoMenuHelper.shouldShowLogin(
      loginUrl: source?.loginUrl,
    );
    final canSetVariable = source != null;
    final showAllowUpdate = source != null;
    const canClearCache = true;
    final showUpload = _isLocalBook();
    final showSplitLongChapter = _isLocalTxtBook();

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(_displayName),
        actions: [
          if (showUpload)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _uploadToRemote();
              },
              child: const Text('上传 WebDav'),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _triggerRefresh();
            },
            child: const Text('刷新'),
          ),
          if (hasLogin)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _openSourceLogin();
              },
              child: const Text('登录'),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _pinBookToTop();
            },
            child: const Text('置顶'),
          ),
          if (canSetVariable)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _setSourceVariable();
              },
              child: const Text('设置源变量'),
            ),
          if (canSetVariable)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _setBookVariable();
              },
              child: const Text('设置书籍变量'),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _copyBookUrl();
            },
            child: const Text('拷贝书籍 URL'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _copyTocUrl();
            },
            child: const Text('拷贝目录 URL'),
          ),
          if (showAllowUpdate)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _toggleAllowUpdate();
              },
              child: _buildCheckableActionLabel(
                title: '允许更新',
                checked: _allowUpdate,
              ),
            ),
          if (showSplitLongChapter)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _toggleSplitLongChapter();
              },
              child: Text(_splitLongChapter ? '分割长章节：开' : '分割长章节：关'),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _toggleDeleteAlertEnabled();
            },
            child: _buildCheckableActionLabel(
              title: '删除提醒',
              checked: _deleteAlertEnabled,
            ),
          ),
          if (canClearCache)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _clearBookCache();
              },
              child: const Text('清理缓存'),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _openAppLogDialog();
            },
            child: const Text('日志'),
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

    final selected = await showSourceSwitchCandidateSheet(
      context: context,
      keyword: keyword,
      candidates: candidates,
    );
    if (selected == null) return;
    await _applySourceCandidate(selected);
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
          if (_inBookshelf)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _openBookEdit,
              child: const Icon(CupertinoIcons.pencil),
            ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _shareBook,
            child: const Icon(CupertinoIcons.share),
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

class _SearchBookTocRuleUpdateResult {
  final List<TocItem> toc;
  final List<String> displayTitles;
  final bool splitLongChapterEnabled;
  final bool useReplaceEnabled;
  final bool loadWordCountEnabled;

  const _SearchBookTocRuleUpdateResult({
    required this.toc,
    required this.displayTitles,
    required this.splitLongChapterEnabled,
    required this.useReplaceEnabled,
    required this.loadWordCountEnabled,
  }) : assert(displayTitles.length == toc.length);
}

enum _SearchBookTocMenuAction {
  reverseToc,
  useReplace,
  loadWordCount,
  tocRule,
  splitLongChapter,
  exportBookmark,
  exportBookmarkMarkdown,
}

class _SearchBookTocView extends StatefulWidget {
  final String bookTitle;
  final String sourceName;
  final List<TocItem> toc;
  final List<String> displayTitles;
  final bool showTxtTocRuleAction;
  final bool showSplitLongChapterAction;
  final bool splitLongChapterEnabled;
  final bool showUseReplaceAction;
  final bool useReplaceEnabled;
  final bool showLoadWordCountAction;
  final bool loadWordCountEnabled;
  final bool showExportBookmarkAction;
  final Future<_SearchBookTocRuleUpdateResult?> Function()? onEditTocRule;
  final Future<_SearchBookTocRuleUpdateResult?> Function()?
      onToggleSplitLongChapter;
  final Future<_SearchBookTocRuleUpdateResult?> Function()? onToggleUseReplace;
  final Future<_SearchBookTocRuleUpdateResult?> Function()?
      onToggleLoadWordCount;
  final Future<void> Function()? onExportBookmark;
  final Future<void> Function()? onExportBookmarkMarkdown;

  const _SearchBookTocView({
    required this.bookTitle,
    required this.sourceName,
    required this.toc,
    required this.displayTitles,
    this.showTxtTocRuleAction = false,
    this.showSplitLongChapterAction = false,
    this.splitLongChapterEnabled = false,
    this.showUseReplaceAction = true,
    this.useReplaceEnabled = false,
    this.showLoadWordCountAction = true,
    this.loadWordCountEnabled = true,
    this.showExportBookmarkAction = false,
    this.onEditTocRule,
    this.onToggleSplitLongChapter,
    this.onToggleUseReplace,
    this.onToggleLoadWordCount,
    this.onExportBookmark,
    this.onExportBookmarkMarkdown,
  }) : assert(displayTitles.length == toc.length);

  @override
  State<_SearchBookTocView> createState() => _SearchBookTocViewState();
}

class _SearchBookTocViewState extends State<_SearchBookTocView> {
  static const Key _menuSearchActionKey =
      Key('search_book_toc_menu_search_action');
  static const Key _menuSearchFieldKey =
      Key('search_book_toc_menu_search_field');
  static const Key _menuSearchCloseKey =
      Key('search_book_toc_menu_search_close');
  static const Key _menuMoreActionKey = Key('search_book_toc_menu_more_action');
  static const Key _menuReverseTocActionKey =
      Key('search_book_toc_menu_reverse_toc_action');
  static const Key _menuUseReplaceActionKey =
      Key('search_book_toc_menu_use_replace_action');
  static const Key _menuLoadWordCountActionKey =
      Key('search_book_toc_menu_load_word_count_action');
  static const Key _menuTocRuleActionKey =
      Key('search_book_toc_menu_toc_rule_action');
  static const Key _menuSplitLongChapterActionKey =
      Key('search_book_toc_menu_split_long_chapter_action');
  static const Key _menuExportBookmarkActionKey =
      Key('search_book_toc_menu_export_bookmark_action');
  static const Key _menuExportBookmarkMarkdownActionKey =
      Key('search_book_toc_menu_export_markdown_action');

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _searchExpanded = false;
  bool _reversed = false;
  bool _runningUseReplaceAction = false;
  bool _runningLoadWordCountAction = false;
  bool _runningTocRuleAction = false;
  bool _runningSplitLongChapterAction = false;
  bool _runningExportBookmarkAction = false;
  bool _runningExportBookmarkMarkdownAction = false;
  late bool _useReplaceEnabled;
  late bool _loadWordCountEnabled;
  late bool _splitLongChapterEnabled;
  late List<TocItem> _toc;
  late List<String> _displayTitles;

  @override
  void initState() {
    super.initState();
    _toc = widget.toc;
    _displayTitles = widget.displayTitles;
    _useReplaceEnabled = widget.useReplaceEnabled;
    _loadWordCountEnabled = widget.loadWordCountEnabled;
    _splitLongChapterEnabled = widget.splitLongChapterEnabled;
    _searchFocusNode.addListener(_handleSearchFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SearchBookTocView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.toc, widget.toc)) {
      _toc = widget.toc;
    }
    if (!listEquals(oldWidget.displayTitles, widget.displayTitles)) {
      _displayTitles = widget.displayTitles;
    }
    if (oldWidget.useReplaceEnabled != widget.useReplaceEnabled) {
      _useReplaceEnabled = widget.useReplaceEnabled;
    }
    if (oldWidget.loadWordCountEnabled != widget.loadWordCountEnabled) {
      _loadWordCountEnabled = widget.loadWordCountEnabled;
    }
    if (oldWidget.splitLongChapterEnabled != widget.splitLongChapterEnabled) {
      _splitLongChapterEnabled = widget.splitLongChapterEnabled;
    }
  }

  void _handleSearchFocusChange() {
    if (_searchFocusNode.hasFocus || !_searchExpanded || !mounted) return;
    setState(() {
      _searchExpanded = false;
    });
  }

  void _openSearch() {
    if (_searchExpanded) return;
    setState(() {
      _searchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch({required bool clearQuery}) {
    if (!_searchExpanded && !(clearQuery && _searchQuery.isNotEmpty)) return;
    setState(() {
      _searchExpanded = false;
      if (clearQuery) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    _searchFocusNode.unfocus();
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<int, TocItem>> get _filtered {
    return SearchBookTocFilterHelper.filterEntries(
      toc: _toc,
      rawQuery: _searchQuery,
      reversed: _reversed,
    );
  }

  Widget _buildCheckableActionLabel({
    required String title,
    required bool checked,
  }) {
    if (!checked) {
      return Text(title);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.check_mark, size: 18),
        const SizedBox(width: 6),
        Text(title),
      ],
    );
  }

  Future<void> _showTocMenu() async {
    if (_runningUseReplaceAction ||
        _runningLoadWordCountAction ||
        _runningTocRuleAction ||
        _runningSplitLongChapterAction ||
        _runningExportBookmarkAction ||
        _runningExportBookmarkMarkdownAction) {
      return;
    }
    final selected = await showCupertinoModalPopup<_SearchBookTocMenuAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('目录操作'),
        actions: [
          if (widget.showTxtTocRuleAction)
            CupertinoActionSheetAction(
              key: _menuTocRuleActionKey,
              onPressed: () =>
                  Navigator.pop(sheetContext, _SearchBookTocMenuAction.tocRule),
              child: const Text('TXT 目录规则'),
            ),
          if (widget.showSplitLongChapterAction)
            CupertinoActionSheetAction(
              key: _menuSplitLongChapterActionKey,
              onPressed: () => Navigator.pop(
                sheetContext,
                _SearchBookTocMenuAction.splitLongChapter,
              ),
              child: _buildCheckableActionLabel(
                title: '拆分超长章节',
                checked: _splitLongChapterEnabled,
              ),
            ),
          CupertinoActionSheetAction(
            key: _menuReverseTocActionKey,
            onPressed: () => Navigator.pop(
              sheetContext,
              _SearchBookTocMenuAction.reverseToc,
            ),
            child: const Text('反转目录'),
          ),
          if (widget.showUseReplaceAction)
            CupertinoActionSheetAction(
              key: _menuUseReplaceActionKey,
              onPressed: () => Navigator.pop(
                sheetContext,
                _SearchBookTocMenuAction.useReplace,
              ),
              child: _buildCheckableActionLabel(
                title: '使用替换',
                checked: _useReplaceEnabled,
              ),
            ),
          if (widget.showLoadWordCountAction)
            CupertinoActionSheetAction(
              key: _menuLoadWordCountActionKey,
              onPressed: () => Navigator.pop(
                sheetContext,
                _SearchBookTocMenuAction.loadWordCount,
              ),
              child: _buildCheckableActionLabel(
                title: '加载字数',
                checked: _loadWordCountEnabled,
              ),
            ),
          if (widget.showExportBookmarkAction)
            CupertinoActionSheetAction(
              key: _menuExportBookmarkActionKey,
              onPressed: () => Navigator.pop(
                sheetContext,
                _SearchBookTocMenuAction.exportBookmark,
              ),
              child: const Text('导出'),
            ),
          if (widget.showExportBookmarkAction)
            CupertinoActionSheetAction(
              key: _menuExportBookmarkMarkdownActionKey,
              onPressed: () => Navigator.pop(
                sheetContext,
                _SearchBookTocMenuAction.exportBookmarkMarkdown,
              ),
              child: const Text('导出(MD)'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    switch (selected) {
      case _SearchBookTocMenuAction.reverseToc:
        _toggleReverseToc();
        return;
      case _SearchBookTocMenuAction.useReplace:
        await _runUseReplaceAction();
        return;
      case _SearchBookTocMenuAction.loadWordCount:
        await _runLoadWordCountAction();
        return;
      case _SearchBookTocMenuAction.tocRule:
        await _runTocRuleAction();
        return;
      case _SearchBookTocMenuAction.splitLongChapter:
        await _runSplitLongChapterAction();
        return;
      case _SearchBookTocMenuAction.exportBookmark:
        await _runExportBookmarkAction();
        return;
      case _SearchBookTocMenuAction.exportBookmarkMarkdown:
        await _runExportBookmarkMarkdownAction();
        return;
    }
  }

  void _toggleReverseToc() {
    setState(() => _reversed = !_reversed);
  }

  String? _resolveChapterWordCountLabel(TocItem item) {
    if (!_loadWordCountEnabled || item.isVolume) return null;
    final value = (item.wordCount ?? '').trim();
    if (value.isEmpty) return null;
    return value;
  }

  Future<void> _runUseReplaceAction() async {
    final handler = widget.onToggleUseReplace;
    if (handler == null || _runningUseReplaceAction) return;
    setState(() => _runningUseReplaceAction = true);
    try {
      final updated = await handler();
      if (!mounted || updated == null) return;
      if (updated.displayTitles.length != updated.toc.length) return;
      setState(() {
        _toc = updated.toc;
        _displayTitles = updated.displayTitles;
        _splitLongChapterEnabled = updated.splitLongChapterEnabled;
        _useReplaceEnabled = updated.useReplaceEnabled;
        _loadWordCountEnabled = updated.loadWordCountEnabled;
      });
    } finally {
      if (mounted) {
        setState(() => _runningUseReplaceAction = false);
      }
    }
  }

  Future<void> _runLoadWordCountAction() async {
    final handler = widget.onToggleLoadWordCount;
    if (handler == null || _runningLoadWordCountAction) return;
    setState(() => _runningLoadWordCountAction = true);
    try {
      final updated = await handler();
      if (!mounted || updated == null) return;
      if (updated.displayTitles.length != updated.toc.length) return;
      setState(() {
        _toc = updated.toc;
        _displayTitles = updated.displayTitles;
        _splitLongChapterEnabled = updated.splitLongChapterEnabled;
        _useReplaceEnabled = updated.useReplaceEnabled;
        _loadWordCountEnabled = updated.loadWordCountEnabled;
      });
    } finally {
      if (mounted) {
        setState(() => _runningLoadWordCountAction = false);
      }
    }
  }

  Future<void> _runTocRuleAction() async {
    final handler = widget.onEditTocRule;
    if (handler == null || _runningTocRuleAction) return;
    setState(() => _runningTocRuleAction = true);
    try {
      final updated = await handler();
      if (!mounted || updated == null) return;
      if (updated.displayTitles.length != updated.toc.length) return;
      setState(() {
        _toc = updated.toc;
        _displayTitles = updated.displayTitles;
        _splitLongChapterEnabled = updated.splitLongChapterEnabled;
        _useReplaceEnabled = updated.useReplaceEnabled;
        _loadWordCountEnabled = updated.loadWordCountEnabled;
      });
    } finally {
      if (mounted) {
        setState(() => _runningTocRuleAction = false);
      }
    }
  }

  Future<void> _runSplitLongChapterAction() async {
    final handler = widget.onToggleSplitLongChapter;
    if (handler == null || _runningSplitLongChapterAction) return;
    setState(() => _runningSplitLongChapterAction = true);
    try {
      final updated = await handler();
      if (!mounted || updated == null) return;
      if (updated.displayTitles.length != updated.toc.length) return;
      setState(() {
        _toc = updated.toc;
        _displayTitles = updated.displayTitles;
        _splitLongChapterEnabled = updated.splitLongChapterEnabled;
        _useReplaceEnabled = updated.useReplaceEnabled;
        _loadWordCountEnabled = updated.loadWordCountEnabled;
      });
    } finally {
      if (mounted) {
        setState(() => _runningSplitLongChapterAction = false);
      }
    }
  }

  Future<void> _runExportBookmarkAction() async {
    final handler = widget.onExportBookmark;
    if (handler == null || _runningExportBookmarkAction) return;
    setState(() => _runningExportBookmarkAction = true);
    try {
      await handler();
    } finally {
      if (mounted) {
        setState(() => _runningExportBookmarkAction = false);
      }
    }
  }

  Future<void> _runExportBookmarkMarkdownAction() async {
    final handler = widget.onExportBookmarkMarkdown;
    if (handler == null || _runningExportBookmarkMarkdownAction) return;
    setState(() => _runningExportBookmarkMarkdownAction = true);
    try {
      await handler();
    } finally {
      if (mounted) {
        setState(() => _runningExportBookmarkMarkdownAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _filtered;
    final searchAction = _searchExpanded
        ? CupertinoButton(
            key: _menuSearchCloseKey,
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: () => _closeSearch(clearQuery: true),
            child: const Icon(CupertinoIcons.xmark, size: 18),
          )
        : CupertinoButton(
            key: _menuSearchActionKey,
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _openSearch,
            child: const Icon(CupertinoIcons.search, size: 18),
          );
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        searchAction,
        if (_runningUseReplaceAction ||
            _runningLoadWordCountAction ||
            _runningTocRuleAction ||
            _runningSplitLongChapterAction ||
            _runningExportBookmarkAction ||
            _runningExportBookmarkMarkdownAction)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: CupertinoActivityIndicator(radius: 8),
          ),
        CupertinoButton(
          key: _menuMoreActionKey,
          padding: EdgeInsets.zero,
          minimumSize: const Size(30, 30),
          onPressed: (_runningUseReplaceAction ||
                  _runningLoadWordCountAction ||
                  _runningTocRuleAction ||
                  _runningSplitLongChapterAction ||
                  _runningExportBookmarkAction ||
                  _runningExportBookmarkMarkdownAction)
              ? null
              : _showTocMenu,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 18),
        ),
      ],
    );

    return AppCupertinoPageScaffold(
      title: '目录',
      middle: _searchExpanded
          ? SizedBox(
              height: 34,
              child: CupertinoSearchTextField(
                key: _menuSearchFieldKey,
                controller: _searchController,
                focusNode: _searchFocusNode,
                placeholder: '搜索',
                onChanged: (value) => setState(() => _searchQuery = value),
                onSubmitted: (value) => setState(() => _searchQuery = value),
              ),
            )
          : null,
      trailing: trailing,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchQuery.trim().isEmpty
                    ? '共 ${_toc.length} 章'
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
                final displayTitle = _displayTitles[entry.key];
                final wordCountLabel =
                    _resolveChapterWordCountLabel(entry.value);
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
                              displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.p.copyWith(
                                color: scheme.foreground,
                              ),
                            ),
                          ),
                          if (wordCountLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                wordCountLabel,
                                style: theme.textTheme.small.copyWith(
                                  color: scheme.mutedForeground,
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
