import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/source_aware_cover_image.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../source/services/source_cover_loader.dart';
import '../models/search_scope.dart';
import '../models/search_scope_group_helper.dart';
import '../services/search_cache_service.dart';
import 'search_book_info_view.dart';
import 'search_scope_picker_view.dart';

/// 搜索页面（对齐 legado 核心语义：范围、过滤、可停止、历史词）。
class SearchView extends StatefulWidget {
  final List<String>? sourceUrls;
  final String? initialKeyword;
  final bool autoSearchOnOpen;

  const SearchView({super.key})
      : sourceUrls = null,
        initialKeyword = null,
        autoSearchOnOpen = false;
  const SearchView.scoped({
    super.key,
    required this.sourceUrls,
    this.initialKeyword,
    this.autoSearchOnOpen = false,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _resultScrollController = ScrollController();
  final SettingsService _settingsService = SettingsService();
  final SearchCacheService _cacheService = SearchCacheService();
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
  bool _enabledGroupsReady = false;
  List<String> _enabledGroups = const <String>[];
  final Map<String, SourceAwareCoverLoadState> _coverLoadStateByItem =
      <String, SourceAwareCoverLoadState>{};

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _sourceRepo = SourceRepository(db);
    _addService = BookAddService(database: db);
    _resultScrollController.addListener(_onResultScroll);
    _settings = _sanitizeSettings(_settingsService.appSettings);
    _applyScopedEntrySearchScope();
    _startEnabledGroupsFlow();
    unawaited(_prepareLocalState());

    final initialKeyword = widget.initialKeyword?.trim();
    if (initialKeyword != null && initialKeyword.isNotEmpty) {
      _searchController.text = initialKeyword;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: initialKeyword.length),
      );
    }

    if (widget.autoSearchOnOpen == true && initialKeyword != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _search();
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_enabledGroupsSub?.cancel());
    _cancelOngoingSearch(updateState: false);
    _resultScrollController.removeListener(_onResultScroll);
    _resultScrollController.dispose();
    _searchController.dispose();
    super.dispose();
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

  int get _coverUrlEmptyCount => _displayResults
      .where((item) => item.displayCoverUrl.trim().isEmpty)
      .length;

  int get _coverLoadSuccessCount => _coverLoadStateByItem.values
      .where((state) => state == SourceAwareCoverLoadState.success)
      .length;

  int get _coverLoadFailedCount => _coverLoadStateByItem.values
      .where((state) => state == SourceAwareCoverLoadState.failed)
      .length;

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
    switch (_settings.searchFilterMode) {
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
      precision: _settings.searchFilterMode == SearchFilterMode.precise,
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

  bool _isCanceledError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.cancel;
    }
    return false;
  }

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
    if (_resultScrollController.position.extentAfter > 120) return;
    if (_isSearching || !_hasMore) return;
    if (_currentKeyword.trim().isEmpty) return;
    if (_displayResults.isEmpty) return;
    unawaited(_loadNextPage());
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

    if (!_isSearchSessionActive(sessionId)) return;
    _currentPage = nextPage;
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

  Future<void> _search() async {
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
      filterMode: _settings.searchFilterMode,
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

    if (!_isSearchSessionActive(searchSessionId)) return;
    if (_results.isNotEmpty && _currentCacheKey.isNotEmpty) {
      unawaited(
          _cacheService.writeCache(key: _currentCacheKey, results: _results));
    }

    setState(() {
      _isSearching = false;
      _searchingSource = '';
      _hasMore = hasMore;
    });
    unawaited(_maybePromptEmptyResultLikeLegado());
  }

  Future<void> _maybePromptEmptyResultLikeLegado() async {
    if (!mounted) return;
    if (_isSearching) return;
    if (_displayResults.isNotEmpty) return;
    if (_currentKeyword.trim().isEmpty) return;
    final scope = _resolveSearchScope().resolvedScope;
    if (scope.isAll) return;
    final scopeLabel = scope.display();

    if (_settings.searchFilterMode == SearchFilterMode.precise) {
      final confirm = await _confirm(
        title: '搜索结果为空',
        content: '$scopeLabel 搜索结果为空，是否关闭精准过滤并重试？',
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
      content: '$scopeLabel 搜索结果为空，是否切换到所有书源并重试？',
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
        } catch (e) {
          if (!_isSearchSessionActive(searchSessionId)) return;
          if (_isCanceledError(e)) {
            setState(() => _completedSources++);
            return;
          }
          if (e is TimeoutException) {
            setState(() => _completedSources++);
            return;
          }
          setState(() {
            _completedSources++;
            _sourceIssues.add(
              _SourceRunIssue(
                sourceName: source.bookSourceName,
                reason: '搜索异常：${_compactReason(e.toString())}',
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
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => SearchBookInfoView(result: result),
      ),
    );
    if (!mounted) return;
    setState(() => _rebuildDisplayResults(keyword: _currentKeyword));
  }

  String _filterModeLabel(SearchFilterMode mode) {
    switch (mode) {
      case SearchFilterMode.none:
        return '不过滤';
      case SearchFilterMode.normal:
        return '普通过滤';
      case SearchFilterMode.precise:
        return '精准过滤';
    }
  }

  String _scopeLabel({
    required SearchScopeResolveResult scope,
    required int allEnabledCount,
  }) {
    if (scope.isAll) {
      return '所有书源';
    }
    if (scope.isSource) {
      return scope.display();
    }
    return '${scope.display()}（${scope.sources.length}/$allEnabledCount 源）';
  }

  Future<void> _updateScopeAndMaybeSearch(String nextScope) async {
    final normalized = SearchScope.normalizeScopeText(nextScope);
    if (normalized == _settings.searchScope) return;
    await _saveSettings(_settings.copyWith(searchScope: normalized));
    if (!mounted) return;
    if (_searchController.text.trim().isNotEmpty) {
      await _search();
    }
  }

  Future<void> _showScopeQuickSheet() async {
    final scopeState = _resolveSearchScope();
    final scope = scopeState.resolvedScope;
    final selectedNames = scope.displayNames;
    final enabledGroups = _enabledGroupsReady
        ? _enabledGroups
        : SearchScopeGroupHelper.enabledGroupsFromSources(
            scopeState.allSources,
          );
    final allEnabledCount = scopeState.allEnabledSources.length;

    final action = await showCupertinoModalPopup<_ScopeQuickAction>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('搜索范围'),
        message: Text(
          _scopeLabel(
            scope: scope,
            allEnabledCount: allEnabledCount,
          ),
        ),
        actions: [
          for (final selectedName in selectedNames)
            _buildScopeQuickAction(
              ctx,
              title: selectedName,
              selected: true,
              action: _ScopeQuickAction.remove(selectedName),
            ),
          _buildScopeQuickAction(
            ctx,
            title: '所有书源',
            selected: scope.isAll,
            action: const _ScopeQuickAction(
              type: _ScopeQuickActionType.all,
              value: '',
            ),
          ),
          for (final group in enabledGroups)
            if (!selectedNames.contains(group))
              _buildScopeQuickAction(
                ctx,
                title: group,
                selected: false,
                action: _ScopeQuickAction(
                  type: _ScopeQuickActionType.group,
                  value: group,
                ),
              ),
          _buildScopeQuickAction(
            ctx,
            title: '多分组/单源模式…',
            selected: false,
            action: const _ScopeQuickAction(
              type: _ScopeQuickActionType.dialog,
              value: '',
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
    if (action == null) return;

    switch (action.type) {
      case _ScopeQuickActionType.dialog:
        await _openScopePicker();
        return;
      case _ScopeQuickActionType.all:
        await _updateScopeAndMaybeSearch('');
        return;
      case _ScopeQuickActionType.group:
        await _updateScopeAndMaybeSearch(action.value);
        return;
      case _ScopeQuickActionType.remove:
        if (scope.isSource) {
          await _updateScopeAndMaybeSearch('');
          return;
        }
        final remaining = scope.selectedGroups
            .where((item) => item != action.value)
            .toList(growable: false);
        await _updateScopeAndMaybeSearch(SearchScope.fromGroups(remaining));
        return;
    }
  }

  CupertinoActionSheetAction _buildScopeQuickAction(
    BuildContext ctx, {
    required String title,
    required bool selected,
    required _ScopeQuickAction action,
  }) {
    return CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(ctx, action),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selected)
            Icon(
              CupertinoIcons.check_mark_circled_solid,
              size: 18,
              color: CupertinoColors.activeGreen.resolveFrom(context),
            ),
        ],
      ),
    );
  }

  Future<void> _showSearchSettingsSheet() async {
    final scopeState = _resolveSearchScope();
    final allEnabledCount = scopeState.allEnabledSources.length;
    final action = await showCupertinoModalPopup<_SearchSettingAction>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('搜索设置'),
        message: const Text('以下设置会自动保存'),
        actions: [
          _buildSettingsAction(
            ctx,
            action: _SearchSettingAction.filterMode,
            label: '搜索过滤',
            value: _filterModeLabel(_settings.searchFilterMode),
          ),
          _buildSettingsAction(
            ctx,
            action: _SearchSettingAction.scope,
            label: '搜索范围',
            value: _scopeLabel(
              scope: scopeState.resolvedScope,
              allEnabledCount: allEnabledCount,
            ),
          ),
          _buildSettingsAction(
            ctx,
            action: _SearchSettingAction.concurrency,
            label: '并发任务',
            value: '${_settings.searchConcurrency} 个',
          ),
          _buildSettingsAction(
            ctx,
            action: _SearchSettingAction.cacheRetention,
            label: '搜索缓存保留时间',
            value: '${_settings.searchCacheRetentionDays} 天',
          ),
          _buildSettingsAction(
            ctx,
            action: _SearchSettingAction.coverToggle,
            label: '结果封面',
            value: _settings.searchShowCover ? '开启' : '关闭',
          ),
          _buildSettingsAction(
            ctx,
            action: _SearchSettingAction.clearCache,
            label: '清除搜索缓存',
            value: '',
            isDestructive: true,
          ),
          _buildSettingsAction(
            ctx,
            action: _SearchSettingAction.clearHistory,
            label: '清空搜索历史',
            value: '',
            isDestructive: true,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );

    if (action == null) return;
    switch (action) {
      case _SearchSettingAction.filterMode:
        await _pickFilterMode();
        break;
      case _SearchSettingAction.scope:
        await _showScopeQuickSheet();
        break;
      case _SearchSettingAction.concurrency:
        await _pickConcurrency();
        break;
      case _SearchSettingAction.cacheRetention:
        await _pickCacheRetention();
        break;
      case _SearchSettingAction.coverToggle:
        await _toggleCover();
        break;
      case _SearchSettingAction.clearCache:
        await _clearSearchCache();
        break;
      case _SearchSettingAction.clearHistory:
        await _clearHistory();
        break;
    }
  }

  CupertinoActionSheetAction _buildSettingsAction(
    BuildContext ctx, {
    required _SearchSettingAction action,
    required String label,
    required String value,
    bool isDestructive = false,
  }) {
    return CupertinoActionSheetAction(
      isDestructiveAction: isDestructive,
      onPressed: () => Navigator.pop(ctx, action),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFilterMode() async {
    final selected = await showCupertinoModalPopup<SearchFilterMode>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('过滤模式'),
        actions: [
          _buildFilterModeAction(
              ctx, SearchFilterMode.none, '不过滤搜索结果', '保留所有搜索结果'),
          _buildFilterModeAction(ctx, SearchFilterMode.normal, '普通过滤搜索结果',
              '保留书名或作者含关键字的结果，也可少量输入错误'),
          _buildFilterModeAction(
              ctx, SearchFilterMode.precise, '精准过滤搜索结果', '仅保留书名或作者匹配关键字的结果'),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null || selected == _settings.searchFilterMode) return;
    await _saveSettings(_settings.copyWith(searchFilterMode: selected));
    if (!mounted) return;
    if (_searchController.text.trim().isNotEmpty) {
      await _search();
      return;
    }
    setState(() => _rebuildDisplayResults(keyword: _currentKeyword));
  }

  CupertinoActionSheetAction _buildFilterModeAction(
    BuildContext ctx,
    SearchFilterMode mode,
    String title,
    String subtitle,
  ) {
    final selected = _settings.searchFilterMode == mode;
    return CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(ctx, mode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              if (selected)
                Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  size: 18,
                  color: CupertinoColors.activeGreen.resolveFrom(context),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openScopePicker() async {
    final scopeState = _resolveSearchScope();
    if (scopeState.allSources.isEmpty) {
      _showMessage('没有可用书源。');
      return;
    }

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
    if (_searchController.text.trim().isNotEmpty) {
      await _search();
    }
  }

  Future<void> _pickConcurrency() async {
    final values = List<int>.generate(11, (index) => index + 2);
    final picked = await _pickIntValue(
      title: '设置搜索并发任务',
      values: values,
      current: _settings.searchConcurrency,
      infoMessage: '并发任务越多，搜索越快；同时会增加设备和网络负担。',
    );
    if (picked == null || picked == _settings.searchConcurrency) return;
    await _saveSettings(_settings.copyWith(searchConcurrency: picked));
  }

  Future<void> _pickCacheRetention() async {
    final values = List<int>.generate(30, (index) => index + 1);
    final picked = await _pickIntValue(
      title: '设置搜索缓存保留时间',
      values: values,
      current: _settings.searchCacheRetentionDays,
      infoMessage: '过期缓存会在打开搜索页时自动清理，最多保留 30 天。',
    );
    if (picked == null || picked == _settings.searchCacheRetentionDays) return;
    await _saveSettings(_settings.copyWith(searchCacheRetentionDays: picked));
    await _cacheService.purgeExpiredCache(retentionDays: picked);
  }

  Future<int?> _pickIntValue({
    required String title,
    required List<int> values,
    required int current,
    String? infoMessage,
  }) async {
    if (values.isEmpty) return null;
    var selectedIndex = values.indexOf(current);
    if (selectedIndex < 0) selectedIndex = 0;
    final scrollController = FixedExtentScrollController(
      initialItem: selectedIndex,
    );

    return showCupertinoModalPopup<int>(
      context: context,
      builder: (sheetContext) {
        final backgroundColor = CupertinoColors.systemBackground.resolveFrom(
          sheetContext,
        );
        return Container(
          height: 320,
          color: backgroundColor,
          child: Column(
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('取消'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (infoMessage != null)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(24, 24),
                        onPressed: () => _showMessage(infoMessage),
                        child: const Icon(
                          CupertinoIcons.info_circle,
                          size: 20,
                        ),
                      )
                    else
                      const SizedBox(width: 20),
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 8),
                      onPressed: () =>
                          Navigator.pop(sheetContext, values[selectedIndex]),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: CupertinoColors.separator.resolveFrom(sheetContext),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: scrollController,
                  onSelectedItemChanged: (index) {
                    selectedIndex = index;
                  },
                  children: values
                      .map(
                        (value) => Center(
                          child: Text(
                            '$value${title.contains("时间") ? " 天" : " 个"}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleCover() async {
    await _saveSettings(
      _settings.copyWith(searchShowCover: !_settings.searchShowCover),
    );
  }

  Future<void> _clearSearchCache() async {
    final confirmed = await _confirm(
      title: '清除搜索缓存',
      content: '确定清除所有搜索缓存吗？',
      confirmText: '清除',
      isDestructive: true,
    );
    if (!confirmed) return;
    final removed = await _cacheService.clearCache();
    _showMessage('已清除 $removed 条缓存记录。');
  }

  Future<bool> _confirm({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
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
    final scopeState = _resolveSearchScope();
    final enabledSources = scopeState.sources;
    final totalSources = enabledSources.length;
    final allEnabledCount = scopeState.allEnabledSources.length;
    final scopeLabel = _scopeLabel(
      scope: scopeState.resolvedScope,
      allEnabledCount: allEnabledCount,
    );
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '搜索',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(30, 30),
        onPressed: _showSearchSettingsSheet,
        child: const Icon(CupertinoIcons.slider_horizontal_3, size: 21),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ShadInput(
                        controller: _searchController,
                        placeholder: const Text('请输入书名或作者名'),
                        textInputAction: TextInputAction.search,
                        leading: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(LucideIcons.search, size: 16),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ShadButton(
                      onPressed: _isSearching ? null : _search,
                      leading: _isSearching
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CupertinoActivityIndicator(radius: 8),
                            )
                          : const Icon(LucideIcons.search),
                      child: const Text('搜索'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showSearchSettingsSheet,
                  child: ShadCard(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.gear,
                          size: 17,
                          color: scheme.mutedForeground,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '搜索设置',
                            style: theme.textTheme.p.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${_filterModeLabel(_settings.searchFilterMode)} · '
                          '$scopeLabel · '
                          '并发 ${_settings.searchConcurrency}',
                          style: theme.textTheme.small.copyWith(
                            color: scheme.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 15,
                          color: scheme.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      '书源 $totalSources',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    Text(
                      '结果 ${_displayResults.length}',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    if (_sourceIssues.isNotEmpty)
                      Text(
                        '失败 ${_sourceIssues.length}',
                        style: theme.textTheme.small.copyWith(
                          color: scheme.destructive,
                        ),
                      ),
                    if (_settings.searchShowCover)
                      Text(
                        '封面 空$_coverUrlEmptyCount 成功$_coverLoadSuccessCount 失败$_coverLoadFailedCount',
                        style: theme.textTheme.small.copyWith(
                          color: _coverLoadFailedCount > 0
                              ? scheme.destructive
                              : scheme.mutedForeground,
                        ),
                      )
                    else
                      Text(
                        '封面 已关闭',
                        style: theme.textTheme.small.copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSearching)
            _buildStatusPanel(
              borderColor: scheme.border,
              child: Row(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '正在搜索：$_searchingSource ($_completedSources/$totalSources)',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ),
                  ShadButton.link(
                    onPressed: _cancelOngoingSearch,
                    child: const Text('停止'),
                  ),
                ],
              ),
            )
          else if (_sourceIssues.isNotEmpty)
            _buildStatusPanel(
              borderColor: scheme.destructive,
              child: Row(
                children: [
                  Icon(
                    LucideIcons.triangleAlert,
                    size: 16,
                    color: scheme.destructive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '本次 ${_sourceIssues.length} 个书源失败，可查看原因',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.destructive,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ShadButton.link(
                    onPressed: _showIssueDetails,
                    child: const Text('查看'),
                  ),
                ],
              ),
            ),
          Expanded(
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
        ],
      ),
    );
  }

  Widget _buildStatusPanel({
    required Color borderColor,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: ShadBorder.all(color: borderColor, width: 1),
        child: child,
      ),
    );
  }

  Widget _buildEmptyBody({required int totalSources}) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = _sourceIssues.isNotEmpty
        ? '本次有失败书源，点上方“查看”了解原因'
        : totalSources == 0
            ? '当前没有启用书源，先在“搜索设置”里调整范围'
            : '输入书名或作者后开始搜索';

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      children: [
        ShadCard(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          child: Column(
            children: [
              Icon(
                LucideIcons.search,
                size: 44,
                color: scheme.mutedForeground,
              ),
              const SizedBox(height: 12),
              Text(
                '搜索书籍',
                style: theme.textTheme.h4,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.small.copyWith(
                  color: scheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildHistoryPanel(),
      ],
    );
  }

  Widget _buildHistoryPanel() {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return ShadCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '搜索历史',
                style: theme.textTheme.p.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_historyKeywords.isNotEmpty)
                ShadButton.link(
                  onPressed: _clearHistory,
                  child: const Text('清空'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_historyKeywords.isEmpty)
            Text(
              '暂无历史记录',
              style: theme.textTheme.small.copyWith(
                color: scheme.mutedForeground,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _historyKeywords
                  .map((keyword) => _buildHistoryChip(keyword))
                  .toList(growable: false),
            ),
          if (_historyKeywords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '长按历史词可删除单条',
              style: theme.textTheme.small.copyWith(
                color: scheme.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryChip(String keyword) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return GestureDetector(
      onLongPress: () => _removeHistoryKeyword(keyword),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        color: scheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        onPressed: () {
          _searchController.text = keyword;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: keyword.length),
          );
          _search();
        },
        child: Text(
          keyword,
          style: theme.textTheme.small.copyWith(
            color: scheme.foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(_SearchDisplayItem item) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final result = item.primary;
    final coverUrl = item.displayCoverUrl.trim();
    final sourceCount = item.origins.length;
    final meta = <String>[
      if (result.kind.trim().isNotEmpty) result.kind.trim(),
      if (result.wordCount.trim().isNotEmpty) '字数:${result.wordCount.trim()}',
      if (result.updateTime.trim().isNotEmpty) '更新:${result.updateTime.trim()}',
    ];
    final coverSource = _settings.searchShowCover
        ? _sourceRepo.getSourceByUrl(item.displayCoverSourceUrl)
        : null;

    return Padding(
      key: ValueKey(item.key),
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _openBookInfo(result),
        child: ShadCard(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_settings.searchShowCover) ...[
                coverUrl.isEmpty
                    ? AppCoverImage(
                        urlOrPath: '',
                        title: result.name,
                        author: result.author,
                        width: 52,
                        height: 74,
                        borderRadius: 8,
                        fit: BoxFit.cover,
                        showTextOnPlaceholder: false,
                      )
                    : SourceAwareCoverImage(
                        urlOrPath: coverUrl,
                        source: coverSource,
                        title: result.name,
                        author: result.author,
                        width: 52,
                        height: 74,
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
                            style: theme.textTheme.p.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.foreground,
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
                              color: scheme.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$sourceCount 源',
                              style: theme.textTheme.small.copyWith(
                                color: scheme.primary,
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
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                    if (result.lastChapter.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '最新: ${result.lastChapter.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                    if (result.intro.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.intro.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      sourceCount > 1
                          ? '来源: ${result.sourceName} 等 $sourceCount 个'
                          : '来源: ${result.sourceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                item.inBookshelf
                    ? LucideIcons.bookCheck
                    : LucideIcons.chevronRight,
                size: item.inBookshelf ? 17 : 16,
                color:
                    item.inBookshelf ? scheme.primary : scheme.mutedForeground,
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
      sourceName: item.sourceName.trim().isNotEmpty
          ? item.sourceName.trim()
          : sourceUrl,
    );
  }

  static String _sourceBookKey(SearchResult item) {
    return '${item.sourceUrl.trim()}|${item.bookUrl.trim()}';
  }

  static String _groupKey(SearchResult item) {
    return '${item.name}|${item.author}';
  }

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

    final originKey = result.sourceUrl.trim();
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

enum _ScopeQuickActionType {
  remove,
  group,
  all,
  dialog,
}

class _ScopeQuickAction {
  final _ScopeQuickActionType type;
  final String value;

  const _ScopeQuickAction({
    required this.type,
    required this.value,
  });

  factory _ScopeQuickAction.remove(String name) {
    return _ScopeQuickAction(
      type: _ScopeQuickActionType.remove,
      value: name,
    );
  }
}

enum _SearchSettingAction {
  filterMode,
  scope,
  concurrency,
  cacheRetention,
  coverToggle,
  clearCache,
  clearHistory,
}
