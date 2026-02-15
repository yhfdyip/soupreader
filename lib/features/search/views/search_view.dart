import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/source_aware_cover_image.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
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
  final SettingsService _settingsService = SettingsService();
  final SearchCacheService _cacheService = SearchCacheService();
  late final SourceRepository _sourceRepo;
  late final BookAddService _addService;

  late AppSettings _settings;
  List<String> _historyKeywords = const <String>[];

  List<SearchResult> _results = <SearchResult>[];
  List<_SearchDisplayItem> _displayResults = <_SearchDisplayItem>[];
  final List<_SourceRunIssue> _sourceIssues = <_SourceRunIssue>[];
  final Set<CancelToken> _activeCancelTokens = <CancelToken>{};
  bool _isSearching = false;
  String _searchingSource = '';
  String _currentKeyword = '';
  int _completedSources = 0;
  int _searchSessionSeed = 0;
  int _runningSearchSessionId = 0;

  bool get _isEntryScoped {
    final scoped = widget.sourceUrls;
    if (scoped == null || scoped.isEmpty) return false;
    return scoped.any((item) => item.trim().isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _sourceRepo = SourceRepository(db);
    _addService = BookAddService(database: db);
    _settings = _sanitizeSettings(_settingsService.appSettings);
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
    _cancelOngoingSearch(updateState: false);
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

  AppSettings _sanitizeSettings(AppSettings settings) {
    final normalizedScope = settings.searchScopeSourceUrls
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return settings.copyWith(
      searchConcurrency: settings.searchConcurrency.clamp(2, 12),
      searchCacheRetentionDays: settings.searchCacheRetentionDays.clamp(1, 30),
      searchScopeSourceUrls: normalizedScope,
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

  List<BookSource> _allEnabledSources() {
    final enabled = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled == true)
        .toList(growable: false);
    enabled.sort((a, b) {
      if (a.weight != b.weight) {
        return b.weight.compareTo(a.weight);
      }
      return a.bookSourceName.compareTo(b.bookSourceName);
    });
    return enabled;
  }

  List<BookSource> _enabledSources() {
    final enabled = _allEnabledSources();

    final forcedScope = widget.sourceUrls == null
        ? const <String>{}
        : _normalizeUrlSet(widget.sourceUrls!);
    if (forcedScope.isNotEmpty) {
      return enabled
          .where((source) => forcedScope.contains(source.bookSourceUrl))
          .toList(growable: false);
    }

    final configuredScope = _normalizeUrlSet(_settings.searchScopeSourceUrls);
    if (configuredScope.isEmpty) return enabled;
    return enabled
        .where((source) => configuredScope.contains(source.bookSourceUrl))
        .toList(growable: false);
  }

  String _resultKey(SearchResult item) {
    return '${item.sourceUrl.trim()}|${item.bookUrl.trim()}';
  }

  String _preferNonEmpty(String preferred, String fallback) {
    return preferred.trim().isNotEmpty ? preferred : fallback;
  }

  SearchResult _mergeSearchResult(SearchResult oldItem, SearchResult newItem) {
    return SearchResult(
      name: _preferNonEmpty(newItem.name, oldItem.name),
      author: _preferNonEmpty(newItem.author, oldItem.author),
      coverUrl: _preferNonEmpty(newItem.coverUrl, oldItem.coverUrl),
      intro: _preferNonEmpty(newItem.intro, oldItem.intro),
      kind: _preferNonEmpty(newItem.kind, oldItem.kind),
      lastChapter: _preferNonEmpty(newItem.lastChapter, oldItem.lastChapter),
      updateTime: _preferNonEmpty(newItem.updateTime, oldItem.updateTime),
      wordCount: _preferNonEmpty(newItem.wordCount, oldItem.wordCount),
      bookUrl: _preferNonEmpty(newItem.bookUrl, oldItem.bookUrl),
      sourceUrl: _preferNonEmpty(newItem.sourceUrl, oldItem.sourceUrl),
      sourceName: _preferNonEmpty(newItem.sourceName, oldItem.sourceName),
    );
  }

  bool _searchResultEquals(SearchResult a, SearchResult b) {
    return a.name == b.name &&
        a.author == b.author &&
        a.coverUrl == b.coverUrl &&
        a.intro == b.intro &&
        a.kind == b.kind &&
        a.lastChapter == b.lastChapter &&
        a.updateTime == b.updateTime &&
        a.wordCount == b.wordCount &&
        a.bookUrl == b.bookUrl &&
        a.sourceUrl == b.sourceUrl &&
        a.sourceName == b.sourceName;
  }

  _SearchUpsertStat _upsertResults(
    List<SearchResult> incoming,
    List<SearchResult> target,
    Map<String, int> keyToIndex,
  ) {
    var added = 0;
    var updated = 0;
    for (final item in incoming) {
      final bookUrl = item.bookUrl.trim();
      final sourceUrl = item.sourceUrl.trim();
      if (bookUrl.isEmpty || sourceUrl.isEmpty) continue;

      final normalizedItem = SearchResult(
        name: item.name,
        author: item.author,
        coverUrl: item.coverUrl,
        intro: item.intro,
        kind: item.kind,
        lastChapter: item.lastChapter,
        updateTime: item.updateTime,
        wordCount: item.wordCount,
        bookUrl: bookUrl,
        sourceUrl: sourceUrl,
        sourceName:
            item.sourceName.trim().isNotEmpty ? item.sourceName : sourceUrl,
      );

      final key = _resultKey(normalizedItem);
      final index = keyToIndex[key];
      if (index == null) {
        keyToIndex[key] = target.length;
        target.add(normalizedItem);
        added++;
        continue;
      }

      final merged = _mergeSearchResult(target[index], normalizedItem);
      if (_searchResultEquals(merged, target[index])) {
        continue;
      }
      target[index] = merged;
      updated++;
    }
    return _SearchUpsertStat(added: added, updated: updated);
  }

  String _normalizeCompare(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
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
        final normalizedKeyword = _normalizeCompare(keyword);
        if (normalizedKeyword.isEmpty) return incoming;
        return incoming.where((item) {
          final name = _normalizeCompare(item.name);
          final author = _normalizeCompare(item.author);
          return name.contains(normalizedKeyword) ||
              author.contains(normalizedKeyword);
        }).toList(growable: false);
    }
  }

  int _matchRank(SearchResult result, String normalizedKeyword) {
    if (normalizedKeyword.isEmpty) return 2;
    final name = _normalizeCompare(result.name);
    final author = _normalizeCompare(result.author);
    if (name == normalizedKeyword || author == normalizedKeyword) return 0;
    if (name.contains(normalizedKeyword) ||
        author.contains(normalizedKeyword)) {
      return 1;
    }
    return 2;
  }

  SearchResult _pickPrimaryResult(
    List<SearchResult> origins,
    String normalizedKeyword,
  ) {
    if (origins.length <= 1) return origins.first;
    final sorted = origins.toList(growable: false)
      ..sort((a, b) {
        final rankCompare = _matchRank(a, normalizedKeyword).compareTo(
          _matchRank(b, normalizedKeyword),
        );
        if (rankCompare != 0) return rankCompare;
        final sourceNameCompare = a.sourceName.compareTo(b.sourceName);
        if (sourceNameCompare != 0) return sourceNameCompare;
        return a.bookUrl.compareTo(b.bookUrl);
      });
    return sorted.first;
  }

  void _rebuildDisplayResults({String? keyword}) {
    final normalizedKeyword = _normalizeCompare(keyword ?? _currentKeyword);
    final mode = _settings.searchFilterMode;
    final built = <_SearchDisplayItem>[];

    if (mode == SearchFilterMode.none) {
      for (final item in _results) {
        final cover = _pickDisplayCover(<SearchResult>[item]);
        built.add(
          _SearchDisplayItem(
            key: '${item.sourceUrl.trim()}|${item.bookUrl.trim()}',
            primary: item,
            origins: <SearchResult>[item],
            inBookshelf: _addService.isInBookshelf(item),
            displayCoverUrl: cover.url,
            displayCoverSourceUrl: cover.sourceUrl,
          ),
        );
      }
    } else {
      final grouped = <String, List<SearchResult>>{};
      for (final item in _results) {
        final groupKey =
            '${_normalizeCompare(item.name)}|${_normalizeCompare(item.author)}';
        grouped.putIfAbsent(groupKey, () => <SearchResult>[]).add(item);
      }
      for (final entry in grouped.entries) {
        final origins = entry.value;
        if (origins.isEmpty) continue;
        final primary = _pickPrimaryResult(origins, normalizedKeyword);
        final cover = _pickDisplayCover(origins);
        built.add(
          _SearchDisplayItem(
            key: '${entry.key}|${primary.bookUrl.trim()}',
            primary: primary,
            origins: origins,
            inBookshelf: origins.any(_addService.isInBookshelf),
            displayCoverUrl: cover.url,
            displayCoverSourceUrl: cover.sourceUrl,
          ),
        );
      }
    }

    built.sort((a, b) {
      final rankCompare = _matchRank(a.primary, normalizedKeyword).compareTo(
        _matchRank(b.primary, normalizedKeyword),
      );
      if (rankCompare != 0) return rankCompare;
      final originsCompare = b.origins.length.compareTo(a.origins.length);
      if (originsCompare != 0) return originsCompare;
      final nameCompare = a.primary.name.compareTo(b.primary.name);
      if (nameCompare != 0) return nameCompare;
      return a.primary.author.compareTo(b.primary.author);
    });

    _displayResults = built;
  }

  _DisplayCover _pickDisplayCover(List<SearchResult> origins) {
    for (final item in origins) {
      final cover = item.coverUrl.trim();
      if (cover.isNotEmpty) {
        return _DisplayCover(
          url: cover,
          sourceUrl: item.sourceUrl.trim(),
        );
      }
    }
    return const _DisplayCover(url: '', sourceUrl: '');
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

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    _currentKeyword = keyword;

    final enabledSources = _enabledSources();
    if (enabledSources.isEmpty) {
      _showMessage('当前搜索范围没有启用书源，请先调整“搜索范围”。');
      return;
    }

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
    final keyToIndex = <String, int>{};
    final initialResults = <SearchResult>[];
    _upsertResults(cachedResults, initialResults, keyToIndex);

    final searchSessionId = _startSearchSession();
    var nextSourceIndex = 0;
    final workerCount = enabledSources.length < _settings.searchConcurrency
        ? enabledSources.length
        : _settings.searchConcurrency;

    setState(() {
      _isSearching = true;
      _results = initialResults;
      _sourceIssues.clear();
      _completedSources = 0;
      _searchingSource = '';
      _rebuildDisplayResults(keyword: keyword);
    });

    Future<void> runWorker() async {
      while (true) {
        if (!_isSearchSessionActive(searchSessionId)) return;
        if (nextSourceIndex >= enabledSources.length) return;
        final source = enabledSources[nextSourceIndex++];
        if (!_isSearchSessionActive(searchSessionId)) return;
        setState(() => _searchingSource = source.bookSourceName);

        final token = CancelToken();
        _activeCancelTokens.add(token);

        try {
          final debugEngine = RuleParserEngine();
          final debugResult = await debugEngine.searchDebug(
            source,
            keyword,
            cancelToken: token,
          );
          if (!_isSearchSessionActive(searchSessionId)) return;

          final issue = _buildSearchIssue(source, debugResult);
          final filtered =
              _filterResultsByMode(debugResult.results, keyword.trim());
          final upsertStat = _upsertResults(filtered, _results, keyToIndex);
          if (!_isSearchSessionActive(searchSessionId)) return;

          setState(() {
            if (upsertStat.added > 0 || upsertStat.updated > 0) {
              _rebuildDisplayResults(keyword: keyword);
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

    if (!_isSearchSessionActive(searchSessionId)) return;
    if (_results.isNotEmpty) {
      unawaited(_cacheService.writeCache(key: cacheKey, results: _results));
    }

    setState(() {
      _isSearching = false;
      _runningSearchSessionId = 0;
      _searchingSource = '';
    });
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
    required int scopedCount,
    required int allEnabledCount,
  }) {
    if (_isEntryScoped) {
      return '入口限定 $scopedCount 源';
    }
    if (_settings.searchScopeSourceUrls.isEmpty) {
      return '所有书源';
    }
    return '$scopedCount/$allEnabledCount 书源';
  }

  Future<void> _showSearchSettingsSheet() async {
    final enabledCount = _enabledSources().length;
    final allEnabledCount = _allEnabledSources().length;
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
              scopedCount: enabledCount,
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
        if (_isEntryScoped) {
          _showMessage('当前为源内搜索，范围由入口限定。');
        } else {
          await _openScopePicker();
        }
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
    final allEnabled = _allEnabledSources();
    if (allEnabled.isEmpty) {
      _showMessage('没有可用的启用书源。');
      return;
    }

    final selected = _normalizeUrlSet(_settings.searchScopeSourceUrls);
    final result =
        await Navigator.of(context, rootNavigator: true).push<List<String>>(
      CupertinoPageRoute(
        builder: (_) => SearchScopePickerView(
          sources: allEnabled,
          initialSelectedUrls: selected,
        ),
      ),
    );
    if (result == null) return;

    final normalized = _normalizeUrlSet(result);
    final scopeToSave = normalized.length == allEnabled.length
        ? const <String>[]
        : (normalized.toList(growable: false)..sort());
    await _saveSettings(
      _settings.copyWith(searchScopeSourceUrls: scopeToSave),
    );
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
    final enabledSources = _enabledSources();
    final totalSources = enabledSources.length;
    final allEnabledCount = _allEnabledSources().length;
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
                          '${_scopeLabel(scopedCount: totalSources, allEnabledCount: allEnabledCount)} · '
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
                Row(
                  children: [
                    Text(
                      '书源 $totalSources',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '结果 ${_displayResults.length}',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    if (_sourceIssues.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        '失败 ${_sourceIssues.length}',
                        style: theme.textTheme.small.copyWith(
                          color: scheme.destructive,
                        ),
                      ),
                    ],
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
                SourceAwareCoverImage(
                  urlOrPath: item.displayCoverUrl,
                  source: coverSource,
                  title: result.name,
                  author: result.author,
                  width: 52,
                  height: 74,
                  borderRadius: 8,
                  fit: BoxFit.cover,
                  showTextOnPlaceholder: false,
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

class _DisplayCover {
  final String url;
  final String sourceUrl;

  const _DisplayCover({
    required this.url,
    required this.sourceUrl,
  });
}

class _SearchUpsertStat {
  final int added;
  final int updated;

  const _SearchUpsertStat({
    required this.added,
    required this.updated,
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
  filterMode,
  scope,
  concurrency,
  cacheRetention,
  coverToggle,
  clearCache,
  clearHistory,
}
