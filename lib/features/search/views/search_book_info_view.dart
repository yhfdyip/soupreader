import 'dart:async';
import 'dart:collection';
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
import 'package:uuid/uuid.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
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
import '../../reader/services/txt_toc_rule_store.dart';
import '../../reader/views/simple_reader_view.dart';
import '../../reader/widgets/source_switch_candidate_sheet.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../settings/views/app_log_dialog.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../source/services/source_login_ui_helper.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_login_webview_view.dart';
import '../services/search_book_info_edit_helper.dart';
import '../services/search_book_info_menu_helper.dart';
import '../services/search_book_info_refresh_helper.dart';
import '../services/search_book_info_share_helper.dart';
import '../services/search_book_info_top_helper.dart';
import '../services/search_book_toc_filter_helper.dart';
import 'search_book_info_edit_view.dart';

part 'search_book_info_widgets.dart';

enum _SearchBookInfoMoreMenuAction {
  edit,
  share,
  uploadWebDav,
  refresh,
  login,
  pinTop,
  setSourceVariable,
  setBookVariable,
  copyBookUrl,
  copyTocUrl,
  toggleAllowUpdate,
  toggleSplitLongChapter,
  toggleDeleteAlert,
  clearCache,
  logs,
}

typedef _SearchBookInfoMoreActionConfig = ({
  String actionKey,
  String actionLabel,
  Future<void> Function() action,
});

typedef _BookshelfTocCacheResult = ({
  List<TocItem> toc,
  String? error,
});

class _BookInfoSessionCacheEntry {
  final BookDetail? detail;
  final List<TocItem> toc;
  final DateTime savedAt;

  const _BookInfoSessionCacheEntry({
    required this.detail,
    required this.toc,
    required this.savedAt,
  });
}

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
        intro: book.intro ?? '',
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
  static const int _maxSessionCacheEntries = 48;
  static const Duration _sessionCacheTtl = Duration(hours: 12);
  static const double _minWidthForInlineShareAction = 390;
  static const double _minWidthForInlineEditAction = 460;
  static final LinkedHashMap<String, _BookInfoSessionCacheEntry> _sessionCache =
      LinkedHashMap<String, _BookInfoSessionCacheEntry>();

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
  final TxtTocRuleStore _txtTocRuleStore = TxtTocRuleStore();
  final GlobalKey _moreMenuKey = GlobalKey();

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
  int _changeSourceDelaySeconds = 0;
  String? _error;
  String? _tocError;

  bool get _isBookshelfEntry => widget.bookshelfBook != null;

  bool get _canFetchOnlineDetail {
    return _activeResult.sourceUrl.trim().isNotEmpty &&
        _activeResult.bookUrl.trim().isNotEmpty;
  }

  String _buildSessionCacheKeyForResult(SearchResult value) {
    final sourceUrl = value.sourceUrl.trim().toLowerCase();
    final bookUrl = value.bookUrl.trim();
    if (sourceUrl.isEmpty || bookUrl.isEmpty) return '';
    return '$sourceUrl|$bookUrl';
  }

  String _buildSessionCacheKey() {
    return _buildSessionCacheKeyForResult(_activeResult);
  }

  bool _matchesActiveResult(Book shelfBook) {
    final activeSource = _normalize(_activeResult.sourceUrl);
    final activeBookUrl = _normalize(_activeResult.bookUrl);
    final shelfSource = _normalize(
      (shelfBook.sourceUrl ?? shelfBook.sourceId ?? ''),
    );
    final shelfBookUrl = _normalize(shelfBook.bookUrl ?? '');

    final sourceMatched = activeSource.isEmpty ||
        shelfSource.isEmpty ||
        activeSource == shelfSource;
    final bookMatched = activeBookUrl.isEmpty ||
        shelfBookUrl.isEmpty ||
        activeBookUrl == shelfBookUrl;
    return sourceMatched && bookMatched;
  }

  bool _hasUsableDetail(BookDetail? detail) {
    if (detail == null) return false;
    return detail.name.trim().isNotEmpty ||
        detail.author.trim().isNotEmpty ||
        detail.coverUrl.trim().isNotEmpty ||
        detail.intro.trim().isNotEmpty ||
        detail.lastChapter.trim().isNotEmpty;
  }

  _BookInfoSessionCacheEntry? _readSessionCacheEntry(String key) {
    if (key.isEmpty) return null;
    final entry = _sessionCache.remove(key);
    if (entry == null) return null;
    final age = DateTime.now().difference(entry.savedAt);
    if (age > _sessionCacheTtl) return null;
    if (entry.toc.isEmpty && !_hasUsableDetail(entry.detail)) return null;
    _sessionCache[key] = entry;
    return entry;
  }

  void _writeSessionCacheEntry({
    required String key,
    required BookDetail? detail,
    required List<TocItem> toc,
  }) {
    if (key.isEmpty) return;
    final safeToc = List<TocItem>.from(toc);
    if (safeToc.isEmpty && !_hasUsableDetail(detail)) {
      _sessionCache.remove(key);
      return;
    }
    _sessionCache.remove(key);
    _sessionCache[key] = _BookInfoSessionCacheEntry(
      detail: detail,
      toc: safeToc,
      savedAt: DateTime.now(),
    );
    while (_sessionCache.length > _maxSessionCacheEntries) {
      _sessionCache.remove(_sessionCache.keys.first);
    }
  }

  void _removeSessionCacheEntry(String key) {
    if (key.isEmpty) return;
    _sessionCache.remove(key);
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
    _changeSourceDelaySeconds = _settingsService.getBatchChangeSourceDelay();
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

  String _resolveShareErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'ERROR';

    const exceptionPrefix = 'Exception:';
    if (raw.startsWith(exceptionPrefix)) {
      final message = raw.substring(exceptionPrefix.length).trim();
      return message.isEmpty ? 'ERROR' : _compactReason(message);
    }

    const platformPrefix = 'PlatformException(';
    if (raw.startsWith(platformPrefix) && raw.endsWith(')')) {
      final body = raw.substring(platformPrefix.length, raw.length - 1);
      final segments = body.split(',');
      if (segments.length >= 2) {
        final message = segments[1].trim();
        if (message.isNotEmpty) return _compactReason(message);
      }
    }
    return _compactReason(raw);
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

  List<Chapter> _buildChaptersFromCurrentToc(String bookId) {
    final seen = <String>{};
    final chapters = <Chapter>[];
    for (final item in _toc) {
      final title = item.name.trim();
      final url = item.url.trim();
      if (title.isEmpty || url.isEmpty) continue;
      if (!seen.add(url)) continue;
      final id =
          _uuid.v5(Namespace.url.value, '$bookId|${chapters.length}|$url');
      chapters.add(
        Chapter(
          id: id,
          bookId: bookId,
          title: title,
          url: url,
          index: chapters.length,
        ),
      );
    }
    return chapters;
  }

  List<Chapter> _buildEphemeralChapters(String sessionId) {
    return _buildChaptersFromCurrentToc(sessionId);
  }

  Book _buildShelfBook({
    required String bookId,
    required BookSource source,
    required int chapterCount,
  }) {
    final resolvedBookUrl = _pickFirstNonEmpty([
      _detail?.bookUrl ?? '',
      _activeResult.bookUrl,
    ]);
    return Book(
      id: bookId,
      title: _displayName,
      author: _displayAuthor,
      coverUrl: _displayCoverUrl,
      intro: _displayIntro,
      sourceId: source.bookSourceUrl,
      sourceUrl: source.bookSourceUrl,
      bookUrl: resolvedBookUrl,
      latestChapter: _pickFirstNonEmpty([
        _detail?.lastChapter ?? '',
        _activeResult.lastChapter,
      ]),
      totalChapters: chapterCount,
      currentChapter: 0,
      readProgress: 0,
      lastReadTime: null,
      addedTime: DateTime.now(),
      isLocal: false,
      localPath: null,
    );
  }

  Future<BookAddResult> _addToShelfLikeLegado() async {
    try {
      final source =
          _source ?? _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
      if (source == null) {
        return BookAddResult.error('书源不存在或已被删除');
      }
      final bookId = _addService.buildBookId(_activeResult);
      if (bookId == null) {
        return BookAddResult.error('书源不存在或已被删除');
      }
      if (_bookRepo.hasBook(bookId)) {
        return BookAddResult.alreadyExists(bookId);
      }

      final chapters = _buildChaptersFromCurrentToc(bookId);
      final book = _buildShelfBook(
        bookId: bookId,
        source: source,
        chapterCount: chapters.length,
      );
      await _bookRepo.addBook(book);
      if (chapters.isNotEmpty) {
        await _chapterRepo.addChapters(chapters);
      }

      final storedChapterCount =
          await _chapterRepo.countChaptersForBook(bookId);
      if (storedChapterCount != book.totalChapters) {
        await _bookRepo.updateBook(
          book.copyWith(totalChapters: storedChapterCount),
        );
      }
      return BookAddResult.success(bookId);
    } catch (error) {
      return BookAddResult.error('导入失败: ${_compactReason(error.toString())}');
    }
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

  Book? _resolveCachedBookshelfBook() {
    final explicit = widget.bookshelfBook;
    if (explicit != null) {
      final preferredId = (_bookId ?? '').trim();
      if (preferredId.isNotEmpty) {
        final byPreferredId = _bookRepo.getBookById(preferredId);
        if (byPreferredId != null) return byPreferredId;
      }
      return _bookRepo.getBookById(explicit.id) ?? explicit;
    }

    final id = (_bookId ?? '').trim();
    if (id.isNotEmpty) {
      final byId = _bookRepo.getBookById(id);
      if (byId != null) return byId;
    }

    final targetName = _activeResult.name.trim();
    final targetAuthor = _activeResult.author.trim();
    if (targetName.isNotEmpty && targetAuthor.isNotEmpty) {
      for (final item in _bookRepo.getAllBooks()) {
        if (item.title.trim() == targetName &&
            item.author.trim() == targetAuthor) {
          return item;
        }
      }
    }

    final targetBookUrl = _activeResult.bookUrl.trim();
    if (targetBookUrl.isEmpty) return null;
    for (final item in _bookRepo.getAllBooks()) {
      if ((item.bookUrl ?? '').trim() == targetBookUrl) return item;
    }
    return null;
  }

  BookSource? _resolveCachedBookSource(Book shelfBook) {
    final sourceUrl = (shelfBook.sourceUrl ?? shelfBook.sourceId ?? '').trim();
    if (sourceUrl.isNotEmpty) {
      final source = _sourceRepo.getSourceByUrl(sourceUrl);
      if (source != null) return source;
    }
    return _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
  }

  bool _applyCachedBookshelfContext({
    required Book? shelfBook,
    required List<TocItem> cachedToc,
  }) {
    if (shelfBook == null || cachedToc.isEmpty) return false;
    if (!mounted) return true;

    _refreshBookshelfState();
    setState(() {
      _source = _resolveCachedBookSource(shelfBook);
      _detail = _buildFallbackDetail(shelfBook);
      _toc = cachedToc;
      _loading = false;
      _loadingToc = false;
      _error = null;
      _tocError = null;
    });
    return true;
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

  Future<_BookshelfTocCacheResult> _cacheFetchedBookshelfToc({
    required String bookId,
    required List<TocItem> remoteToc,
  }) async {
    if (remoteToc.isEmpty) {
      return (
        toc: const <TocItem>[],
        error: '目录为空（书架缓存中无章节，请先刷新目录）',
      );
    }
    final chapters = _buildStoredChapters(bookId: bookId, toc: remoteToc);
    if (chapters.isEmpty) {
      ExceptionLogService().record(
        node: 'search_book_info.load_context.cache_bookshelf_toc',
        message: '目录落库失败',
        error: '章节为空',
        context: <String, dynamic>{
          'bookId': bookId,
          'remoteTocCount': remoteToc.length,
        },
      );
      return (
        toc: remoteToc,
        error: '目录解析失败：章节名或章节链接为空',
      );
    }
    try {
      await _chapterRepo.clearChaptersForBook(bookId);
      await _chapterRepo.addChapters(chapters);
      final stored = _loadStoredToc(bookId);
      return (toc: stored.isEmpty ? remoteToc : stored, error: null);
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'search_book_info.load_context.cache_bookshelf_toc',
        message: '目录落库失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'bookId': bookId,
          'remoteTocCount': remoteToc.length,
          'chapterCount': chapters.length,
        },
      );
      return (
        toc: remoteToc,
        error: '目录写入失败：${_compactReason(e.toString())}',
      );
    }
  }

  BookDetail _buildFallbackDetail(Book book) {
    return BookDetail(
      name: book.title,
      author: book.author,
      coverUrl: (book.coverUrl ?? '').trim(),
      intro: book.intro ?? '',
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
      final preferredId = _bookId?.trim() ?? '';
      final fallbackId = widget.bookshelfBook!.id.trim();
      final id = preferredId.isNotEmpty ? preferredId : fallbackId;
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

  Future<bool> _loadContext({
    bool silent = false,
    bool forceRemote = false,
  }) async {
    _refreshBookshelfState();
    _restoreBookMenuSwitches();
    _tocUiUseReplace = _settingsService.getTocUiUseReplace();
    _tocUiLoadWordCount = _settingsService.getTocUiLoadWordCount();
    final cacheKey = _buildSessionCacheKey();
    final sessionCache = forceRemote ? null : _readSessionCacheEntry(cacheKey);

    if (!silent && mounted) {
      if (sessionCache != null) {
        setState(() {
          _source = _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
          _detail = sessionCache.detail;
          _toc = sessionCache.toc;
          _loading = false;
          _loadingToc = false;
          _error = null;
          _tocError = null;
        });
      } else {
        setState(() {
          _loading = true;
          _loadingToc = true;
          _error = null;
          _tocError = null;
        });
      }
    }

    if (!forceRemote &&
        !_inBookshelf &&
        sessionCache != null &&
        sessionCache.toc.isNotEmpty) {
      return true;
    }

    final shelfBook = _resolveCachedBookshelfBook();
    final canReuseShelfCache =
        shelfBook != null && _matchesActiveResult(shelfBook);
    final cachedShelfToc = (shelfBook == null || !canReuseShelfCache)
        ? const <TocItem>[]
        : _loadStoredToc(shelfBook.id);

    // 对齐 legado：进入详情优先复用书架已缓存目录，避免每次进页都发网络请求。
    if (canReuseShelfCache &&
        _applyCachedBookshelfContext(
          shelfBook: shelfBook,
          cachedToc: cachedShelfToc,
        )) {
      if (mounted) {
        _writeSessionCacheEntry(
          key: cacheKey,
          detail: _detail,
          toc: _toc,
        );
      }
      return true;
    }

    if (shelfBook != null && canReuseShelfCache && !_canFetchOnlineDetail) {
      final sourceUrl =
          (shelfBook.sourceUrl ?? shelfBook.sourceId ?? '').trim();
      final source =
          sourceUrl.isEmpty ? null : _sourceRepo.getSourceByUrl(sourceUrl);
      final toc = cachedShelfToc;

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
      _writeSessionCacheEntry(
        key: cacheKey,
        detail: _detail,
        toc: _toc,
      );
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
          ? cachedShelfToc
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
      _writeSessionCacheEntry(
        key: cacheKey,
        detail: _detail,
        toc: _toc,
      );
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
    var resolvedToc = toc;
    var resolvedTocError = tocError;
    final shouldUseStoredBookshelfToc = _inBookshelf &&
        _bookId != null &&
        _bookId!.trim().isNotEmpty &&
        (shelfBook == null || canReuseShelfCache || !_isBookshelfEntry);
    if (shouldUseStoredBookshelfToc) {
      final id = _bookId!.trim();
      final localToc = _loadStoredToc(id);
      if (localToc.isNotEmpty) {
        resolvedToc = localToc;
        resolvedTocError = null;
      } else {
        final cacheResult = await _cacheFetchedBookshelfToc(
          bookId: id,
          remoteToc: toc,
        );
        resolvedToc = cacheResult.toc;
        resolvedTocError = resolvedToc.isEmpty
            ? (cacheResult.error ?? tocError)
            : cacheResult.error;
      }
    } else if (resolvedToc.isNotEmpty) {
      resolvedTocError = null;
    }
    final resolvedDetail =
        detail ?? (shelfBook != null ? _buildFallbackDetail(shelfBook) : null);
    setState(() {
      _source = source;
      _detail = resolvedDetail;
      _toc = resolvedToc;
      _loading = false;
      _loadingToc = false;
      _error = detailError;
      _tocError = resolvedToc.isEmpty ? resolvedTocError : null;
    });
    _writeSessionCacheEntry(
      key: cacheKey,
      detail: resolvedDetail,
      toc: resolvedToc,
    );

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
    final fromDetail = _detail?.intro ?? '';
    if (fromDetail.trim().isNotEmpty) return fromDetail;
    final fromResult = _activeResult.intro;
    if (fromResult.trim().isNotEmpty) return fromResult;
    return '';
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

  String _resolveTocMetaValue() {
    if (_loadingToc) return '加载中';
    if (_tocError != null && _toc.isEmpty) return '加载失败';
    if (_toc.isEmpty) return '暂无';

    var index = 0;
    final shelfBook = widget.bookshelfBook;
    if (shelfBook != null) {
      index = shelfBook.currentChapter;
    }

    final safeIndex = index.clamp(0, _toc.length - 1).toInt();
    final title = _toc[safeIndex].name.trim();
    if (title.isNotEmpty) return title;
    return '第${safeIndex + 1}章';
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

  String? _pickFirstNonBlankPreserve(List<String?> candidates) {
    for (final raw in candidates) {
      final value = raw ?? '';
      if (value.trim().isNotEmpty) return value;
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

  Future<List<TxtTocRuleOption>> _loadTxtTocRuleOptions() async {
    final enabledRules = await _txtTocRuleStore.loadEnabledRules();
    if (enabledRules.isEmpty) {
      return TxtParser.defaultTocRuleOptions;
    }
    return enabledRules
        .map(
          (rule) => TxtTocRuleOption(
            name: rule.name,
            rule: rule.rule,
            example: (rule.example ?? '').trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<String?> _pickTxtTocRuleRegex({
    required String currentRegex,
  }) async {
    final options = await _loadTxtTocRuleOptions();
    if (!mounted) return null;
    final normalizedCurrent = currentRegex.trim();
    final items = <AppActionListItem<String>>[
      AppActionListItem<String>(
        value: '',
        icon: normalizedCurrent.isEmpty
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.circle,
        label: normalizedCurrent.isEmpty ? '✓ 自动识别（默认）' : '自动识别（默认）',
      ),
      ...options.map(
        (option) => AppActionListItem<String>(
          value: option.rule,
          icon: normalizedCurrent == option.rule
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.doc_text,
          label: normalizedCurrent == option.rule
              ? '✓ ${option.name}'
              : option.name,
        ),
      ),
    ];
    return showAppActionListSheet<String>(
      context: context,
      title: 'TXT 目录规则',
      message: '选择后会立即重建本地 TXT 目录。',
      showCancel: true,
      items: items,
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
      unawaited(showAppToast(context, message: 'TXT 目录规则已应用'));
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
      intro: book.intro ?? '',
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
      intro: book.intro ?? '',
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
    final resolvedIntro = _pickFirstNonBlankPreserve(<String?>[
          _detail?.intro,
          _activeResult.intro,
          stored?.intro,
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
    // 对齐 legado `shareWithQr`：二维码承载 `bookUrl#bookJson`，使用高纠错等级降低扫码失败率。
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
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
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'book_info_share_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.menu_share_it.qr_build',
        message: '生成书籍详情分享二维码失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'payloadLength': payload.length,
        },
      );
      rethrow;
    }
  }

  Future<void> _copyText(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    unawaited(showAppToast(context, message: successMessage));
  }

  Future<void> _shareBook() async {
    if (kIsWeb) {
      _showMessage('当前平台暂不支持二维码分享');
      return;
    }
    final snapshot = _buildShareBookSnapshot();
    final payload = SearchBookInfoShareHelper.buildPayload(snapshot);
    final subject =
        snapshot.title.trim().isEmpty ? '分享' : snapshot.title.trim();
    File? qrFile;
    try {
      qrFile = await _buildShareQrPngFile(payload);
    } catch (error) {
      _showMessage('分享失败：${_resolveShareErrorMessage(error)}');
      return;
    }
    if (qrFile == null) {
      ExceptionLogService().record(
        node: 'search_book_info.menu_share_it.qr_file',
        message: '生成书籍详情分享二维码失败',
        error: 'qr_file_null',
        context: <String, dynamic>{
          'bookId': snapshot.id,
          'bookUrl': (snapshot.bookUrl ?? '').trim(),
          'payloadLength': payload.length,
        },
      );
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
        ),
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.menu_share_it.share',
        message: '书籍详情分享失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': snapshot.id,
          'bookUrl': (snapshot.bookUrl ?? '').trim(),
          'payloadLength': payload.length,
        },
      );
      if (!mounted) return;
      _showMessage('分享失败：${_resolveShareErrorMessage(error)}');
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
        builder: (_) => SourceLoginWebViewView(
          source: source,
          initialUrl: resolvedUrl,
        ),
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
    final result = await showCupertinoBottomDialog<String>(
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
                  fontSize: SourceUiTokens.itemMetaSize,
                  color: SourceUiTokens.resolveSecondaryTextColor(context),
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
    final result = await showCupertinoBottomDialog<String>(
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
                  fontSize: SourceUiTokens.itemMetaSize,
                  color: SourceUiTokens.resolveSecondaryTextColor(context),
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
      final confirmed = await showCupertinoBottomDialog<bool>(
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
      await _loadContext(silent: true, forceRemote: true);
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
    _removeSessionCacheEntry(_buildSessionCacheKey());
    try {
      await _chapterRepo.clearDownloadedCacheForBook(id);
      if (!mounted) return;
      unawaited(showAppToast(context, message: '成功清理缓存'));
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
    await _loadContext(forceRemote: true);
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
      unawaited(showAppToast(context, message: '目录已刷新（共 ${localToc.length} 章）'));
    } else if (refreshError != null) {
      _showMessage(refreshError);
    }
    return refreshError == null;
  }

  String? _normalizeLocalFilePath(String? rawValue) {
    final raw = (rawValue ?? '').trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return raw;
    if (uri.scheme.toLowerCase() != 'file') return null;
    try {
      final filePath = uri.toFilePath().trim();
      if (filePath.isEmpty) return null;
      return filePath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteFileIfExists(String? filePath) async {
    final normalized = (filePath ?? '').trim();
    if (normalized.isEmpty) return;
    try {
      final file = File(normalized);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.remove_shelf.delete_file',
        message: '移出书架时删除本地文件失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'filePath': normalized},
      );
    }
  }

  Future<void> _deleteLocalBookArtifacts({
    required Book book,
    required bool deleteOriginal,
  }) async {
    final coverPath = _normalizeLocalFilePath(book.coverUrl);
    await _deleteFileIfExists(coverPath);
    if (!deleteOriginal) return;
    final localPath = _normalizeLocalFilePath(book.localPath);
    final originalPath = localPath ?? _normalizeLocalFilePath(book.bookUrl);
    await _deleteFileIfExists(originalPath);
  }

  Future<void> _removeFromShelf({
    required String bookId,
    required bool deleteOriginal,
  }) async {
    final stored = _bookRepo.getBookById(bookId);
    await _bookRepo.deleteBook(bookId);
    if (stored != null && stored.isLocal) {
      await _deleteLocalBookArtifacts(
        book: stored,
        deleteOriginal: deleteOriginal,
      );
    }
  }

  int _resolveReadStartChapter() {
    if (!_inBookshelf) return 0;
    final id = _bookId?.trim() ?? '';
    if (id.isEmpty) return 0;
    final stored = _bookRepo.getBookById(id);
    if (stored == null) return 0;
    final chapterCount = _chapterRepo.getChaptersForBook(id).length;
    final maxIndex = chapterCount > 0
        ? chapterCount - 1
        : math.max(stored.totalChapters - 1, 0);
    return stored.currentChapter.clamp(0, maxIndex).toInt();
  }

  Future<void> _toggleShelf() async {
    if (_shelfBusy) return;
    setState(() => _shelfBusy = true);
    try {
      if (_inBookshelf) {
        final id = _bookId;
        if (id == null || id.trim().isEmpty) return;
        final deleteOriginal = _settingsService.getDeleteBookOriginal();
        await _removeFromShelf(
          bookId: id.trim(),
          deleteOriginal: deleteOriginal,
        );
        if (!mounted) return;
        setState(() {
          _inBookshelf = false;
        });
        return;
      }

      if (!_canFetchOnlineDetail) return;

      final addResult = await _addToShelfLikeLegado();
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
          onToggleUseReplace: _handleToggleUseReplaceFromToc,
          onToggleLoadWordCount: _handleToggleLoadWordCountFromToc,
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
                intro: _pickFirstNonBlankPreserve(
                      [detail?.intro, storedBook.intro],
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
      unawaited(showAppToast(context, message: '目录已刷新（共 ${localToc.length} 章）'));
    } else if (tocRefreshError != null) {
      _showMessage(tocRefreshError);
    }
  }

  Map<String, dynamic> _buildMoreActionLogContext({
    required String actionKey,
  }) {
    return <String, dynamic>{
      'action': actionKey,
      'bookId': (_bookId ?? '').trim(),
      'bookName': _displayName,
      'sourceUrl': _activeResult.sourceUrl,
      'sourceName': _displaySourceName,
      'bookUrl': _resolveBookUrl(),
      'inBookshelf': _inBookshelf,
      'isLocalBook': _isLocalBook(),
      'isLocalTxtBook': _isLocalTxtBook(),
    };
  }

  /// 详情页菜单动作统一兜底：
  /// 1) 记录关键错误日志；2) 给用户明确提示；3) 防止异常冒泡导致页面崩溃。
  Future<void> _executeMoreActionSafely({
    required String actionKey,
    required String actionLabel,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.more_action.$actionKey',
        message: '详情页菜单动作执行失败',
        error: error,
        stackTrace: stackTrace,
        context: _buildMoreActionLogContext(actionKey: actionKey),
      );
      if (!mounted) return;
      _showMessage('$actionLabel失败：${_compactReason(error.toString())}');
    }
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>> _buildSyncMenuItems({
    required bool showEdit,
    required bool showShare,
    required bool showUpload,
    required bool hasLogin,
  }) {
    return [
      if (showEdit)
        const AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.edit,
          icon: CupertinoIcons.pencil,
          label: '编辑',
        ),
      if (showShare)
        const AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.share,
          icon: CupertinoIcons.share,
          label: '分享',
        ),
      if (showUpload)
        const AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.uploadWebDav,
          icon: CupertinoIcons.cloud_upload,
          label: '上传 WebDav',
        ),
      const AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.refresh,
        icon: CupertinoIcons.refresh,
        label: '刷新',
      ),
      if (hasLogin)
        const AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.login,
          icon: CupertinoIcons.person,
          label: '登录',
        ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>
      _buildVariableMenuItems({
    required bool showSetVariable,
  }) {
    if (!showSetVariable)
      return const <AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>[];
    return const [
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.setSourceVariable,
        icon: CupertinoIcons.slider_horizontal_3,
        label: '设置源变量',
      ),
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.setBookVariable,
        icon: CupertinoIcons.book,
        label: '设置书籍变量',
      ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>
      _buildCopyMenuItems() {
    return const [
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.copyBookUrl,
        icon: CupertinoIcons.link,
        label: '拷贝书籍 URL',
      ),
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.copyTocUrl,
        icon: CupertinoIcons.link,
        label: '拷贝目录 URL',
      ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>
      _buildOptionMenuItems({
    required bool showAllowUpdate,
    required bool showSplitLongChapter,
  }) {
    return [
      if (showAllowUpdate)
        AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.toggleAllowUpdate,
          icon: CupertinoIcons.check_mark,
          label: '${_allowUpdate ? '✓ ' : ''}允许更新',
        ),
      if (showSplitLongChapter)
        AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.toggleSplitLongChapter,
          icon: CupertinoIcons.textformat,
          label: _splitLongChapter ? '分割长章节：开' : '分割长章节：关',
        ),
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.toggleDeleteAlert,
        icon: CupertinoIcons.bell,
        label: '${_deleteAlertEnabled ? '✓ ' : ''}删除提醒',
      ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>
      _buildUtilityMenuItems() {
    return const [
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.clearCache,
        icon: CupertinoIcons.delete,
        label: '清理缓存',
      ),
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.logs,
        icon: CupertinoIcons.doc_text,
        label: '日志',
      ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>> _buildMoreMenuItems({
    required bool showEdit,
    required bool showShare,
    required bool hasLogin,
    required bool showSetVariable,
    required bool showAllowUpdate,
    required bool showUpload,
    required bool showSplitLongChapter,
  }) {
    return [
      ..._buildSyncMenuItems(
        showEdit: showEdit,
        showShare: showShare,
        showUpload: showUpload,
        hasLogin: hasLogin,
      ),
      const AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.pinTop,
        icon: CupertinoIcons.arrow_up_to_line,
        label: '置顶',
      ),
      ..._buildVariableMenuItems(showSetVariable: showSetVariable),
      ..._buildCopyMenuItems(),
      ..._buildOptionMenuItems(
        showAllowUpdate: showAllowUpdate,
        showSplitLongChapter: showSplitLongChapter,
      ),
      ..._buildUtilityMenuItems(),
    ];
  }

  _SearchBookInfoMoreActionConfig? _resolveSyncMoreMenuActionConfig(
    _SearchBookInfoMoreMenuAction action,
  ) {
    switch (action) {
      case _SearchBookInfoMoreMenuAction.edit:
        return (
          actionKey: 'edit',
          actionLabel: '编辑',
          action: _openBookEdit,
        );
      case _SearchBookInfoMoreMenuAction.share:
        return (
          actionKey: 'share',
          actionLabel: '分享',
          action: _shareBook,
        );
      case _SearchBookInfoMoreMenuAction.uploadWebDav:
        return (
          actionKey: 'upload',
          actionLabel: '上传 WebDav',
          action: _uploadToRemote,
        );
      case _SearchBookInfoMoreMenuAction.refresh:
        return (
          actionKey: 'refresh',
          actionLabel: '刷新',
          action: _triggerRefresh,
        );
      case _SearchBookInfoMoreMenuAction.login:
        return (
          actionKey: 'login',
          actionLabel: '登录',
          action: _openSourceLogin,
        );
      case _SearchBookInfoMoreMenuAction.pinTop:
        return (
          actionKey: 'top',
          actionLabel: '置顶',
          action: _pinBookToTop,
        );
      default:
        return null;
    }
  }

  _SearchBookInfoMoreActionConfig? _resolveVariableMoreMenuActionConfig(
    _SearchBookInfoMoreMenuAction action,
  ) {
    switch (action) {
      case _SearchBookInfoMoreMenuAction.setSourceVariable:
        return (
          actionKey: 'set_source_variable',
          actionLabel: '设置源变量',
          action: _setSourceVariable,
        );
      case _SearchBookInfoMoreMenuAction.setBookVariable:
        return (
          actionKey: 'set_book_variable',
          actionLabel: '设置书籍变量',
          action: _setBookVariable,
        );
      case _SearchBookInfoMoreMenuAction.copyBookUrl:
        return (
          actionKey: 'copy_book_url',
          actionLabel: '拷贝书籍 URL',
          action: _copyBookUrl,
        );
      case _SearchBookInfoMoreMenuAction.copyTocUrl:
        return (
          actionKey: 'copy_toc_url',
          actionLabel: '拷贝目录 URL',
          action: _copyTocUrl,
        );
      default:
        return null;
    }
  }

  _SearchBookInfoMoreActionConfig? _resolveToggleMoreMenuActionConfig(
    _SearchBookInfoMoreMenuAction action,
  ) {
    switch (action) {
      case _SearchBookInfoMoreMenuAction.toggleAllowUpdate:
        return (
          actionKey: 'allow_update',
          actionLabel: '允许更新',
          action: _toggleAllowUpdate,
        );
      case _SearchBookInfoMoreMenuAction.toggleSplitLongChapter:
        return (
          actionKey: 'split_long_chapter',
          actionLabel: '分割长章节',
          action: _toggleSplitLongChapter,
        );
      case _SearchBookInfoMoreMenuAction.toggleDeleteAlert:
        return (
          actionKey: 'delete_alert',
          actionLabel: '删除提醒',
          action: _toggleDeleteAlertEnabled,
        );
      case _SearchBookInfoMoreMenuAction.clearCache:
        return (
          actionKey: 'clear_cache',
          actionLabel: '清理缓存',
          action: _clearBookCache,
        );
      case _SearchBookInfoMoreMenuAction.logs:
        return (
          actionKey: 'log',
          actionLabel: '日志',
          action: _openAppLogDialog,
        );
      default:
        return null;
    }
  }

  _SearchBookInfoMoreActionConfig _resolveMoreMenuActionConfig(
    _SearchBookInfoMoreMenuAction action,
  ) {
    final resolved = _resolveSyncMoreMenuActionConfig(action) ??
        _resolveVariableMoreMenuActionConfig(action) ??
        _resolveToggleMoreMenuActionConfig(action);
    if (resolved == null) {
      throw StateError('SearchBookInfo: unhandled more menu action: $action');
    }
    return resolved;
  }

  Future<void> _handleMoreMenuAction(_SearchBookInfoMoreMenuAction action) {
    final config = _resolveMoreMenuActionConfig(action);
    return _executeMoreActionSafely(
      actionKey: config.actionKey,
      actionLabel: config.actionLabel,
      action: config.action,
    );
  }

  Future<void> _showMoreActions() async {
    final showInlineEditAction = _shouldShowInlineEditAction(context);
    final showInlineShareAction = _shouldShowInlineShareAction(context);
    final source = _source;
    final hasLogin = SearchBookInfoMenuHelper.shouldShowLogin(
      loginUrl: source?.loginUrl,
    );
    final showSetVariable = SearchBookInfoMenuHelper.shouldShowSetVariable(
      hasSource: source != null,
    );
    final showAllowUpdate = SearchBookInfoMenuHelper.shouldShowAllowUpdate(
      hasSource: source != null,
    );
    final showUpload = SearchBookInfoMenuHelper.shouldShowUpload(
      isLocalBook: _isLocalBook(),
    );
    final showSplitLongChapter =
        SearchBookInfoMenuHelper.shouldShowSplitLongChapter(
      isLocalTxtBook: _isLocalTxtBook(),
    );
    final items = _buildMoreMenuItems(
      showEdit: _inBookshelf && !showInlineEditAction,
      showShare: !showInlineShareAction,
      hasLogin: hasLogin,
      showSetVariable: showSetVariable,
      showAllowUpdate: showAllowUpdate,
      showUpload: showUpload,
      showSplitLongChapter: showSplitLongChapter,
    );
    if (items.isEmpty || !mounted) return;
    final selected = await showAppPopoverMenu<_SearchBookInfoMoreMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: items,
    );
    if (!mounted || selected == null) return;
    await _handleMoreMenuAction(selected);
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

  int _resolveInlineActionCapacity(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= _minWidthForInlineEditAction) return 2;
    if (width >= _minWidthForInlineShareAction) return 1;
    return 0;
  }

  bool _shouldShowInlineShareAction(BuildContext context) {
    return _resolveInlineActionCapacity(context) >= 1;
  }

  bool _shouldShowInlineEditAction(BuildContext context) {
    if (!_inBookshelf) return false;
    return _resolveInlineActionCapacity(context) >= 2;
  }

  int _normalizeChangeSourceDelaySeconds(int seconds) {
    return seconds.clamp(0, 9999).toInt();
  }

  Future<void> _handleChangeSourceDelayChanged(int seconds) async {
    final normalized = _normalizeChangeSourceDelaySeconds(seconds);
    _changeSourceDelaySeconds = normalized;
    await _settingsService.saveBatchChangeSourceDelay(normalized);
  }

  List<Chapter> _loadStoredChapters(String bookId) {
    final chapters = _chapterRepo
        .getChaptersForBook(bookId)
        .toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));
    return chapters;
  }

  String _resolveSwitchSourceChapterTitle({
    required Book previousBook,
    required List<Chapter> previousChapters,
  }) {
    if (previousChapters.isEmpty) {
      return _pickFirstNonEmpty(
            <String>[
              previousBook.latestChapter ?? '',
              _activeResult.lastChapter,
            ],
          ) ??
          '';
    }
    final safeIndex = previousBook.currentChapter
        .clamp(0, previousChapters.length - 1)
        .toInt();
    return previousChapters[safeIndex].title;
  }

  Future<bool> _migrateBookshelfBookAfterSourceSwitch({
    required Book previousBook,
    required List<Chapter> previousChapters,
  }) async {
    final source =
        _source ?? _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
    if (source == null) return false;

    final targetBookId = _addService.buildBookId(_activeResult)?.trim() ?? '';
    if (targetBookId.isEmpty) return false;

    final targetChapters =
        _buildStoredChapters(bookId: targetBookId, toc: _toc);
    if (targetChapters.isEmpty) return false;

    final currentChapterTitle = _resolveSwitchSourceChapterTitle(
      previousBook: previousBook,
      previousChapters: previousChapters,
    );
    final targetChapterIndex =
        ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: targetChapters,
      currentChapterTitle: currentChapterTitle,
      currentChapterIndex: previousBook.currentChapter,
      oldChapterCount: previousChapters.length,
    ).clamp(0, targetChapters.length - 1).toInt();

    final resolvedBookUrl = _resolveBookUrl().trim();
    final migratedBook = previousBook.copyWith(
      id: targetBookId,
      title: _displayName,
      author: _displayAuthor,
      coverUrl: _displayCoverUrl,
      intro: _displayIntro,
      sourceId: source.bookSourceUrl,
      sourceUrl: source.bookSourceUrl,
      bookUrl: resolvedBookUrl.isEmpty ? previousBook.bookUrl : resolvedBookUrl,
      latestChapter: _pickFirstNonEmpty(<String>[
        _detail?.lastChapter ?? '',
        targetChapters.last.title,
        previousBook.latestChapter ?? '',
      ]),
      totalChapters: targetChapters.length,
      currentChapter: targetChapterIndex,
    );

    final previousBookId = previousBook.id.trim();
    final sameBookId = previousBookId == targetBookId;
    if (!sameBookId && _bookRepo.hasBook(targetBookId)) {
      await _bookRepo.deleteBook(targetBookId);
    }
    if (sameBookId) {
      await _bookRepo.updateBook(migratedBook);
    } else {
      await _bookRepo.addBook(migratedBook);
    }
    await _chapterRepo.clearChaptersForBook(targetBookId);
    await _chapterRepo.addChapters(targetChapters);
    if (!sameBookId && previousBookId.isNotEmpty) {
      await _bookRepo.deleteBook(previousBookId);
    }

    if (!mounted) return true;
    final refreshedToc = _loadStoredToc(targetBookId);
    setState(() {
      _bookId = targetBookId;
      _inBookshelf = true;
      _syncDisplayFromStoredBook(migratedBook);
      _toc = refreshedToc;
      _tocError = refreshedToc.isEmpty ? '目录为空（书架缓存中无章节，请先刷新目录）' : null;
    });
    return true;
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
    final searchDelaySeconds = _normalizeChangeSourceDelaySeconds(
      _changeSourceDelaySeconds,
    );
    final searchResults = <SearchResult>[];
    for (var index = 0; index < sortedEnabledSources.length; index++) {
      final source = sortedEnabledSources[index];
      if (index > 0 && searchDelaySeconds > 0) {
        await Future<void>.delayed(Duration(seconds: searchDelaySeconds));
      }
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
      loadTocEnabled: false,
      changeSourceDelaySeconds: _changeSourceDelaySeconds,
      onChangeSourceDelayChanged: _handleChangeSourceDelayChanged,
    );
    if (selected == null) return;
    await _applySourceCandidate(selected);
  }

  Future<void> _applySourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final previousResult = _activeResult;
    final previousBookId = (_bookId ?? '').trim();
    final previousBook = (_inBookshelf && previousBookId.isNotEmpty)
        ? _bookRepo.getBookById(previousBookId)
        : null;
    final previousChapters = previousBook == null
        ? const <Chapter>[]
        : _loadStoredChapters(previousBook.id);
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

    final loaded = await _loadContext(silent: true, forceRemote: true);
    if (!loaded) {
      if (!mounted) return;
      setState(() {
        _activeResult = previousResult;
        if (previousBookId.isNotEmpty) {
          _bookId = previousBookId;
          _inBookshelf = _bookRepo.hasBook(previousBookId);
        }
      });
      await _loadContext(forceRemote: true);
      _showMessage('换源失败，已回退到原书源');
      return;
    }

    if (previousBook != null) {
      final migrated = await _migrateBookshelfBookAfterSourceSwitch(
        previousBook: previousBook,
        previousChapters: previousChapters,
      );
      if (!migrated) {
        if (!mounted) return;
        setState(() {
          _activeResult = previousResult;
          _bookId = previousBookId;
          _inBookshelf = _bookRepo.hasBook(previousBookId);
        });
        await _loadContext(forceRemote: true);
        _showMessage('换源失败，已回退到原书源');
        return;
      }
    }

    _removeSessionCacheEntry(_buildSessionCacheKeyForResult(previousResult));
    if (!mounted) return;
    unawaited(showAppToast(context, message: '已切换到：${candidate.source.bookSourceName}'));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showInlineEditAction = _shouldShowInlineEditAction(context);
    final showInlineShareAction = _shouldShowInlineShareAction(context);
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final backgroundColor =
        CupertinoColors.systemBackground.resolveFrom(context);
    final borderColor = SourceUiTokens.resolveSeparatorColor(context);
    final primaryTextColor = CupertinoColors.label.resolveFrom(context);
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);
    final primaryActionColor =
        SourceUiTokens.resolvePrimaryActionColor(context);
    final destructiveColor = SourceUiTokens.resolveDangerColor(context);
    final warningColor = CupertinoColors.systemOrange.resolveFrom(context);
    final coverUrl = _displayCoverUrl;
    final heroTopExtend =
        MediaQuery.paddingOf(context).top + kMinInteractiveDimensionCupertino;

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
    final showUpdateTime = updateTime != null;
    final showWordCount = wordCount != null;
    final tocIsLast = !showUpdateTime && !showWordCount;
    final updateTimeIsLast = showUpdateTime && !showWordCount;

    return AppCupertinoPageScaffold(
      title: '书籍详情',
      includeTopSafeArea: false,
      includeBottomSafeArea: false,
      transitionBetweenRoutes: false,
      navigationBarBackgroundColor: CupertinoColors.transparent,
      navigationBarBorder: const Border(),
      navigationBarEnableBackgroundFilterBlur: false,
      navigationBarAutomaticBackgroundVisibility: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showInlineEditAction)
            AppNavBarButton(
              onPressed: _openBookEdit,
              child: const Icon(CupertinoIcons.pencil),
            ),
          if (showInlineShareAction)
            AppNavBarButton(
              onPressed: _shareBook,
              child: const Icon(CupertinoIcons.share),
            ),
          AppNavBarButton(
            key: _moreMenuKey,
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
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 286,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -heroTopExtend,
                        left: 0,
                        right: 0,
                        height: 286 + heroTopExtend,
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
                                      CupertinoColors.black.withValues(
                                        alpha: 0.32,
                                      ),
                                      CupertinoColors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: backgroundColor,
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
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
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
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SourceUiTokens.pagePaddingHorizontal,
                    4,
                    SourceUiTokens.pagePaddingHorizontal,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle.copyWith(
                          fontSize: SourceUiTokens.detailTitleSize,
                          height: 1.25,
                          color: primaryTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (kind != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: _StatusChip(
                            label: kind,
                            color: primaryActionColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _CupertinoCardContainer(
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
                                  ? _MetaActionChip(
                                      label: '换源',
                                      onPressed: _switchingSource
                                          ? null
                                          : _switchSource,
                                      color: primaryActionColor,
                                    )
                                  : null,
                            ),
                            _MetaLine(
                              icon: CupertinoIcons.book,
                              text: '最新：${lastChapter ?? '暂无'}',
                            ),
                            _MetaLine(
                              icon: CupertinoIcons.folder_open,
                              text: '目录：${_resolveTocMetaValue()}',
                              trailing: _MetaActionChip(
                                label: '查看',
                                onPressed: _openToc,
                                color: primaryActionColor,
                              ),
                              isLast: tocIsLast,
                            ),
                            if (updateTime != null)
                              _MetaLine(
                                icon: CupertinoIcons.clock,
                                text: '更新：$updateTime',
                                isLast: updateTimeIsLast,
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
                      _CupertinoCardContainer(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '简介',
                              style: textStyle.copyWith(
                                fontSize: SourceUiTokens.itemTitleSize,
                                color: primaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Text(
                                _displayIntro,
                                style: textStyle.copyWith(
                                  fontSize: SourceUiTokens.actionTextSize,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
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
                                color: primaryActionColor,
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
                        _CupertinoCardContainer(
                          borderColor: destructiveColor,
                          borderWidth: 0.5,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Text(
                            _error!,
                            style: textStyle.copyWith(
                              fontSize: SourceUiTokens.actionTextSize,
                              color: destructiveColor,
                            ),
                          ),
                        ),
                      ],
                      if (_tocError != null) ...[
                        const SizedBox(height: 10),
                        _CupertinoCardContainer(
                          borderColor: warningColor,
                          borderWidth: 0.5,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Text(
                            _tocError!,
                            style: textStyle.copyWith(
                              fontSize: SourceUiTokens.actionTextSize,
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
              color: backgroundColor,
              border: Border(
                top: BorderSide(
                  color: borderColor,
                  width: SourceUiTokens.borderWidth,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              SourceUiTokens.pagePaddingHorizontal,
              8,
              SourceUiTokens.pagePaddingHorizontal,
              math.max(8, MediaQuery.paddingOf(context).bottom),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _shelfBusy ? null : _toggleShelf,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius:
                            BorderRadius.circular(SourceUiTokens.radiusControl),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            if (_shelfBusy) ...[
                              const SizedBox.square(
                                dimension: 14,
                                child: CupertinoActivityIndicator(radius: 7),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _inBookshelf ? '移出书架' : '加入书架',
                              style: textStyle.copyWith(
                                fontSize: SourceUiTokens.actionTextSize,
                                fontWeight: FontWeight.w600,
                                color: primaryActionColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    minimumSize: const Size.square(SourceUiTokens.minTapSize),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: (_loading || _loadingToc)
                        ? null
                        : () => _openReader(
                              initialChapter: _resolveReadStartChapter(),
                            ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: primaryActionColor,
                        borderRadius:
                            BorderRadius.circular(SourceUiTokens.radiusControl),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Center(
                          child: Text(
                            '开始阅读',
                            style: textStyle.copyWith(
                              fontSize: SourceUiTokens.actionTextSize,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    minimumSize: const Size.square(SourceUiTokens.minTapSize),
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

