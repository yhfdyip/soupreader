// ignore_for_file: invalid_use_of_protected_member
part of 'simple_reader_view.dart';

extension _SimpleReaderScroll on _SimpleReaderViewState {
  GlobalKey _scrollSegmentKeyFor(int chapterIndex) {
    return _scrollSegmentKeys.putIfAbsent(
      chapterIndex,
      () => GlobalKey(debugLabel: 'scroll_segment_$chapterIndex'),
    );
  }

  double _resolveScrollTopSystemInset(MediaQueryData mediaQuery) {
    if (_settings.showStatusBar) {
      return mediaQuery.padding.top;
    }
    if (_settings.paddingDisplayCutouts) {
      return mediaQuery.viewPadding.top;
    }
    return 0.0;
  }

  double _resolveScrollBottomSystemInset(MediaQueryData mediaQuery) {
    if (_settings.hideNavigationBar) {
      if (_settings.paddingDisplayCutouts) {
        return mediaQuery.viewPadding.bottom;
      }
      return 0.0;
    }
    return mediaQuery.padding.bottom;
  }

  double _resolveScrollHeaderSlotHeight() {
    if (!_settings.shouldShowHeader(showStatusBar: _settings.showStatusBar)) {
      return 0.0;
    }
    return PagedReaderWidget.resolveHeaderSlotHeight(
      settings: _settings,
      showStatusBar: _settings.showStatusBar,
    );
  }

  double _resolveScrollFooterSlotHeight() {
    if (!_settings.shouldShowFooter()) {
      return 0.0;
    }
    return PagedReaderWidget.resolveFooterSlotHeight(
      settings: _settings,
    );
  }

  EdgeInsets _resolveScrollContentInsets(MediaQueryData mediaQuery) {
    final leftInset =
        _settings.paddingDisplayCutouts ? mediaQuery.padding.left : 0.0;
    final rightInset =
        _settings.paddingDisplayCutouts ? mediaQuery.padding.right : 0.0;
    return EdgeInsets.fromLTRB(
      leftInset,
      _resolveScrollTopSystemInset(mediaQuery) +
          _resolveScrollHeaderSlotHeight(),
      rightInset,
      _resolveScrollBottomSystemInset(mediaQuery) +
          _resolveScrollFooterSlotHeight(),
    );
  }

  double _scrollBodyWidth() {
    if (!mounted) return 320.0;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return 320.0;
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;
    final horizontalSafeInset = _settings.paddingDisplayCutouts
        ? safePadding.left + safePadding.right
        : 0.0;
    return (screenSize.width -
            horizontalSafeInset -
            _settings.paddingLeft -
            _settings.paddingRight)
        .clamp(1.0, double.infinity)
        .toDouble();
  }

  TextStyle _scrollParagraphStyle() {
    return TextStyle(
      fontSize: _settings.fontSize,
      height: _settings.lineHeight,
      color: _currentTheme.text,
      letterSpacing: _settings.letterSpacing,
      fontFamily: _currentFontFamily,
      fontFamilyFallback: _currentFontFamilyFallback,
      fontWeight: _currentFontWeight,
      decoration: _currentTextDecoration,
    );
  }

  ScrollTextLayoutKey _scrollLayoutKeyFor({
    required _ScrollSegmentSeed seed,
    required double maxWidth,
    required TextStyle style,
  }) {
    return ScrollTextLayoutKey(
      chapterId: seed.chapterId,
      contentHash: seed.content.hashCode,
      widthPx: maxWidth.round(),
      fontSizeX100: ((style.fontSize ?? 16.0) * 100).round(),
      lineHeightX100: ((style.height ?? 1.2) * 100).round(),
      letterSpacingX100: ((style.letterSpacing ?? 0.0) * 100).round(),
      fontFamily: style.fontFamily,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      justify: _settings.textFullJustify,
      paragraphIndent: _settings.paragraphIndent,
      paragraphSpacingX100: (_settings.paragraphSpacing * 100).round(),
    );
  }

  ScrollTextLayout _resolveScrollTextLayout({
    required _ScrollSegmentSeed seed,
    required double maxWidth,
    required TextStyle style,
  }) {
    return _scrollTextLayoutEngine.compose(
      key: _scrollLayoutKeyFor(
        seed: seed,
        maxWidth: maxWidth,
        style: style,
      ),
      content: seed.content,
      style: style,
      maxWidth: maxWidth,
      justify: _settings.textFullJustify,
      paragraphIndent: _settings.paragraphIndent,
      paragraphSpacing: _settings.paragraphSpacing,
    );
  }

  double _estimateScrollSegmentHeight({
    required ScrollTextLayout layout,
    required bool hasTitle,
  }) {
    final titleLineHeight = (_settings.fontSize + _settings.titleSize) *
        ((_scrollParagraphStyle().height ?? 1.2).clamp(1.0, 2.5));
    final titleExtra = hasTitle
        ? (_settings.titleTopSpacing > 0 ? _settings.titleTopSpacing : 20) +
            titleLineHeight +
            (_settings.titleBottomSpacing > 0
                ? _settings.titleBottomSpacing
                : _settings.paragraphSpacing * 1.5)
        : 0.0;
    return _settings.paddingTop +
        _settings.paddingBottom +
        titleExtra +
        layout.bodyHeight +
        24.0;
  }

  Future<_ScrollSegment> _loadScrollSegment(
    int chapterIndex, {
    bool showLoading = false,
  }) async {
    final chapter = _chapters[chapterIndex];
    final book = _bookRepo.getBookById(widget.bookId);
    String content = chapter.content ?? '';

    final chapterUrl = (chapter.url ?? '').trim();
    final canFetchFromSource = chapterUrl.isNotEmpty &&
        (book == null || !book.isLocal) &&
        _resolveActiveSourceUrl(book).isNotEmpty;
    if (content.isEmpty && canFetchFromSource) {
      content = await _fetchChapterContent(
        chapter: chapter,
        index: chapterIndex,
        book: book,
        showLoading: showLoading,
      );
    }

    final stage = await _computeReplaceStage(
      chapterId: chapter.id,
      rawTitle: chapter.title,
      rawContent: content,
    );
    final resolved = _resolveChapterSnapshotFromBase(
      chapter: chapter,
      baseTitle: stage.title,
      baseContent: stage.content,
    );
    final seed = _ScrollSegmentSeed(
      chapterId: chapter.id,
      title: resolved.title,
      content: resolved.content,
    );
    final paragraphStyle = _scrollParagraphStyle();
    final bodyWidth = _scrollBodyWidth();
    final layout = _resolveScrollTextLayout(
      seed: seed,
      maxWidth: bodyWidth,
      style: paragraphStyle,
    );

    return _ScrollSegment(
      chapterIndex: chapterIndex,
      chapterId: seed.chapterId,
      title: seed.title,
      content: seed.content,
      estimatedHeight: _estimateScrollSegmentHeight(
        layout: layout,
        hasTitle: _settings.titleMode != 2,
      ),
    );
  }

  Future<void> _initializeScrollSegments({
    required int centerIndex,
    required bool restoreOffset,
    required bool goToLastPage,
    double? targetChapterProgress,
  }) async {
    final readableChapterCount = _effectiveReadableChapterCount();
    if (readableChapterCount <= 0) return;
    final maxReadableIndex = readableChapterCount - 1;
    final safeCenterIndex = centerIndex.clamp(0, maxReadableIndex).toInt();
    final start = (safeCenterIndex - 1).clamp(0, maxReadableIndex);
    final end = (safeCenterIndex + 1).clamp(0, maxReadableIndex);
    final segments = <_ScrollSegment>[];
    for (var i = start; i <= end; i++) {
      segments.add(
        await _loadScrollSegment(
          i,
          showLoading: i == safeCenterIndex,
        ),
      );
    }
    if (!mounted) return;
    final centerSegment = segments.firstWhere(
      (segment) => segment.chapterIndex == safeCenterIndex,
      orElse: () => segments.first,
    );

    setState(() {
      _scrollSegments
        ..clear()
        ..addAll(segments);
      _currentChapterIndex = centerSegment.chapterIndex;
      _currentTitle = centerSegment.title;
      _currentContent = centerSegment.content;
      _currentScrollChapterProgress = 0.0;
      _invalidateScrollLayoutSnapshot();
    });

    final savedProgress = _settingsService.getChapterPageProgress(
      widget.bookId,
      chapterIndex: safeCenterIndex,
    );
    final preferredProgress = targetChapterProgress ??
        (restoreOffset ? savedProgress : (goToLastPage ? null : 0.0));

    _pendingScrollTargetChapterIndex = safeCenterIndex;
    _pendingScrollTargetChapterProgress =
        preferredProgress?.clamp(0.0, 1.0).toDouble();
    _pendingScrollJumpToEnd = goToLastPage;
    _pendingScrollJumpRetry = 0;
    _scheduleApplyPendingScrollTarget();
  }

  void _scheduleApplyPendingScrollTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPendingScrollTarget();
    });
  }

  void _applyPendingScrollTarget() {
    final targetChapterIndex = _pendingScrollTargetChapterIndex;
    if (targetChapterIndex == null) return;
    if (!_scrollController.hasClients) {
      if (_pendingScrollJumpRetry++ < 8) {
        _scheduleApplyPendingScrollTarget();
      }
      return;
    }

    final targetContext =
        _scrollSegmentKeyFor(targetChapterIndex).currentContext;
    if (targetContext == null) {
      if (_pendingScrollJumpRetry++ < 8) {
        _scheduleApplyPendingScrollTarget();
      }
      return;
    }

    final progress =
        (_pendingScrollTargetChapterProgress ?? 0.0).clamp(0.0, 1.0).toDouble();
    final jumpToEnd = _pendingScrollJumpToEnd;

    if (jumpToEnd) {
      Scrollable.ensureVisible(
        targetContext,
        duration: Duration.zero,
        alignment: 1.0,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } else {
      Scrollable.ensureVisible(
        targetContext,
        duration: Duration.zero,
        alignment: 0.0,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      if (progress > 0) {
        final renderObject = targetContext.findRenderObject();
        if (renderObject is RenderBox) {
          final viewport = _scrollController.position.viewportDimension;
          final movable =
              (renderObject.size.height - viewport).clamp(0.0, double.infinity);
          if (movable > 0) {
            final target = (_scrollController.offset + movable * progress)
                .clamp(
                  _scrollController.position.minScrollExtent,
                  _scrollController.position.maxScrollExtent,
                )
                .toDouble();
            _scrollController.jumpTo(target);
          }
        }
      }
    }

    _pendingScrollTargetChapterIndex = null;
    _pendingScrollTargetChapterProgress = null;
    _pendingScrollJumpToEnd = false;
    _pendingScrollJumpRetry = 0;
    _refreshScrollSegmentHeights();
    _syncCurrentChapterFromScroll(saveProgress: true);
  }

  void _refreshScrollSegmentHeights() {
    for (final segment in _scrollSegments) {
      final context = _scrollSegmentKeyFor(segment.chapterIndex).currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        _scrollSegmentHeights[segment.chapterIndex] = renderObject.size.height;
      }
    }
    _rebuildScrollSegmentOffsetRanges();
    _refreshScrollAnchorWithinViewport();
  }

  void _rebuildScrollSegmentOffsetRanges() {
    _scrollSegmentOffsetRanges.clear();
    if (_scrollSegments.isEmpty) return;
    var cursor = 0.0;
    for (final segment in _scrollSegments) {
      final measuredHeight = _scrollSegmentHeights[segment.chapterIndex];
      final fallbackHeight = segment.estimatedHeight > 1.0
          ? segment.estimatedHeight
          : (_scrollController.hasClients
              ? _scrollController.position.viewportDimension
                  .clamp(1.0, double.infinity)
                  .toDouble()
              : 600.0);
      final height = (measuredHeight != null && measuredHeight > 1.0)
          ? measuredHeight
          : fallbackHeight;
      final end = cursor + height;
      _scrollSegmentOffsetRanges.add(
        _ScrollSegmentOffsetRange(
          segment: segment,
          start: cursor,
          end: end,
          height: height,
        ),
      );
      cursor = end;
    }
  }

  void _refreshScrollAnchorWithinViewport() {
    if (!mounted) return;
    final viewportContext = _scrollViewportKey.currentContext;
    final viewportRenderObject = viewportContext?.findRenderObject();
    if (viewportRenderObject is! RenderBox || !viewportRenderObject.hasSize) {
      return;
    }
    final mediaQuery = MediaQuery.of(context);
    final targetGlobalAnchor = _resolveScrollTopSystemInset(mediaQuery) +
        _resolveScrollHeaderSlotHeight() +
        110.0;
    final viewportTop = viewportRenderObject.localToGlobal(Offset.zero).dy;
    final withinViewport = (targetGlobalAnchor - viewportTop)
        .clamp(0.0, viewportRenderObject.size.height)
        .toDouble();
    _scrollAnchorWithinViewport = withinViewport;
  }

  void _handleScrollControllerTick() {
    if (!mounted) return;
    if (_settings.pageTurnMode != PageTurnMode.scroll) return;
    if (!_scrollController.hasClients) return;

    _scheduleScrollPreload();
    if (!_programmaticScrollInFlight && _shouldSyncScrollUiNow()) {
      _syncCurrentChapterFromScroll();
    }
  }

  bool _shouldSyncScrollUiNow() {
    final now = DateTime.now();
    final shouldRun = ScrollRuntimeHelper.shouldRun(
      now: now,
      lastRunAt: _lastScrollUiSyncAt,
      minIntervalMs: _SimpleReaderViewState._scrollUiSyncIntervalMs,
    );
    if (!shouldRun) return false;
    _lastScrollUiSyncAt = now;
    return true;
  }

  bool _shouldCheckScrollPreloadNow() {
    final now = DateTime.now();
    final shouldRun = ScrollRuntimeHelper.shouldRun(
      now: now,
      lastRunAt: _lastScrollPreloadCheckAt,
      minIntervalMs: _SimpleReaderViewState._scrollPreloadIntervalMs,
    );
    if (!shouldRun) return false;
    _lastScrollPreloadCheckAt = now;
    return true;
  }

  void _scheduleScrollPreload() {
    if (!_scrollController.hasClients || !_shouldCheckScrollPreloadNow()) {
      return;
    }
    final metrics = _scrollController.position;
    if (metrics.maxScrollExtent - metrics.pixels <= _SimpleReaderViewState._scrollPreloadExtent) {
      unawaited(_appendNextScrollSegmentIfNeeded());
    }
    if (metrics.pixels - metrics.minScrollExtent <= _SimpleReaderViewState._scrollPreloadExtent) {
      unawaited(_prependPrevScrollSegmentIfNeeded());
    }
  }

  void _syncCurrentChapterFromScroll({bool saveProgress = false}) {
    if (!mounted ||
        !_scrollController.hasClients ||
        _scrollSegments.isEmpty ||
        _syncingScrollVisibleChapter) {
      return;
    }
    _syncingScrollVisibleChapter = true;
    try {
      if (_scrollSegmentOffsetRanges.length != _scrollSegments.length) {
        _rebuildScrollSegmentOffsetRanges();
      }
      if (_scrollSegmentOffsetRanges.isEmpty) return;

      final position = _scrollController.position;
      final anchorOffset =
          (_scrollController.offset + _scrollAnchorWithinViewport)
              .clamp(
                position.minScrollExtent,
                position.maxScrollExtent + position.viewportDimension,
              )
              .toDouble();

      _ScrollSegmentOffsetRange? chosenRange;
      double chosenProgress = _currentScrollChapterProgress;
      double bestDistance = double.infinity;

      for (final range in _scrollSegmentOffsetRanges) {
        if (anchorOffset >= range.start && anchorOffset <= range.end) {
          chosenRange = range;
          chosenProgress = ((anchorOffset - range.start) / range.height)
              .clamp(0.0, 1.0)
              .toDouble();
          break;
        }

        final distance = anchorOffset < range.start
            ? (range.start - anchorOffset)
            : (anchorOffset - range.end);
        if (distance < bestDistance) {
          bestDistance = distance;
          chosenRange = range;
          chosenProgress = ((anchorOffset - range.start) / range.height)
              .clamp(0.0, 1.0)
              .toDouble();
        }
      }

      final chosen = chosenRange?.segment;
      if (chosen == null) return;

      final chapterChanged = chosen.chapterIndex != _currentChapterIndex;
      final progressChanged =
          (chosenProgress - _currentScrollChapterProgress).abs() > 0.02;
      if (!chapterChanged && !progressChanged) return;

      if (chapterChanged || saveProgress) {
        setState(() {
          _currentChapterIndex = chosen.chapterIndex;
          _currentTitle = chosen.title;
          _currentContent = chosen.content;
          _currentScrollChapterProgress = chosenProgress;
        });
      } else {
        _currentScrollChapterProgress = chosenProgress;
      }
      if (chapterChanged) {
        _updateBookmarkStatus();
      }

      if (saveProgress) {
        final now = DateTime.now();
        if (now.difference(_lastScrollProgressSyncAt).inMilliseconds >=
            _SimpleReaderViewState._scrollSaveProgressIntervalMs) {
          _lastScrollProgressSyncAt = now;
          unawaited(_saveProgress());
        }
      }
    } finally {
      _syncingScrollVisibleChapter = false;
    }
  }

  Future<void> _appendNextScrollSegmentIfNeeded() async {
    if (_scrollAppending || _scrollSegments.isEmpty) return;
    final maxReadableIndex = _effectiveReadableMaxChapterIndex();
    if (maxReadableIndex < 0) return;
    final lastIndex = _scrollSegments.last.chapterIndex;
    if (lastIndex >= maxReadableIndex) return;
    _scrollAppending = true;
    try {
      final nextIndex = lastIndex + 1;
      final exists =
          _scrollSegments.any((segment) => segment.chapterIndex == nextIndex);
      if (exists) return;

      final segment = await _loadScrollSegment(nextIndex);
      if (!mounted) return;

      setState(() {
        _scrollSegments.add(segment);
      });
      _schedulePostScrollFlowAdjustments();
    } finally {
      _scrollAppending = false;
    }
  }

  Future<void> _prependPrevScrollSegmentIfNeeded() async {
    if (_scrollPrepending || _scrollSegments.isEmpty) return;
    final firstIndex = _scrollSegments.first.chapterIndex;
    if (firstIndex <= 0) return;
    final hasClients = _scrollController.hasClients;
    final oldOffset = hasClients ? _scrollController.offset : 0.0;
    final oldMax =
        hasClients ? _scrollController.position.maxScrollExtent : 0.0;

    _scrollPrepending = true;
    try {
      final prevIndex = firstIndex - 1;
      final exists =
          _scrollSegments.any((segment) => segment.chapterIndex == prevIndex);
      if (exists) return;

      final segment = await _loadScrollSegment(prevIndex);
      if (!mounted) return;

      setState(() {
        _scrollSegments.insert(0, segment);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final newMax = _scrollController.position.maxScrollExtent;
        final delta = (newMax - oldMax).clamp(0.0, double.infinity).toDouble();
        final target = (oldOffset + delta)
            .clamp(
              _scrollController.position.minScrollExtent,
              _scrollController.position.maxScrollExtent,
            )
            .toDouble();
        _scrollController.jumpTo(target);
        _schedulePostScrollFlowAdjustments();
      });
    } finally {
      _scrollPrepending = false;
    }
  }

  void _schedulePostScrollFlowAdjustments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshScrollSegmentHeights();
      _trimScrollSegmentsWindow();
      _syncCurrentChapterFromScroll(saveProgress: true);
    });
  }

  void _trimScrollSegmentsWindow() {
    if (_scrollSegments.length <= 9) return;
    if (!_scrollController.hasClients) return;
    var changed = false;
    while (_scrollSegments.length > 9) {
      final first = _scrollSegments.first.chapterIndex;
      final last = _scrollSegments.last.chapterIndex;
      final removeFromStart =
          (_currentChapterIndex - first) > (last - _currentChapterIndex);
      if (removeFromStart) {
        final removed = _scrollSegments.removeAt(0);
        final removedHeight =
            _scrollSegmentHeights.remove(removed.chapterIndex) ?? 0.0;
        _scrollSegmentKeys.remove(removed.chapterIndex);
        if (removedHeight > 0 && _scrollController.hasClients) {
          final target = (_scrollController.offset - removedHeight)
              .clamp(
                _scrollController.position.minScrollExtent,
                _scrollController.position.maxScrollExtent,
              )
              .toDouble();
          _scrollController.jumpTo(target);
        }
      } else {
        final removed = _scrollSegments.removeLast();
        _scrollSegmentHeights.remove(removed.chapterIndex);
        _scrollSegmentKeys.remove(removed.chapterIndex);
      }
      changed = true;
    }
    if (changed && mounted) {
      _rebuildScrollSegmentOffsetRanges();
      setState(() {});
    }
  }

  Future<void> _loadChapter(int index,
      {bool restoreOffset = false,
      bool goToLastPage = false,
      double? targetChapterProgress}) async {
    final readableChapterCount = _effectiveReadableChapterCount();
    if (index < 0 || index >= readableChapterCount) return;
    final deferFarChapterTransforms = _shouldDeferFarChapterTransforms();

    if (_settings.pageTurnMode == PageTurnMode.scroll) {
      _isRestoringProgress = restoreOffset;
      try {
        await _initializeScrollSegments(
          centerIndex: index,
          restoreOffset: restoreOffset,
          goToLastPage: goToLastPage,
          targetChapterProgress: targetChapterProgress,
        );
        if (!mounted) return;
        _updateBookmarkStatus();
        _syncPageFactoryChapters(
          centerIndex: index,
          preferCachedForFarChapters: deferFarChapterTransforms,
        );
        _syncReadAloudChapterContext();
        unawaited(_prefetchNeighborChapters(centerIndex: index));
      } finally {
        _isRestoringProgress = false;
      }
      if (!restoreOffset) {
        await _saveProgress();
      }
      return;
    }

    final book = _bookRepo.getBookById(widget.bookId);
    final chapter = _chapters[index];
    String content = chapter.content ?? '';

    final chapterUrl = (chapter.url ?? '').trim();
    final canFetchFromSource = chapterUrl.isNotEmpty &&
        (book == null || !book.isLocal) &&
        _resolveActiveSourceUrl(book).isNotEmpty;

    if (content.isEmpty && canFetchFromSource) {
      content = await _fetchChapterContent(
        chapter: chapter,
        index: index,
        book: book,
      );
    }

    final stage = await _computeReplaceStage(
      chapterId: chapter.id,
      rawTitle: chapter.title,
      rawContent: content,
    );
    final resolved = _resolveChapterSnapshotFromBase(
      chapter: chapter,
      baseTitle: stage.title,
      baseContent: stage.content,
    );
    final warmupFuture = _settings.pageTurnMode == PageTurnMode.scroll
        ? Future<bool>.value(false)
        : _warmupPagedImageSizeCache(
            resolved.content,
            maxProbeCount: _SimpleReaderViewState._chapterLoadImageWarmupMaxProbeCount,
            maxDuration: _SimpleReaderViewState._chapterLoadImageWarmupMaxDuration,
          );
    setState(() {
      _currentChapterIndex = index;
      _currentTitle = resolved.title;
      _currentContent = resolved.content;
      _invalidateScrollLayoutSnapshot();
    });
    _cacheCurrentChapterImageMetasFromSnapshot(resolved);
    _updateBookmarkStatus();
    _syncReadAloudChapterContext();

    _syncPageFactoryChapters(
      centerIndex: index,
      preferCachedForFarChapters: deferFarChapterTransforms,
    );
    unawaited(_prefetchNeighborChapters(centerIndex: index));

    // 如果是非滚动模式，需要在build后进行分页
    _isRestoringProgress = restoreOffset;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var shouldPaginate = _settings.pageTurnMode != PageTurnMode.scroll;
      if (shouldPaginate) {
        await warmupFuture;
        if (!mounted) {
          return;
        }
        shouldPaginate = _settings.pageTurnMode != PageTurnMode.scroll;
      }

      if (shouldPaginate) {
        _paginateContent();

        // 使用PageFactory跳转章节（自动处理goToLastPage）
        _pageFactory.jumpToChapter(index, goToLastPage: goToLastPage);

        if ((restoreOffset || targetChapterProgress != null) && !goToLastPage) {
          final desiredChapterProgress = targetChapterProgress ??
              _settingsService.getChapterPageProgress(
                widget.bookId,
                chapterIndex: index,
              );
          final totalPages = _pageFactory.totalPages;
          if (totalPages > 0) {
            final targetPage = ChapterProgressUtils.pageIndexFromProgress(
              progress: desiredChapterProgress,
              totalPages: totalPages,
            );
            if (targetPage != _pageFactory.currentPageIndex) {
              _pageFactory.jumpToPage(targetPage);
            }
          }
        }
      }

      _isRestoringProgress = false;

      if (_scrollController.hasClients) {
        if (restoreOffset && _settings.pageTurnMode == PageTurnMode.scroll) {
          final savedOffset = _settingsService.getScrollOffset(
            widget.bookId,
            chapterIndex: index,
          );
          if (savedOffset > 0) {
            final max = _scrollController.position.maxScrollExtent;
            final offset = savedOffset.clamp(0.0, max).toDouble();
            _scrollController.jumpTo(offset);
            return;
          }
        }
        // 跳转到最后（从上一章滑动过来时）
        if (goToLastPage && _settings.pageTurnMode == PageTurnMode.scroll) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.jumpTo(0);
        }
      }
    });

    if (!restoreOffset) {
      await _saveProgress();
    }
  }

  void _syncPageFactoryChapters({
    bool keepPosition = false,
    bool preferCachedForFarChapters = false,
    int? centerIndex,
  }) {
    _pruneResolvedChapterCachesIfNeeded();
    final readableChapters = _effectiveReadableChapters();
    if (readableChapters.isEmpty) {
      if (keepPosition) {
        _pageFactory.replaceChaptersKeepingPosition(const <ChapterData>[]);
      } else {
        _pageFactory.setChapters(const <ChapterData>[], 0);
      }
      _hasDeferredChapterTransformRefresh = false;
      return;
    }
    final maxReadableIndex = readableChapters.length - 1;
    final safeCurrentIndex =
        _currentChapterIndex.clamp(0, maxReadableIndex).toInt();
    final center =
        (centerIndex ?? safeCurrentIndex).clamp(0, maxReadableIndex).toInt();
    var deferredFarSnapshotUsed = false;
    final chapterDataList = List<ChapterData>.generate(
      readableChapters.length,
      (index) {
        final chapter = readableChapters[index];
        final isNearChapter = (index - center).abs() <= 1;
        final snapshot = preferCachedForFarChapters && !isNearChapter
            ? () {
                final chapterId = chapter.id;
                final cached = _resolvedChapterSnapshotByChapterId[chapterId];
                if (cached != null) {
                  return cached;
                }
                deferredFarSnapshotUsed = true;
                return _resolveDeferredChapterSnapshot(index);
              }()
            : _resolveChapterSnapshot(index);
        return ChapterData(
          title: snapshot.title,
          content: snapshot.content,
        );
      },
      growable: false,
    );
    if (keepPosition) {
      _pageFactory.replaceChaptersKeepingPosition(chapterDataList);
    } else {
      _pageFactory.setChapters(chapterDataList, safeCurrentIndex);
    }
    if (deferredFarSnapshotUsed) {
      _hasDeferredChapterTransformRefresh = true;
    } else if (!preferCachedForFarChapters) {
      _hasDeferredChapterTransformRefresh = false;
    }
  }

  bool _shouldDeferFarChapterTransforms() {
    if (_effectiveReadableChapterCount() <= 2) return false;
    if (_settings.pageTurnMode == PageTurnMode.scroll) return true;
    return _isCurrentBookLocal();
  }

  _ResolvedChapterSnapshot _resolveDeferredChapterSnapshot(int chapterIndex) {
    final chapter = _chapters[chapterIndex];
    final stage = _replaceStageCache[chapter.id];
    final baseTitle = stage?.title ?? chapter.title;
    final baseContent = stage?.content ?? (chapter.content ?? '');
    return _ResolvedChapterSnapshot(
      chapterId: chapter.id,
      postProcessSignature: _chapterPostProcessSignature(chapter.id),
      baseTitleHash: baseTitle.hashCode,
      baseContentHash: baseContent.hashCode,
      title: _postProcessTitle(baseTitle),
      // 远端章节先复用基础内容，命中章节时再走完整正文后处理。
      content: baseContent,
      isDeferredPlaceholder: true,
    );
  }

  int _chapterPostProcessSignature(String chapterId) {
    final removeSameTitle = _settings.cleanChapterTitle ||
        _isChapterSameTitleRemovalEnabled(chapterId);
    return Object.hashAll(<Object?>[
      removeSameTitle,
      _settings.chineseConverterType,
      _reSegment,
      _delRubyTag,
      _delHTag,
      _settings.pageTurnMode,
      _normalizeLegacyImageStyle(_imageStyle),
    ]);
  }

  _ResolvedChapterSnapshot _resolveChapterSnapshotFromBase({
    required Chapter chapter,
    required String baseTitle,
    required String baseContent,
  }) {
    final signature = _chapterPostProcessSignature(chapter.id);
    final baseTitleHash = baseTitle.hashCode;
    final baseContentHash = baseContent.hashCode;
    final cached = _resolvedChapterSnapshotByChapterId[chapter.id];
    if (cached != null &&
        !cached.isDeferredPlaceholder &&
        cached.postProcessSignature == signature &&
        cached.baseTitleHash == baseTitleHash &&
        cached.baseContentHash == baseContentHash) {
      return cached;
    }

    final snapshot = _ResolvedChapterSnapshot(
      chapterId: chapter.id,
      postProcessSignature: signature,
      baseTitleHash: baseTitleHash,
      baseContentHash: baseContentHash,
      title: _postProcessTitle(baseTitle),
      content: _postProcessContent(
        baseContent,
        baseTitle,
        chapterId: chapter.id,
      ),
    );
    _resolvedChapterSnapshotByChapterId[chapter.id] = snapshot;
    return snapshot;
  }

  void _pruneResolvedChapterCachesIfNeeded() {
    final readableChapters = _effectiveReadableChapters();
    final activeChapterCount = readableChapters.length;
    final shouldPruneResolved =
        _resolvedChapterSnapshotByChapterId.length > activeChapterCount + 8;
    final shouldPruneImageMeta =
        _chapterImageMetaSnapshotByChapterId.length > activeChapterCount + 8;
    if (!shouldPruneResolved && !shouldPruneImageMeta) {
      return;
    }
    final activeChapterIds =
        readableChapters.map((chapter) => chapter.id).toSet();
    if (shouldPruneResolved) {
      _resolvedChapterSnapshotByChapterId.removeWhere(
        (chapterId, _) => !activeChapterIds.contains(chapterId),
      );
    }
    if (shouldPruneImageMeta) {
      _chapterImageMetaSnapshotByChapterId.removeWhere(
        (chapterId, _) => !activeChapterIds.contains(chapterId),
      );
    }
  }

  _ResolvedChapterSnapshot _resolveChapterSnapshot(
    int chapterIndex, {
    bool allowStale = false,
  }) {
    final chapter = _chapters[chapterIndex];
    if (allowStale) {
      final cached = _resolvedChapterSnapshotByChapterId[chapter.id];
      if (cached != null) {
        return cached;
      }
    }
    final stage = _replaceStageCache[chapter.id];
    return _resolveChapterSnapshotFromBase(
      chapter: chapter,
      baseTitle: stage?.title ?? chapter.title,
      baseContent: stage?.content ?? (chapter.content ?? ''),
    );
  }

  bool _isChapterSnapshotFresh(int chapterIndex) {
    final chapter = _chapters[chapterIndex];
    final stage = _replaceStageCache[chapter.id];
    final baseTitle = stage?.title ?? chapter.title;
    final baseContent = stage?.content ?? (chapter.content ?? '');
    final cached = _resolvedChapterSnapshotByChapterId[chapter.id];
    if (cached == null) {
      return false;
    }
    return cached.postProcessSignature ==
            _chapterPostProcessSignature(chapter.id) &&
        cached.baseTitleHash == baseTitle.hashCode &&
        cached.baseContentHash == baseContent.hashCode;
  }

  _ChapterImageMetaSnapshot _resolveChapterImageMetaSnapshot(
    _ResolvedChapterSnapshot snapshot,
  ) {
    final contentHash = snapshot.content.hashCode;
    final cached = _chapterImageMetaSnapshotByChapterId[snapshot.chapterId];
    if (cached != null &&
        cached.postProcessSignature == snapshot.postProcessSignature &&
        cached.contentHash == contentHash) {
      return cached;
    }

    final next = _ChapterImageMetaSnapshot(
      chapterId: snapshot.chapterId,
      postProcessSignature: snapshot.postProcessSignature,
      contentHash: contentHash,
      metas: _collectUniqueImageMarkerMetas(
        snapshot.content,
        maxCount: _SimpleReaderViewState._persistedImageSizeSnapshotMaxEntries,
      ),
    );

    _chapterImageMetaSnapshotByChapterId.remove(snapshot.chapterId);
    _chapterImageMetaSnapshotByChapterId[snapshot.chapterId] = next;
    while (_chapterImageMetaSnapshotByChapterId.length >
        _SimpleReaderViewState._chapterImageMetaSnapshotMaxEntries) {
      _chapterImageMetaSnapshotByChapterId.remove(
        _chapterImageMetaSnapshotByChapterId.keys.first,
      );
    }
    return next;
  }

  void _cacheCurrentChapterImageMetasFromSnapshot(
    _ResolvedChapterSnapshot snapshot,
  ) {
    _chapterImageMetaByCacheKey.clear();
    final metas = _resolveChapterImageMetaSnapshot(snapshot).metas;
    for (final meta in metas) {
      final key = ReaderImageMarkerCodec.normalizeResolvedSizeKey(meta.src);
      if (key.isEmpty) continue;
      _chapterImageMetaByCacheKey[key] = meta;
    }
  }

  void _handlePageFactoryContentChanged() {
    if (!mounted || _chapters.isEmpty) return;
    _screenOffTimerStart();

    final factoryChapterIndex = _pageFactory.currentChapterIndex;
    if (factoryChapterIndex < 0 || factoryChapterIndex >= _chapters.length) {
      return;
    }

    final chapterSnapshotFreshBeforeResolve =
        _isChapterSnapshotFresh(factoryChapterIndex);
    final chapterChanged = factoryChapterIndex != _currentChapterIndex;
    final snapshot = _resolveChapterSnapshot(factoryChapterIndex);
    final chapterPayloadChanged = chapterChanged ||
        _currentTitle != snapshot.title ||
        _currentContent != snapshot.content;
    setState(() {
      _currentChapterIndex = factoryChapterIndex;
      if (chapterPayloadChanged) {
        _currentTitle = snapshot.title;
        _currentContent = snapshot.content;
      }
    });
    if (chapterPayloadChanged) {
      _cacheCurrentChapterImageMetasFromSnapshot(snapshot);
    }
    unawaited(_saveProgress());
    if (chapterChanged) {
      _syncReadAloudChapterContext();
      unawaited(_prefetchNeighborChapters(centerIndex: factoryChapterIndex));
    }

    final shouldRefreshFactoryAroundCurrent =
        _hasDeferredChapterTransformRefresh &&
            !chapterSnapshotFreshBeforeResolve &&
            _settings.pageTurnMode != PageTurnMode.scroll;
    if (shouldRefreshFactoryAroundCurrent) {
      _syncPageFactoryChapters(
        keepPosition: true,
        preferCachedForFarChapters: true,
        centerIndex: factoryChapterIndex,
      );
      _paginateContentLogicOnly();
    }

    if (!chapterChanged) {
      _syncCurrentFactoryChapterLoadingState();
      return;
    }

    final chapter = _chapters[factoryChapterIndex];
    final hasContent = (chapter.content ?? '').trim().isNotEmpty;
    if (hasContent) {
      _syncCurrentFactoryChapterLoadingState();
      return;
    }
    if (_isHydratingChapterFromPageFactory) {
      _pendingHydratingChapterFromPageFactoryIndex = factoryChapterIndex;
      _syncCurrentFactoryChapterLoadingState();
      return;
    }

    unawaited(_hydrateCurrentFactoryChapter(factoryChapterIndex));
  }

  Future<void> _hydrateCurrentFactoryChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    if (_isHydratingChapterFromPageFactory) {
      _pendingHydratingChapterFromPageFactoryIndex = index;
      _syncCurrentFactoryChapterLoadingState();
      return;
    }

    _isHydratingChapterFromPageFactory = true;
    _activeHydratingChapterFromPageFactoryIndex = index;
    _syncCurrentFactoryChapterLoadingState();
    try {
      await _prefetchChapterIfNeeded(index, showLoading: true);
    } finally {
      _isHydratingChapterFromPageFactory = false;
      _activeHydratingChapterFromPageFactoryIndex = null;
      final pendingIndex = _pendingHydratingChapterFromPageFactoryIndex;
      _pendingHydratingChapterFromPageFactoryIndex = null;
      _syncCurrentFactoryChapterLoadingState();
      if (pendingIndex != null &&
          pendingIndex >= 0 &&
          pendingIndex < _chapters.length &&
          pendingIndex != index) {
        unawaited(_hydrateCurrentFactoryChapter(pendingIndex));
      }
    }
  }

  void _syncCurrentFactoryChapterLoadingState() {
    if (!mounted) return;
    if (_settings.pageTurnMode == PageTurnMode.scroll || _chapters.isEmpty) {
      if (_isCurrentFactoryChapterLoading) {
        setState(() {
          _isCurrentFactoryChapterLoading = false;
        });
      }
      return;
    }

    final factoryChapterIndex = _pageFactory.currentChapterIndex;
    if (factoryChapterIndex < 0 || factoryChapterIndex >= _chapters.length) {
      if (_isCurrentFactoryChapterLoading) {
        setState(() {
          _isCurrentFactoryChapterLoading = false;
        });
      }
      return;
    }

    final chapter = _chapters[factoryChapterIndex];
    final chapterContentEmpty = (chapter.content ?? '').trim().isEmpty;
    final nextLoading = chapterContentEmpty &&
        (_chapterContentInFlight.containsKey(chapter.id) ||
            (_isHydratingChapterFromPageFactory &&
                _activeHydratingChapterFromPageFactoryIndex ==
                    factoryChapterIndex) ||
            _pendingHydratingChapterFromPageFactoryIndex ==
                factoryChapterIndex);
    if (_isCurrentFactoryChapterLoading == nextLoading) return;
    setState(() {
      _isCurrentFactoryChapterLoading = nextLoading;
    });
  }

  Future<void> _prefetchNeighborChapters({required int centerIndex}) async {
    final readableChapterCount = _effectiveReadableChapterCount();
    if (centerIndex < 0 || centerIndex >= readableChapterCount) return;

    final tasks = <Future<void>>[];
    final prevIndex = centerIndex - 1;
    if (prevIndex >= 0) {
      tasks.add(_prefetchChapterIfNeeded(prevIndex));
    }
    final nextIndex = centerIndex + 1;
    if (nextIndex < readableChapterCount) {
      tasks.add(_prefetchChapterIfNeeded(nextIndex));
    }
    if (tasks.isEmpty) return;

    await Future.wait(tasks);
  }

  Future<void> _prefetchChapterIfNeeded(
    int index, {
    bool showLoading = false,
  }) async {
    final readableChapterCount = _effectiveReadableChapterCount();
    if (index < 0 || index >= readableChapterCount) return;

    final chapter = _chapters[index];
    var content = chapter.content ?? '';
    var fetchedFromSource = false;

    try {
      if (content.trim().isEmpty) {
        final inFlight = _chapterContentInFlight[chapter.id];
        if (inFlight != null) {
          _syncCurrentFactoryChapterLoadingState();
          if (showLoading) {
            await inFlight;
            _syncCurrentFactoryChapterLoadingState();
          }
          return;
        }

        final book = _bookRepo.getBookById(widget.bookId);
        final chapterUrl = (chapter.url ?? '').trim();
        final canFetchFromSource = chapterUrl.isNotEmpty &&
            (book == null || !book.isLocal) &&
            _resolveActiveSourceUrl(book).isNotEmpty;
        if (!canFetchFromSource) return;

        content = await _fetchChapterContent(
          chapter: chapter,
          index: index,
          book: book,
          showLoading: showLoading,
        );
        fetchedFromSource = true;
      }
      if (content.trim().isEmpty) return;

      final previousStage = _replaceStageCache[chapter.id];
      final stage = await _computeReplaceStage(
        chapterId: chapter.id,
        rawTitle: chapter.title,
        rawContent: content,
      );
      final stageChanged = !identical(previousStage, stage);
      final resolved = _resolveChapterSnapshotFromBase(
        chapter: chapter,
        baseTitle: stage.title,
        baseContent: stage.content,
      );

      await _warmupPagedImageSizeCache(
        resolved.content,
        maxProbeCount: _SimpleReaderViewState._prefetchImageWarmupMaxProbeCount,
        maxDuration: _SimpleReaderViewState._prefetchImageWarmupMaxDuration,
      );

      if (!mounted) return;
      if (fetchedFromSource || stageChanged) {
        _syncPageFactoryChapters(keepPosition: true);
        if (_settings.pageTurnMode != PageTurnMode.scroll) {
          _paginateContentLogicOnly();
        }
      }
    } catch (_) {
      // 预加载失败不影响当前阅读流程。
    }
  }

  Future<String> _fetchChapterContent({
    required Chapter chapter,
    required int index,
    Book? book,
    bool showLoading = true,
  }) async {
    final inFlight = _chapterContentInFlight[chapter.id];
    if (inFlight != null) {
      return inFlight;
    }
    final task = _fetchChapterContentInternal(
      chapter: chapter,
      index: index,
      book: book,
      showLoading: showLoading,
    );
    _chapterContentInFlight[chapter.id] = task;
    _syncCurrentFactoryChapterLoadingState();
    try {
      return await task;
    } finally {
      if (identical(_chapterContentInFlight[chapter.id], task)) {
        _chapterContentInFlight.remove(chapter.id);
      }
      _syncCurrentFactoryChapterLoadingState();
    }
  }

  Future<String> _fetchChapterContentInternal({
    required Chapter chapter,
    required int index,
    Book? book,
    bool showLoading = true,
  }) async {
    final sourceUrl = _resolveActiveSourceUrl(book);
    if (sourceUrl.isEmpty) {
      return chapter.content ?? '';
    }
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) return chapter.content ?? '';

    if (_currentSourceUrl != source.bookSourceUrl) {
      _readerImageCookieHeaderByHost.clear();
      _readerImageCookieLoadInFlight.clear();
    }
    _currentSourceUrl = source.bookSourceUrl;
    _currentSourceName = source.bookSourceName;

    if (showLoading && mounted) {
      setState(() => _isLoadingChapter = true);
    }

    String content = chapter.content ?? '';
    final stopwatch = Stopwatch()..start();
    try {
      final nextChapterUrl = (index + 1 < _chapters.length)
          ? (_chapters[index + 1].url ?? '')
          : null;
      content = await _ruleEngine.getContent(
        source,
        chapter.url ?? '',
        nextChapterUrl: nextChapterUrl,
      );
      if (content.isNotEmpty) {
        await _chapterRepo.cacheChapterContent(chapter.id, content);
        _chapters[index] =
            chapter.copyWith(content: content, isDownloaded: true);
      }
    } finally {
      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds > 0) {
        _recentChapterFetchDuration = stopwatch.elapsed;
      }
      if (showLoading && mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }

    return content;
  }

  String _resolveActiveSourceUrl(Book? book) {
    final fromBook = (book?.sourceUrl ?? book?.sourceId ?? '').trim();
    if (fromBook.isNotEmpty) return fromBook;
    final fromSession = (widget.effectiveSourceUrl ?? '').trim();
    if (fromSession.isNotEmpty) return fromSession;
    return (_currentSourceUrl ?? '').trim();
  }

}
