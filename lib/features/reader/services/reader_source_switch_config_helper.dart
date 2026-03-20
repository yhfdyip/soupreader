import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../bookshelf/models/book.dart';
import '../../search/models/search_scope.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import 'reader_source_switch_helper.dart';

/// Dependencies the source-switch config helper needs from
/// the host reader.
class ReaderSourceSwitchConfigContext {
  /// The book ID.
  final String bookId;

  /// Returns the current chapter index.
  final int Function() currentChapterIndex;

  /// Returns the current chapter title.
  final String Function() currentTitle;

  /// Returns the chapter list.
  final List<Chapter> Function() chapters;

  /// Returns the book progress (0.0 - 1.0).
  final double Function() bookProgress;

  /// Shows a toast message.
  final void Function(String message) showToast;

  const ReaderSourceSwitchConfigContext({
    required this.bookId,
    required this.currentChapterIndex,
    required this.currentTitle,
    required this.chapters,
    required this.bookProgress,
    required this.showToast,
  });
}

/// Manages source-switch configuration state, candidate
/// loading, and candidate list operations for the reader.
///
/// Configuration changes (group, delay, toggles) are persisted
/// through [SettingsService]. The UI-heavy sheet display and
/// actual book switching remain in the host widget.
class ReaderSourceSwitchConfigHelper extends ChangeNotifier {
  ReaderSourceSwitchConfigHelper(
    this._context, {
    required SourceRepository sourceRepo,
    required RuleParserEngine ruleEngine,
    required SettingsService settingsService,
  })  : _sourceRepo = sourceRepo,
        _ruleEngine = ruleEngine,
        _settingsService = settingsService;

  final ReaderSourceSwitchConfigContext _context;
  final SourceRepository _sourceRepo;
  final RuleParserEngine _ruleEngine;
  final SettingsService _settingsService;

  // ── State ──────────────────────────────────────────────

  bool _checkAuthor = false;
  bool _loadInfo = false;
  bool _loadWordCount = false;
  bool _loadToc = false;
  String _group = '';
  int _delaySeconds = 0;
  CancelToken? _searchCancelToken;
  bool _isAutoChangingSource = false;

  // ── Public getters ────────────────────────────────────

  bool get checkAuthor => _checkAuthor;
  bool get loadInfo => _loadInfo;
  bool get loadWordCount => _loadWordCount;
  bool get loadToc => _loadToc;
  String get group => _group;
  int get delaySeconds => _delaySeconds;
  bool get isAutoChangingSource => _isAutoChangingSource;

  // ── Init ──────────────────────────────────────────────

  /// Loads persisted configuration from settings.
  void loadConfig() {
    _checkAuthor = _settingsService.getChangeSourceCheckAuthor();
    _loadInfo = _settingsService.getChangeSourceLoadInfo();
    _loadWordCount =
        _settingsService.getChangeSourceLoadWordCount();
    _loadToc = _settingsService.getChangeSourceLoadToc();
    _group = _settingsService.getChangeSourceGroup();
    _delaySeconds = _settingsService.getBatchChangeSourceDelay();
  }

  // ── Config Change Handlers ────────────────────────────

  Future<void> handleLoadWordCountChanged(bool enabled) async {
    _loadWordCount = enabled;
    await _settingsService.saveChangeSourceLoadWordCount(enabled);
    notifyListeners();
  }

  Future<void> handleLoadInfoChanged(bool enabled) async {
    _loadInfo = enabled;
    await _settingsService.saveChangeSourceLoadInfo(enabled);
    notifyListeners();
  }

  Future<void> handleLoadTocChanged(bool enabled) async {
    _loadToc = enabled;
    await _settingsService.saveChangeSourceLoadToc(enabled);
    notifyListeners();
  }

  Future<void> handleCheckAuthorChanged(bool enabled) async {
    _checkAuthor = enabled;
    await _settingsService.saveChangeSourceCheckAuthor(enabled);
    notifyListeners();
  }

  Future<void> handleGroupChanged(String g) async {
    final normalized = _normalizeGroup(g);
    _group = normalized;
    await _settingsService.saveChangeSourceGroup(normalized);
    notifyListeners();
  }

  Future<void> handleDelayChanged(int seconds) async {
    final normalized = _normalizeDelaySeconds(seconds);
    _delaySeconds = normalized;
    await _settingsService.saveBatchChangeSourceDelay(normalized);
    notifyListeners();
  }

  // ── Group Helpers ─────────────────────────────────────

  List<String> buildGroups() {
    return SearchScopeGroupHelper.enabledGroupsFromSources(
      _sourceRepo.getAllSources(),
    );
  }

  List<BookSource> scopeSourcesByGroup(
    List<BookSource> enabledSources,
  ) {
    final selectedGroup = _normalizeGroup(_group);
    if (selectedGroup.isEmpty) return enabledSources;
    final scoped = enabledSources.where((source) {
      return SearchScope.splitSourceGroups(
        source.bookSourceGroup,
      ).contains(selectedGroup);
    }).toList(growable: false);
    if (scoped.isNotEmpty) return scoped;
    _group = '';
    unawaited(_settingsService.saveChangeSourceGroup(''));
    return enabledSources;
  }

  // ── Candidate Search ──────────────────────────────────

  void stopCandidateSearch() {
    final token = _searchCancelToken;
    if (token == null || token.isCancelled) return;
    token.cancel('source switch candidate search stopped');
  }

  Future<List<ReaderSourceSwitchCandidate>>
      startCandidateSearch({
    required Book currentBook,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
    bool? loadInfoEnabled,
    bool? loadWordCountEnabled,
    bool? loadTocEnabled,
    int? sourceDelaySeconds,
  }) async {
    stopCandidateSearch();
    final token = CancelToken();
    _searchCancelToken = token;
    try {
      final searched = await loadCandidates(
        currentBook: currentBook,
        loadInfoEnabled: loadInfoEnabled ?? _loadInfo,
        loadWordCountEnabled:
            loadWordCountEnabled ?? _loadWordCount,
        loadTocEnabled: loadTocEnabled ?? _loadToc,
        sourceDelaySeconds: sourceDelaySeconds ?? _delaySeconds,
        cancelToken: token,
      );
      if (token.isCancelled) return currentCandidates;
      return searched;
    } catch (_) {
      if (token.isCancelled) return currentCandidates;
      rethrow;
    } finally {
      if (identical(_searchCancelToken, token)) {
        _searchCancelToken = null;
      }
    }
  }

  Future<List<ReaderSourceSwitchCandidate>> loadCandidates({
    required Book currentBook,
    bool? loadInfoEnabled,
    bool? loadWordCountEnabled,
    bool? loadTocEnabled,
    int? sourceDelaySeconds,
    CancelToken? cancelToken,
  }) async {
    final enabledSources = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled)
        .toList(growable: false);
    if (enabledSources.isEmpty) {
      return const <ReaderSourceSwitchCandidate>[];
    }
    final orderedSources = enabledSources
        .asMap()
        .entries
        .toList(growable: false)
      ..sort((a, b) {
        final orderCompare =
            a.value.customOrder.compareTo(b.value.customOrder);
        if (orderCompare != 0) return orderCompare;
        return a.key.compareTo(b.key);
      });
    final sorted = orderedSources
        .map((entry) => entry.value)
        .toList(growable: false);
    final scoped = scopeSourcesByGroup(sorted);

    return loadCandidatesBySources(
      currentBook: currentBook,
      sourcesToSearch: scoped,
      loadInfoEnabled: loadInfoEnabled ?? _loadInfo,
      loadWordCountEnabled:
          loadWordCountEnabled ?? _loadWordCount,
      loadTocEnabled: loadTocEnabled ?? _loadToc,
      sourceDelaySeconds: sourceDelaySeconds ?? _delaySeconds,
      cancelToken: cancelToken,
    );
  }

  Future<List<ReaderSourceSwitchCandidate>>
      refreshCandidatesByCurrentList({
    required Book currentBook,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
    bool? loadInfoEnabled,
    bool? loadWordCountEnabled,
    bool? loadTocEnabled,
    int? sourceDelaySeconds,
    CancelToken? cancelToken,
  }) async {
    if (currentCandidates.isEmpty) {
      return const <ReaderSourceSwitchCandidate>[];
    }
    final enabledSourceByUrl = <String, BookSource>{
      for (final source in _sourceRepo.getAllSources())
        if (source.enabled)
          ReaderSourceSwitchHelper.normalizeForCompare(
            source.bookSourceUrl,
          ): source,
    };
    final scoped = <BookSource>[];
    final keys = <String>{};
    for (final candidate in currentCandidates) {
      final key = ReaderSourceSwitchHelper.normalizeForCompare(
        candidate.source.bookSourceUrl,
      );
      if (key.isEmpty || !keys.add(key)) continue;
      final source = enabledSourceByUrl[key];
      if (source == null) continue;
      scoped.add(source);
    }
    if (scoped.isEmpty) {
      return const <ReaderSourceSwitchCandidate>[];
    }
    return loadCandidatesBySources(
      currentBook: currentBook,
      sourcesToSearch: scoped,
      loadInfoEnabled: loadInfoEnabled ?? _loadInfo,
      loadWordCountEnabled:
          loadWordCountEnabled ?? _loadWordCount,
      loadTocEnabled: loadTocEnabled ?? _loadToc,
      sourceDelaySeconds: sourceDelaySeconds ?? _delaySeconds,
      cancelToken: cancelToken,
    );
  }

  Future<List<ReaderSourceSwitchCandidate>>
      loadCandidatesBySources({
    required Book currentBook,
    required List<BookSource> sourcesToSearch,
    required bool loadInfoEnabled,
    required bool loadWordCountEnabled,
    required bool loadTocEnabled,
    required int sourceDelaySeconds,
    CancelToken? cancelToken,
  }) async {
    final keyword = currentBook.title.trim();
    if (keyword.isEmpty || sourcesToSearch.isEmpty) {
      return const <ReaderSourceSwitchCandidate>[];
    }

    final searchDelay = _normalizeDelaySeconds(sourceDelaySeconds);
    final searchResults = <SearchResult>[];
    final wordCountTextByKey = <String, String>{};
    final wordCountByKey = <String, int>{};
    final respondTimeByKey = <String, int>{};

    String metricKey(SearchResult result) {
      final sourceKey =
          ReaderSourceSwitchHelper.normalizeForCompare(
        result.sourceUrl,
      );
      return '$sourceKey|${result.bookUrl.trim()}';
    }

    void recordMeta(
      SearchResult result, {
      required String text,
      required int count,
      required int timeMs,
    }) {
      if (!loadWordCountEnabled) return;
      final sourceKey =
          ReaderSourceSwitchHelper.normalizeForCompare(
        result.sourceUrl,
      );
      if (sourceKey.isEmpty) return;
      if (result.bookUrl.trim().isEmpty) return;
      final key = metricKey(result);
      wordCountTextByKey[key] = text.trim();
      wordCountByKey[key] = count;
      respondTimeByKey[key] = timeMs;
    }

    for (var i = 0; i < sourcesToSearch.length; i++) {
      if (cancelToken?.isCancelled == true) break;
      final source = sourcesToSearch[i];
      if (i > 0 && searchDelay > 0) {
        final ok = await _waitDelayWithCancel(
          seconds: searchDelay,
          cancelToken: cancelToken,
        );
        if (!ok) break;
      }
      try {
        final list = await _ruleEngine.search(
          source,
          keyword,
          filter: (name, _) => name == keyword,
          cancelToken: cancelToken,
        );
        if (cancelToken?.isCancelled == true) break;
        if (!(loadInfoEnabled ||
            loadTocEnabled ||
            loadWordCountEnabled) ||
            list.isEmpty) {
          searchResults.addAll(list);
          continue;
        }
        for (final item in list) {
          if (cancelToken?.isCancelled == true) break;
          try {
            final hydrated = await hydrateSearchResult(
              currentBook: currentBook,
              source: source,
              result: item,
              loadInfoEnabled: loadInfoEnabled,
              loadTocEnabled: loadTocEnabled,
              loadWordCountEnabled: loadWordCountEnabled,
              cancelToken: cancelToken,
            );
            searchResults.add(hydrated.result);
            recordMeta(
              hydrated.result,
              text: hydrated.chapterWordCountText,
              count: hydrated.chapterWordCount,
              timeMs: hydrated.respondTimeMs,
            );
          } catch (_) {
            if (cancelToken?.isCancelled == true) break;
            searchResults.add(item);
          }
        }
      } catch (_) {
        if (cancelToken?.isCancelled == true) break;
      }
    }

    return ReaderSourceSwitchHelper.buildCandidates(
      currentBook: currentBook,
      enabledSources: sourcesToSearch,
      searchResults: searchResults,
      loadWordCountEnabled: loadWordCountEnabled,
      chapterWordCountTextByKey: wordCountTextByKey,
      chapterWordCountByKey: wordCountByKey,
      respondTimeMsByKey: respondTimeByKey,
    );
  }

  /// Hydrates a search result with book info, TOC, and word
  /// count data from the source.
  Future<SourceSwitchHydratedResult> hydrateSearchResult({
    required Book currentBook,
    required BookSource source,
    required SearchResult result,
    required bool loadInfoEnabled,
    required bool loadTocEnabled,
    required bool loadWordCountEnabled,
    CancelToken? cancelToken,
  }) async {
    final bookUrl = result.bookUrl.trim();
    if (bookUrl.isEmpty ||
        (!loadInfoEnabled &&
            !loadTocEnabled &&
            !loadWordCountEnabled)) {
      return SourceSwitchHydratedResult(
        result: result,
        chapterWordCountText: '',
        chapterWordCount: -1,
        respondTimeMs: -1,
      );
    }

    final detail = await _ruleEngine.getBookInfo(
      source,
      bookUrl,
      clearRuntimeVariables: true,
      cancelToken: cancelToken,
    );
    final detailLastChapter =
        detail?.lastChapter.trim() ?? '';
    final tocUrl =
        detail?.tocUrl.trim().isNotEmpty == true
            ? detail!.tocUrl.trim()
            : bookUrl;
    var toc = const <TocItem>[];
    if (loadTocEnabled || loadWordCountEnabled) {
      toc = await _ruleEngine.getToc(
        source,
        tocUrl,
        clearRuntimeVariables: false,
        cancelToken: cancelToken,
      );
    }

    var nextLastChapter = result.lastChapter;
    if (loadTocEnabled && toc.isNotEmpty) {
      final latest = toc.last.name.trim();
      if (latest.isNotEmpty) nextLastChapter = latest;
    } else if (detailLastChapter.isNotEmpty &&
        (loadInfoEnabled ||
            loadWordCountEnabled ||
            loadTocEnabled)) {
      nextLastChapter = detailLastChapter;
    } else if (loadTocEnabled &&
        detailLastChapter.isNotEmpty) {
      nextLastChapter = detailLastChapter;
    }
    final nextResult = nextLastChapter == result.lastChapter
        ? result
        : _copySearchResult(
            result,
            lastChapter: nextLastChapter,
          );
    if (!loadWordCountEnabled || toc.isEmpty) {
      return SourceSwitchHydratedResult(
        result: nextResult,
        chapterWordCountText: '',
        chapterWordCount: -1,
        respondTimeMs: -1,
      );
    }

    final parsedChapters = <Chapter>[];
    for (final item in toc) {
      final title = item.name.trim();
      final url = item.url.trim();
      if (title.isEmpty || url.isEmpty) continue;
      parsedChapters.add(
        Chapter(
          id: '${_context.bookId}_switch_wc_'
              '${parsedChapters.length}',
          bookId: _context.bookId,
          title: title,
          url: url,
          index: parsedChapters.length,
        ),
      );
    }
    if (parsedChapters.isEmpty) {
      return SourceSwitchHydratedResult(
        result: nextResult,
        chapterWordCountText: '',
        chapterWordCount: -1,
        respondTimeMs: -1,
      );
    }

    final currentChapterTitle =
        _resolveCurrentChapterTitle(currentBook);
    final currentIdx = currentBook.currentChapter.clamp(
      0,
      parsedChapters.length - 1,
    );
    final oldCount = currentBook.totalChapters > 0
        ? currentBook.totalChapters
        : _context.chapters().length;
    final targetIdx =
        ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: parsedChapters,
      currentChapterTitle: currentChapterTitle,
      currentChapterIndex: currentIdx,
      oldChapterCount: oldCount,
    ).clamp(0, parsedChapters.length - 1);
    final targetChapter = parsedChapters[targetIdx];
    final nextChapterUrl =
        targetIdx + 1 < parsedChapters.length
            ? parsedChapters[targetIdx + 1].url
            : null;

    final startMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final content = await _ruleEngine.getContent(
        source,
        targetChapter.url ?? '',
        nextChapterUrl: nextChapterUrl,
        clearRuntimeVariables: false,
        cancelToken: cancelToken,
      );
      final elapsedMs =
          DateTime.now().millisecondsSinceEpoch - startMs;
      return SourceSwitchHydratedResult(
        result: nextResult,
        chapterWordCountText: _buildWordCountText(
          chapterIndex: targetIdx,
          chapterTitle: targetChapter.title,
          wordCount: content.length,
        ),
        chapterWordCount: content.length,
        respondTimeMs: elapsedMs,
      );
    } catch (error) {
      if (cancelToken?.isCancelled == true) rethrow;
      final elapsedMs =
          DateTime.now().millisecondsSinceEpoch - startMs;
      final message = error.toString();
      final errorText =
          message.trim().isEmpty ? '未知错误' : message;
      return SourceSwitchHydratedResult(
        result: nextResult,
        chapterWordCountText:
            '[${targetIdx + 1}] ${targetChapter.title}\n'
            '获取字数失败：$errorText',
        chapterWordCount: -1,
        respondTimeMs: elapsedMs,
      );
    }
  }

  // ── Candidate List Operations ─────────────────────────

  Future<List<ReaderSourceSwitchCandidate>> topCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) async {
    final source = _sourceRepo.getSourceByUrl(
      candidate.source.bookSourceUrl,
    );
    if (source == null) {
      return List<ReaderSourceSwitchCandidate>.from(
        currentCandidates,
        growable: false,
      );
    }
    final allSources = _sourceRepo.getAllSources();
    if (allSources.isEmpty) {
      return List<ReaderSourceSwitchCandidate>.from(
        currentCandidates,
        growable: false,
      );
    }
    var minOrder = allSources.first.customOrder;
    for (final item in allSources.skip(1)) {
      if (item.customOrder < minOrder) minOrder = item.customOrder;
    }
    final updated = source.copyWith(customOrder: minOrder - 1);
    await _sourceRepo.updateSource(updated);

    final key = ReaderSourceSwitchHelper.normalizeForCompare(
      updated.bookSourceUrl,
    );
    final mapped = currentCandidates.map((item) {
      final itemKey =
          ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      if (itemKey != key) return item;
      return ReaderSourceSwitchCandidate(
        source: updated,
        book: item.book,
        chapterWordCountText: item.chapterWordCountText,
        chapterWordCount: item.chapterWordCount,
        respondTimeMs: item.respondTimeMs,
      );
    }).toList(growable: false);
    return reorderByCustomOrder(mapped);
  }

  Future<List<ReaderSourceSwitchCandidate>> bottomCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) async {
    final source = _sourceRepo.getSourceByUrl(
      candidate.source.bookSourceUrl,
    );
    if (source == null) {
      return List<ReaderSourceSwitchCandidate>.from(
        currentCandidates,
        growable: false,
      );
    }
    final allSources = _sourceRepo.getAllSources();
    if (allSources.isEmpty) {
      return List<ReaderSourceSwitchCandidate>.from(
        currentCandidates,
        growable: false,
      );
    }
    var maxOrder = allSources.first.customOrder;
    for (final item in allSources.skip(1)) {
      if (item.customOrder > maxOrder) maxOrder = item.customOrder;
    }
    final updated = source.copyWith(customOrder: maxOrder + 1);
    await _sourceRepo.updateSource(updated);

    final key = ReaderSourceSwitchHelper.normalizeForCompare(
      updated.bookSourceUrl,
    );
    final mapped = currentCandidates.map((item) {
      final itemKey =
          ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      if (itemKey != key) return item;
      return ReaderSourceSwitchCandidate(
        source: updated,
        book: item.book,
        chapterWordCountText: item.chapterWordCountText,
        chapterWordCount: item.chapterWordCount,
        respondTimeMs: item.respondTimeMs,
      );
    }).toList(growable: false);
    return reorderByCustomOrder(mapped);
  }

  Future<List<ReaderSourceSwitchCandidate>> disableCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) async {
    final source = _sourceRepo.getSourceByUrl(
      candidate.source.bookSourceUrl,
    );
    if (source != null) {
      await _sourceRepo.updateSource(
        source.copyWith(enabled: false),
      );
    }
    return _removeCandidateFromList(
      candidate: candidate,
      currentCandidates: currentCandidates,
    );
  }

  Future<List<ReaderSourceSwitchCandidate>> deleteCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) async {
    await _sourceRepo.deleteSource(
      candidate.source.bookSourceUrl,
    );
    await SourceVariableStore.removeVariable(
      candidate.source.bookSourceUrl,
    );
    return _removeCandidateFromList(
      candidate: candidate,
      currentCandidates: currentCandidates,
    );
  }

  Future<List<ReaderSourceSwitchCandidate>>
      refreshEditedCandidate({
    required ReaderSourceSwitchCandidate editedCandidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
    required Book currentBook,
    required String savedSourceUrl,
  }) async {
    final oldKey = ReaderSourceSwitchHelper.normalizeForCompare(
      editedCandidate.source.bookSourceUrl,
    );
    final newKey =
        ReaderSourceSwitchHelper.normalizeForCompare(
      savedSourceUrl,
    );
    final retained = <ReaderSourceSwitchCandidate>[];
    var firstReplaced = -1;
    for (final item in currentCandidates) {
      final key = ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      final shouldReplace = key == oldKey || key == newKey;
      if (shouldReplace) {
        if (firstReplaced < 0) firstReplaced = retained.length;
        continue;
      }
      retained.add(item);
    }

    final savedSource =
        _sourceRepo.getSourceByUrl(savedSourceUrl);
    if (savedSource == null) {
      return List<ReaderSourceSwitchCandidate>.from(
        retained,
        growable: false,
      );
    }

    final refreshed = await loadCandidatesBySources(
      currentBook: currentBook,
      sourcesToSearch: <BookSource>[savedSource],
      loadInfoEnabled: _loadInfo,
      loadWordCountEnabled: _loadWordCount,
      loadTocEnabled: _loadToc,
      sourceDelaySeconds: _delaySeconds,
    );
    if (refreshed.isEmpty) {
      return List<ReaderSourceSwitchCandidate>.from(
        retained,
        growable: false,
      );
    }

    final merged = List<ReaderSourceSwitchCandidate>.from(
      retained,
      growable: true,
    );
    final insertIdx =
        firstReplaced < 0 || firstReplaced > merged.length
            ? merged.length
            : firstReplaced;
    merged.insertAll(insertIdx, refreshed);
    return List<ReaderSourceSwitchCandidate>.from(
      merged,
      growable: false,
    );
  }

  /// Reorders candidates by custom order.
  List<ReaderSourceSwitchCandidate> reorderByCustomOrder(
    List<ReaderSourceSwitchCandidate> candidates,
  ) {
    if (candidates.length <= 1) {
      return List<ReaderSourceSwitchCandidate>.from(
        candidates,
        growable: false,
      );
    }
    final sourceOrderByKey = <String, int>{
      for (final source in _sourceRepo.getAllSources())
        ReaderSourceSwitchHelper.normalizeForCompare(
          source.bookSourceUrl,
        ): source.customOrder,
    };
    final indexed =
        candidates.asMap().entries.toList(growable: false);
    indexed.sort((left, right) {
      final leftKey =
          ReaderSourceSwitchHelper.normalizeForCompare(
        left.value.source.bookSourceUrl,
      );
      final rightKey =
          ReaderSourceSwitchHelper.normalizeForCompare(
        right.value.source.bookSourceUrl,
      );
      final leftOrder = sourceOrderByKey[leftKey] ??
          left.value.source.customOrder;
      final rightOrder = sourceOrderByKey[rightKey] ??
          right.value.source.customOrder;
      final orderCompare =
          leftOrder.compareTo(rightOrder);
      if (orderCompare != 0) return orderCompare;
      return left.key.compareTo(right.key);
    });
    return indexed
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  // ── Auto Change Source ────────────────────────────────

  /// Sets the auto-changing-source flag. The host widget
  /// should call this when entering/exiting auto-change mode.
  void setAutoChangingSource(bool value) {
    _isAutoChangingSource = value;
    notifyListeners();
  }

  // ── Private Helpers ───────────────────────────────────

  String _normalizeGroup(String g) => g.trim();

  int _normalizeDelaySeconds(int seconds) =>
      seconds.clamp(0, 9999).toInt();

  String _resolveCurrentChapterTitle(Book currentBook) {
    final chapters = _context.chapters();
    if (chapters.isNotEmpty) {
      final chapterIndex = currentBook.currentChapter.clamp(
        0,
        chapters.length - 1,
      );
      final title = chapters[chapterIndex].title.trim();
      if (title.isNotEmpty) return title;
    }
    return _context.currentTitle().trim();
  }

  String _buildWordCountText({
    required int chapterIndex,
    required String chapterTitle,
    required int wordCount,
  }) {
    final trimmed = chapterTitle.trim();
    final display = trimmed.isEmpty ? '未知章节' : trimmed;
    final folded = display.length > 20
        ? '${display.substring(0, 20)}…'
        : display;
    return '[${chapterIndex + 1}] $folded\n字数：$wordCount';
  }

  SearchResult _copySearchResult(
    SearchResult source, {
    required String lastChapter,
  }) {
    return SearchResult(
      name: source.name,
      author: source.author,
      coverUrl: source.coverUrl,
      intro: source.intro,
      kind: source.kind,
      lastChapter: lastChapter,
      updateTime: source.updateTime,
      wordCount: source.wordCount,
      bookUrl: source.bookUrl,
      sourceUrl: source.sourceUrl,
      sourceName: source.sourceName,
    );
  }

  List<ReaderSourceSwitchCandidate> _removeCandidateFromList({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) {
    final targetKey =
        ReaderSourceSwitchHelper.normalizeForCompare(
      candidate.source.bookSourceUrl,
    );
    final targetBookUrl = candidate.book.bookUrl.trim();
    return currentCandidates.where((item) {
      final key = ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      if (key != targetKey) return true;
      if (targetBookUrl.isEmpty) return false;
      return item.book.bookUrl.trim() != targetBookUrl;
    }).toList(growable: false);
  }

  Future<bool> _waitDelayWithCancel({
    required int seconds,
    CancelToken? cancelToken,
  }) async {
    if (seconds <= 0) return true;
    final totalMs = seconds * 1000;
    var elapsedMs = 0;
    while (elapsedMs < totalMs) {
      if (cancelToken?.isCancelled == true) return false;
      final remaining = totalMs - elapsedMs;
      final step = remaining > 200 ? 200 : remaining;
      await Future<void>.delayed(Duration(milliseconds: step));
      elapsedMs += step;
    }
    return cancelToken?.isCancelled != true;
  }
}

/// Result from hydrating a search result with additional data.
class SourceSwitchHydratedResult {
  final SearchResult result;
  final String chapterWordCountText;
  final int chapterWordCount;
  final int respondTimeMs;

  const SourceSwitchHydratedResult({
    required this.result,
    required this.chapterWordCountText,
    required this.chapterWordCount,
    required this.respondTimeMs,
  });
}
