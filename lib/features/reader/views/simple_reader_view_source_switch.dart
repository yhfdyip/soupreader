// ignore_for_file: invalid_use_of_protected_member
part of 'simple_reader_view.dart';

extension _SimpleReaderSourceSwitch on _SimpleReaderViewState {
  Future<List<ReaderSourceSwitchCandidate>> _disableSourceSwitchCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) async {
    final source = _sourceRepo.getSourceByUrl(candidate.source.bookSourceUrl);
    if (source != null) {
      await _sourceRepo.updateSource(source.copyWith(enabled: false));
    }
    final targetSourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
      candidate.source.bookSourceUrl,
    );
    final targetBookUrl = candidate.book.bookUrl.trim();
    return currentCandidates.where((item) {
      final sourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      if (sourceKey != targetSourceKey) {
        return true;
      }
      if (targetBookUrl.isEmpty) {
        return false;
      }
      return item.book.bookUrl.trim() != targetBookUrl;
    }).toList(growable: false);
  }

  Future<List<ReaderSourceSwitchCandidate>> _deleteSourceSwitchCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) async {
    await _deleteSourceByLegacyRule(candidate.source.bookSourceUrl);
    final targetSourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
      candidate.source.bookSourceUrl,
    );
    final targetBookUrl = candidate.book.bookUrl.trim();
    return currentCandidates.where((item) {
      final sourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      if (sourceKey != targetSourceKey) {
        return true;
      }
      if (targetBookUrl.isEmpty) {
        return false;
      }
      return item.book.bookUrl.trim() != targetBookUrl;
    }).toList(growable: false);
  }

  Future<List<ReaderSourceSwitchCandidate>> _topSourceSwitchCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) async {
    final source = _sourceRepo.getSourceByUrl(candidate.source.bookSourceUrl);
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
      if (item.customOrder < minOrder) {
        minOrder = item.customOrder;
      }
    }
    final updatedSource = source.copyWith(customOrder: minOrder - 1);
    await _sourceRepo.updateSource(updatedSource);

    final targetKey = ReaderSourceSwitchHelper.normalizeForCompare(
      updatedSource.bookSourceUrl,
    );
    final updatedCandidates = currentCandidates.map((item) {
      final itemKey = ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      if (itemKey != targetKey) {
        return item;
      }
      return ReaderSourceSwitchCandidate(
        source: updatedSource,
        book: item.book,
        chapterWordCountText: item.chapterWordCountText,
        chapterWordCount: item.chapterWordCount,
        respondTimeMs: item.respondTimeMs,
      );
    }).toList(growable: false);

    return _reorderSourceSwitchCandidatesByCustomOrder(updatedCandidates);
  }

  Future<List<ReaderSourceSwitchCandidate>> _bottomSourceSwitchCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
  }) async {
    final source = _sourceRepo.getSourceByUrl(candidate.source.bookSourceUrl);
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
      if (item.customOrder > maxOrder) {
        maxOrder = item.customOrder;
      }
    }
    final updatedSource = source.copyWith(customOrder: maxOrder + 1);
    await _sourceRepo.updateSource(updatedSource);

    final targetKey = ReaderSourceSwitchHelper.normalizeForCompare(
      updatedSource.bookSourceUrl,
    );
    final updatedCandidates = currentCandidates.map((item) {
      final itemKey = ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      if (itemKey != targetKey) {
        return item;
      }
      return ReaderSourceSwitchCandidate(
        source: updatedSource,
        book: item.book,
        chapterWordCountText: item.chapterWordCountText,
        chapterWordCount: item.chapterWordCount,
        respondTimeMs: item.respondTimeMs,
      );
    }).toList(growable: false);

    return _reorderSourceSwitchCandidatesByCustomOrder(updatedCandidates);
  }

  Future<List<ReaderSourceSwitchCandidate>>
      _refreshEditedSourceSwitchCandidate({
    required ReaderSourceSwitchCandidate editedCandidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
    required Book currentBook,
    required String savedSourceUrl,
  }) async {
    final oldSourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
      editedCandidate.source.bookSourceUrl,
    );
    final nextSourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
      savedSourceUrl,
    );
    final retained = <ReaderSourceSwitchCandidate>[];
    var firstReplacedIndex = -1;
    for (final item in currentCandidates) {
      final key = ReaderSourceSwitchHelper.normalizeForCompare(
        item.source.bookSourceUrl,
      );
      final shouldReplace = key == oldSourceKey || key == nextSourceKey;
      if (shouldReplace) {
        if (firstReplacedIndex < 0) {
          firstReplacedIndex = retained.length;
        }
        continue;
      }
      retained.add(item);
    }

    final savedSource = _sourceRepo.getSourceByUrl(savedSourceUrl);
    if (savedSource == null) {
      return List<ReaderSourceSwitchCandidate>.from(
        retained,
        growable: false,
      );
    }

    final refreshed = await _loadSourceSwitchCandidatesBySources(
      currentBook: currentBook,
      sourcesToSearch: <BookSource>[savedSource],
      loadInfoEnabled: _changeSourceLoadInfo,
      loadWordCountEnabled: _changeSourceLoadWordCount,
      loadTocEnabled: _changeSourceLoadToc,
      sourceDelaySeconds: _changeSourceDelaySeconds,
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
    final insertIndex =
        firstReplacedIndex < 0 || firstReplacedIndex > merged.length
            ? merged.length
            : firstReplacedIndex;
    merged.insertAll(insertIndex, refreshed);
    return List<ReaderSourceSwitchCandidate>.from(merged, growable: false);
  }

  Future<List<ReaderSourceSwitchCandidate>> _editSourceSwitchCandidate({
    required ReaderSourceSwitchCandidate candidate,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
    required Book currentBook,
    required bool refreshAllAfterEdit,
  }) async {
    final savedSourceUrl =
        await _openSourceEditorFromReader(candidate.source.bookSourceUrl);
    if (savedSourceUrl == null) {
      return List<ReaderSourceSwitchCandidate>.from(
        currentCandidates,
        growable: false,
      );
    }
    if (refreshAllAfterEdit) {
      return _startSourceSwitchCandidateSearch(
        currentBook: currentBook,
        currentCandidates: currentCandidates,
        loadInfoEnabled: _changeSourceLoadInfo,
        loadWordCountEnabled: _changeSourceLoadWordCount,
        loadTocEnabled: _changeSourceLoadToc,
        sourceDelaySeconds: _changeSourceDelaySeconds,
      );
    }
    return _refreshEditedSourceSwitchCandidate(
      editedCandidate: candidate,
      currentCandidates: currentCandidates,
      currentBook: currentBook,
      savedSourceUrl: savedSourceUrl,
    );
  }

  List<ReaderSourceSwitchCandidate> _reorderSourceSwitchCandidatesByCustomOrder(
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
        ReaderSourceSwitchHelper.normalizeForCompare(source.bookSourceUrl):
            source.customOrder,
    };
    final indexed = candidates.asMap().entries.toList(growable: false);
    indexed.sort((left, right) {
      final leftKey = ReaderSourceSwitchHelper.normalizeForCompare(
        left.value.source.bookSourceUrl,
      );
      final rightKey = ReaderSourceSwitchHelper.normalizeForCompare(
        right.value.source.bookSourceUrl,
      );
      final leftOrder =
          sourceOrderByKey[leftKey] ?? left.value.source.customOrder;
      final rightOrder =
          sourceOrderByKey[rightKey] ?? right.value.source.customOrder;
      final orderCompare = leftOrder.compareTo(rightOrder);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return left.key.compareTo(right.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  void _stopSourceSwitchCandidateSearch() {
    final token = _sourceSwitchCandidateSearchCancelToken;
    if (token == null || token.isCancelled) return;
    token.cancel('source switch candidate search stopped by user');
  }

  Future<List<ReaderSourceSwitchCandidate>> _startSourceSwitchCandidateSearch({
    required Book currentBook,
    required List<ReaderSourceSwitchCandidate> currentCandidates,
    bool? loadInfoEnabled,
    bool? loadWordCountEnabled,
    bool? loadTocEnabled,
    int? sourceDelaySeconds,
  }) async {
    _stopSourceSwitchCandidateSearch();
    final token = CancelToken();
    _sourceSwitchCandidateSearchCancelToken = token;
    try {
      final searched = await _loadSourceSwitchCandidates(
        currentBook: currentBook,
        loadInfoEnabled: loadInfoEnabled ?? _changeSourceLoadInfo,
        loadWordCountEnabled:
            loadWordCountEnabled ?? _changeSourceLoadWordCount,
        loadTocEnabled: loadTocEnabled ?? _changeSourceLoadToc,
        sourceDelaySeconds: sourceDelaySeconds ?? _changeSourceDelaySeconds,
        cancelToken: token,
      );
      if (token.isCancelled) {
        return currentCandidates;
      }
      return searched;
    } catch (_) {
      if (token.isCancelled) {
        return currentCandidates;
      }
      rethrow;
    } finally {
      if (identical(_sourceSwitchCandidateSearchCancelToken, token)) {
        _sourceSwitchCandidateSearchCancelToken = null;
      }
    }
  }

  Book _buildCurrentBookForSourceSwitch() {
    return _bookRepo.getBookById(widget.bookId) ??
        Book(
          id: widget.bookId,
          title: widget.bookTitle,
          author: _bookAuthor,
          sourceId: _currentSourceUrl,
          sourceUrl: _currentSourceUrl,
          bookUrl: null,
          latestChapter: _currentTitle,
          totalChapters: _chapters.length,
          currentChapter: _currentChapterIndex,
          readProgress: _getBookProgress(),
          isLocal: false,
        );
  }

  SearchResult _copySourceSwitchSearchResult(
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

  String _resolveCurrentChapterTitleForSourceSwitch(Book currentBook) {
    if (_chapters.isNotEmpty) {
      final chapterIndex = currentBook.currentChapter.clamp(
        0,
        _chapters.length - 1,
      );
      final chapterTitle = _chapters[chapterIndex].title.trim();
      if (chapterTitle.isNotEmpty) {
        return chapterTitle;
      }
    }
    return _currentTitle.trim();
  }

  String _buildSourceSwitchWordCountText({
    required int chapterIndex,
    required String chapterTitle,
    required int wordCount,
  }) {
    final trimmedTitle = chapterTitle.trim();
    final displayTitle = trimmedTitle.isEmpty ? '未知章节' : trimmedTitle;
    final foldedTitle = displayTitle.length > 20
        ? '${displayTitle.substring(0, 20)}…'
        : displayTitle;
    return '[${chapterIndex + 1}] $foldedTitle\n字数：$wordCount';
  }

  Future<
      ({
        SearchResult result,
        String chapterWordCountText,
        int chapterWordCount,
        int respondTimeMs
      })> _hydrateSourceSwitchSearchResult({
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
        (!loadInfoEnabled && !loadTocEnabled && !loadWordCountEnabled)) {
      return (
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
    final detailLastChapter = detail?.lastChapter.trim() ?? '';
    final tocUrl = detail?.tocUrl.trim().isNotEmpty == true
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
      if (latest.isNotEmpty) {
        nextLastChapter = latest;
      }
    } else if (detailLastChapter.isNotEmpty &&
        (loadInfoEnabled || loadWordCountEnabled || loadTocEnabled)) {
      nextLastChapter = detailLastChapter;
    } else if (loadTocEnabled) {
      if (detailLastChapter.isNotEmpty) {
        nextLastChapter = detailLastChapter;
      }
    }
    final nextResult = nextLastChapter == result.lastChapter
        ? result
        : _copySourceSwitchSearchResult(
            result,
            lastChapter: nextLastChapter,
          );
    if (!loadWordCountEnabled || toc.isEmpty) {
      return (
        result: nextResult,
        chapterWordCountText: '',
        chapterWordCount: -1,
        respondTimeMs: -1,
      );
    }

    final parsedChapters = <Chapter>[];
    for (final item in toc) {
      final chapterTitle = item.name.trim();
      final chapterUrl = item.url.trim();
      if (chapterTitle.isEmpty || chapterUrl.isEmpty) continue;
      parsedChapters.add(
        Chapter(
          id: '${widget.bookId}_switch_word_count_${parsedChapters.length}',
          bookId: widget.bookId,
          title: chapterTitle,
          url: chapterUrl,
          index: parsedChapters.length,
        ),
      );
    }
    if (parsedChapters.isEmpty) {
      return (
        result: nextResult,
        chapterWordCountText: '',
        chapterWordCount: -1,
        respondTimeMs: -1,
      );
    }

    final currentChapterTitle = _resolveCurrentChapterTitleForSourceSwitch(
      currentBook,
    );
    final currentChapterIndex = currentBook.currentChapter.clamp(
      0,
      parsedChapters.length - 1,
    );
    final oldChapterCount = currentBook.totalChapters > 0
        ? currentBook.totalChapters
        : _chapters.length;
    final targetChapterIndex =
        ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: parsedChapters,
      currentChapterTitle: currentChapterTitle,
      currentChapterIndex: currentChapterIndex,
      oldChapterCount: oldChapterCount,
    ).clamp(0, parsedChapters.length - 1);
    final targetChapter = parsedChapters[targetChapterIndex];
    final targetNextChapterUrl = targetChapterIndex + 1 < parsedChapters.length
        ? parsedChapters[targetChapterIndex + 1].url
        : null;

    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final content = await _ruleEngine.getContent(
        source,
        targetChapter.url ?? '',
        nextChapterUrl: targetNextChapterUrl,
        clearRuntimeVariables: false,
        cancelToken: cancelToken,
      );
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAtMs;
      final chapterWordCount = content.length;
      return (
        result: nextResult,
        chapterWordCountText: _buildSourceSwitchWordCountText(
          chapterIndex: targetChapterIndex,
          chapterTitle: targetChapter.title,
          wordCount: chapterWordCount,
        ),
        chapterWordCount: chapterWordCount,
        respondTimeMs: elapsedMs,
      );
    } catch (error) {
      if (cancelToken?.isCancelled == true) rethrow;
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAtMs;
      final message = _normalizeReaderErrorMessage(error);
      final errorText = message.isEmpty ? '未知错误' : message;
      return (
        result: nextResult,
        chapterWordCountText:
            '[${targetChapterIndex + 1}] ${targetChapter.title}\n获取字数失败：$errorText',
        chapterWordCount: -1,
        respondTimeMs: elapsedMs,
      );
    }
  }

  Future<void> _handleChangeSourceLoadWordCountChanged(bool enabled) async {
    _changeSourceLoadWordCount = enabled;
    await _settingsService.saveChangeSourceLoadWordCount(enabled);
  }

  Future<void> _handleChangeSourceLoadInfoChanged(bool enabled) async {
    _changeSourceLoadInfo = enabled;
    await _settingsService.saveChangeSourceLoadInfo(enabled);
  }

  Future<void> _handleChangeSourceLoadTocChanged(bool enabled) async {
    _changeSourceLoadToc = enabled;
    await _settingsService.saveChangeSourceLoadToc(enabled);
  }

  Future<void> _handleChangeSourceCheckAuthorChanged(bool enabled) async {
    _changeSourceCheckAuthor = enabled;
    await _settingsService.saveChangeSourceCheckAuthor(enabled);
  }

  String _normalizeChangeSourceGroup(String group) {
    return group.trim();
  }

  Future<void> _handleChangeSourceGroupChanged(String group) async {
    final normalized = _normalizeChangeSourceGroup(group);
    _changeSourceGroup = normalized;
    await _settingsService.saveChangeSourceGroup(normalized);
  }

  List<String> _buildChangeSourceGroups() {
    return SearchScopeGroupHelper.enabledGroupsFromSources(
      _sourceRepo.getAllSources(),
    );
  }

  List<BookSource> _scopeChangeSourceSourcesByGroup(
    List<BookSource> enabledSources,
  ) {
    final selectedGroup = _normalizeChangeSourceGroup(_changeSourceGroup);
    if (selectedGroup.isEmpty) {
      return enabledSources;
    }
    final scopedSources = enabledSources.where((source) {
      return SearchScope.splitSourceGroups(source.bookSourceGroup)
          .contains(selectedGroup);
    }).toList(growable: false);
    if (scopedSources.isNotEmpty) {
      return scopedSources;
    }
    _changeSourceGroup = '';
    unawaited(_settingsService.saveChangeSourceGroup(''));
    return enabledSources;
  }

  Future<bool> _confirmSwitchChangeSourceGroupToAll(String group) async {
    final result = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('搜索结果为空'),
        content: Text('$group分组搜索结果为空,是否切换到全部分组'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<List<ReaderSourceSwitchCandidate>>
      _loadSourceSwitchCandidatesWithGroupFallback({
    required Book currentBook,
    bool? loadInfoEnabled,
    bool? loadWordCountEnabled,
    bool? loadTocEnabled,
    int? sourceDelaySeconds,
    CancelToken? cancelToken,
  }) async {
    var candidates = await _loadSourceSwitchCandidates(
      currentBook: currentBook,
      loadInfoEnabled: loadInfoEnabled,
      loadWordCountEnabled: loadWordCountEnabled,
      loadTocEnabled: loadTocEnabled,
      sourceDelaySeconds: sourceDelaySeconds,
      cancelToken: cancelToken,
    );
    if (!mounted) {
      return candidates;
    }
    final selectedGroup = _normalizeChangeSourceGroup(_changeSourceGroup);
    if (candidates.isNotEmpty ||
        selectedGroup.isEmpty ||
        cancelToken?.isCancelled == true) {
      return candidates;
    }
    final fallbackToAll = await _confirmSwitchChangeSourceGroupToAll(
      selectedGroup,
    );
    if (!mounted || !fallbackToAll || cancelToken?.isCancelled == true) {
      return candidates;
    }
    await _handleChangeSourceGroupChanged('');
    candidates = await _loadSourceSwitchCandidates(
      currentBook: currentBook,
      loadInfoEnabled: loadInfoEnabled,
      loadWordCountEnabled: loadWordCountEnabled,
      loadTocEnabled: loadTocEnabled,
      sourceDelaySeconds: sourceDelaySeconds,
      cancelToken: cancelToken,
    );
    return candidates;
  }

  int _normalizeChangeSourceDelaySeconds(int seconds) {
    return seconds.clamp(0, 9999).toInt();
  }

  Future<void> _handleChangeSourceDelayChanged(int seconds) async {
    final normalized = _normalizeChangeSourceDelaySeconds(seconds);
    _changeSourceDelaySeconds = normalized;
    await _settingsService.saveBatchChangeSourceDelay(normalized);
  }

  Future<bool> _waitSourceSwitchDelayWithCancel({
    required int seconds,
    CancelToken? cancelToken,
  }) async {
    if (seconds <= 0) return true;
    final totalMs = seconds * 1000;
    var elapsedMs = 0;
    while (elapsedMs < totalMs) {
      if (cancelToken?.isCancelled == true) {
        return false;
      }
      final remainingMs = totalMs - elapsedMs;
      final stepMs = remainingMs > 200 ? 200 : remainingMs;
      await Future<void>.delayed(Duration(milliseconds: stepMs));
      elapsedMs += stepMs;
    }
    return cancelToken?.isCancelled != true;
  }

  Future<List<ReaderSourceSwitchCandidate>> _loadSourceSwitchCandidates({
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
        final orderCompare = a.value.customOrder.compareTo(b.value.customOrder);
        if (orderCompare != 0) return orderCompare;
        return a.key.compareTo(b.key);
      });
    final sortedEnabledSources =
        orderedSources.map((entry) => entry.value).toList(growable: false);
    final scopedSources = _scopeChangeSourceSourcesByGroup(
      sortedEnabledSources,
    );

    return _loadSourceSwitchCandidatesBySources(
      currentBook: currentBook,
      sourcesToSearch: scopedSources,
      loadInfoEnabled: loadInfoEnabled ?? _changeSourceLoadInfo,
      loadWordCountEnabled: loadWordCountEnabled ?? _changeSourceLoadWordCount,
      loadTocEnabled: loadTocEnabled ?? _changeSourceLoadToc,
      sourceDelaySeconds: sourceDelaySeconds ?? _changeSourceDelaySeconds,
      cancelToken: cancelToken,
    );
  }

  Future<List<ReaderSourceSwitchCandidate>>
      _refreshSourceSwitchCandidatesByCurrentList({
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
          ReaderSourceSwitchHelper.normalizeForCompare(source.bookSourceUrl):
              source,
    };
    final scopedSources = <BookSource>[];
    final scopedSourceKeys = <String>{};
    for (final candidate in currentCandidates) {
      final sourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
        candidate.source.bookSourceUrl,
      );
      if (sourceKey.isEmpty || !scopedSourceKeys.add(sourceKey)) {
        continue;
      }
      final source = enabledSourceByUrl[sourceKey];
      if (source == null) continue;
      scopedSources.add(source);
    }
    if (scopedSources.isEmpty) {
      return const <ReaderSourceSwitchCandidate>[];
    }

    return _loadSourceSwitchCandidatesBySources(
      currentBook: currentBook,
      sourcesToSearch: scopedSources,
      loadInfoEnabled: loadInfoEnabled ?? _changeSourceLoadInfo,
      loadWordCountEnabled: loadWordCountEnabled ?? _changeSourceLoadWordCount,
      loadTocEnabled: loadTocEnabled ?? _changeSourceLoadToc,
      sourceDelaySeconds: sourceDelaySeconds ?? _changeSourceDelaySeconds,
      cancelToken: cancelToken,
    );
  }

  Future<List<ReaderSourceSwitchCandidate>>
      _loadSourceSwitchCandidatesBySources({
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

    final searchDelaySeconds = _normalizeChangeSourceDelaySeconds(
      sourceDelaySeconds,
    );
    final searchResults = <SearchResult>[];
    final chapterWordCountTextByKey = <String, String>{};
    final chapterWordCountByKey = <String, int>{};
    final respondTimeMsByKey = <String, int>{};

    String buildCandidateMetricKey(SearchResult result) {
      final sourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
        result.sourceUrl,
      );
      final bookUrl = result.bookUrl.trim();
      return '$sourceKey|$bookUrl';
    }

    void recordWordCountMeta(
      SearchResult result, {
      required String chapterWordCountText,
      required int chapterWordCount,
      required int respondTimeMs,
    }) {
      if (!loadWordCountEnabled) return;
      final sourceKey = ReaderSourceSwitchHelper.normalizeForCompare(
        result.sourceUrl,
      );
      if (sourceKey.isEmpty) return;
      final bookUrl = result.bookUrl.trim();
      if (bookUrl.isEmpty) return;
      final key = buildCandidateMetricKey(result);
      chapterWordCountTextByKey[key] = chapterWordCountText.trim();
      chapterWordCountByKey[key] = chapterWordCount;
      respondTimeMsByKey[key] = respondTimeMs;
    }

    for (var index = 0; index < sourcesToSearch.length; index++) {
      if (cancelToken?.isCancelled == true) {
        break;
      }
      final source = sourcesToSearch[index];
      if (index > 0 && searchDelaySeconds > 0) {
        final continueSearch = await _waitSourceSwitchDelayWithCancel(
          seconds: searchDelaySeconds,
          cancelToken: cancelToken,
        );
        if (!continueSearch) {
          break;
        }
      }
      try {
        final list = await _ruleEngine.search(
          source,
          keyword,
          filter: (name, _) {
            if (name != keyword) return false;
            return true;
          },
          cancelToken: cancelToken,
        );
        if (cancelToken?.isCancelled == true) {
          break;
        }
        if (!(loadInfoEnabled || loadTocEnabled || loadWordCountEnabled) ||
            list.isEmpty) {
          searchResults.addAll(list);
          continue;
        }

        for (final item in list) {
          if (cancelToken?.isCancelled == true) {
            break;
          }
          try {
            final hydrated = await _hydrateSourceSwitchSearchResult(
              currentBook: currentBook,
              source: source,
              result: item,
              loadInfoEnabled: loadInfoEnabled,
              loadTocEnabled: loadTocEnabled,
              loadWordCountEnabled: loadWordCountEnabled,
              cancelToken: cancelToken,
            );
            final hydratedResult = hydrated.result;
            searchResults.add(hydratedResult);
            recordWordCountMeta(
              hydratedResult,
              chapterWordCountText: hydrated.chapterWordCountText,
              chapterWordCount: hydrated.chapterWordCount,
              respondTimeMs: hydrated.respondTimeMs,
            );
          } catch (_) {
            if (cancelToken?.isCancelled == true) {
              break;
            }
            searchResults.add(item);
          }
        }
      } catch (_) {
        if (cancelToken?.isCancelled == true) {
          break;
        }
        // 单源失败隔离
      }
    }

    return ReaderSourceSwitchHelper.buildCandidates(
      currentBook: currentBook,
      enabledSources: sourcesToSearch,
      searchResults: searchResults,
      loadWordCountEnabled: loadWordCountEnabled,
      chapterWordCountTextByKey: chapterWordCountTextByKey,
      chapterWordCountByKey: chapterWordCountByKey,
      respondTimeMsByKey: respondTimeMsByKey,
    );
  }

  Future<void> _showSwitchSourceBookMenu() async {
    final currentBook = _buildCurrentBookForSourceSwitch();
    final keyword = currentBook.title.trim();
    if (keyword.isEmpty) {
      _showToast('书名为空，无法换源');
      return;
    }

    final enabledSourceCount =
        _sourceRepo.getAllSources().where((source) => source.enabled).length;
    if (enabledSourceCount <= 0) {
      _showToast('没有可用书源');
      return;
    }

    final candidates = await _loadSourceSwitchCandidatesWithGroupFallback(
      currentBook: currentBook,
      loadInfoEnabled: _changeSourceLoadInfo,
      loadWordCountEnabled: _changeSourceLoadWordCount,
      loadTocEnabled: _changeSourceLoadToc,
      sourceDelaySeconds: _changeSourceDelaySeconds,
    );
    if (!mounted) return;
    if (candidates.isEmpty) {
      _showToast('未找到可切换的匹配书源');
      return;
    }

    final selected = await showSourceSwitchCandidateSheet(
      context: context,
      keyword: keyword,
      candidates: candidates,
      changeSourceGroup: _changeSourceGroup,
      sourceGroups: _buildChangeSourceGroups(),
      authorKeyword: currentBook.author,
      checkAuthorEnabled: _changeSourceCheckAuthor,
      loadInfoEnabled: _changeSourceLoadInfo,
      loadWordCountEnabled: _changeSourceLoadWordCount,
      loadTocEnabled: _changeSourceLoadToc,
      changeSourceDelaySeconds: _changeSourceDelaySeconds,
      onChangeSourceGroupChanged: _handleChangeSourceGroupChanged,
      onCheckAuthorChanged: _handleChangeSourceCheckAuthorChanged,
      onLoadInfoChanged: _handleChangeSourceLoadInfoChanged,
      onLoadWordCountChanged: _handleChangeSourceLoadWordCountChanged,
      onLoadTocChanged: _handleChangeSourceLoadTocChanged,
      onChangeSourceDelayChanged: _handleChangeSourceDelayChanged,
      onOpenSourceManage: _openSourceManageFromReader,
      onStartCandidatesSearch: (currentCandidates) {
        return _startSourceSwitchCandidateSearch(
          currentBook: currentBook,
          currentCandidates: currentCandidates,
          loadInfoEnabled: _changeSourceLoadInfo,
          loadWordCountEnabled: _changeSourceLoadWordCount,
          loadTocEnabled: _changeSourceLoadToc,
          sourceDelaySeconds: _changeSourceDelaySeconds,
        );
      },
      onStopCandidatesSearch: () async {
        _stopSourceSwitchCandidateSearch();
      },
      onRefreshCandidates: (currentCandidates) {
        return _refreshSourceSwitchCandidatesByCurrentList(
          currentBook: currentBook,
          currentCandidates: currentCandidates,
          loadInfoEnabled: _changeSourceLoadInfo,
          loadWordCountEnabled: _changeSourceLoadWordCount,
          loadTocEnabled: _changeSourceLoadToc,
          sourceDelaySeconds: _changeSourceDelaySeconds,
        );
      },
      onTopSourceCandidate: (candidate, currentCandidates) {
        return _topSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
        );
      },
      onEditSourceCandidate: (candidate, currentCandidates) {
        return _editSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
          currentBook: currentBook,
          refreshAllAfterEdit: false,
        );
      },
      onBottomSourceCandidate: (candidate, currentCandidates) {
        return _bottomSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
        );
      },
      onDisableSourceCandidate: (candidate, currentCandidates) {
        return _disableSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
        );
      },
      onDeleteSourceCandidate: (candidate, currentCandidates) {
        return _deleteSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
        );
      },
      confirmDeleteSourceCandidate: true,
    );
    _stopSourceSwitchCandidateSearch();
    if (selected == null) return;
    await _switchToSourceCandidate(selected);
  }

  Future<void> _showSwitchSourceChapterMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      _showToast('当前章节不存在');
      return;
    }

    final currentBook = _buildCurrentBookForSourceSwitch();
    final keyword = currentBook.title.trim();
    if (keyword.isEmpty) {
      _showToast('书名为空，无法换源');
      return;
    }

    final enabledSourceCount =
        _sourceRepo.getAllSources().where((source) => source.enabled).length;
    if (enabledSourceCount <= 0) {
      _showToast('没有可用书源');
      return;
    }

    final candidates = await _loadSourceSwitchCandidatesWithGroupFallback(
      currentBook: currentBook,
      loadInfoEnabled: _changeSourceLoadInfo,
      loadWordCountEnabled: _changeSourceLoadWordCount,
      loadTocEnabled: _changeSourceLoadToc,
      sourceDelaySeconds: _changeSourceDelaySeconds,
    );
    if (!mounted) return;
    if (candidates.isEmpty) {
      _showToast('未找到可切换的匹配书源');
      return;
    }

    final selected = await showSourceSwitchCandidateSheet(
      context: context,
      keyword: keyword,
      candidates: candidates,
      changeSourceGroup: _changeSourceGroup,
      sourceGroups: _buildChangeSourceGroups(),
      authorKeyword: currentBook.author,
      checkAuthorEnabled: _changeSourceCheckAuthor,
      loadInfoEnabled: _changeSourceLoadInfo,
      loadWordCountEnabled: _changeSourceLoadWordCount,
      loadTocEnabled: _changeSourceLoadToc,
      changeSourceDelaySeconds: _changeSourceDelaySeconds,
      onChangeSourceGroupChanged: _handleChangeSourceGroupChanged,
      onCheckAuthorChanged: _handleChangeSourceCheckAuthorChanged,
      onLoadInfoChanged: _handleChangeSourceLoadInfoChanged,
      onLoadWordCountChanged: _handleChangeSourceLoadWordCountChanged,
      onLoadTocChanged: _handleChangeSourceLoadTocChanged,
      onChangeSourceDelayChanged: _handleChangeSourceDelayChanged,
      onOpenSourceManage: _openSourceManageFromReader,
      onStartCandidatesSearch: (currentCandidates) {
        return _startSourceSwitchCandidateSearch(
          currentBook: currentBook,
          currentCandidates: currentCandidates,
          loadInfoEnabled: _changeSourceLoadInfo,
          loadWordCountEnabled: _changeSourceLoadWordCount,
          loadTocEnabled: _changeSourceLoadToc,
          sourceDelaySeconds: _changeSourceDelaySeconds,
        );
      },
      onStopCandidatesSearch: () async {
        _stopSourceSwitchCandidateSearch();
      },
      onRefreshCandidates: (currentCandidates) {
        return _refreshSourceSwitchCandidatesByCurrentList(
          currentBook: currentBook,
          currentCandidates: currentCandidates,
          loadInfoEnabled: _changeSourceLoadInfo,
          loadWordCountEnabled: _changeSourceLoadWordCount,
          loadTocEnabled: _changeSourceLoadToc,
          sourceDelaySeconds: _changeSourceDelaySeconds,
        );
      },
      onTopSourceCandidate: (candidate, currentCandidates) {
        return _topSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
        );
      },
      onEditSourceCandidate: (candidate, currentCandidates) {
        return _editSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
          currentBook: currentBook,
          refreshAllAfterEdit: true,
        );
      },
      onBottomSourceCandidate: (candidate, currentCandidates) {
        return _bottomSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
        );
      },
      onDisableSourceCandidate: (candidate, currentCandidates) {
        return _disableSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
        );
      },
      onDeleteSourceCandidate: (candidate, currentCandidates) {
        return _deleteSourceSwitchCandidate(
          candidate: candidate,
          currentCandidates: currentCandidates,
        );
      },
    );
    _stopSourceSwitchCandidateSearch();
    if (selected == null) return;
    await _switchCurrentChapterSourceCandidate(selected);
  }

  Future<void> _switchCurrentChapterSourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      _showToast('当前章节不存在');
      return;
    }

    final source = candidate.source;
    final result = candidate.book;
    final currentChapterIndex = _currentChapterIndex;
    final currentChapter = _chapters[currentChapterIndex];
    final currentRawTitle = currentChapter.title;

    try {
      final detail = await _ruleEngine.getBookInfo(
        source,
        result.bookUrl,
        clearRuntimeVariables: true,
      );
      final primaryTocUrl =
          detail?.tocUrl.isNotEmpty == true ? detail!.tocUrl : result.bookUrl;
      final toc = await _ruleEngine.getToc(
        source,
        primaryTocUrl,
        clearRuntimeVariables: false,
      );
      if (toc.isEmpty) {
        _showToast('章节换源失败：目录为空（可能是 ruleToc 不匹配）');
        return;
      }

      final parsedChapters = <Chapter>[];
      for (final item in toc) {
        final title = item.name.trim();
        final url = item.url.trim();
        if (title.isEmpty || url.isEmpty) continue;
        parsedChapters.add(
          Chapter(
            id: '${widget.bookId}_tmp_${parsedChapters.length}',
            bookId: widget.bookId,
            title: title,
            url: url,
            index: parsedChapters.length,
          ),
        );
      }
      if (parsedChapters.isEmpty) {
        _showToast('章节换源失败：新源章节为空');
        return;
      }

      final selectedIndex = await _showChapterSourcePicker(
        source: source,
        chapters: parsedChapters,
        currentChapterTitle: currentRawTitle,
        currentChapterIndex: currentChapterIndex,
        oldChapterCount: _chapters.length,
      );
      if (selectedIndex == null) {
        return;
      }
      if (selectedIndex < 0 || selectedIndex >= parsedChapters.length) {
        _showToast('章节换源失败：目标章节不存在');
        return;
      }

      final targetChapter = parsedChapters[selectedIndex];
      final nextChapterUrl = selectedIndex + 1 < parsedChapters.length
          ? parsedChapters[selectedIndex + 1].url
          : null;
      final content = await _ruleEngine.getContent(
        source,
        targetChapter.url ?? '',
        nextChapterUrl: nextChapterUrl,
      );

      if (!widget.isEphemeral) {
        await _chapterRepo.cacheChapterContent(currentChapter.id, content);
      }

      if (!mounted) return;
      setState(() {
        _replaceStageCache.remove(currentChapter.id);
        _catalogDisplayTitleCacheByChapterId.remove(currentChapter.id);
        _chapterContentInFlight.remove(currentChapter.id);
        _chapters[currentChapterIndex] = currentChapter.copyWith(
          content: content,
          isDownloaded: true,
        );
      });

      await _loadChapter(currentChapterIndex, restoreOffset: true);
    } catch (e) {
      if (!mounted) return;
      final message = _normalizeReaderErrorMessage(e);
      if (message.isEmpty) {
        _showToast('章节换源失败：获取正文出错');
      } else {
        _showToast('章节换源失败：$message');
      }
    }
  }

  Future<int?> _showChapterSourcePicker({
    required BookSource source,
    required List<Chapter> chapters,
    required String currentChapterTitle,
    required int currentChapterIndex,
    required int oldChapterCount,
  }) async {
    if (chapters.isEmpty) return null;
    final suggestedIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: chapters,
      currentChapterTitle: currentChapterTitle,
      currentChapterIndex: currentChapterIndex,
      oldChapterCount: oldChapterCount,
    );
    final currentValue = suggestedIndex.clamp(0, chapters.length - 1).toInt();

    final items = <OptionPickerItem<int>>[];
    for (var i = 0; i < chapters.length; i++) {
      final rawTitle = chapters[i].title.trim();
      final title = rawTitle.isEmpty ? '第${i + 1}章' : rawTitle;
      items.add(
        OptionPickerItem<int>(
          value: i,
          label: '${i + 1}. $title',
          isRecommended: i == currentValue,
        ),
      );
    }

    return showOptionPickerSheet<int>(
      context: context,
      title: '单章换源',
      message: '${source.bookSourceName} · 选择目标章节',
      items: items,
      currentValue: currentValue,
    );
  }

  Future<void> _switchToSourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final source = candidate.source;
    final result = candidate.book;
    final previousSourceUrl = _currentSourceUrl;
    final previousSourceName = _currentSourceName;
    final previousBookUrl = _bookRepo.getBookById(widget.bookId)?.bookUrl;
    final previousChapterIndex = _currentChapterIndex;
    final previousTitle = _currentTitle;
    final previousChapters = List<Chapter>.from(_chapters);
    final previousChapterVipByUrl = Map<String, bool>.from(_chapterVipByUrl);
    final previousChapterPayByUrl = Map<String, bool>.from(_chapterPayByUrl);

    try {
      final detail = await _ruleEngine.getBookInfo(
        source,
        result.bookUrl,
        clearRuntimeVariables: true,
      );
      final primaryTocUrl =
          detail?.tocUrl.isNotEmpty == true ? detail!.tocUrl : result.bookUrl;
      final toc = await _ruleEngine.getToc(
        source,
        primaryTocUrl,
        clearRuntimeVariables: false,
      );
      if (toc.isEmpty) {
        _showToast('切换失败：目录为空（可能是 ruleToc 不匹配）');
        return;
      }

      final newChapters = <Chapter>[];
      for (final item in toc) {
        final title = item.name.trim();
        final url = item.url.trim();
        if (title.isEmpty || url.isEmpty) continue;
        final chapterId = '${widget.bookId}_${newChapters.length}';
        newChapters.add(
          Chapter(
            id: chapterId,
            bookId: widget.bookId,
            title: title,
            url: url,
            index: newChapters.length,
          ),
        );
      }
      if (newChapters.isEmpty) {
        _showToast('切换失败：新源章节为空');
        return;
      }

      final previousRawTitle = previousChapters.isEmpty
          ? previousTitle
          : previousChapters[
                  previousChapterIndex.clamp(0, previousChapters.length - 1)]
              .title;

      if (!widget.isEphemeral) {
        await _chapterRepo.clearChaptersForBook(widget.bookId);
        await _chapterRepo.addChapters(newChapters);

        final oldBook = _bookRepo.getBookById(widget.bookId);
        if (oldBook != null) {
          await _bookRepo.updateBook(
            oldBook.copyWith(
              sourceId: source.bookSourceUrl,
              sourceUrl: source.bookSourceUrl,
              bookUrl: result.bookUrl.trim(),
              latestChapter: newChapters.last.title,
              totalChapters: newChapters.length,
              currentChapter: 0,
              readProgress: 0,
            ),
          );
        }
      }

      final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
        newChapters: newChapters,
        currentChapterTitle: previousRawTitle,
        currentChapterIndex: previousChapterIndex,
        oldChapterCount: previousChapters.length,
      );

      if (!mounted) return;
      _cacheChapterPayFlags(toc);
      setState(() {
        _catalogDisplayTitleCacheByChapterId.clear();
        _chapters = newChapters;
        _currentSourceUrl = source.bookSourceUrl;
        _currentSourceName = source.bookSourceName;
      });

      await _loadChapter(
        _clampChapterIndexToReadableRange(targetIndex),
        restoreOffset: true,
      );
    } catch (e) {
      try {
        if (!widget.isEphemeral) {
          await _chapterRepo.clearChaptersForBook(widget.bookId);
          await _chapterRepo.addChapters(previousChapters);
          final oldBook = _bookRepo.getBookById(widget.bookId);
          if (oldBook != null && previousSourceUrl != null) {
            await _bookRepo.updateBook(
              oldBook.copyWith(
                sourceId: previousSourceUrl,
                sourceUrl: previousSourceUrl,
                bookUrl: previousBookUrl,
                latestChapter: previousChapters.isEmpty
                    ? oldBook.latestChapter
                    : previousChapters.last.title,
                totalChapters: previousChapters.length,
                currentChapter: previousChapterIndex.clamp(
                  0,
                  previousChapters.isEmpty ? 0 : previousChapters.length - 1,
                ),
              ),
            );
          }
        }
      } catch (_) {
        // 回滚失败时保留原错误提示，避免吞掉主错误
      }
      if (mounted) {
        setState(() {
          _catalogDisplayTitleCacheByChapterId.clear();
          _chapters = previousChapters;
          _currentSourceUrl = previousSourceUrl;
          _currentSourceName = previousSourceName;
          _chapterVipByUrl
            ..clear()
            ..addAll(previousChapterVipByUrl);
          _chapterPayByUrl
            ..clear()
            ..addAll(previousChapterPayByUrl);
        });
      }
      if (!mounted) return;
      _showToast('换源失败：$e');
    }
  }

  int _legacyTextSizeProgress() {
    return (_settings.fontSize.round() - 5).clamp(0, 45).toInt();
  }

  int _legacyLetterSpacingProgress() {
    return ((_settings.letterSpacing * 100).round() + 50).clamp(0, 100).toInt();
  }

  int _legacyLineSpacingProgress() {
    final mapped = ((_settings.lineHeight - 1.0) * 10 + 10).round();
    return mapped.clamp(0, 20).toInt();
  }

  int _legacyParagraphSpacingProgress() {
    return _settings.paragraphSpacing.round().clamp(0, 20).toInt();
  }

  int _nextTextBoldValue(int current) {
    switch (current) {
      case 2:
        return 0;
      case 0:
        return 1;
      case 1:
      default:
        return 2;
    }
  }

  String _legacyLetterSpacingLabel(int progress) {
    return ((progress - 50) / 100).toStringAsFixed(2);
  }

  String _legacyLineSpacingLabel(int progress) {
    return ((progress - 10) / 10).toStringAsFixed(1);
  }

  String _legacyParagraphSpacingLabel(int progress) {
    return (progress / 10).toStringAsFixed(1);
  }

  PageTurnMode _legacyStyleDialogPageAnimMode() {
    switch (_settings.pageTurnMode) {
      case PageTurnMode.cover:
      case PageTurnMode.slide:
      case PageTurnMode.simulation:
      case PageTurnMode.scroll:
      case PageTurnMode.none:
        return _settings.pageTurnMode;
      case PageTurnMode.simulation2:
        return PageTurnMode.simulation;
    }
  }

  // ignore: unused_element
}
