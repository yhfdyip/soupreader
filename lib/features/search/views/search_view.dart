import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/source_aware_cover_image.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/models/book.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../source/services/source_cover_loader.dart';
import '../../source/views/source_list_view.dart';
import '../../settings/views/app_log_dialog.dart';
import '../models/search_scope.dart';
import '../models/search_scope_group_helper.dart';
import '../services/search_cache_service.dart';
import '../services/search_input_hint_helper.dart';
import '../services/search_load_more_helper.dart';
import 'search_book_info_view.dart';
import 'search_scope_picker_view.dart';

/// 搜索页面（对齐 legado 核心语义：范围、过滤、可停止、历史词）。
class SearchView extends StatefulWidget {
  final List<String>? sourceUrls;
  final String? initialKeyword;

  const SearchView({
    super.key,
    this.initialKeyword,
  }) : sourceUrls = null;
  const SearchView.scoped({
    super.key,
    required this.sourceUrls,
    this.initialKeyword,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _resultScrollController = ScrollController();
  final SettingsService _settingsService = SettingsService();
  final SearchCacheService _cacheService = SearchCacheService();
  late final BookRepository _bookRepo;
  late final SourceRepository _sourceRepo;
  late final BookAddService _addService;
  final _LegadoSearchAggregator _aggregator = _LegadoSearchAggregator();

  late AppSettings _settings;
  List<String> _historyKeywords = const <String>[];

  List<SearchResult> _results = <SearchResult>[];
  List<_SearchDisplayItem> _displayResults = <_SearchDisplayItem>[];
  final List<_SourceRunIssue> _sourceIssues = <_SourceRunIssue>[];
  final Set<CancelToken> _activeCancelTokens = <CancelToken>{};
  bool _isSearching = false;
  String _searchingSource = '';
  String _currentKeyword = '';
  String _currentCacheKey = '';
  int _currentPage = 0;
  bool _hasMore = false;
  List<BookSource> _sessionSources = const <BookSource>[];
  int _completedSources = 0;
  int _searchSessionSeed = 0;
  int _runningSearchSessionId = 0;
  StreamSubscription<List<BookSource>>? _enabledGroupsSub;
  StreamSubscription<List<Book>>? _bookshelfBooksSub;
  bool _enabledGroupsReady = false;
  List<String> _enabledGroups = const <String>[];
  List<Book> _bookshelfBooks = const <Book>[];
  bool _searchHasFocus = false;
  final Map<String, SourceAwareCoverLoadState> _coverLoadStateByItem =
      <String, SourceAwareCoverLoadState>{};

  bool get _showManualLoadMorePanel =>
      SearchLoadMoreHelper.shouldShowManualLoadMore(
        isSearching: _isSearching,
        hasMore: _hasMore,
        resultCount: _displayResults.length,
      );

  bool get _isPrecisionSearchEnabled =>
      normalizeSearchFilterMode(_settings.searchFilterMode) ==
      SearchFilterMode.precise;

  bool get _showInputHelpPanel =>
      SearchInputHintHelper.shouldShowInputHelpPanel(
        isSearching: _isSearching,
        hasInputFocus: _searchHasFocus,
        resultCount: _displayResults.length,
        currentKeyword: _searchController.text,
      );

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _bookRepo = BookRepository(db);
    _sourceRepo = SourceRepository(db);
    _addService = BookAddService(database: db);
    _searchHasFocus = _searchFocusNode.hasFocus;
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _resultScrollController.addListener(_onResultScroll);
    _settings = _sanitizeSettings(_settingsService.appSettings);
    _applyScopedEntrySearchScope();
    _startEnabledGroupsFlow();
    _startBookshelfFlow();
    unawaited(_prepareLocalState());

    final initialKeyword =
        SearchInputHintHelper.normalizeKeyword(widget.initialKeyword ?? '');
    if (initialKeyword.isNotEmpty) {
      _searchController.text = initialKeyword;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: initialKeyword.length),
      );
    }

    final shouldAutoSubmit =
        SearchInputHintHelper.shouldAutoSubmitInitialKeyword(
      initialKeyword: initialKeyword,
    );
    final shouldRequestFocus = SearchInputHintHelper.shouldRequestFocusOnOpen(
      initialKeyword: initialKeyword,
    );
    if (shouldAutoSubmit || shouldRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (shouldAutoSubmit) {
          _search();
          return;
        }
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    unawaited(_enabledGroupsSub?.cancel());
    unawaited(_bookshelfBooksSub?.cancel());
    _cancelOngoingSearch(updateState: false);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _resultScrollController.removeListener(_onResultScroll);
    _resultScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    final hasFocus = _searchFocusNode.hasFocus;
    if (_searchHasFocus == hasFocus) {
      return;
    }
    if (!mounted) {
      _searchHasFocus = hasFocus;
      return;
    }
    setState(() {
      _searchHasFocus = hasFocus;
    });
  }

  Future<void> _prepareLocalState() async {
    final history = await _cacheService.loadHistory();
    await _cacheService.purgeExpiredCache(
      retentionDays: _settings.searchCacheRetentionDays,
    );
    if (!mounted) return;
    setState(() => _historyKeywords = history);
  }

  void _startEnabledGroupsFlow() {
    _enabledGroupsSub?.cancel();
    _enabledGroupsSub = _sourceRepo.watchAllSources().listen((allSources) {
      final next = SearchScopeGroupHelper.enabledGroupsFromSources(allSources);
      if (_enabledGroupsReady && listEquals(next, _enabledGroups)) {
        return;
      }
      if (!mounted) {
        _enabledGroupsReady = true;
        _enabledGroups = next;
        return;
      }
      setState(() {
        _enabledGroupsReady = true;
        _enabledGroups = next;
      });
    });
  }

  void _startBookshelfFlow() {
    _bookshelfBooksSub?.cancel();
    _bookshelfBooksSub = _bookRepo.watchAllBooks().listen((books) {
      if (!mounted) {
        _bookshelfBooks = books;
        return;
      }
      setState(() {
        _bookshelfBooks = books;
      });
    });
  }

  AppSettings _sanitizeSettings(AppSettings settings) {
    final normalizedScope =
        SearchScope.normalizeScopeText(settings.searchScope);
    final legacyUrls = settings.searchScopeSourceUrls
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return settings.copyWith(
      searchFilterMode: normalizeSearchFilterMode(settings.searchFilterMode),
      searchConcurrency: settings.searchConcurrency.clamp(2, 12),
      searchCacheRetentionDays: settings.searchCacheRetentionDays.clamp(1, 30),
      searchScope: normalizedScope,
      searchScopeSourceUrls: legacyUrls,
    );
  }

  Future<void> _saveSettings(AppSettings next) async {
    final normalized = _sanitizeSettings(next);
    if (mounted) {
      setState(() => _settings = normalized);
    } else {
      _settings = normalized;
    }
    await _settingsService.saveAppSettings(normalized);
  }

  Set<String> _normalizeUrlSet(Iterable<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  List<BookSource> _allSources() {
    final all = _sourceRepo.getAllSources().toList(growable: false);
    final indexed = all.asMap().entries.toList(growable: false);
    indexed.sort((a, b) {
      final orderCompare = a.value.customOrder.compareTo(b.value.customOrder);
      if (orderCompare != 0) return orderCompare;
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  List<BookSource> _allEnabledSources(List<BookSource> allSources) {
    return allSources
        .where((source) => source.enabled == true)
        .toList(growable: false);
  }

  void _applyScopedEntrySearchScope() {
    final scoped = widget.sourceUrls;
    if (scoped == null || scoped.isEmpty) return;
    final scopedUrls = _normalizeUrlSet(scoped);
    if (scopedUrls.isEmpty) return;
    if (scopedUrls.length != 1) return;
    final sourceUrl = scopedUrls.first;
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) return;
    final nextScope = SearchScope.fromSource(source);
    if (nextScope == _settings.searchScope) return;
    unawaited(_saveSettings(_settings.copyWith(searchScope: nextScope)));
  }

  _ResolvedSearchScope _resolveSearchScope() {
    final allSources = _allSources();
    final enabledSources = _allEnabledSources(allSources);
    final resolved = SearchScope(_settings.searchScope).resolve(
      enabledSources,
      allSourcesForSourceMode: allSources,
    );
    return _ResolvedSearchScope(
      allSources: allSources,
      allEnabledSources: enabledSources,
      resolvedScope: resolved,
    );
  }

  void _handleCoverLoadState(String itemKey, SourceAwareCoverLoadState state) {
    if (!mounted) return;
    if (_coverLoadStateByItem[itemKey] == state) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_coverLoadStateByItem[itemKey] == state) return;
      setState(() {
        _coverLoadStateByItem[itemKey] = state;
      });
    });
  }

  List<SearchResult> _filterResultsByMode(
    List<SearchResult> incoming,
    String keyword,
  ) {
    switch (normalizeSearchFilterMode(_settings.searchFilterMode)) {
      case SearchFilterMode.none:
      case SearchFilterMode.normal:
        return incoming;
      case SearchFilterMode.precise:
        if (keyword.isEmpty) return incoming;
        return incoming.where((item) {
          return item.name.contains(keyword) || item.author.contains(keyword);
        }).toList(growable: false);
    }
  }

  void _rebuildDisplayResults({String? keyword}) {
    final searchKeyword = keyword ?? _currentKeyword;
    final bookshelfKeys = _addService.buildSearchBookshelfKeys();
    final built = _aggregator.buildDisplayItems(
      searchKeyword: searchKeyword,
      precision: _isPrecisionSearchEnabled,
      isInBookshelf: (item) => _addService.isInBookshelf(
        item,
        bookshelfKeys: bookshelfKeys,
      ),
    );
    _results = _aggregator.rawResults;

    final activeKeys = built.map((item) => item.key).toSet();
    _coverLoadStateByItem.removeWhere((key, _) => !activeKeys.contains(key));
    for (final item in built) {
      final coverUrl = item.displayCoverUrl.trim();
      if (coverUrl.isEmpty) {
        _coverLoadStateByItem[item.key] = SourceAwareCoverLoadState.emptyUrl;
      } else if (_coverLoadStateByItem[item.key] ==
          SourceAwareCoverLoadState.emptyUrl) {
        _coverLoadStateByItem.remove(item.key);
      }
    }

    _displayResults = built;
  }

  bool _isSearchSessionActive(int sessionId) {
    return mounted && _isSearching && _runningSearchSessionId == sessionId;
  }

  int _startSearchSession() {
    _searchSessionSeed++;
    _runningSearchSessionId = _searchSessionSeed;
    return _runningSearchSessionId;
  }

  bool _isCanceledError(Object error) =>
      error is DioException && error.type == DioExceptionType.cancel;

  void _cancelOngoingSearch({bool updateState = true}) {
    _isSearching = false;
    _runningSearchSessionId = 0;
    _searchingSource = '';
    _hasMore = false;

    final tokens = _activeCancelTokens.toList(growable: false);
    _activeCancelTokens.clear();
    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel('search canceled');
      }
    }

    if (updateState && mounted) {
      setState(() {});
    }
  }

  void _onResultScroll() {
    if (!_resultScrollController.hasClients) return;
    final position = _resultScrollController.position;
    if (!_isAtBottomLikeLegado(position)) return;
    if (_isSearching || !_hasMore) return;
    if (_currentKeyword.trim().isEmpty) return;
    if (_displayResults.isEmpty) return;
    unawaited(_loadNextPage());
  }

  /// 对齐 legado `SearchActivity`：仅在“已到底部”时触发下一页。
  bool _isAtBottomLikeLegado(ScrollPosition position) {
    final remaining = position.maxScrollExtent - position.pixels;
    return remaining <= 1.0;
  }

  Future<void> _continueLoadMoreLikeLegado() async {
    if (!_showManualLoadMorePanel) return;
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isSearching || !_hasMore) return;
    if (_sessionSources.isEmpty) return;
    if (_currentKeyword.trim().isEmpty) return;
    final sessionId = _runningSearchSessionId;
    if (sessionId == 0) return;
    final nextPage = _currentPage + 1;

    setState(() {
      _isSearching = true;
      _completedSources = 0;
      _searchingSource = '';
    });

    final hasMore = await _runSearchPage(
      searchSessionId: sessionId,
      sources: _sessionSources,
      page: nextPage,
    );

    _finishSearchPage(sessionId, hasMore, newPage: nextPage);
  }

  Future<void> _search() async {
    _searchFocusNode.unfocus();
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final resolvedScopeState = _resolveSearchScope();
    if (resolvedScopeState.resolvedScope.normalizedScope !=
        _settings.searchScope) {
      await _saveSettings(
        _settings.copyWith(
          searchScope: resolvedScopeState.resolvedScope.normalizedScope,
        ),
      );
      if (!mounted) return;
    }

    final enabledSources = resolvedScopeState.sources;
    if (enabledSources.isEmpty) {
      _showMessage('当前搜索范围没有启用书源，请先调整“搜索范围”。');
      return;
    }

    // 新搜索会话清理封面内存缓存（含失败负缓存），避免旧失败状态持续影响显示。
    SourceCoverLoader.instance.clearMemoryCache();

    await _saveHistoryKeyword(keyword);

    final cacheKey = _cacheService.buildCacheKey(
      keyword: keyword,
      filterMode: normalizeSearchFilterMode(_settings.searchFilterMode),
      scopeSourceUrls: enabledSources.map((item) => item.bookSourceUrl),
    );
    final cached = await _cacheService.readCache(
      key: cacheKey,
      retentionDays: _settings.searchCacheRetentionDays,
    );
    final cachedResults = cached?.results ?? const <SearchResult>[];

    _cancelOngoingSearch(updateState: false);
    final searchSessionId = _startSearchSession();
    _currentKeyword = keyword;
    _currentCacheKey = cacheKey;
    _currentPage = 1;
    _hasMore = true;
    _sessionSources = enabledSources;
    _aggregator.reset();
    _aggregator.ingest(cachedResults);

    setState(() {
      _isSearching = true;
      _coverLoadStateByItem.clear();
      _sourceIssues.clear();
      _completedSources = 0;
      _searchingSource = '';
      _rebuildDisplayResults(keyword: keyword);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_resultScrollController.hasClients) return;
      _resultScrollController.jumpTo(0);
    });

    final hasMore = await _runSearchPage(
      searchSessionId: searchSessionId,
      sources: enabledSources,
      page: _currentPage,
    );

    _finishSearchPage(searchSessionId, hasMore);
    unawaited(_maybePromptEmptyResultLikeLegado());
  }

  void _finishSearchPage(int sessionId, bool hasMore, {int? newPage}) {
    if (!_isSearchSessionActive(sessionId)) return;
    if (newPage != null) _currentPage = newPage;
    if (_results.isNotEmpty && _currentCacheKey.isNotEmpty) {
      unawaited(
          _cacheService.writeCache(key: _currentCacheKey, results: _results));
    }
    setState(() {
      _isSearching = false;
      _searchingSource = '';
      _hasMore = hasMore;
    });
  }

  Future<void> _maybePromptEmptyResultLikeLegado() async {
    if (!mounted) return;
    if (_isSearching) return;
    if (_displayResults.isNotEmpty) return;
    if (_currentKeyword.trim().isEmpty) return;
    final scope = _resolveSearchScope().resolvedScope;
    if (scope.isAll) return;
    final scopeLabel = scope.display();

    if (_isPrecisionSearchEnabled) {
      final confirm = await _confirm(
        title: '搜索结果为空',
        content: '$scopeLabel 搜索结果为空，是否关闭精准搜索并重试？',
        confirmText: '关闭并重试',
      );
      if (!confirm || !mounted) return;
      await _saveSettings(
        _settings.copyWith(searchFilterMode: SearchFilterMode.normal),
      );
      if (!mounted) return;
      await _search();
      return;
    }

    final confirm = await _confirm(
      title: '搜索结果为空',
      content: '$scopeLabel 搜索结果为空，是否切换到全部书源并重试？',
      confirmText: '切换并重试',
    );
    if (!confirm || !mounted) return;
    await _saveSettings(
      _settings.copyWith(searchScope: ''),
    );
    if (!mounted) return;
    await _search();
  }

  Future<bool> _runSearchPage({
    required int searchSessionId,
    required List<BookSource> sources,
    required int page,
  }) async {
    if (sources.isEmpty) return false;
    var nextSourceIndex = 0;
    var pageHasAnyResult = false;
    final workerCount = sources.length < _settings.searchConcurrency
        ? sources.length
        : _settings.searchConcurrency;

    Future<void> runWorker() async {
      while (true) {
        if (!_isSearchSessionActive(searchSessionId)) return;
        if (nextSourceIndex >= sources.length) return;
        final source = sources[nextSourceIndex++];
        if (!_isSearchSessionActive(searchSessionId)) return;
        setState(() => _searchingSource = source.bookSourceName);

        final token = CancelToken();
        _activeCancelTokens.add(token);

        try {
          final debugEngine = RuleParserEngine();
          final debugResult = await debugEngine
              .searchDebug(
                source,
                _currentKeyword,
                page: page,
                cancelToken: token,
              )
              .timeout(const Duration(seconds: 30));
          if (!_isSearchSessionActive(searchSessionId)) return;

          final issue = _buildSearchIssue(source, debugResult);
          if (issue != null) {
            _recordSearchIssueLog(
              source: source,
              page: page,
              reason: issue.reason,
              statusCode: debugResult.fetch.statusCode,
              listCount: debugResult.listCount,
            );
          }
          final filtered =
              _filterResultsByMode(debugResult.results, _currentKeyword.trim());
          if (filtered.isNotEmpty) {
            pageHasAnyResult = true;
          }
          final ingestStat = _aggregator.ingest(filtered);
          if (!_isSearchSessionActive(searchSessionId)) return;

          setState(() {
            if (ingestStat.changed) {
              _rebuildDisplayResults(keyword: _currentKeyword);
            }
            if (issue != null) {
              _sourceIssues.add(issue);
            }
            _completedSources++;
          });
        } catch (e, st) {
          if (!_isSearchSessionActive(searchSessionId)) return;
          if (_isCanceledError(e)) {
            setState(() => _completedSources++);
            return;
          }
          if (e is TimeoutException) {
            _recordSearchIssueLog(
              source: source,
              page: page,
              reason: '请求超时（30s）',
              error: e,
              stackTrace: st,
            );
            setState(() => _completedSources++);
            return;
          }
          final reason = '搜索异常：${_compactReason(e.toString())}';
          _recordSearchIssueLog(
            source: source,
            page: page,
            reason: reason,
            error: e,
            stackTrace: st,
          );
          setState(() {
            _completedSources++;
            _sourceIssues.add(
              _SourceRunIssue(
                sourceName: source.bookSourceName,
                reason: reason,
              ),
            );
          });
        } finally {
          _activeCancelTokens.remove(token);
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => runWorker()),
    );
    return pageHasAnyResult;
  }

  _SourceRunIssue? _buildSearchIssue(
    BookSource source,
    SearchDebugResult debugResult,
  ) {
    final explicitError = (debugResult.error ?? '').trim();
    if (explicitError.isNotEmpty) {
      return _SourceRunIssue(
        sourceName: source.bookSourceName,
        reason: _compactReason(explicitError),
      );
    }

    final statusCode = debugResult.fetch.statusCode;
    if (statusCode != null && statusCode >= 400) {
      final detail =
          _compactReason(debugResult.fetch.error ?? 'HTTP $statusCode');
      return _SourceRunIssue(
        sourceName: source.bookSourceName,
        reason: '请求失败（HTTP $statusCode）：$detail',
      );
    }

    if (debugResult.fetch.body != null &&
        debugResult.listCount > 0 &&
        debugResult.results.isEmpty) {
      return _SourceRunIssue(
        sourceName: source.bookSourceName,
        reason: '解析到列表 ${debugResult.listCount} 项，但缺少 name/bookUrl',
      );
    }

    return null;
  }

  String _compactReason(String text, {int maxLength = 96}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}…';
  }

  Future<void> _saveHistoryKeyword(String keyword) async {
    final history = await _cacheService.saveHistoryKeyword(keyword);
    if (!mounted) return;
    setState(() => _historyKeywords = history);
  }

  Future<void> _removeHistoryKeyword(String keyword) async {
    final history = await _cacheService.deleteHistoryKeyword(keyword);
    if (!mounted) return;
    setState(() => _historyKeywords = history);
  }

  Future<void> _clearHistory() async {
    final confirmed = await _confirm(
      title: '清空搜索历史',
      content: '确定清空所有搜索历史吗？',
      confirmText: '清空',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _cacheService.clearHistory();
    if (!mounted) return;
    setState(() => _historyKeywords = const <String>[]);
  }

  Future<void> _openBookInfo(SearchResult result) async {
    try {
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => SearchBookInfoView(result: result),
        ),
      );
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'search.open_book_info',
        message: '打开书籍详情失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'bookName': result.name,
          'bookUrl': result.bookUrl,
          'sourceUrl': result.sourceUrl,
          'sourceName': result.sourceName,
        },
      );
      if (mounted) {
        _showMessage('打开详情失败，请稍后重试');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _rebuildDisplayResults(keyword: _currentKeyword));
  }

  void _recordSearchIssueLog({
    required BookSource source,
    required int page,
    required String reason,
    int? statusCode,
    int? listCount,
    Object? error,
    StackTrace? stackTrace,
  }) {
    ExceptionLogService().record(
      node: 'search.run_source',
      message: '书源搜索失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'keyword': _currentKeyword,
        'page': page,
        'reason': reason,
        'sourceUrl': source.bookSourceUrl,
        'sourceName': source.bookSourceName,
        if (statusCode != null) 'statusCode': statusCode,
        if (listCount != null) 'listCount': listCount,
      },
    );
  }

  bool _shouldAutoSearchOnScopeChanged() {
    return SearchInputHintHelper.shouldAutoSearchOnScopeChanged(
      isSearching: _isSearching,
      hasInputFocus: _searchHasFocus,
      resultCount: _displayResults.length,
      currentKeyword: _searchController.text,
    );
  }

  Future<void> _showSearchSettingsSheet() async {
    final action = await showAppActionListSheet<_SearchSettingAction>(
      context: context,
      title: '搜索设置',
      message: '以下设置会自动保存',
      showCancel: true,
      items: [
        AppActionListItem<_SearchSettingAction>(
          value: _SearchSettingAction.precisionSearch,
          icon: _isPrecisionSearchEnabled
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.search,
          label: _isPrecisionSearchEnabled ? '✓ 精准搜索' : '精准搜索',
        ),
        const AppActionListItem<_SearchSettingAction>(
          value: _SearchSettingAction.sourceManage,
          icon: CupertinoIcons.book,
          label: '书源管理',
        ),
        const AppActionListItem<_SearchSettingAction>(
          value: _SearchSettingAction.scope,
          icon: CupertinoIcons.square_grid_2x2,
          label: '多分组/书源',
        ),
        const AppActionListItem<_SearchSettingAction>(
          value: _SearchSettingAction.logs,
          icon: CupertinoIcons.doc_text,
          label: '日志',
        ),
      ],
    );

    if (action == null) return;
    switch (action) {
      case _SearchSettingAction.precisionSearch:
        await _togglePrecisionSearchLikeLegado();
        break;
      case _SearchSettingAction.scope:
        await _openScopePickerLikeLegado();
        break;
      case _SearchSettingAction.sourceManage:
        await _openSourceManage();
        break;
      case _SearchSettingAction.logs:
        await _openAppLogDialog();
        break;
    }
  }

  Future<void> _togglePrecisionSearchLikeLegado() async {
    final nextMode = _isPrecisionSearchEnabled
        ? SearchFilterMode.normal
        : SearchFilterMode.precise;
    await _saveSettings(_settings.copyWith(searchFilterMode: nextMode));
    if (!mounted) return;
    await _search();
  }

  Future<void> _openScopePickerLikeLegado() async {
    final scopeState = _resolveSearchScope();
    final result =
        await Navigator.of(context, rootNavigator: true).push<String>(
      CupertinoPageRoute(
        builder: (_) => SearchScopePickerView(
          sources: scopeState.allSources,
          enabledSources: scopeState.allEnabledSources,
        ),
      ),
    );
    if (result == null) return;

    final scopeToSave = SearchScope.normalizeScopeText(result);
    await _saveSettings(
      _settings.copyWith(searchScope: scopeToSave),
    );
    if (!mounted) return;
    if (_shouldAutoSearchOnScopeChanged()) {
      await _search();
    }
  }

  Future<void> _openSourceManage() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SourceListView(),
      ),
    );
  }

  Future<void> _openAppLogDialog() async {
    await showAppLogDialog(context);
  }

  Future<bool> _confirm({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    final result = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(content),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showIssueDetails() {
    if (_sourceIssues.isEmpty) return;
    final lines = <String>['失败书源：${_sourceIssues.length} 条'];
    final preview = _sourceIssues.take(12).toList(growable: false);
    for (final issue in preview) {
      lines.add('• ${issue.sourceName}：${issue.reason}');
    }
    final remain = _sourceIssues.length - preview.length;
    if (remain > 0) {
      lines.add('…其余 $remain 条省略');
    }
    lines.add('可在“书源可用性检测”或“调试”继续定位。');
    _showMessage(lines.join('\n'));
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(message),
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
    final scopeState = _resolveSearchScope();
    final totalSources = scopeState.sources.length;
    final uiTokens = AppUiTokens.resolve(context);

    return PopScope<void>(
      canPop: !SearchInputHintHelper.shouldConsumeBackToClearFocus(
        hasInputFocus: _searchHasFocus,
      ),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (SearchInputHintHelper.shouldConsumeBackToClearFocus(
          hasInputFocus: _searchHasFocus,
        )) {
          _searchFocusNode.unfocus();
        }
      },
      child: AppCupertinoPageScaffold(
        title: '搜索',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: AppManageSearchField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      placeholder: '输入书名/作者，进行精准搜索书源...',
                      onChanged: (_) {
                        if (_isSearching) {
                          _cancelOngoingSearch();
                          return;
                        }
                        if (_hasMore) {
                          setState(() {
                            // 对齐 legado onQueryTextChange：输入变更即隐藏“继续加载”入口。
                            _hasMore = false;
                          });
                          return;
                        }
                        setState(() {});
                      },
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    minimumSize: const Size(0, 32),
                    onPressed: _openScopePickerLikeLegado,
                    child: Text(
                      _resolveSearchScope().resolvedScope.display(),
                      style: TextStyle(
                        fontSize: 13,
                        color: uiTokens.colors.accent,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 4, right: 2),
                    minimumSize: const Size(42, 32),
                    onPressed: () {
                      _searchFocusNode.unfocus();
                      if (_isSearching) {
                        _cancelOngoingSearch();
                      }
                    },
                    child: Text(_isSearching ? '停止' : '取消'),
                  ),
                ],
              ),
            ),
            if (_isSearching)
              _buildStatusPanel(
                borderColor: uiTokens.colors.separator,
                child: Row(
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '正在搜索：$_searchingSource ($_completedSources/$totalSources)',
                        style: TextStyle(
                          fontSize: 13,
                          color: uiTokens.colors.mutedForeground,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      onPressed: _cancelOngoingSearch,
                      child: Text(
                        '停止',
                        style: TextStyle(color: uiTokens.colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isSearching && _sourceIssues.isNotEmpty)
              _buildStatusPanel(
                borderColor: uiTokens.colors.destructive,
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 16,
                      color: uiTokens.colors.destructive,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '本次 ${_sourceIssues.length} 个书源失败，可查看原因',
                        style: TextStyle(
                          fontSize: 12,
                          color: uiTokens.colors.destructive,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      onPressed: _showIssueDetails,
                      child: Text(
                        '查看',
                        style: TextStyle(color: uiTokens.colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            if (_showManualLoadMorePanel)
              _buildStatusPanel(
                borderColor: uiTokens.colors.accent.withValues(alpha: 0.35),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_down_circle,
                      size: 16,
                      color: uiTokens.colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '还有更多结果，可继续加载下一页',
                        style: TextStyle(
                          fontSize: 12,
                          color: uiTokens.colors.mutedForeground,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      onPressed: _continueLoadMoreLikeLegado,
                      child: Text(
                        '继续',
                        style: TextStyle(color: uiTokens.colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _displayResults.isEmpty
                        ? _buildEmptyBody(totalSources: totalSources)
                        : ListView.builder(
                            controller: _resultScrollController,
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                            itemCount: _displayResults.length,
                            itemBuilder: (context, index) =>
                                _buildResultItem(_displayResults[index]),
                          ),
                  ),
                  if (_showInputHelpPanel)
                    Positioned.fill(
                      child: _buildInputHelpPanel(),
                    ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: SafeArea(
                      top: false,
                      child: _buildFloatingSettingsButton(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingSettingsButton() {
    const buttonSize = 40.0;
    const iconSize = 18.0;
    const shadowAlpha = 0.10;
    const shadowBlur = 14.0;
    const shadowOffset = Offset(0, 8);

    final uiTokens = AppUiTokens.resolve(context);
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final shadow = CupertinoColors.black.withValues(alpha: shadowAlpha);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: uiTokens.sizes.compactTapSquare,
      onPressed: _showSearchSettingsSheet,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadow,
              blurRadius: shadowBlur,
              offset: shadowOffset,
            ),
          ],
        ),
        child: Icon(
          CupertinoIcons.line_horizontal_3,
          size: iconSize,
          color: uiTokens.colors.accent,
        ),
      ),
    );
  }

  Widget _buildStatusPanel({
    required Color borderColor,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: borderColor.withValues(alpha: 0.82),
        borderWidth: 0.5,
        child: child,
      ),
    );
  }

  Widget _buildInputHelpPanel() {
    final bookshelfHints = _bookshelfHintsForInput();
    final historyHints = _historyHintsForInput();
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(
      context,
    );
    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
        children: [
          if (bookshelfHints.isNotEmpty) ...[
            _buildBookshelfHintPanel(bookshelfHints),
            const SizedBox(height: 10),
          ],
          _buildHistoryPanel(historyHints),
        ],
      ),
    );
  }

  List<Book> _bookshelfHintsForInput() {
    return SearchInputHintHelper.filterBookshelfBooks(
      _bookshelfBooks,
      _searchController.text,
    );
  }

  List<String> _historyHintsForInput() {
    return SearchInputHintHelper.filterHistoryKeywords(
      _historyKeywords,
      _searchController.text,
    );
  }

  Future<void> _openBookshelfBookInfo(Book book) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleHistoryKeywordTap(String keyword) async {
    final normalized = SearchInputHintHelper.normalizeKeyword(keyword);
    if (normalized.isEmpty) return;
    final shouldSubmit = SearchInputHintHelper.shouldSubmitHistoryKeyword(
      currentKeyword: _searchController.text,
      selectedKeyword: normalized,
      hasExactBookshelfTitle: SearchInputHintHelper.hasExactBookTitle(
        _bookshelfBooks,
        normalized,
      ),
    );
    _searchController.text = normalized;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: normalized.length),
    );
    if (shouldSubmit) {
      await _search();
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildEmptyBody({required int totalSources}) {
    final uiTokens = AppUiTokens.resolve(context);
    final historyHints = _historyHintsForInput();
    if (_isSearching) {
      return const SizedBox.shrink();
    }

    final hint = _sourceIssues.isNotEmpty
        ? '本次有失败书源，点上方“查看”了解原因'
        : totalSources == 0
            ? '当前没有启用书源，请先在“搜索设置”里调整范围'
            : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      children: [
        if (hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: uiTokens.colors.mutedForeground,
              ),
            ),
          ),
        _buildHistoryPanel(historyHints),
      ],
    );
  }

  Widget _buildBookshelfHintPanel(List<Book> books) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '书架匹配',
            style: theme.textTheme.textStyle.copyWith(
              color: uiTokens.colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: books
                .map((book) => _buildBookshelfHintChip(book))
                .toList(growable: false),
          ),
          const SizedBox(height: 6),
          Text(
            '点击可直接进入该书详情',
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 12,
              color: uiTokens.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookshelfHintChip(Book book) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: uiTokens.sizes.compactTapSquare,
      color: uiTokens.colors.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      onPressed: () => unawaited(_openBookshelfBookInfo(book)),
      child: Text(
        book.title,
        style: theme.textTheme.textStyle.copyWith(
          fontSize: 12,
          color: uiTokens.colors.foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildHistoryPanel(List<String> historyHints) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    final hasQuery =
        SearchInputHintHelper.normalizeKeyword(_searchController.text)
            .isNotEmpty;
    if (historyHints.isEmpty) {
      return AppEmptyState(
        illustration: const AppEmptyPlanetIllustration(size: 72),
        title: hasQuery ? '无匹配历史词' : '暂无历史记录',
        message: hasQuery ? '可调整关键词后重试' : '搜索后会自动保存历史词',
      );
    }
    final headerColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '搜索历史',
                style: theme.textTheme.textStyle.copyWith(
                  color: headerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (historyHints.isNotEmpty)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  onPressed: _clearHistory,
                  child: Text(
                    '清除',
                    style: TextStyle(
                      color: uiTokens.colors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: historyHints
                .map((keyword) => _buildHistoryChip(keyword))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChip(String keyword) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    final chipBg = CupertinoColors.systemGrey5.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    return GestureDetector(
      onLongPress: () => _removeHistoryKeyword(keyword),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: uiTokens.sizes.compactTapSquare,
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
        onPressed: () => unawaited(_handleHistoryKeywordTap(keyword)),
        child: Text(
          keyword,
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 12,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(_SearchDisplayItem item) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    final result = item.primary;
    final coverUrl = item.displayCoverUrl;
    final sourceCount = item.origins.length;
    final mutedStyle = theme.textTheme.textStyle.copyWith(
      fontSize: 12,
      color: uiTokens.colors.mutedForeground,
    );
    final meta = <String>[
      if (result.kind.isNotEmpty) result.kind,
      if (result.wordCount.isNotEmpty) '字数:${result.wordCount}',
      if (result.updateTime.isNotEmpty) '更新:${result.updateTime}',
    ];
    final coverSource = _settings.searchShowCover
        ? _sourceRepo.getSourceByUrl(item.displayCoverSourceUrl)
        : null;

    return Padding(
      key: ValueKey(item.key),
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _openBookInfo(result),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: uiTokens.colors.card,
            borderRadius: BorderRadius.circular(uiTokens.radii.control),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_settings.searchShowCover) ...[
                coverUrl.isEmpty
                    ? AppCoverImage(
                        urlOrPath: '',
                        title: result.name,
                        author: result.author,
                        width: 66,
                        height: 92,
                        borderRadius: 8,
                        fit: BoxFit.cover,
                        showTextOnPlaceholder: false,
                      )
                    : SourceAwareCoverImage(
                        urlOrPath: coverUrl,
                        source: coverSource,
                        title: result.name,
                        author: result.author,
                        width: 66,
                        height: 92,
                        borderRadius: 8,
                        fit: BoxFit.cover,
                        showTextOnPlaceholder: false,
                        onLoadStateChanged: (state) =>
                            _handleCoverLoadState(item.key, state),
                      ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.textStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: uiTokens.colors.foreground,
                            ),
                          ),
                        ),
                        if (sourceCount > 1)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: uiTokens.colors.accent
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$sourceCount 源',
                              style: theme.textTheme.textStyle.copyWith(
                                fontSize: 12,
                                color: uiTokens.colors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.author.isNotEmpty ? result.author : '未知作者',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mutedStyle,
                      ),
                    ],
                    if (result.lastChapter.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '最新: ${result.lastChapter}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mutedStyle,
                      ),
                    ],
                    if (result.intro.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.intro,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: mutedStyle,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      sourceCount > 1
                          ? '来源: ${result.sourceName} 等 $sourceCount 个'
                          : '来源: ${result.sourceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                item.inBookshelf
                    ? CupertinoIcons.book_fill
                    : CupertinoIcons.chevron_forward,
                size: item.inBookshelf ? 17 : 16,
                color: item.inBookshelf
                    ? uiTokens.colors.accent
                    : uiTokens.colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolvedSearchScope {
  final List<BookSource> allSources;
  final List<BookSource> allEnabledSources;
  final SearchScopeResolveResult resolvedScope;

  const _ResolvedSearchScope({
    required this.allSources,
    required this.allEnabledSources,
    required this.resolvedScope,
  });

  List<BookSource> get sources => resolvedScope.sources;
}

class _SearchDisplayItem {
  final String key;
  final SearchResult primary;
  final List<SearchResult> origins;
  final bool inBookshelf;
  final String displayCoverUrl;
  final String displayCoverSourceUrl;

  const _SearchDisplayItem({
    required this.key,
    required this.primary,
    required this.origins,
    required this.inBookshelf,
    required this.displayCoverUrl,
    required this.displayCoverSourceUrl,
  });
}

class _LegadoSearchAggregator {
  final Map<String, SearchResult> _rawBySourceBookKey =
      <String, SearchResult>{};
  final Map<String, _LegadoSearchGroup> _groupMap =
      <String, _LegadoSearchGroup>{};
  int _seenOrderSeed = 0;

  void reset() {
    _rawBySourceBookKey.clear();
    _groupMap.clear();
    _seenOrderSeed = 0;
  }

  List<SearchResult> get rawResults =>
      _rawBySourceBookKey.values.toList(growable: false);

  _AggregatorIngestStat ingest(List<SearchResult> incoming) {
    var changed = false;
    for (final item in incoming) {
      final normalized = _normalizeResult(item);
      if (normalized == null) continue;
      final sourceBookKey = _sourceBookKey(normalized);
      final groupKey = _groupKey(normalized);
      if (groupKey.isEmpty) continue;

      final existingRaw = _rawBySourceBookKey[sourceBookKey];
      if (existingRaw == null) {
        _rawBySourceBookKey[sourceBookKey] = normalized;
        changed = true;
      }

      final group = _groupMap[groupKey];
      if (group == null) {
        final nextGroup = _LegadoSearchGroup(
          key: groupKey,
          primary: normalized,
          orderRank: _seenOrderSeed++,
        );
        nextGroup.addResult(sourceBookKey, normalized);
        _groupMap[groupKey] = nextGroup;
        changed = true;
        continue;
      }

      if (group.addResult(sourceBookKey, normalized)) {
        changed = true;
      }
    }
    return _AggregatorIngestStat(changed: changed);
  }

  List<_SearchDisplayItem> buildDisplayItems({
    required String searchKeyword,
    required bool precision,
    required bool Function(SearchResult item) isInBookshelf,
  }) {
    final exact = <_LegadoSearchGroup>[];
    final contains = <_LegadoSearchGroup>[];
    final others = <_LegadoSearchGroup>[];

    final groups = _groupMap.values.toList(growable: false)
      ..sort((a, b) => a.orderRank.compareTo(b.orderRank));
    for (final group in groups) {
      final rank = _matchRank(group.primary, searchKeyword);
      if (rank == 0) {
        exact.add(group);
      } else if (rank == 1) {
        contains.add(group);
      } else if (!precision) {
        others.add(group);
      }
    }

    _stableSortByOriginCountDesc(exact);
    _stableSortByOriginCountDesc(contains);

    final ordered = <_LegadoSearchGroup>[...exact, ...contains, ...others];
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].orderRank = i;
    }

    return ordered.map((group) {
      final originList = group.originRepresentatives;
      final primary = group.primary;
      return _SearchDisplayItem(
        key: group.key,
        primary: primary,
        origins: originList,
        inBookshelf: isInBookshelf(primary),
        displayCoverUrl: primary.coverUrl.trim(),
        displayCoverSourceUrl: primary.sourceUrl.trim(),
      );
    }).toList(growable: false);
  }

  static void _stableSortByOriginCountDesc(List<_LegadoSearchGroup> groups) {
    if (groups.length < 2) return;
    final indexed = groups.asMap().entries.toList(growable: false);
    indexed.sort((a, b) {
      final originCompare =
          b.value.origins.length.compareTo(a.value.origins.length);
      if (originCompare != 0) {
        return originCompare;
      }
      return a.key.compareTo(b.key);
    });
    groups
      ..clear()
      ..addAll(indexed.map((entry) => entry.value));
  }

  static SearchResult? _normalizeResult(SearchResult item) {
    final name = item.name.trim();
    final bookUrl = item.bookUrl.trim();
    final sourceUrl = item.sourceUrl.trim();
    if (name.isEmpty || bookUrl.isEmpty || sourceUrl.isEmpty) {
      return null;
    }
    return SearchResult(
      name: name,
      author: item.author.trim(),
      coverUrl: item.coverUrl.trim(),
      intro: item.intro.trim(),
      kind: item.kind.trim(),
      lastChapter: item.lastChapter.trim(),
      updateTime: item.updateTime.trim(),
      wordCount: item.wordCount.trim(),
      bookUrl: bookUrl,
      sourceUrl: sourceUrl,
      sourceName: () {
        final trimmed = item.sourceName.trim();
        return trimmed.isNotEmpty ? trimmed : sourceUrl;
      }(),
    );
  }

  static String _sourceBookKey(SearchResult item) =>
      '${item.sourceUrl}|${item.bookUrl}';

  static String _groupKey(SearchResult item) => '${item.name}|${item.author}';

  static int _matchRank(SearchResult result, String searchKeyword) {
    if (searchKeyword.isEmpty) return 2;
    final name = result.name;
    final author = result.author;
    if (name == searchKeyword || author == searchKeyword) {
      return 0;
    }
    if (name.contains(searchKeyword) || author.contains(searchKeyword)) {
      return 1;
    }
    return 2;
  }
}

class _LegadoSearchGroup {
  final String key;
  int orderRank;
  SearchResult primary;
  final LinkedHashMap<String, SearchResult> _resultBySourceBookKey =
      LinkedHashMap<String, SearchResult>();
  final LinkedHashMap<String, SearchResult> _representativeByOrigin =
      LinkedHashMap<String, SearchResult>();

  _LegadoSearchGroup({
    required this.key,
    required this.primary,
    required this.orderRank,
  });

  Set<String> get origins => _representativeByOrigin.keys.toSet();

  List<SearchResult> get originRepresentatives =>
      _representativeByOrigin.values.toList(growable: false);

  bool addResult(String sourceBookKey, SearchResult result) {
    var changed = false;
    final oldSourceBook = _resultBySourceBookKey[sourceBookKey];
    if (oldSourceBook == null) {
      _resultBySourceBookKey[sourceBookKey] = result;
      changed = true;
    }

    final originKey = result.sourceUrl;
    final oldRepresentative = _representativeByOrigin[originKey];
    if (oldRepresentative == null) {
      _representativeByOrigin[originKey] = result;
      changed = true;
    }

    return changed;
  }
}

class _AggregatorIngestStat {
  final bool changed;

  const _AggregatorIngestStat({
    required this.changed,
  });
}

class _SourceRunIssue {
  final String sourceName;
  final String reason;

  const _SourceRunIssue({
    required this.sourceName,
    required this.reason,
  });
}

enum _SearchSettingAction {
  precisionSearch,
  sourceManage,
  scope,
  logs,
}
