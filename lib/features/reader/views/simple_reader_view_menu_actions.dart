// ignore_for_file: invalid_use_of_protected_member
part of 'simple_reader_view.dart';

extension _SimpleReaderMenuActions on _SimpleReaderViewState {
  Future<void> _showChangeSourceEntryActions() async {
    final selected =
        await showCupertinoBottomDialog<ReaderLegacyChangeSourceMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('换源'),
        actions: ReaderLegacyMenuHelper.buildChangeSourceMenuActions()
            .map(
              (action) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, action),
                child:
                    Text(ReaderLegacyMenuHelper.changeSourceMenuLabel(action)),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    switch (selected) {
      case ReaderLegacyChangeSourceMenuAction.chapter:
        await _showSwitchSourceChapterMenu();
        return;
      case ReaderLegacyChangeSourceMenuAction.book:
        await _showSwitchSourceBookMenu();
        return;
    }
  }

  Future<void> _handleTopMenuChangeSourceTap() async {
    _closeReaderMenuOverlay();
    await _showSwitchSourceBookMenu();
  }

  Future<void> _handleTopMenuChangeSourceLongPress() async {
    _closeReaderMenuOverlay();
    await _showChangeSourceEntryActions();
  }

  Future<void> _handleTopMenuRefreshTap() async {
    _closeReaderMenuOverlay();
    await _runLegacyDefaultRefreshAction();
  }

  Future<void> _handleTopMenuRefreshLongPress() async {
    _closeReaderMenuOverlay();
    await _showRefreshEntryActions();
  }

  Future<void> _handleTopMenuOfflineCacheTap() async {
    _closeReaderMenuOverlay();
    await _showOfflineCacheDialogFromMenu();
  }

  Future<void> _handleTopMenuTocRuleTap() async {
    _closeReaderMenuOverlay();
    await _showTxtTocRuleDialogFromMenu();
  }

  Future<void> _handleTopMenuSetCharsetTap() async {
    _closeReaderMenuOverlay();
    await _showCharsetConfigFromMenu();
  }

  Future<void> _showOfflineCacheDialogFromMenu() async {
    if (_offlineCacheRunning) {
      _showToast('离线缓存进行中，请稍候');
      return;
    }
    if (_isCurrentBookLocal()) {
      return;
    }
    if (_chapters.isEmpty) {
      _showToast('当前目录为空，无法离线缓存');
      return;
    }

    final input = await _showOfflineCacheRangeInputDialog();
    if (input == null) return;

    final range = _resolveOfflineCacheRange(
      startText: input.startChapter,
      endText: input.endChapter,
      totalChapters: _chapters.length,
    );
    if (range == null) {
      _showToast('章节范围输入无效');
      return;
    }
    if (range.endIndex < range.startIndex) {
      _showToast('离线缓存范围为空');
      return;
    }

    await _cacheChapterRangeFromMenu(range: range);
  }

  Future<_ReaderOfflineCacheInput?> _showOfflineCacheRangeInputDialog() async {
    final totalChapters = _chapters.length;
    if (totalChapters <= 0) return null;
    final defaultStartChapter =
        (_currentChapterIndex + 1).clamp(1, totalChapters).toInt();
    final startController = TextEditingController(
      text: defaultStartChapter.toString(),
    );
    final endController = TextEditingController(
      text: totalChapters.toString(),
    );
    try {
      return await showCupertinoBottomDialog<_ReaderOfflineCacheInput>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('离线缓存'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '缓存章节范围（1-$totalChapters）',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: startController,
                  placeholder: '开始章节',
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: false,
                  ),
                  clearButtonMode: OverlayVisibilityMode.editing,
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: endController,
                  placeholder: '结束章节',
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: false,
                  ),
                  clearButtonMode: OverlayVisibilityMode.editing,
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  _ReaderOfflineCacheInput(
                    startChapter: startController.text,
                    endChapter: endController.text,
                  ),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } finally {
      startController.dispose();
      endController.dispose();
    }
  }

  _ReaderOfflineCacheRange? _resolveOfflineCacheRange({
    required String startText,
    required String endText,
    required int totalChapters,
  }) {
    if (totalChapters <= 0) return null;
    final startRaw = startText.trim();
    final endRaw = endText.trim();
    final startInput = startRaw.isEmpty ? 0 : int.tryParse(startRaw);
    if (startInput == null) return null;
    final endInput = endRaw.isEmpty ? totalChapters : int.tryParse(endRaw);
    if (endInput == null) return null;
    final maxIndex = totalChapters - 1;
    final startIndex = (startInput - 1).clamp(0, maxIndex).toInt();
    final endIndex = (endInput - 1).clamp(0, maxIndex).toInt();
    return _ReaderOfflineCacheRange(
      startIndex: startIndex,
      endIndex: endIndex,
    );
  }

  Future<void> _cacheChapterRangeFromMenu({
    required _ReaderOfflineCacheRange range,
  }) async {
    if (_chapters.isEmpty) return;
    final maxIndex = _chapters.length - 1;
    final startIndex = range.startIndex.clamp(0, maxIndex).toInt();
    final endIndex = range.endIndex.clamp(0, maxIndex).toInt();
    final requestedCount =
        endIndex >= startIndex ? endIndex - startIndex + 1 : 0;
    if (requestedCount <= 0) {
      _showToast('离线缓存范围为空');
      return;
    }

    var successCount = 0;
    var skippedCount = 0;
    var failureCount = 0;
    final book = _bookRepo.getBookById(widget.bookId);

    if (mounted) {
      setState(() {
        _offlineCacheRunning = true;
        _isLoadingChapter = true;
      });
    } else {
      _offlineCacheRunning = true;
    }

    try {
      for (var index = startIndex; index <= endIndex; index += 1) {
        final chapter = _chapters[index];
        final cachedContent = (chapter.content ?? '').trim();
        if (chapter.isDownloaded && cachedContent.isNotEmpty) {
          skippedCount += 1;
          continue;
        }
        try {
          final content = await _fetchChapterContent(
            chapter: chapter,
            index: index,
            book: book,
            showLoading: false,
          );
          if (content.trim().isNotEmpty) {
            successCount += 1;
            continue;
          }
          failureCount += 1;
          ExceptionLogService().record(
            node: 'reader.menu.offline_cache.empty_content',
            message: '离线缓存章节正文为空',
            error: 'empty_content',
            context: <String, dynamic>{
              'bookId': widget.bookId,
              'bookTitle': widget.bookTitle,
              'chapterIndex': index,
              'chapterTitle': chapter.title,
              'chapterUrl': chapter.url,
            },
          );
        } catch (error, stackTrace) {
          failureCount += 1;
          ExceptionLogService().record(
            node: 'reader.menu.offline_cache.fetch_failed',
            message: '离线缓存章节失败',
            error: error,
            stackTrace: stackTrace,
            context: <String, dynamic>{
              'bookId': widget.bookId,
              'bookTitle': widget.bookTitle,
              'chapterIndex': index,
              'chapterTitle': chapter.title,
              'chapterUrl': chapter.url,
            },
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _offlineCacheRunning = false;
          _isLoadingChapter = false;
        });
      } else {
        _offlineCacheRunning = false;
      }
    }

    if (!mounted) return;
    _showToast(
      _buildOfflineCacheSummary(
        requestedCount: requestedCount,
        successCount: successCount,
        skippedCount: skippedCount,
        failureCount: failureCount,
      ),
    );
  }

  String _buildOfflineCacheSummary({
    required int requestedCount,
    required int successCount,
    required int skippedCount,
    required int failureCount,
  }) {
    final parts = <String>[
      '新增$successCount章',
      if (skippedCount > 0) '已缓存$skippedCount章',
      if (failureCount > 0) '失败$failureCount章',
    ];
    return '离线缓存完成（共$requestedCount章）：${parts.join('，')}';
  }

  Future<void> _showRefreshEntryActions() async {
    final selected =
        await showCupertinoBottomDialog<ReaderLegacyRefreshMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('刷新'),
        actions: ReaderLegacyMenuHelper.buildRefreshMenuActions()
            .map(
              (action) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, action),
                child: Text(ReaderLegacyMenuHelper.refreshMenuLabel(action)),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    await _executeLegacyRefreshMenuAction(selected);
  }

  Future<void> _executeLegacyRefreshMenuAction(
    ReaderLegacyRefreshMenuAction action,
  ) async {
    if (!_canRefreshChapterContentFromSource()) {
      _refreshChapter();
      return;
    }
    final selection = ReaderRefreshScopeHelper.selectionFromLegacyAction(
      action: action,
      currentChapterIndex: _currentChapterIndex,
    );
    await _refreshChapterContentFromSource(
      startIndex: selection.startIndex,
      clearFollowing: selection.clearFollowing,
    );
  }

  bool _canRefreshChapterContentFromSource() {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book?.isLocal == true) {
      return false;
    }
    final sourceUrl = _resolveActiveSourceUrl(book);
    return sourceUrl.isNotEmpty;
  }

  Future<void> _refreshChapterContentFromSource({
    required int startIndex,
    required bool clearFollowing,
  }) async {
    final result = ReaderRefreshScopeHelper.clearCachedRange(
      chapters: _chapters,
      startIndex: startIndex,
      clearFollowing: clearFollowing,
    );
    if (!result.hasRange) {
      return;
    }

    if (!widget.isEphemeral && result.updates.isNotEmpty) {
      await _chapterRepo.addChapters(result.updates);
    }

    if (!mounted) return;
    setState(() {
      for (var index = result.startIndex;
          index <= result.endIndex;
          index += 1) {
        final oldId = _chapters[index].id;
        _replaceStageCache.remove(oldId);
        _catalogDisplayTitleCacheByChapterId.remove(oldId);
        _chapterContentInFlight.remove(oldId);
      }
      _chapters = result.nextChapters;
    });

    await _loadChapter(
      _clampChapterIndexToReadableRange(_currentChapterIndex),
      restoreOffset: true,
    );
  }

  Future<void> _executeLegacyReadMenuAction(
    ReaderLegacyReadMenuAction action,
  ) async {
    switch (action) {
      case ReaderLegacyReadMenuAction.changeSource:
        await _showSwitchSourceBookMenu();
        return;
      case ReaderLegacyReadMenuAction.refresh:
        await _runLegacyDefaultRefreshAction();
        return;
      case ReaderLegacyReadMenuAction.download:
        await _showOfflineCacheDialogFromMenu();
        return;
      case ReaderLegacyReadMenuAction.tocRule:
        await _showTxtTocRuleDialogFromMenu();
        return;
      case ReaderLegacyReadMenuAction.setCharset:
        await _showCharsetConfigFromMenu();
        return;
      case ReaderLegacyReadMenuAction.addBookmark:
        await _openAddBookmarkDialog();
        return;
      case ReaderLegacyReadMenuAction.editContent:
        await _openContentEditFromMenu();
        return;
      case ReaderLegacyReadMenuAction.pageAnim:
        await _showBookPageAnimConfigFromMenu();
        return;
      case ReaderLegacyReadMenuAction.getProgress:
        await _pullBookProgressFromWebDav();
        return;
      case ReaderLegacyReadMenuAction.coverProgress:
        await _pushBookProgressToWebDav();
        return;
      case ReaderLegacyReadMenuAction.reverseContent:
        await _reverseCurrentChapterContentFromMenu();
        return;
      case ReaderLegacyReadMenuAction.simulatedReading:
        await _openSimulatedReadingFromMenu();
        return;
      case ReaderLegacyReadMenuAction.enableReplace:
        await _toggleReplaceRuleState();
        return;
      case ReaderLegacyReadMenuAction.sameTitleRemoved:
        await _toggleSameTitleRemovedFromMenu();
        return;
      case ReaderLegacyReadMenuAction.reSegment:
        await _toggleReSegmentFromMenu();
        return;
      case ReaderLegacyReadMenuAction.enableReview:
        // legado 当前代码中该入口默认隐藏且事件分支已注释，保持 no-op。
        return;
      case ReaderLegacyReadMenuAction.delRubyTag:
        await _toggleEpubTagCleanupFromMenu(ruby: true);
        return;
      case ReaderLegacyReadMenuAction.delHTag:
        await _toggleEpubTagCleanupFromMenu(ruby: false);
        return;
      case ReaderLegacyReadMenuAction.imageStyle:
        await _openImageStyleFromMenu();
        return;
      case ReaderLegacyReadMenuAction.updateToc:
        final isLocalBook = _isCurrentBookLocal();
        if (mounted) {
          setState(() => _isLoadingChapter = true);
        }
        try {
          await _refreshCatalogFromSource();
        } catch (e, stackTrace) {
          ExceptionLogService().record(
            node: 'reader.menu.update_toc.failed',
            message: '阅读页更新目录失败',
            error: e,
            stackTrace: stackTrace,
            context: <String, dynamic>{
              'bookId': widget.bookId,
              'bookTitle': widget.bookTitle,
              'isLocalBook': isLocalBook,
              'currentSourceUrl': _currentSourceUrl,
            },
          );
          if (!mounted) return;
          _showToast(
            _legacyUpdateTocErrorMessage(
              isLocalBook: isLocalBook,
              error: e,
            ),
          );
        } finally {
          if (mounted) {
            setState(() => _isLoadingChapter = false);
          }
        }
        return;
      case ReaderLegacyReadMenuAction.effectiveReplaces:
        await _openEffectiveReplacesFromMenu();
        return;
      case ReaderLegacyReadMenuAction.log:
        await showAppLogDialog(context);
        return;
      case ReaderLegacyReadMenuAction.help:
        await _openReadMenuHelpFromMenu();
        return;
    }
  }

  Future<void> _openReadMenuHelpFromMenu() async {
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/readMenuHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!mounted) return;
      await showCupertinoBottomDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('帮助'),
          content: Text('帮助文档加载失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _runLegacyDefaultRefreshAction() async {
    await _executeLegacyRefreshMenuAction(
      ReaderLegacyMenuHelper.defaultRefreshAction(),
    );
  }

  BookSource? _resolveCurrentSource() {
    final sourceUrl = (_currentSourceUrl ?? '').trim();
    if (sourceUrl.isEmpty) return null;
    return _sourceRepo.getSourceByUrl(sourceUrl);
  }

  String _resolvedCurrentChapterUrlForTopMenu() {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return '';
    }
    final chapter = _chapters[_currentChapterIndex];
    final source = _resolveCurrentSource();
    final bookUrl = _bookRepo.getBookById(widget.bookId)?.bookUrl;
    return ReaderTopBarActionHelper.resolveChapterUrl(
      chapterUrl: chapter.url,
      bookUrl: bookUrl,
      sourceUrl: source?.bookSourceUrl ?? _currentSourceUrl,
    );
  }

  Future<void> _openBookInfoFromTopMenu() async {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null) {
      _showToast('当前会话未关联书架书籍，无法打开书籍详情');
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    if (!mounted) return;
    _refreshCurrentSourceName();
    setState(() {});
  }

  Future<void> _openChapterLinkFromTopMenu() async {
    if (_isCurrentBookLocal()) {
      _showToast('本地书籍不支持打开章节链接');
      return;
    }

    final chapterUrl = _resolvedCurrentChapterUrlForTopMenu();
    if (chapterUrl.isEmpty) {
      _showToast('当前章节链接为空');
      return;
    }
    if (!ReaderTopBarActionHelper.isHttpUrl(chapterUrl)) {
      _showToast('当前章节链接不是有效网页地址');
      return;
    }
    final uri = Uri.tryParse(chapterUrl);
    if (uri == null) {
      _showToast('当前章节链接不是有效网页地址');
      return;
    }

    if (_settingsService.readerChapterUrlOpenInBrowser) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showToast('打开浏览器失败');
      }
      return;
    }

    final source = _resolveCurrentSource();
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(
          initialUrl: chapterUrl,
          sourceOrigin: source?.bookSourceUrl ?? (_currentSourceUrl ?? ''),
          sourceName: source?.bookSourceName ?? '',
        ),
      ),
    );
  }

  Future<void> _toggleChapterLinkOpenModeFromTopMenu() async {
    if (_isCurrentBookLocal()) {
      _showToast('本地书籍不支持章节链接打开');
      return;
    }

    final currentOpenInBrowser = _settingsService.readerChapterUrlOpenInBrowser;
    final nextOpenInBrowser = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('章节链接打开方式'),
        content: Text(
          '\n当前：${currentOpenInBrowser ? '浏览器打开' : '应用内网页打开'}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('应用内网页打开'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('浏览器打开'),
          ),
        ],
      ),
    );
    if (nextOpenInBrowser == null ||
        nextOpenInBrowser == currentOpenInBrowser) {
      return;
    }

    await _settingsService.saveReaderChapterUrlOpenInBrowser(
      nextOpenInBrowser,
    );
    if (!mounted) return;
    _showToast(
      nextOpenInBrowser ? '已切换为浏览器打开章节链接' : '已切换为应用内网页打开章节链接',
    );
  }

  bool? _resolveCurrentChapterIsVip() {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return null;
    }
    final chapterUrl =
        _normalizeChapterUrl(_chapters[_currentChapterIndex].url);
    if (chapterUrl.isEmpty) return null;
    return _chapterVipByUrl[chapterUrl];
  }

  bool? _resolveCurrentChapterIsPay() {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return null;
    }
    final chapterUrl =
        _normalizeChapterUrl(_chapters[_currentChapterIndex].url);
    if (chapterUrl.isEmpty) return null;
    return _chapterPayByUrl[chapterUrl];
  }

  void _cacheChapterPayFlags(List<TocItem> toc) {
    _chapterVipByUrl.clear();
    _chapterPayByUrl.clear();
    for (final item in toc) {
      final url = _normalizeChapterUrl(item.url);
      if (url.isEmpty) continue;
      _chapterVipByUrl[url] = item.isVip;
      _chapterPayByUrl[url] = item.isPay;
    }
  }

  Future<void> _ensureCurrentChapterPayFlags(BookSource source) async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return;
    }
    final chapterUrl =
        _normalizeChapterUrl(_chapters[_currentChapterIndex].url);
    if (chapterUrl.isEmpty) {
      return;
    }
    if (_chapterVipByUrl.containsKey(chapterUrl) &&
        _chapterPayByUrl.containsKey(chapterUrl)) {
      return;
    }

    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || book.isLocal) {
      return;
    }
    final bookUrl = (book.bookUrl ?? '').trim();
    if (bookUrl.isEmpty) {
      return;
    }

    try {
      final detail = await _ruleEngine.getBookInfo(
        source,
        bookUrl,
        clearRuntimeVariables: true,
      );
      final primaryTocUrl =
          detail?.tocUrl.isNotEmpty == true ? detail!.tocUrl : bookUrl;
      final toc = await _ruleEngine.getToc(
        source,
        primaryTocUrl,
        clearRuntimeVariables: false,
      );
      if (toc.isEmpty) {
        return;
      }
      _cacheChapterPayFlags(toc);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.chapter_pay.resolve_flag_failed',
        message: '章节购买入口状态计算失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'sourceUrl': source.bookSourceUrl,
          'chapterUrl': chapterUrl,
        },
      );
    }
  }

  Future<void> _showSourceActionsMenu() async {
    _closeReaderMenuOverlay();
    if (_isCurrentBookLocal()) {
      _showToast('本地书籍不支持书源操作');
      return;
    }

    final source = _resolveCurrentSource();
    if (source == null) {
      _showToast('未找到当前书源');
      return;
    }

    await _ensureCurrentChapterPayFlags(source);

    final hasLogin = ReaderSourceActionHelper.hasLoginUrl(source.loginUrl);
    final showChapterPay = ReaderSourceActionHelper.shouldShowChapterPay(
      hasLoginUrl: hasLogin,
      currentChapterIsVip: _resolveCurrentChapterIsVip(),
      currentChapterIsPay: _resolveCurrentChapterIsPay(),
    );

    await showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        message: Text(source.bookSourceUrl),
        actions: [
          if (hasLogin)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _openSourceLoginFromReader(source.bookSourceUrl);
              },
              child: const Text('登录'),
            ),
          if (showChapterPay)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _triggerChapterPayAction(source.bookSourceUrl);
              },
              child: const Text('章节购买'),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _openSourceEditorFromReader(source.bookSourceUrl);
            },
            child: const Text('编辑书源'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _disableSourceFromReader(source.bookSourceUrl);
            },
            child: const Text('禁用书源'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _openSourceLoginFromReader(String sourceUrl) async {
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) {
      _showToast('未找到书源');
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
      _showToast('当前书源未配置登录地址');
      return;
    }
    final uri = Uri.tryParse(resolvedUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      _showToast('登录地址不是有效网页地址');
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

  Future<void> _triggerChapterPayAction(String sourceUrl) async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      _showToast('no chapter');
      return;
    }
    final chapterIndex = _currentChapterIndex;
    final chapter = _chapters[chapterIndex];
    final chapterIsVip = _resolveCurrentChapterIsVip();
    final chapterIsPay = _resolveCurrentChapterIsPay();

    final confirmed = await showCupertinoBottomDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('章节购买'),
            content: Text(chapter.title),
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

    try {
      final source = _sourceRepo.getSourceByUrl(sourceUrl);
      if (source == null) {
        throw StateError('no book source');
      }
      final payAction = (source.ruleContent?.payAction ?? '').trim();
      if (payAction.isEmpty) {
        throw StateError('no pay action');
      }

      final output = _evaluateChapterPayAction(
        source: source,
        chapter: chapter,
        chapterIndex: chapterIndex,
        chapterIsVip: chapterIsVip,
        chapterIsPay: chapterIsPay,
        payAction: payAction,
      );
      if (ReaderSourceActionHelper.isAbsoluteHttpUrl(output)) {
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => SourceWebVerifyView(
              initialUrl: output.trim(),
              sourceOrigin: source.bookSourceUrl,
              sourceName: source.bookSourceName,
            ),
          ),
        );
        return;
      }
      if (!ReaderSourceActionHelper.isLegadoTruthy(output)) {
        return;
      }

      await _refreshCatalogAfterChapterPaySuccess(
        chapterIndex: chapterIndex,
      );
    } catch (error, stackTrace) {
      _recordChapterPayActionError(
        error: error,
        stackTrace: stackTrace,
        sourceUrl: sourceUrl,
        chapterIndex: chapterIndex,
        chapterTitle: chapter.title,
      );
    }
  }

  String _evaluateChapterPayAction({
    required BookSource source,
    required Chapter chapter,
    required int chapterIndex,
    required bool? chapterIsVip,
    required bool? chapterIsPay,
    required String payAction,
  }) {
    final runtime = createJsRuntime();
    final chapterUrl = (chapter.url ?? '').trim();
    final book = _bookRepo.getBookById(widget.bookId);
    final script = '''
      (function() {
        var source = {
          bookSourceUrl: ${jsonEncode(source.bookSourceUrl)},
          bookSourceName: ${jsonEncode(source.bookSourceName)},
          loginUrl: ${jsonEncode(source.loginUrl ?? '')}
        };
        var book = {
          id: ${jsonEncode(widget.bookId)},
          name: ${jsonEncode(widget.bookTitle)},
          author: ${jsonEncode(_bookAuthor)},
          bookUrl: ${jsonEncode((book?.bookUrl ?? '').trim())}
        };
        var chapter = {
          title: ${jsonEncode(chapter.title)},
          url: ${jsonEncode(chapterUrl)},
          index: $chapterIndex,
          isVip: ${jsonEncode(chapterIsVip)},
          isPay: ${jsonEncode(chapterIsPay)}
        };
        var baseUrl = chapter.url || book.bookUrl || source.bookSourceUrl || '';
        var url = baseUrl;
        var result = eval(${jsonEncode(payAction)});
        if (result === undefined || result === null) return '';
        if (typeof result === 'boolean') return result ? 'true' : 'false';
        if (typeof result === 'string') return result;
        try {
          return JSON.stringify(result);
        } catch (e) {
          return String(result);
        }
      })()
    ''';
    return runtime.evaluate(script).trim();
  }

  Future<void> _refreshCatalogAfterChapterPaySuccess({
    required int chapterIndex,
  }) async {
    if (_chapters.isEmpty ||
        chapterIndex < 0 ||
        chapterIndex >= _chapters.length) {
      return;
    }
    final currentChapter = _chapters[chapterIndex];
    final clearedChapter = currentChapter.copyWith(
      content: null,
      isDownloaded: false,
    );
    if (!widget.isEphemeral) {
      await _chapterRepo.addChapters(<Chapter>[clearedChapter]);
    }

    if (mounted) {
      setState(() {
        _replaceStageCache.remove(currentChapter.id);
        _catalogDisplayTitleCacheByChapterId.remove(currentChapter.id);
        _chapterContentInFlight.remove(currentChapter.id);
        _chapters[chapterIndex] = clearedChapter;
      });
    }

    try {
      await _refreshCatalogFromSource();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.chapter_pay.refresh_toc_failed',
        message: '章节购买后刷新目录失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'sourceUrl': _currentSourceUrl,
          'chapterIndex': chapterIndex,
          'chapterTitle': currentChapter.title,
        },
      );
      if (mounted) {
        _showToast(
          _legacyUpdateTocErrorMessage(
            isLocalBook: false,
            error: error,
          ),
        );
      }
      return;
    }

    if (!mounted || _chapters.isEmpty) return;
    final targetIndex = _clampChapterIndexToReadableRange(_currentChapterIndex);
    await _loadChapter(
      targetIndex,
      restoreOffset: _settings.pageTurnMode == PageTurnMode.scroll,
    );
  }

  void _recordChapterPayActionError({
    required Object error,
    required StackTrace stackTrace,
    required String sourceUrl,
    required int chapterIndex,
    required String chapterTitle,
  }) {
    final reason = _normalizeReaderErrorMessage(error);
    ExceptionLogService().record(
      node: 'reader.menu.chapter_pay.failed',
      message: '执行购买操作出错\n$reason',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'bookId': widget.bookId,
        'bookTitle': widget.bookTitle,
        'sourceUrl': sourceUrl,
        'chapterIndex': chapterIndex,
        'chapterTitle': chapterTitle,
      },
    );
  }

  Future<String?> _openSourceEditorFromReader(String sourceUrl) async {
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) {
      _showToast('未找到书源');
      return null;
    }

    final result = await Navigator.of(context).push<String?>(
      CupertinoPageRoute<String?>(
        builder: (_) => SourceEditView.fromSource(
          source,
          rawJson: _sourceRepo.getRawJsonByUrl(source.bookSourceUrl),
        ),
      ),
    );
    if (result == null) return null;
    if (!mounted) return result;
    _refreshCurrentSourceName();
    setState(() {});
    return result;
  }

  Future<void> _openSourceManageFromReader() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => const SourceListView(),
      ),
    );
    if (!mounted) return;
    _refreshCurrentSourceName();
    setState(() {});
  }

  Future<void> _disableSourceFromReader(String sourceUrl) async {
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) {
      _showToast('未找到书源');
      return;
    }
    await _sourceRepo.updateSource(source.copyWith(enabled: false));
    if (!mounted) return;
    _refreshCurrentSourceName();
    setState(() {});
    _showToast('已禁用书源：${source.bookSourceName}');
  }

  Future<void> _deleteSourceByLegacyRule(String sourceUrl) async {
    await _sourceRepo.deleteSource(sourceUrl);
    await SourceVariableStore.removeVariable(sourceUrl);
  }
}
