// ignore_for_file: invalid_use_of_protected_member
part of 'simple_reader_view.dart';

extension _SimpleReaderBuildX on _SimpleReaderViewState {
  Widget _buildReadingContent() {
    // 根据翻页模式选择渲染方式
    if (_settings.pageTurnMode != PageTurnMode.scroll) {
      return _buildPagedContent();
    }

    // 滚动模式
    return _buildScrollContent();
  }

  void _warmUpReadStyleBackgroundDirectoryPath() {
    if (kIsWeb) return;
    unawaited(() async {
      try {
        final directory = await _resolveReadStyleBackgroundDirectory();
        if (!mounted) return;
        if (_readStyleBackgroundDirectoryPath == directory.path) {
          return;
        }
        setState(() {
          _readStyleBackgroundDirectoryPath = directory.path;
        });
      } catch (_) {
        // ignore path lookup failure; reader will gracefully fallback to solid bg
      }
    }());
  }

  Widget _buildReaderBackgroundLayer() {
    final style = _currentReadStyleConfig;
    final baseColor = Color(style.backgroundColor);
    final backgroundImage = _buildReaderBackgroundImage(style);
    if (backgroundImage == null) {
      return ColoredBox(color: baseColor);
    }
    final imageOpacity = style.bgAlpha.clamp(0, 100).toInt() / 100.0;
    if (imageOpacity <= 0) {
      return ColoredBox(color: baseColor);
    }
    return ColoredBox(
      color: baseColor,
      child: Opacity(
        opacity: imageOpacity,
        child: backgroundImage,
      ),
    );
  }

  Widget? _buildReaderBackgroundImage(ReadStyleConfig style) {
    final safeStyle = style.sanitize();
    switch (safeStyle.bgType) {
      case ReadStyleConfig.bgTypeAsset:
        final assetPath = _normalizeBundledReadStyleAssetPath(safeStyle.bgStr);
        if (assetPath == null) {
          return null;
        }
        return Image.asset(
          assetPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => const SizedBox.expand(),
        );
      case ReadStyleConfig.bgTypeFile:
        if (kIsWeb) {
          return null;
        }
        final resolvedPath =
            _resolveReadStyleBackgroundFilePath(safeStyle.bgStr);
        if (resolvedPath == null || resolvedPath.isEmpty) {
          return null;
        }
        return Image.file(
          File(resolvedPath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => const SizedBox.expand(),
        );
      case ReadStyleConfig.bgTypeColor:
      default:
        return null;
    }
  }

  String? _normalizeBundledReadStyleAssetPath(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('assets/bg/')) {
      return normalized;
    }
    if (normalized.startsWith('bg/')) {
      return 'assets/$normalized';
    }
    final name = p.basename(normalized).trim();
    if (name.isEmpty) return null;
    return 'assets/bg/$name';
  }

  String? _resolveReadStyleBackgroundFilePath(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final normalized = value.replaceAll('\\', '/');
    if (p.isAbsolute(normalized)) {
      return normalized;
    }
    final baseName = p.basename(normalized);
    final bgDirectoryPath = _readStyleBackgroundDirectoryPath;
    if (bgDirectoryPath == null || bgDirectoryPath.isEmpty) {
      return normalized;
    }
    return p.join(bgDirectoryPath, baseName);
  }

  Widget _buildBrightnessOverlay() {
    if (_settings.useSystemBrightness) return const SizedBox.shrink();
    // Android/iOS 使用原生亮度调节；仅在 Web/桌面端用遮罩模拟降低亮度。
    if (_brightnessService.supportsNative) return const SizedBox.shrink();
    final opacity = 1.0 - _safeBrightnessValue(_settings.brightness);
    if (opacity <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        color: const Color(0xFF000000).withValues(alpha: opacity),
      ),
    );
  }

  /// 翻页模式内容（对标 Legado ReadView）
  Widget _buildPagedContent() {
    return PagedReaderWidget(
      controller: _pagedReaderController,
      pageFactory: _pageFactory,
      pageTurnMode: _settings.pageTurnMode,
      textStyle: TextStyle(
        fontSize: _settings.fontSize,
        height: _settings.lineHeight,
        color: _currentTheme.text,
        letterSpacing: _settings.letterSpacing,
        fontFamily: _currentFontFamily,
        fontFamilyFallback: _currentFontFamilyFallback,
        fontWeight: _currentFontWeight,
        decoration: _currentTextDecoration,
      ),
      backgroundColor: _readerContentBackgroundColor,
      padding: _contentPadding,
      enableGestures: !_showMenu && !_showSearchMenu, // 菜单显示时禁止翻页手势
      onTap: () {
        if (_showSearchMenu) {
          _setSearchMenuVisible(false);
          return;
        }
        _toggleReaderMenuVisible();
      },
      onTextLongPress: _handlePagedTextLongPress,
      showStatusBar: _settings.showStatusBar,
      settings: _settings,
      legacyImageStyle: _imageStyle,
      paddingDisplayCutouts: _settings.paddingDisplayCutouts,
      bookTitle: widget.bookTitle,
      // 对标 legado：翻页动画时长固定 300ms
      animDuration: ReadingSettings.legacyPageAnimDuration,
      pageDirection: _settings.pageDirection,
      pageTouchSlop: _settings.pageTouchSlop,
      // 菜单/搜索/自动阅读面板打开时隐藏页眉页脚提示，避免与底部菜单层叠。
      showTipBars: !_showMenu && !_showSearchMenu && !_showAutoReadPanel,
      searchHighlightQuery: _activeSearchHighlightQuery,
      searchHighlightColor: _searchHighlightColor,
      searchHighlightTextColor: _searchHighlightTextColor,
      onAction: _handleClickAction,
      clickActions: _clickActions,
      onImageSizeCacheUpdated: _handlePagedImageSizeCacheUpdated,
      onImageSizeResolved: _handlePagedImageSizeResolved,
      onImageTap: _openImagePreview,
    );
  }

  Future<void> _handlePagedTextLongPress(
    PagedReaderLongPressSelection selection,
  ) async {
    final selectedText = _normalizeSelectedTextForTextAction(selection.text);
    if (selectedText.isEmpty) {
      return;
    }

    if (_showSearchMenu) {
      _setSearchMenuVisible(false);
    }
    if (_showMenu) {
      _closeReaderMenuOverlay();
    }

    _contentSelectMenuLongPressHandled = false;
    _contentSelectMenuLongPressResetTimer?.cancel();
    _contentSelectMenuLongPressResetTimer = null;
    await _showTextActionMenu(
      selectedText: selectedText,
      rawSelectedText: selection.text,
    );
    _contentSelectMenuLongPressHandled = false;
    _contentSelectMenuLongPressResetTimer?.cancel();
    _contentSelectMenuLongPressResetTimer = null;
  }

  Future<void> _showTextActionMenu({
    required String selectedText,
    required String rawSelectedText,
  }) async {
    // 对齐 legado：可通过设置项控制“默认展开文本菜单”。
    var expanded = _settings.expandTextMenu;
    while (mounted) {
      final selectedAction =
          await showCupertinoBottomDialog<_ReaderTextActionMenuAction>(
        context: context,
        barrierDismissible: true,
        builder: (sheetContext) => CupertinoActionSheet(
          title: const Text('文本操作'),
          message: Text(_selectedTextActionPreview(selectedText)),
          actions: _buildTextActionMenuActions(
            sheetContext: sheetContext,
            expanded: expanded,
          ),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('取消'),
          ),
        ),
      );

      _contentSelectMenuLongPressHandled = false;
      _contentSelectMenuLongPressResetTimer?.cancel();
      _contentSelectMenuLongPressResetTimer = null;
      if (selectedAction == null) {
        debugPrint('[reader][text-action] menu dismissed');
        return;
      }
      if (selectedAction == _ReaderTextActionMenuAction.more) {
        debugPrint('[reader][text-action] expand more');
        expanded = true;
        continue;
      }
      if (selectedAction == _ReaderTextActionMenuAction.collapse) {
        debugPrint('[reader][text-action] collapse to primary');
        expanded = false;
        continue;
      }
      try {
        await _handleTextActionMenuAction(
          selectedAction,
          selectedText: selectedText,
          rawSelectedText: rawSelectedText,
        );
      } catch (error, stackTrace) {
        ExceptionLogService().record(
          node: 'reader.menu.content_select_action.execute',
          message: '文本操作执行失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'action': _textActionMenuActionName(selectedAction),
            'bookId': widget.bookId,
            'chapterIndex': _currentChapterIndex,
            'textLength': selectedText.length,
          },
        );
        _showToast(_resolveTextActionErrorMessage(error));
      }
      return;
    }
  }

  List<CupertinoActionSheetAction> _buildTextActionMenuActions({
    required BuildContext sheetContext,
    required bool expanded,
  }) {
    final primaryActions = <CupertinoActionSheetAction>[
      _buildTextActionMenuAction(
        sheetContext: sheetContext,
        action: _ReaderTextActionMenuAction.replace,
        label: '替换',
      ),
      _buildTextActionMenuAction(
        sheetContext: sheetContext,
        action: _ReaderTextActionMenuAction.copy,
        label: '复制',
      ),
      _buildTextActionMenuAction(
        sheetContext: sheetContext,
        action: _ReaderTextActionMenuAction.bookmark,
        label: '书签',
      ),
      if (!MigrationExclusions.excludeTts)
        _buildTextActionMenuAction(
          sheetContext: sheetContext,
          action: _ReaderTextActionMenuAction.readAloud,
          label: '朗读',
        ),
      _buildTextActionMenuAction(
        sheetContext: sheetContext,
        action: _ReaderTextActionMenuAction.dict,
        label: '字典',
      ),
    ];
    final alwaysExpanded = _settings.expandTextMenu;
    if (!alwaysExpanded && !expanded) {
      return <CupertinoActionSheetAction>[
        ...primaryActions,
        _buildTextActionMenuAction(
          sheetContext: sheetContext,
          action: _ReaderTextActionMenuAction.more,
          label: '更多',
        ),
      ];
    }

    final expandedActions = <CupertinoActionSheetAction>[
      _buildTextActionMenuAction(
        sheetContext: sheetContext,
        action: _ReaderTextActionMenuAction.searchContent,
        label: '搜索正文',
      ),
      _buildTextActionMenuAction(
        sheetContext: sheetContext,
        action: _ReaderTextActionMenuAction.browser,
        label: '浏览器',
      ),
      _buildTextActionMenuAction(
        sheetContext: sheetContext,
        action: _ReaderTextActionMenuAction.share,
        label: '分享',
      ),
      if (_settingsService.appSettings.processText)
        _buildTextActionMenuAction(
          sheetContext: sheetContext,
          action: _ReaderTextActionMenuAction.processText,
          label: '系统处理文本',
        ),
    ];
    if (alwaysExpanded) {
      return <CupertinoActionSheetAction>[
        ...primaryActions,
        ...expandedActions,
      ];
    }
    return <CupertinoActionSheetAction>[
      ...expandedActions,
      _buildTextActionMenuAction(
        sheetContext: sheetContext,
        action: _ReaderTextActionMenuAction.collapse,
        label: '收起',
      ),
    ];
  }

  CupertinoActionSheetAction _buildTextActionMenuAction({
    required BuildContext sheetContext,
    required _ReaderTextActionMenuAction action,
    required String label,
  }) {
    return CupertinoActionSheetAction(
      onPressed: () {
        if (_contentSelectMenuLongPressHandled) {
          _contentSelectMenuLongPressHandled = false;
          return;
        }
        Navigator.pop(sheetContext, action);
      },
      child: _buildTextActionMenuLabel(label),
    );
  }

  Future<void> _handleTextActionMenuAction(
    _ReaderTextActionMenuAction action, {
    required String selectedText,
    required String rawSelectedText,
  }) async {
    debugPrint(
        '[reader][text-action] selected=${_textActionMenuActionName(action)}');
    switch (action) {
      case _ReaderTextActionMenuAction.replace:
        await _openReplaceRuleEditorFromSelectedText(selectedText);
        return;
      case _ReaderTextActionMenuAction.copy:
        await _copySelectedTextFromMenu(rawSelectedText);
        return;
      case _ReaderTextActionMenuAction.bookmark:
        await _openBookmarkEditorFromSelectedText(selectedText);
        return;
      case _ReaderTextActionMenuAction.readAloud:
        await _handleSelectedTextReadAloud(selectedText);
        return;
      case _ReaderTextActionMenuAction.dict:
        await _openDictDialogFromSelectedText(selectedText);
        return;
      case _ReaderTextActionMenuAction.searchContent:
        await _searchSelectedTextInContent(selectedText);
        return;
      case _ReaderTextActionMenuAction.browser:
        await _openBrowserFromSelectedText(selectedText);
        return;
      case _ReaderTextActionMenuAction.share:
        await _shareSelectedText(selectedText);
        return;
      case _ReaderTextActionMenuAction.processText:
        await _processSelectedTextWithSystem(selectedText);
        return;
      case _ReaderTextActionMenuAction.more:
      case _ReaderTextActionMenuAction.collapse:
        return;
    }
  }

  /// 统一文本操作枚举名称，便于日志与异常记录定位。
  String _textActionMenuActionName(_ReaderTextActionMenuAction action) {
    return switch (action) {
      _ReaderTextActionMenuAction.replace => 'replace',
      _ReaderTextActionMenuAction.copy => 'copy',
      _ReaderTextActionMenuAction.bookmark => 'bookmark',
      _ReaderTextActionMenuAction.readAloud => 'readAloud',
      _ReaderTextActionMenuAction.dict => 'dict',
      _ReaderTextActionMenuAction.searchContent => 'searchContent',
      _ReaderTextActionMenuAction.browser => 'browser',
      _ReaderTextActionMenuAction.share => 'share',
      _ReaderTextActionMenuAction.processText => 'processText',
      _ReaderTextActionMenuAction.more => 'more',
      _ReaderTextActionMenuAction.collapse => 'collapse',
    };
  }

  Widget _buildTextActionMenuLabel(String label) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        _contentSelectMenuLongPressHandled = true;
        _contentSelectMenuLongPressResetTimer?.cancel();
        _contentSelectMenuLongPressResetTimer = Timer(
          const Duration(milliseconds: 260),
          () => _contentSelectMenuLongPressHandled = false,
        );
        _toggleContentSelectSpeakMode();
      },
      child: SizedBox(
        width: double.infinity,
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _normalizeSelectedTextForTextAction(String rawText) {
    final lines = rawText.replaceAll('\r\n', '\n').split('\n');
    return lines.map((line) => line.trim()).join('\n').trim();
  }

  String _selectedTextActionPreview(String selectedText) {
    final preview = selectedText.trim();
    if (preview.isEmpty) {
      return '未选中文本';
    }
    if (preview.length <= 120) {
      return preview;
    }
    return '${preview.substring(0, 120)}...';
  }

  String _buildReplaceScopeFromCurrentContext() {
    final scopes = <String>[];
    final bookName = widget.bookTitle.trim();
    if (bookName.isNotEmpty) {
      scopes.add(bookName);
    }
    final sourceUrl = (_currentSourceUrl ?? '').trim();
    if (sourceUrl.isNotEmpty && !scopes.contains(sourceUrl)) {
      scopes.add(sourceUrl);
    }
    return scopes.join(';');
  }

  int _nextReplaceRuleOrder() {
    var maxOrder = ReplaceRule.unsetOrder;
    for (final rule in _replaceRuleRepo.getAllRules()) {
      if (rule.order > maxOrder) {
        maxOrder = rule.order;
      }
    }
    return maxOrder + 1;
  }

  ReplaceRule _normalizeReplaceRuleForSave(ReplaceRule rule) {
    if (rule.order != ReplaceRule.unsetOrder) {
      return rule;
    }
    return rule.copyWith(order: _nextReplaceRuleOrder());
  }

  Future<void> _openReplaceRuleEditorFromSelectedText(
      String selectedText) async {
    final normalizedText = _normalizeSelectedTextForTextAction(selectedText);
    if (normalizedText.isEmpty) {
      return;
    }

    var saved = false;
    final initialRule = ReplaceRule.create().copyWith(
      pattern: normalizedText,
      scope: _buildReplaceScopeFromCurrentContext(),
      isRegex: false,
    );

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ReplaceRuleEditView(
          initial: initialRule,
          onSave: (rule) async {
            await _replaceRuleRepo.addRule(_normalizeReplaceRuleForSave(rule));
            saved = true;
          },
        ),
      ),
    );

    if (!saved) {
      return;
    }
    if (!mounted) return;

    _replaceStageCache.clear();
    _catalogDisplayTitleCacheByChapterId.clear();
    if (_chapters.isEmpty) return;

    await _loadChapter(
      _clampChapterIndexToReadableRange(_currentChapterIndex),
      restoreOffset: _settings.pageTurnMode == PageTurnMode.scroll,
    );
  }

  Future<void> _handleSelectedTextReadAloud(String selectedText) async {
    final normalizedText = _normalizeSelectedTextForTextAction(selectedText);
    if (normalizedText.isEmpty) {
      return;
    }
    if (MigrationExclusions.excludeTts) {
      await _showReadAloudExcludedHint(entry: 'text_action_menu.read_aloud');
      return;
    }
    if (_contentSelectSpeakMode == 1) {
      await _startReadAloudFromSelectedText(normalizedText);
      return;
    }
    await _speakSelectedTextOnce(normalizedText);
  }

  Future<void> _openDictDialogFromSelectedText(String selectedText) async {
    final normalizedText = _normalizeSelectedTextForTextAction(selectedText);
    if (normalizedText.isEmpty || !mounted) {
      return;
    }
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (_) => ReaderDictLookupSheet(selectedText: normalizedText),
    );
  }

  Future<void> _openBrowserFromSelectedText(String selectedText) async {
    final normalizedText = _normalizeSelectedTextForTextAction(selectedText);
    if (normalizedText.isEmpty) {
      return;
    }
    try {
      final targetUri =
          ReaderSourceActionHelper.isAbsoluteHttpUrl(normalizedText)
              ? Uri.parse(normalizedText)
              : Uri(
                  scheme: 'https',
                  host: 'www.google.com',
                  path: '/search',
                  queryParameters: <String, String>{'q': normalizedText},
                );
      final launched = await launchUrl(
        targetUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showToast('ERROR');
      }
    } catch (error) {
      _showToast(_resolveTextActionErrorMessage(error));
    }
  }

  Future<void> _searchSelectedTextInContent(String selectedText) async {
    final normalizedText = _normalizeSelectedTextForTextAction(selectedText);
    if (normalizedText.isEmpty) {
      return;
    }
    await _applyContentSearch(normalizedText);
  }

  Future<void> _copySelectedTextFromMenu(String selectedText) async {
    if (selectedText.isEmpty) {
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: selectedText));
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.content_select_action.copy.failed',
        message: '复制选中文本失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'chapterIndex': _currentChapterIndex,
          'textLength': selectedText.length,
        },
      );
      return;
    }
    if (!mounted) return;
    _showCopyToast('已拷贝');
  }

  Future<void> _shareSelectedText(String selectedText) async {
    final normalizedText = _normalizeSelectedTextForTextAction(selectedText);
    if (normalizedText.isEmpty) {
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: normalizedText,
          subject: '分享',
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share：分享异常静默吞掉，不追加提示。
    }
  }

  Future<void> _processSelectedTextWithSystem(String selectedText) async {
    final normalizedText = _normalizeSelectedTextForTextAction(selectedText);
    if (normalizedText.isEmpty) {
      return;
    }
    if (!_settingsService.appSettings.processText) {
      _showToast('系统文本处理已关闭');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: normalizedText,
          subject: '系统处理文本',
        ),
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.content_select_action.process_text.failed',
        message: '系统处理文本失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'chapterIndex': _currentChapterIndex,
          'textLength': normalizedText.length,
        },
      );
      _showToast('ERROR');
    }
  }

  String _resolveTextActionErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return 'ERROR';
    }
    if (raw.startsWith('Exception:')) {
      final message = raw.substring('Exception:'.length).trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    return raw;
  }

  void _toggleContentSelectSpeakMode() {
    final nextMode = _contentSelectSpeakMode == 1 ? 0 : 1;
    if (mounted) {
      setState(() {
        _contentSelectSpeakMode = nextMode;
      });
    } else {
      _contentSelectSpeakMode = nextMode;
    }
    unawaited(_settingsService.saveContentSelectSpeakMode(nextMode));
    _showToast(
      nextMode == 1 ? '切换为从选择的地方开始一直朗读' : '切换为朗读选择内容',
    );
  }

  Future<void> _startReadAloudFromSelectedText(String selectedText) async {
    final capability = _detectReadAloudCapability();
    if (!capability.available) {
      _showToast(capability.reason);
      return;
    }

    if (_autoPager.isRunning) {
      _autoPagerPausedByMenu = false;
      _autoPager.stop();
      if (_showAutoReadPanel) {
        setState(() {
          _showAutoReadPanel = false;
        });
      }
    }

    final normalizedSelection = selectedText.trim();
    final selectionStartIndex = _resolveSelectedTextStartIndexInChapterContent(
      normalizedSelection,
    );
    ReadAloudActionResult result;
    if (selectionStartIndex >= 0) {
      result = await _readAloudService.start(
        chapterIndex: _currentChapterIndex,
        chapterTitle: _currentTitle,
        content: _currentContent.substring(selectionStartIndex),
        startParagraphIndex: 0,
      );
    } else {
      final startParagraphIndex =
          _resolveReadAloudStartParagraphIndex(normalizedSelection);
      result = await _readAloudService.start(
        chapterIndex: _currentChapterIndex,
        chapterTitle: _currentTitle,
        content: _currentContent,
        startParagraphIndex: startParagraphIndex,
      );
    }
    if (!mounted || result.success) return;
    _showToast(result.message);
  }

  int _resolveSelectedTextStartIndexInChapterContent(String selectedText) {
    if (selectedText.isEmpty) {
      return -1;
    }
    final content = _currentContent;
    if (content.isEmpty) {
      return -1;
    }
    final matches = <int>[];
    var cursor = 0;
    while (cursor < content.length) {
      final matchIndex = content.indexOf(selectedText, cursor);
      if (matchIndex < 0) break;
      matches.add(matchIndex);
      cursor = matchIndex + 1;
    }
    if (matches.isEmpty) {
      return -1;
    }
    final estimatedOffset =
        (content.length * _getChapterProgress().clamp(0.0, 1.0))
            .round()
            .clamp(0, content.length)
            .toInt();
    matches.sort(
      (a, b) =>
          (a - estimatedOffset).abs().compareTo((b - estimatedOffset).abs()),
    );
    return matches.first;
  }

  int _resolveReadAloudStartParagraphIndex(String selectedText) {
    final paragraphs = _buildReadAloudParagraphs(_currentContent);
    if (paragraphs.isEmpty) {
      return 0;
    }
    final normalizedText = selectedText.trim();
    if (normalizedText.isEmpty) {
      return 0;
    }
    final exactIndex = paragraphs
        .indexWhere((paragraph) => paragraph.contains(normalizedText));
    if (exactIndex >= 0) {
      return exactIndex;
    }
    final compactSelected = normalizedText.replaceAll(RegExp(r'\s+'), '');
    if (compactSelected.isEmpty) {
      return 0;
    }
    final compactIndex = paragraphs.indexWhere(
      (paragraph) =>
          paragraph.replaceAll(RegExp(r'\s+'), '').contains(compactSelected),
    );
    return compactIndex >= 0 ? compactIndex : 0;
  }

  List<String> _buildReadAloudParagraphs(String content) {
    final normalizedContent =
        content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return normalizedContent
        .split('\n')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && _SimpleReaderViewState._readAloudSpeakablePattern.hasMatch(line),
        )
        .toList(growable: false);
  }

  Future<void> _speakSelectedTextOnce(String selectedText) async {
    if (kIsWeb) {
      _showToast('当前平台暂不支持语音朗读');
      return;
    }
    try {
      final tts = await _ensureContentSelectReadAloudTtsReady();
      await tts.stop();
      final result = await tts.speak(selectedText);
      if (!mounted) return;
      if (result != 1) {
        _showToast('启动朗读失败');
      }
    } catch (error) {
      if (!mounted) return;
      _showToast('启动朗读失败：$error');
    }
  }

  Future<FlutterTts> _ensureContentSelectReadAloudTtsReady() async {
    final existing = _contentSelectReadAloudTts;
    if (existing != null && _contentSelectReadAloudTtsReady) {
      return existing;
    }
    final tts = existing ?? FlutterTts();
    _contentSelectReadAloudTts ??= tts;
    if (!_contentSelectReadAloudTtsReady) {
      await tts.awaitSpeakCompletion(true);
      _contentSelectReadAloudTtsReady = true;
    }
    return tts;
  }

  Future<void> _disposeContentSelectReadAloudTts() async {
    final tts = _contentSelectReadAloudTts;
    _contentSelectReadAloudTts = null;
    _contentSelectReadAloudTtsReady = false;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (_) {
      // ignore dispose errors
    }
  }

  /// 滚动模式内容（跨章节连续滚动，对齐 legado）
  Widget _buildScrollContent() {
    final mediaPadding = MediaQuery.paddingOf(context);
    final mediaViewPadding = MediaQuery.viewPaddingOf(context);
    final scrollInsets =
        _resolveScrollContentInsetsFromPadding(mediaPadding, mediaViewPadding);

    return _ScrollContentView(
      config: _ScrollContentConfig(
        fontSize: _settings.fontSize,
        lineHeight: _settings.lineHeight,
        letterSpacing: _settings.letterSpacing,
        paragraphSpacing: _settings.paragraphSpacing,
        paragraphIndent: _settings.paragraphIndent,
        textFullJustify: _settings.textFullJustify,
        textColor: _currentTheme.text,
        fontFamily: _currentFontFamily,
        fontFamilyFallback: _currentFontFamilyFallback,
        fontWeight: _currentFontWeight,
        textDecoration: _currentTextDecoration,
        titleMode: _settings.titleMode,
        titleSize: _settings.titleSize,
        titleTopSpacing: _settings.titleTopSpacing,
        titleBottomSpacing: _settings.titleBottomSpacing,
        titleTextAlign: _titleTextAlign,
        paddingLeft: _settings.paddingLeft,
        paddingRight: _settings.paddingRight,
        paddingTop: _settings.paddingTop,
        paddingBottom: _settings.paddingBottom,
        paddingDisplayCutouts: _settings.paddingDisplayCutouts,
        imageStyle: _normalizeLegacyImageStyle(_imageStyle),
        searchHighlightQuery: _activeSearchHighlightQuery,
        searchHighlightColor: _searchHighlightColor,
        searchHighlightTextColor: _searchHighlightTextColor,
      ),
      scrollInsets: scrollInsets,
      segments: _scrollSegments,
      segmentsVersion: _scrollSegmentsVersion,
      scrollController: _scrollController,
      scrollViewportKey: _scrollViewportKey,
      onScrollStart: _screenOffTimerStart,
      onScrollEnd: () {
        if (!_isRestoringProgress) {
          _syncCurrentChapterFromScroll(saveProgress: true);
          unawaited(_saveProgress());
        }
      },
      resolveScrollTextLayout: _resolveScrollTextLayout,
      resolveSegmentKey: _scrollSegmentKeyFor,
      resolveImageProvider: _resolveReaderImageProvider,
      normalizeImageSrc: _normalizeReaderImageSrc,
    );
  }

  EdgeInsets _resolveScrollContentInsetsFromPadding(
    EdgeInsets padding,
    EdgeInsets viewPadding,
  ) {
    final leftInset =
        _settings.paddingDisplayCutouts ? padding.left : 0.0;
    final rightInset =
        _settings.paddingDisplayCutouts ? padding.right : 0.0;
    final topInset = _settings.showStatusBar
        ? padding.top
        : (_settings.paddingDisplayCutouts ? viewPadding.top : 0.0);
    final bottomInset = _settings.hideNavigationBar
        ? (_settings.paddingDisplayCutouts ? viewPadding.bottom : 0.0)
        : padding.bottom;
    return EdgeInsets.fromLTRB(
      leftInset,
      topInset + _resolveScrollHeaderSlotHeight(),
      rightInset,
      bottomInset + _resolveScrollFooterSlotHeight(),
    );
  }


  String _normalizeReaderImageSrc(String raw) {
    return _readerImageResolver.normalizeSrc(raw);
  }

  ImageProvider<Object>? _resolveReaderImageProvider(String src) {
    final request = ReaderImageRequestParser.parse(src);
    return _resolveReaderImageProviderFromRequest(request);
  }

  ImageProvider<Object>? _resolveReaderImageProviderFromRequest(
    ReaderImageRequest request,
  ) {
    final uri = Uri.tryParse(request.url.trim());
    final headers = _composeReaderImageHeaders(request, uri: uri);
    return _readerImageResolver.resolveProvider(request, headers: headers);
  }

  Map<String, String> _composeReaderImageHeaders(
    ReaderImageRequest request, {
    Uri? uri,
  }) {
    final source = _resolveCurrentSource();
    return _readerImageResolver.composeHeaders(
      request: request,
      sourceHeaderText: source?.header,
      referer: _readerImageReferer(),
      cachedCookieHeaders: _readerImageCookieHeaderByHost,
      uri: uri,
    );
  }

  Future<void> _ensureReaderImageCookieHeaderCached(
    ReaderImageRequest request, {
    Duration timeout = const Duration(milliseconds: 120),
  }) async {
    final source = _resolveCurrentSource();
    if (source == null) return;
    if (source.enabledCookieJar == false) return;

    final uri = Uri.tryParse(request.url);
    if (uri == null || !_isHttpLikeUri(uri)) return;
    final cookieKey = _readerImageCookieCacheKey(uri);
    if (_readerImageCookieHeaderByHost.containsKey(cookieKey)) {
      return;
    }
    if (_readerImageCookieLoadInFlight.contains(cookieKey)) {
      return;
    }

    _readerImageCookieLoadInFlight.add(cookieKey);
    try {
      final future = RuleParserEngine.loadCookiesForUrl(uri.toString());
      final cookies = timeout > Duration.zero
          ? await future.timeout(
              timeout,
              onTimeout: () => const <Cookie>[],
            )
          : await future;
      if (cookies.isEmpty) return;
      final cookieHeader = cookies
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .where((segment) => segment.trim().isNotEmpty)
          .join('; ');
      if (cookieHeader.isEmpty) return;
      _readerImageCookieHeaderByHost[cookieKey] = cookieHeader;
    } catch (_) {
      // 读 Cookie 失败不应阻断阅读主流程。
    } finally {
      _readerImageCookieLoadInFlight.remove(cookieKey);
    }
  }

  String _readerImageCookieCacheKey(Uri uri) {
    return _readerImageResolver.cookieCacheKey(uri);
  }

  String? _readerImageReferer() {
    final chapterUrl =
        (_currentChapterIndex >= 0 && _currentChapterIndex < _chapters.length)
            ? _chapters[_currentChapterIndex].url
            : null;
    return _readerImageResolver.resolveReferer(
      chapterUrl: chapterUrl,
      sourceUrl: _currentSourceUrl,
    );
  }

  bool _isHttpLikeUri(Uri uri) {
    return _readerImageResolver.isHttpLikeUri(uri);
  }

  void _syncScrollSegmentsAfterTransformChange() {
    if (_settings.pageTurnMode != PageTurnMode.scroll ||
        _scrollSegments.isEmpty) {
      return;
    }
    unawaited(
      _loadChapter(
        _currentChapterIndex,
        restoreOffset: false,
        targetChapterProgress: _currentScrollChapterProgress,
      ),
    );
  }

  /// 构建格式化的正文内容（支持段落间距，用于翻页模式）
  void _closeReaderMenuOverlay() {
    if (!_showMenu) return;
    _setReaderMenuVisible(false);
  }

  void _openChapterListFromMenu() {
    _closeReaderMenuOverlay();
    _showChapterList();
  }

  void _openInterfaceSettingsFromMenu() {
    _closeReaderMenuOverlay();
    _showStyleQuickSheet();
  }

  void _openBehaviorSettingsFromMenu() {
    _closeReaderMenuOverlay();
    showReaderMoreConfigSheet(context);
  }

  void _showStyleQuickSheet() {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (context) => ReaderStyleQuickSheet(
        settings: _settings,
        themes: _activeReadStyles,
        onSettingsChanged: (next) {
          if (next.pageTurnMode != _settings.pageTurnMode &&
              _bookPageAnimOverride != null) {
            _bookPageAnimOverride = null;
            if (!widget.isEphemeral) {
              unawaited(
                _settingsService.saveBookPageAnim(widget.bookId, null),
              );
            }
          }
          _updateSettings(next);
        },
        onOpenTipSettings: () {
          Navigator.pop(context);
          unawaited(_openTipSettingsFromReader());
        },
        onOpenPaddingSettings: () {
          unawaited(showReaderPaddingConfigDialog(
            context,
            settings: _settings,
            onSettingsChanged: _updateSettings,
            isDarkMode: CupertinoTheme.of(context).brightness == Brightness.dark,
          ));
        },
        onImportStyle: () {
          Navigator.pop(context);
          unawaited(_importReadStyleFromSheet());
        },
        onExportStyle: () {
          Navigator.pop(context);
          unawaited(_exportCurrentReadStyleFromSheet());
        },
      ),
    );
  }

  Future<void> _importReadStyleFromSheet() async {
    final bgDir = await _resolveReadStyleBackgroundDirectory();
    final service = ReadStyleImportExportService(
      bgDirectoryResolver: () async => bgDir,
    );
    final result = await service.importFromFile();
    if (!mounted) return;
    if (result.cancelled) return;
    if (!result.success || result.style == null) {
      _showToast(result.message ?? '导入失败');
      return;
    }
    final styles = List<ReadStyleConfig>.from(_activeReadStyleConfigs)
      ..add(result.style!.sanitize());
    _updateSettings(_settings.copyWith(readStyleConfigs: styles));
    if (result.warning != null) _showToast(result.warning!);
    else _showToast('主题已导入');
  }

  Future<void> _exportCurrentReadStyleFromSheet() async {
    final configs = _activeReadStyleConfigs;
    final idx = _settings.themeIndex.clamp(0, configs.length - 1);
    final style = configs[idx];
    final bgDir = await _resolveReadStyleBackgroundDirectory();
    final service = ReadStyleImportExportService(
      bgDirectoryResolver: () async => bgDir,
    );
    final result = await service.exportStyle(style);
    if (!mounted) return;
    if (result.cancelled) return;
    if (!result.success) {
      _showToast(result.message ?? '导出失败');
      return;
    }
    _showToast(result.message ?? '主题已导出');
  }

  Future<void> _openTipSettingsFromReader() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ReadingTipSettingsView(),
      ),
    );
  }

  void _openImagePreview(String src) {
    final request = ReaderImageRequestParser.parse(src);
    final imageProvider = const ReaderImageResolver(isWeb: kIsWeb)
        .resolveProvider(request, headers: request.headers);
    if (imageProvider == null) return;
    _autoPager.pause();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ImagePreviewPage(imageProvider: imageProvider),
      ),
    ).then((_) {
      if (_autoPager.isPaused) _autoPager.resume();
    });
  }


  void _openReadAloudFromMenu() {
    _closeReaderMenuOverlay();
    if (MigrationExclusions.excludeTts) {
      unawaited(_showReadAloudExcludedHint(entry: 'bottom_menu.tap'));
      return;
    }
    unawaited(_openReadAloudAction());
  }

  void _openReadAloudDialogFromMenu() {
    _closeReaderMenuOverlay();
    if (MigrationExclusions.excludeTts) {
      unawaited(_showReadAloudExcludedHint(entry: 'bottom_menu.long_press'));
      return;
    }
    unawaited(_showAudioPlayActionsFromMenu());
  }

  Future<void> _showAudioPlayActionsFromMenu() async {
    final source = _resolveCurrentSource();
    final hasLogin =
        source != null && ReaderSourceActionHelper.hasLoginUrl(source.loginUrl);
    final selected =
        await showCupertinoBottomDialog<_ReaderAudioPlayMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('播放'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReaderAudioPlayMenuAction.changeSource,
            ),
            child: const Text('换源'),
          ),
          if (hasLogin)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(
                sheetContext,
                _ReaderAudioPlayMenuAction.login,
              ),
              child: const Text('登录'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReaderAudioPlayMenuAction.copyAudioUrl,
            ),
            child: const Text('拷贝播放 URL'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReaderAudioPlayMenuAction.editSource,
            ),
            child: const Text('编辑书源'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReaderAudioPlayMenuAction.wakeLock,
            ),
            child: Text(
              _audioPlayUseWakeLock ? '✓ 音频服务唤醒锁' : '音频服务唤醒锁',
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReaderAudioPlayMenuAction.log,
            ),
            child: const Text('日志'),
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
      case _ReaderAudioPlayMenuAction.login:
        if (source != null) {
          await _openSourceLoginFromReader(source.bookSourceUrl);
        }
        return;
      case _ReaderAudioPlayMenuAction.changeSource:
        await _showSwitchSourceBookMenu();
        return;
      case _ReaderAudioPlayMenuAction.copyAudioUrl:
        await _copyAudioPlayUrlFromMenu();
        return;
      case _ReaderAudioPlayMenuAction.editSource:
        if (source != null) {
          await _openSourceEditorFromReader(source.bookSourceUrl);
        }
        return;
      case _ReaderAudioPlayMenuAction.wakeLock:
        final next = !_audioPlayUseWakeLock;
        if (mounted) {
          setState(() {
            _audioPlayUseWakeLock = next;
          });
        } else {
          _audioPlayUseWakeLock = next;
        }
        await _settingsService.saveAudioPlayUseWakeLock(next);
        return;
      case _ReaderAudioPlayMenuAction.log:
        await _openAppLogsFromAudioPlayMenu();
        return;
    }
  }

  Future<void> _openAppLogsFromAudioPlayMenu() async {
    await showAppLogDialog(context);
  }

  Future<void> _copyAudioPlayUrlFromMenu() async {
    final playUrl = _resolvedCurrentChapterUrlForTopMenu();
    try {
      await Clipboard.setData(ClipboardData(text: playUrl));
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.audio_play.copy_audio_url.failed',
        message: '复制播放 URL 失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'playUrl': playUrl,
        },
      );
      return;
    }
    if (!mounted) return;
    _showToast('已拷贝');
  }

  void _openAutoReadPanel() {
    if (_showAutoReadPanel) return;
    setState(() {
      _showAutoReadPanel = true;
      _showMenu = false;
      _showSearchMenu = false;
    });
    _syncSystemUiForOverlay();
  }

  void _openReaderMenuFromAutoReadPanel() {
    if (_showMenu && !_showAutoReadPanel) return;
    setState(() => _showAutoReadPanel = false);
    _setReaderMenuVisible(true);
  }

  void _openChapterListFromAutoReadPanel() {
    if (_showAutoReadPanel) {
      setState(() {
        _showAutoReadPanel = false;
      });
    }
    _showChapterList();
    _screenOffTimerStart(force: true);
  }


  ReadingSettings _effectiveSettingsWithBookPageAnim({
    required ReadingSettings base,
    required int? bookPageAnimOverride,
  }) {
    final targetMode = _resolveBookPageTurnMode(
      fallback: base.pageTurnMode,
      bookPageAnimOverride: bookPageAnimOverride,
    );
    if (base.pageTurnMode == targetMode) {
      return base;
    }
    return base.copyWith(pageTurnMode: targetMode);
  }

  ReadingSettings _readSettingsWithExclusions(ReadingSettings settings) {
    var normalized = settings;
    if (!_supportsVolumeKeyPaging) {
      normalized = normalized.copyWith(
        volumeKeyPage: false,
        volumeKeyPageOnPlay: false,
      );
    }
    if (!_supportsCustomPageKeyMapping) {
      normalized = normalized.copyWith(
        prevKeys: const <int>[],
        nextKeys: const <int>[],
      );
    }
    if (!MigrationExclusions.excludeTts) {
      return normalized.sanitize();
    }
    return normalized
        .copyWith(
          clickActions: ClickAction.normalizeConfigForExclusions(
            normalized.clickActions,
            excludeTts: true,
          ),
          volumeKeyPageOnPlay: false,
        )
        .sanitize();
  }

  PageTurnMode _resolveBookPageTurnMode({
    required PageTurnMode fallback,
    required int? bookPageAnimOverride,
  }) {
    if (bookPageAnimOverride == null) return fallback;
    return switch (bookPageAnimOverride) {
      0 => PageTurnMode.cover,
      1 => PageTurnMode.slide,
      2 => PageTurnMode.simulation,
      3 => PageTurnMode.scroll,
      4 => PageTurnMode.none,
      _ => fallback,
    };
  }

  int _legacyBookPageAnimSelection() {
    return _bookPageAnimOverride ?? _SimpleReaderViewState._legacyBookPageAnimDefault;
  }

  Future<void> _showBookPageAnimConfigFromMenu() async {
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '翻页动画',
      currentValue: _legacyBookPageAnimSelection(),
      accentColor: _uiAccent,
      items: _SimpleReaderViewState._legacyBookPageAnimOptions
          .map(
            (item) => OptionPickerItem<int>(
              value: item.key,
              label: item.value,
            ),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    await _applyBookPageAnimFromMenu(selected);
  }

  Future<void> _applyBookPageAnimFromMenu(int selectedValue) async {
    final nextOverride =
        selectedValue == _SimpleReaderViewState._legacyBookPageAnimDefault ? null : selectedValue;
    if (!widget.isEphemeral) {
      await _settingsService.saveBookPageAnim(widget.bookId, nextOverride);
    }
    if (!mounted) return;
    _bookPageAnimOverride = nextOverride;
    final nextSettings = _effectiveSettingsWithBookPageAnim(
      base: _readSettingsWithExclusions(_settingsService.readingSettings),
      bookPageAnimOverride: _bookPageAnimOverride,
    );
    _updateSettings(nextSettings, persist: false);
  }


  Future<void> _openPageAnimConfigFromAutoReadPanel() async {
    _screenOffTimerStart(force: true);
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '翻页动画',
      currentValue: _legacyBookPageAnimSelection(),
      accentColor: _uiAccent,
      items: _SimpleReaderViewState._legacyBookPageAnimOptions
          .map(
            (item) => OptionPickerItem<int>(
              value: item.key,
              label: item.value,
            ),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    await _applyBookPageAnimFromMenu(selected);
    _screenOffTimerStart(force: true);
  }

  void _stopAutoReadFromPanel() {
    _screenOffTimerStart(force: true);
    if (mounted) {
      _showToast('自动阅读已停止');
    }
  }

  void _stopAutoPagerAtBoundary() {
    if (!_autoPager.isRunning && !_autoPager.isPaused) return;
    _autoPagerPausedByMenu = false;
    _autoPager.stop();
    if (!mounted) return;
    if (_showAutoReadPanel) {
      setState(() {
        _showAutoReadPanel = false;
      });
    }
    _showToast('已到最后一页，自动阅读已停止');
  }

  void _handleAutoPagerNextTick() {
    if (!mounted) return;
    if (_settings.pageTurnMode == PageTurnMode.scroll) {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final atBottom =
            _scrollController.offset >= position.maxScrollExtent - 1;
        final hasNextChapter =
            _currentChapterIndex < _effectiveReadableMaxChapterIndex();
        if (atBottom && !hasNextChapter) {
          _stopAutoPagerAtBoundary();
          return;
        }
      }
      unawaited(_scrollPage(up: false));
      return;
    }

    final moved = _pagedReaderController.isAttached
        ? _pagedReaderController.turnNextPage()
        : (_settings.doublePage
            ? _pageFactory.moveToNextDouble()
            : _pageFactory.moveToNext());
    if (!moved) {
      _stopAutoPagerAtBoundary();
    }
  }

  Future<void> _toggleAutoPageFromQuickAction() async {
    _closeReaderMenuOverlay();
    if (!_autoPager.isRunning && !_autoPager.isPaused) {
      if (_readAloudSnapshot.isRunning) {
        await _readAloudService.stop();
        if (!mounted) return;
      }
      _autoPager.start();
      _openAutoReadPanel();
      _showToast('自动阅读已开启');
      _screenOffTimerStart(force: true);
      return;
    }

    _autoPagerPausedByMenu = false;
    _autoPager.stop();
    if (mounted && _showAutoReadPanel) {
      setState(() {
        _showAutoReadPanel = false;
      });
    }
    _showToast('自动阅读已停止');
    _screenOffTimerStart(force: true);
  }

  Future<void> _openReplaceRuleListFromMenu() async {
    _closeReaderMenuOverlay();
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ReplaceRuleListView(),
      ),
    );
    if (!mounted) return;
    _replaceStageCache.clear();
    await _loadChapter(
      _currentChapterIndex,
      restoreOffset: _settings.pageTurnMode == PageTurnMode.scroll,
    );
  }

  Chapter? _resolveCurrentChapterForEffectiveReplaces() {
    if (_chapters.isEmpty) return null;
    if (_currentChapterIndex < 0 || _currentChapterIndex >= _chapters.length) {
      return null;
    }
    return _chapters[_currentChapterIndex];
  }

  Future<List<_EffectiveReplaceMenuEntry>>
      _buildEffectiveReplaceEntriesForCurrentChapter() async {
    final chapter = _resolveCurrentChapterForEffectiveReplaces();
    if (chapter == null) {
      return const <_EffectiveReplaceMenuEntry>[];
    }
    final stage = await _computeReplaceStage(
      chapterId: chapter.id,
      rawTitle: chapter.title,
      rawContent: chapter.content ?? '',
    );

    final entries = stage.effectiveContentReplaceRules.map((rule) {
      final label = rule.name.trim().isEmpty ? '(未命名)' : rule.name.trim();
      return _EffectiveReplaceMenuEntry.rule(
        label: label,
        rule: rule,
      );
    }).toList(growable: true);

    if (_settings.chineseConverterType != ChineseConverterType.off) {
      entries.add(
        const _EffectiveReplaceMenuEntry.chineseConverter(label: '繁简转换'),
      );
    }
    return entries;
  }

  Future<_EffectiveReplaceMenuEntry?> _showEffectiveReplacesDialog(
    List<_EffectiveReplaceMenuEntry> entries,
  ) async {
    return showCupertinoBottomDialog<_EffectiveReplaceMenuEntry>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('起效的替换'),
          actions: entries
              .map(
                (entry) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(sheetContext, entry),
                  child: Text(entry.label),
                ),
              )
              .toList(growable: false),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('关闭'),
          ),
        );
      },
    );
  }

  Future<bool> _showChineseConverterPickerFromEffectiveReplaces() async {
    final selected = await showCupertinoBottomDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('简繁转换'),
          actions: _SimpleReaderViewState._chineseConverterOptions
              .map(
                (option) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(sheetContext, option.value),
                  child: Text(option.label),
                ),
              )
              .toList(growable: false),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (selected == null || selected == _settings.chineseConverterType) {
      return false;
    }
    _updateSettings(_settings.copyWith(chineseConverterType: selected));
    return true;
  }

  Future<bool> _openReplaceRuleEditFromEffectiveReplaces(
    ReplaceRule rule,
  ) async {
    var saved = false;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ReplaceRuleEditView(
          initial: rule,
          onSave: (next) async {
            await _replaceRuleRepo.addRule(_normalizeReplaceRuleForSave(next));
            saved = true;
          },
        ),
      ),
    );
    if (!saved) {
      return false;
    }
    return true;
  }

  Future<void> _openEffectiveReplacesFromMenu() async {
    _closeReaderMenuOverlay();
    var hasEdited = false;

    while (mounted) {
      final entries = await _buildEffectiveReplaceEntriesForCurrentChapter();
      final selected = await _showEffectiveReplacesDialog(entries);
      if (selected == null) break;

      if (selected.isChineseConverter) {
        final changed =
            await _showChineseConverterPickerFromEffectiveReplaces();
        hasEdited = hasEdited || changed;
        if (changed) {
          _replaceStageCache.clear();
        }
        continue;
      }

      final rule = selected.rule;
      if (rule == null) {
        continue;
      }
      final changed = await _openReplaceRuleEditFromEffectiveReplaces(rule);
      hasEdited = hasEdited || changed;
      if (changed) {
        _replaceStageCache.clear();
      }
    }

    if (!mounted || !hasEdited) return;
    _replaceStageCache.clear();
    _catalogDisplayTitleCacheByChapterId.clear();
    if (_chapters.isNotEmpty) {
      await _loadChapter(
        _clampChapterIndexToReadableRange(_currentChapterIndex),
        restoreOffset: _settings.pageTurnMode == PageTurnMode.scroll,
      );
    }
  }

  Future<void> _toggleReplaceRuleState() async {
    final nextUseReplaceRule = !_useReplaceRule;
    setState(() {
      _useReplaceRule = nextUseReplaceRule;
      _catalogDisplayTitleCacheByChapterId.clear();
    });
    await _settingsService.saveBookUseReplaceRule(
      widget.bookId,
      nextUseReplaceRule,
    );

    _replaceStageCache.clear();
    if (_chapters.isNotEmpty) {
      await _saveProgress();
      final targetIndex =
          _clampChapterIndexToReadableRange(_currentChapterIndex);
      await _loadChapter(
        targetIndex,
        restoreOffset: true,
      );
    }
  }

  void _toggleDayNightThemeFromQuickAction() {
    final settings = _settingsService.appSettings;
    final mode = ReaderThemeModeHelper.resolveMode(
      appearanceMode: settings.appearanceMode,
      effectiveBrightness: _effectiveBrightnessForReaderThemeMode(),
    );
    final targetMode = mode == ReaderThemeMode.night
        ? AppAppearanceMode.light
        : AppAppearanceMode.dark;
    if (settings.appearanceMode == targetMode) {
      return;
    }
    unawaited(
      _settingsService.saveAppSettings(
        settings.copyWith(appearanceMode: targetMode),
      ),
    );
  }

  /// 迁移排除态提示：朗读（TTS）仅保留锚点，不进入业务实现。
  ///
  /// 约束：
  /// - 需要用户可感知（避免“静默无反应”）；
  /// - 文案与全局排除口径一致；
  /// - 避免重复弹窗堆叠导致交互异常。
  Future<void> _showReadAloudExcludedHint({required String entry}) async {
    if (!mounted) return;
    debugPrint('[migration-exclusion][tts] blocked entry=$entry');

    if (_showingReadAloudExclusionDialog) {
      _showToast('朗读（TTS）功能暂不开放');
      return;
    }

    _showingReadAloudExclusionDialog = true;
    try {
      await showCupertinoBottomDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('扩展阶段'),
          content: Text('\n$_SimpleReaderViewState._readAloudExclusionHint'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('好'),
            ),
          ],
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[migration-exclusion][tts] dialog failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showToast('朗读（TTS）功能暂不开放');
    } finally {
      _showingReadAloudExclusionDialog = false;
    }
  }

  Future<void> _triggerReadAloudPreviousParagraph() async {
    final result = await _readAloudService.previousParagraph();
    if (!mounted) return;
    if (!result.success) {
      _showToast(result.message);
    }
  }

  Future<void> _triggerReadAloudNextParagraph() async {
    final result = await _readAloudService.nextParagraph();
    if (!mounted) return;
    if (!result.success) {
      _showToast(result.message);
    }
  }

  Future<void> _triggerReadAloudPauseResume() async {
    final result = await _readAloudService.togglePauseResume();
    if (!mounted) return;
    _showToast(result.message);
  }

  Future<void> _openReadAloudAction() async {
    final capability = _detectReadAloudCapability();
    if (!capability.available) {
      _showToast(capability.reason);
      return;
    }

    if (_autoPager.isRunning) {
      _autoPagerPausedByMenu = false;
      _autoPager.stop();
      if (_showAutoReadPanel) {
        setState(() {
          _showAutoReadPanel = false;
        });
      }
    }

    ReadAloudActionResult result;
    if (!_readAloudSnapshot.isRunning) {
      result = await _readAloudService.start(
        chapterIndex: _currentChapterIndex,
        chapterTitle: _currentTitle,
        content: _currentContent,
      );
    } else if (_readAloudSnapshot.isPaused) {
      result = await _readAloudService.resume();
    } else {
      result = await _readAloudService.pause();
    }
    if (!mounted) return;
    _showToast(result.message);
  }

  Future<bool> _handleReadAloudChapterSwitchRequest(
    ReadAloudChapterDirection direction,
  ) async {
    final readableChapterCount = _effectiveReadableChapterCount();
    if (readableChapterCount <= 0) return false;
    final step = direction == ReadAloudChapterDirection.next ? 1 : -1;
    final targetIndex = _currentChapterIndex + step;
    if (targetIndex < 0 || targetIndex >= readableChapterCount) {
      return false;
    }
    await _loadChapter(
      targetIndex,
      goToLastPage: direction == ReadAloudChapterDirection.previous,
    );
    return true;
  }

  void _handleReadAloudStateChanged(ReadAloudStatusSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _readAloudSnapshot = snapshot;
    });
  }

  void _handleReadAloudMessage(String message) {
    if (!mounted) return;
    _showToast(message);
  }

  void _syncReadAloudChapterContext() {
    // 迁移排除态下不进入朗读业务链路：不主动同步章节上下文。
    if (MigrationExclusions.excludeTts) return;
    unawaited(
      _readAloudService.updateChapter(
        chapterIndex: _currentChapterIndex,
        chapterTitle: _currentTitle,
        content: _currentContent,
      ),
    );
  }

  /// 定时停止选择器，对标 legado ReadAloudDialog tvTimer 快速选择。
  Future<void> _showReadAloudTimerPicker() async {
    const times = [0, 5, 10, 15, 30, 60, 90, 180];
    final current = _readAloudSnapshot.sleepTimerMinutes;
    final selected = await showCupertinoBottomDialog<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('定时停止'),
        actions: times.map((t) {
          final label = t == 0 ? '取消定时' : '$t 分钟';
          final isActive = t == current;
          return CupertinoActionSheetAction(
            isDefaultAction: isActive,
            onPressed: () => Navigator.pop(ctx, t),
            child: Text(label),
          );
        }).toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    _readAloudService.setTimer(selected);
    if (mounted) setState(() {});
    if (selected > 0) {
      _showToast('将在 $selected 分钟后停止朗读');
    } else {
      _showToast('已取消定时');
    }
  }

  Future<void> _seekByChapterProgress(int targetChapterIndex) async {
    final readableChapterCount = _effectiveReadableChapterCount();
    if (readableChapterCount <= 0) return;
    if (targetChapterIndex < 0 || targetChapterIndex >= readableChapterCount) {
      return;
    }
    if (targetChapterIndex == _currentChapterIndex) return;

    if (_settings.progressBarBehavior == ProgressBarBehavior.chapter &&
        _settings.confirmSkipChapter &&
        !_chapterSeekConfirmed) {
      final confirmed = await showCupertinoBottomDialog<bool>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: const Text('章节跳转确认'),
              content: const Text('\n确定要跳转章节吗？'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('跳转'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      _chapterSeekConfirmed = true;
    }
    await _loadChapter(targetChapterIndex);
  }

  void _showReaderActionsMenu() {
    _closeReaderMenuOverlay();
    final isLocal = _isCurrentBookLocal();
    final actions = ReaderLegacyMenuHelper.buildReadMenuActions(
      isOnline: !isLocal,
      isLocalTxt: _isCurrentBookLocalTxt(),
      isEpub: _isCurrentBookEpub(),
      showWebDavProgressActions: _hasWebDavProgressConfig(),
      // legado: menu_enable_review 默认 visible=false，主流程保持隐藏。
      showReviewAction: false,
    )
        .where(
          (action) =>
              action != ReaderLegacyReadMenuAction.changeSource &&
              action != ReaderLegacyReadMenuAction.refresh &&
              action != ReaderLegacyReadMenuAction.download &&
              action != ReaderLegacyReadMenuAction.tocRule &&
              action != ReaderLegacyReadMenuAction.setCharset,
        )
        .toList(growable: false);
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('阅读操作'),
        actions: actions
            .map(
              (action) => CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _executeLegacyReadMenuAction(action);
                },
                child: _buildReaderActionSheetLabel(action),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  bool _isReaderActionChecked(ReaderLegacyReadMenuAction action) {
    return switch (action) {
      ReaderLegacyReadMenuAction.enableReplace => _useReplaceRule,
      ReaderLegacyReadMenuAction.sameTitleRemoved =>
        _isCurrentChapterSameTitleRemoved(),
      ReaderLegacyReadMenuAction.reSegment => _reSegment,
      ReaderLegacyReadMenuAction.delRubyTag => _delRubyTag,
      ReaderLegacyReadMenuAction.delHTag => _delHTag,
      _ => false,
    };
  }

  Widget _buildReaderActionSheetLabel(ReaderLegacyReadMenuAction action) {
    final label = ReaderLegacyMenuHelper.readMenuLabel(action);
    if (!_isReaderActionChecked(action)) {
      return Text(label);
    }
    final checkColor = CupertinoTheme.of(context).primaryColor;
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Icon(
          CupertinoIcons.check_mark,
          size: 16,
          color: checkColor,
        ),
      ],
    );
  }

  void _showContentSearchDialog() {
    if (_showMenu) {
      _closeReaderMenuOverlay();
    }
    final controller = TextEditingController(text: _contentSearchQuery);
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('搜索正文'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: '输入关键词',
            clearButtonMode: OverlayVisibilityMode.editing,
            onSubmitted: (_) {
              final query = controller.text.trim();
              Navigator.pop(dialogContext);
              unawaited(_applyContentSearch(query));
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final query = controller.text.trim();
              Navigator.pop(dialogContext);
              unawaited(_applyContentSearch(query));
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _applyContentSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }
    _captureSearchProgressSnapshotIfNeeded();

    final taskToken = ++_contentSearchTaskToken;
    setState(() {
      _contentSearchQuery = normalized;
      _isSearchingContent = true;
      _contentSearchHits = const <_ReaderSearchHit>[];
      _currentSearchHitIndex = -1;
    });
    _setSearchMenuVisible(true);

    debugPrint(
      '[reader][content-search] start token=$taskToken queryLength=${normalized.length}',
    );
    late final List<_ReaderSearchHit> hits;
    try {
      hits = await _collectBookContentSearchHits(
        normalized,
        taskToken: taskToken,
      );
    } catch (error, stackTrace) {
      if (!mounted || taskToken != _contentSearchTaskToken) {
        return;
      }
      ExceptionLogService().record(
        node: 'reader.menu.search_content.collect',
        message: '全文搜索失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'chapterIndex': _currentChapterIndex,
          'queryLength': normalized.length,
          'searchableChapterCount': _effectiveReadableChapters().length,
        },
      );
      setState(() {
        _isSearchingContent = false;
        _contentSearchHits = const <_ReaderSearchHit>[];
        _currentSearchHitIndex = -1;
      });
      _showToast('全文搜索失败');
      return;
    }
    if (!mounted || taskToken != _contentSearchTaskToken) {
      return;
    }

    setState(() {
      _isSearchingContent = false;
      _contentSearchHits = hits;
      _currentSearchHitIndex = hits.isEmpty ? -1 : 0;
    });
    debugPrint(
      '[reader][content-search] done token=$taskToken hits=${hits.length}',
    );

    if (hits.isNotEmpty) {
      unawaited(_jumpToSearchHit(hits.first));
    }
  }

  Future<List<_ReaderSearchHit>> _collectBookContentSearchHits(
    String query, {
    required int taskToken,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const <_ReaderSearchHit>[];
    final searchableChapters = _effectiveReadableChapters();
    if (searchableChapters.isEmpty) return const <_ReaderSearchHit>[];
    final hits = <_ReaderSearchHit>[];
    for (var chapterIndex = 0;
        chapterIndex < searchableChapters.length;
        chapterIndex++) {
      if (taskToken != _contentSearchTaskToken) {
        return const <_ReaderSearchHit>[];
      }

      final chapter = searchableChapters[chapterIndex];
      final rawContent = (chapter.content ?? '')
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      // 对齐 legado SearchContentActivity：在线书仅搜索已缓存正文（content 为空即跳过）。
      if (rawContent.trim().isEmpty) {
        continue;
      }

      final searchableContent = await _resolveContentSearchableContent(
        rawContent,
        taskToken: taskToken,
      );
      if (taskToken != _contentSearchTaskToken) {
        return const <_ReaderSearchHit>[];
      }
      if (searchableContent.isEmpty) {
        continue;
      }

      final chapterTitle = _postProcessTitle(chapter.title);
      hits.addAll(
        _collectChapterSearchHits(
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          content: searchableContent,
          query: normalizedQuery,
        ),
      );

      if ((chapterIndex & 7) == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return hits;
  }

  Future<String> _resolveContentSearchableContent(
    String rawContent, {
    required int taskToken,
  }) async {
    var processed = rawContent;
    // 对齐 legado SearchContentActivity.menu_enable_replace：
    // 开关只影响全文搜索流程，且仍受书籍“替换净化”总开关约束。
    if (_contentSearchUseReplace && _useReplaceRule) {
      processed = await _replaceService.applyContent(
        processed,
        bookName: widget.bookTitle,
        sourceUrl: _currentSourceUrl,
      );
      if (taskToken != _contentSearchTaskToken) {
        return '';
      }
    }
    return _convertByChineseConverterType(processed);
  }

  List<_ReaderSearchHit> _collectChapterSearchHits({
    required int chapterIndex,
    required String chapterTitle,
    required String content,
    required String query,
  }) {
    final hits = <_ReaderSearchHit>[];
    var from = 0;
    var occurrenceIndex = 0;
    while (from < content.length) {
      final found = content.indexOf(query, from);
      if (found == -1) break;
      final end = found + query.length;
      final previewStart = (found - 20).clamp(0, content.length).toInt();
      final previewEnd = (end + 24).clamp(0, content.length).toInt();
      final previewRaw =
          content.substring(previewStart, previewEnd).replaceAll('\n', ' ');
      final localStart =
          (found - previewStart).clamp(0, previewRaw.length).toInt();
      final localEnd = (localStart + query.length)
          .clamp(localStart, previewRaw.length)
          .toInt();
      final previewBefore = previewRaw.substring(0, localStart);
      final previewMatch = previewRaw.substring(localStart, localEnd);
      final previewAfter = previewRaw.substring(localEnd);
      final pageIndex = chapterIndex == _currentChapterIndex &&
              _settings.pageTurnMode != PageTurnMode.scroll
          ? _resolveSearchHitPageIndex(
              contentOffset: found,
              occurrenceIndex: occurrenceIndex,
              query: query,
            )
          : null;
      hits.add(
        _ReaderSearchHit(
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          chapterContentLength: content.length,
          start: found,
          end: end,
          query: query,
          occurrenceIndex: occurrenceIndex,
          previewBefore: previewBefore,
          previewMatch: previewMatch,
          previewAfter: previewAfter,
          pageIndex: pageIndex,
        ),
      );
      occurrenceIndex += 1;
      from = found + query.length;
    }
    return hits;
  }

  int? _resolveSearchHitPageIndex({
    required int contentOffset,
    required int occurrenceIndex,
    required String query,
  }) {
    final byOccurrence = _resolveSearchHitPageIndexByOccurrence(
      occurrenceIndex: occurrenceIndex,
      query: query,
    );
    if (byOccurrence != null) return byOccurrence;
    return _resolveSearchHitPageIndexByOffset(contentOffset);
  }

  int? _resolveSearchHitPageIndexByOccurrence({
    required int occurrenceIndex,
    required String query,
  }) {
    return ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
      pages: _pageFactory.currentPages,
      query: query,
      occurrenceIndex: occurrenceIndex,
      chapterTitle: _currentTitle,
      trimFirstPageTitlePrefix: _settings.titleMode != 2,
    );
  }

  int? _resolveSearchHitPageIndexByOffset(int contentOffset) {
    return ReaderSearchNavigationHelper.resolvePageIndexByOffset(
      pages: _pageFactory.currentPages,
      contentOffset: contentOffset,
    );
  }

  Future<void> _jumpToSearchHit(_ReaderSearchHit hit) async {
    final chapterChanged = hit.chapterIndex != _currentChapterIndex;
    if (hit.chapterIndex != _currentChapterIndex) {
      await _loadChapter(hit.chapterIndex);
      if (!mounted || hit.chapterIndex != _currentChapterIndex) {
        return;
      }
    }

    if (_settings.pageTurnMode == PageTurnMode.scroll) {
      await _jumpToSearchHitInScroll(hit);
      return;
    }
    if (chapterChanged) {
      _paginateContentLogicOnly();
    }

    final totalPages = _pageFactory.totalPages;
    if (totalPages <= 0) return;
    final resolvedPage = _resolveSearchHitPageIndex(
      contentOffset: hit.start,
      occurrenceIndex: hit.occurrenceIndex,
      query: hit.query,
    );
    final targetPage = (resolvedPage ?? hit.pageIndex ?? 0).clamp(
      0,
      totalPages - 1,
    );
    _pageFactory.jumpToPage(targetPage);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _jumpToSearchHitInScroll(_ReaderSearchHit hit) async {
    if (!_scrollController.hasClients) return;
    final target = _resolveScrollSearchTargetOffset(hit);
    if (target == null) return;

    _programmaticScrollInFlight = true;
    try {
      if (_settings.noAnimScrollPage) {
        _scrollController.jumpTo(target);
      } else {
        await _scrollController.animateTo(
          target,
          duration: AppDesignTokens.motionNormal,
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _programmaticScrollInFlight = false;
    }
    if (mounted) {
      _syncCurrentChapterFromScroll(saveProgress: true);
    }
  }

  double? _resolveScrollSearchTargetOffset(_ReaderSearchHit hit) {
    if (!_scrollController.hasClients) return null;
    if (_scrollSegments.isEmpty) return null;

    _refreshScrollSegmentHeights();
    final range = _findCurrentChapterScrollOffsetRange();
    if (range == null) {
      final maxOffset = _scrollController.position.maxScrollExtent;
      if (maxOffset <= 0 || _currentContent.isEmpty) {
        return null;
      }
      final ratio = (hit.start / _currentContent.length).clamp(0.0, 1.0);
      return (maxOffset * ratio).clamp(0.0, maxOffset).toDouble();
    }

    final localAnchor = _resolveScrollHitLocalAnchor(
      segment: range.segment,
      hit: hit,
    );
    final offsetWithAnchor =
        range.start + localAnchor - _scrollAnchorWithinViewport;
    final minOffset = _scrollController.position.minScrollExtent;
    final maxOffset = _scrollController.position.maxScrollExtent;
    return offsetWithAnchor.clamp(minOffset, maxOffset).toDouble();
  }

  _ScrollSegmentOffsetRange? _findCurrentChapterScrollOffsetRange() {
    for (final range in _scrollSegmentOffsetRanges) {
      if (range.segment.chapterIndex == _currentChapterIndex) {
        return range;
      }
    }
    return null;
  }

  double _resolveScrollHitLocalAnchor({
    required _ScrollSegment segment,
    required _ReaderSearchHit hit,
  }) {
    final paragraphStyle = _scrollParagraphStyle();
    final layout = _resolveScrollTextLayout(
      seed: _ScrollSegmentSeed(
        chapterId: segment.chapterId,
        title: segment.title,
        content: segment.content,
      ),
      maxWidth: _scrollBodyWidth(),
      style: paragraphStyle,
    );
    final contentTop = _scrollSegmentContentTopInset(segment);
    if (layout.lines.isEmpty) {
      return contentTop;
    }

    var occurrenceCursor = 0;
    for (final line in layout.lines) {
      final lineText = _lineText(line);
      if (lineText.isEmpty) {
        continue;
      }
      var from = 0;
      while (from < lineText.length) {
        final found = lineText.indexOf(hit.query, from);
        if (found == -1) break;
        if (occurrenceCursor == hit.occurrenceIndex) {
          return contentTop + line.y + line.height * 0.32;
        }
        occurrenceCursor += 1;
        from = found + hit.query.length;
      }
    }

    final totalLength = _currentContent.isEmpty ? 1 : _currentContent.length;
    final ratio = (hit.start / totalLength).clamp(0.0, 1.0).toDouble();
    return contentTop + layout.bodyHeight * ratio;
  }

  double _scrollSegmentContentTopInset(_ScrollSegment segment) {
    return _settings.paddingTop + _scrollSegmentTitleBlockHeight(segment);
  }

  double _scrollSegmentTitleBlockHeight(_ScrollSegment segment) {
    if (_settings.titleMode == 2 || segment.title.trim().isEmpty) {
      return 0.0;
    }
    final topSpacing =
        _settings.titleTopSpacing > 0 ? _settings.titleTopSpacing : 20.0;
    final bottomSpacing = _settings.titleBottomSpacing > 0
        ? _settings.titleBottomSpacing
        : _settings.paragraphSpacing * 1.5;
    final titlePainter = TextPainter(
      text: TextSpan(
        text: segment.title,
        style: TextStyle(
          fontSize: _settings.fontSize + _settings.titleSize,
          fontWeight: FontWeight.w600,
          fontFamily: _currentFontFamily,
          fontFamilyFallback: _currentFontFamilyFallback,
        ),
      ),
      textAlign: _titleTextAlign,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: _scrollBodyWidth());
    return topSpacing + titlePainter.height + bottomSpacing;
  }

  String _lineText(ScrollTextLine line) {
    if (line.runs.isEmpty) return '';
    final buffer = StringBuffer();
    for (final run in line.runs) {
      buffer.write(run.text);
    }
    return buffer.toString();
  }

  void _navigateSearchHit(int delta) {
    if (_contentSearchHits.isEmpty) return;
    final size = _contentSearchHits.length;
    final nextIndex = ReaderSearchNavigationHelper.resolveNextHitIndex(
      currentIndex: _currentSearchHitIndex,
      delta: delta,
      totalHits: size,
    );
    if (nextIndex < 0) {
      return;
    }
    setState(() {
      _currentSearchHitIndex = nextIndex;
    });
    unawaited(_jumpToSearchHit(_contentSearchHits[nextIndex]));
  }

  void _captureSearchProgressSnapshotIfNeeded() {
    if (_searchProgressSnapshot != null) return;
    final readableCount = _effectiveReadableChapterCount();
    if (readableCount <= 0) return;
    _searchProgressSnapshot = _ReaderSearchProgressSnapshot(
      chapterIndex: _clampChapterIndexToReadableRange(_currentChapterIndex),
      chapterProgress: _getChapterProgress().clamp(0.0, 1.0).toDouble(),
    );
  }

  Future<void> _handleReaderBack() async {
    if (!mounted) return;
    // legado: 非书架书籍退出时提示加入书架（仅 ephemeral 模式）
    if (widget.isEphemeral) {
      final appSettings = _settingsService.appSettings;
      if (appSettings.showAddToShelfAlert) {
        final addToShelf = await _promptAddToShelf();
        if (!mounted) return;
        if (addToShelf == true) {
          // ephemeral 模式没有真正书架书籍，提示后直接退出
          // 实际加入书架逻辑由调用方（discovery_explore_results_view）处理
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool?> _promptAddToShelf() {
    return showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('加入书架'),
        content: Text('\n是否将「${widget.bookTitle}」加入书架？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('不加入'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackFromSearchMenu() async {
    if (!_showSearchMenu) return;
    final snapshot = _searchProgressSnapshot;
    if (snapshot == null) {
      _exitSearchMenu();
      return;
    }
    final shouldRestore = await _confirmRestoreSearchProgress();
    if (!shouldRestore) {
      _exitSearchMenu();
      return;
    }
    _exitSearchMenu(clearProgressSnapshot: false);
    await _loadChapter(
      snapshot.chapterIndex,
      restoreOffset: true,
      targetChapterProgress: snapshot.chapterProgress,
    );
    _searchProgressSnapshot = null;
  }

  Future<bool> _confirmRestoreSearchProgress() async {
    return await showCupertinoBottomDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('恢复进度'),
            content: const Text('\n是否恢复到搜索前的阅读位置？'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('恢复'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _exitSearchMenu({bool clearProgressSnapshot = true}) {
    debugPrint(
      '[reader][content-search] exit queryLength=${_contentSearchQuery.length} '
      'hits=${_contentSearchHits.length}',
    );
    _contentSearchTaskToken += 1;
    setState(() {
      _showSearchMenu = false;
      _isSearchingContent = false;
      _contentSearchHits = <_ReaderSearchHit>[];
      _currentSearchHitIndex = -1;
      _contentSearchQuery = '';
      _contentSearchUseReplace = false;
    });
    if (clearProgressSnapshot) {
      _searchProgressSnapshot = null;
    }
    _syncSystemUiForOverlay();
  }

  void _showContentSearchOptionsSheet() {
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _contentSearchUseReplace = !_contentSearchUseReplace;
                });
              }
              Navigator.pop(sheetContext);
            },
            child: Text(_contentSearchUseReplace ? '✓ 替换' : '替换'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Widget _buildSearchMenuOverlay() {
    final currentHit = (_currentSearchHitIndex >= 0 &&
            _currentSearchHitIndex < _contentSearchHits.length)
        ? _contentSearchHits[_currentSearchHitIndex]
        : null;
    final isSearching = _isSearchingContent;
    final hasHits = _contentSearchHits.isNotEmpty;
    final canNavigate = hasHits && !isSearching;
    final info = isSearching
        ? '正在搜索全文...'
        : hasHits
            ? '结果 ${_currentSearchHitIndex + 1}/${_contentSearchHits.length} · ${currentHit?.chapterTitle ?? _currentTitle}'
            : (_contentSearchQuery.trim().isEmpty ? '未开始全文搜索' : '全文未找到匹配内容');
    final location = hasHits && currentHit != null
        ? '位置 ${currentHit.start + 1}/${currentHit.chapterContentLength}'
        : null;
    final accent = _isUiDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
    final navBtnBg = _uiPanelBg.withValues(alpha: _isUiDark ? 0.94 : 0.95);
    final navBtnShadow = CupertinoColors.black.withValues(
      alpha: _isUiDark ? 0.32 : 0.12,
    );
    final sideButtonTop = MediaQuery.sizeOf(context).height * 0.42;

    return Stack(
      children: [
        Positioned(
          left: 12,
          top: sideButtonTop,
          child: FadeTransition(
            opacity: _searchMenuFadeAnim,
            child: _buildSearchSideNavButton(
              icon: CupertinoIcons.chevron_left,
              onTap: canNavigate ? () => _navigateSearchHit(-1) : null,
              color: navBtnBg,
              shadowColor: navBtnShadow,
              semanticsLabel: '上一个',
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: sideButtonTop,
          child: FadeTransition(
            opacity: _searchMenuFadeAnim,
            child: _buildSearchSideNavButton(
              icon: CupertinoIcons.chevron_right,
              onTap: canNavigate ? () => _navigateSearchHit(1) : null,
              color: navBtnBg,
              shadowColor: navBtnShadow,
              semanticsLabel: '下一个',
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _searchMenuSlideAnim,
            child: FadeTransition(
              opacity: _searchMenuFadeAnim,
              child: SafeArea(
            top: false,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              decoration: BoxDecoration(
                color: _uiPanelBg.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: _uiBorder.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color:
                          _uiCardBg.withValues(alpha: _isUiDark ? 0.78 : 0.86),
                      border: Border(
                        bottom: BorderSide(
                          color: _uiBorder.withValues(alpha: 0.9),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildSearchTopIconButton(
                          icon: CupertinoIcons.chevron_up,
                          onTap:
                              canNavigate ? () => _navigateSearchHit(-1) : null,
                        ),
                        _buildSearchTopIconButton(
                          icon: CupertinoIcons.chevron_down,
                          onTap:
                              canNavigate ? () => _navigateSearchHit(1) : null,
                        ),
                        const SizedBox(width: 6),
                        if (isSearching)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: CupertinoActivityIndicator(radius: 7),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                info,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _uiTextNormal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (location != null)
                                Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _uiTextSubtle,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _buildSearchTopIconButton(
                          icon: CupertinoIcons.ellipsis_circle,
                          onTap: _showContentSearchOptionsSheet,
                        ),
                      ],
                    ),
                  ),
                  if (currentHit != null)
                    SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        child: _buildSearchPreviewText(currentHit, accent),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: _uiBorder.withValues(alpha: 0.78),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSearchMenuMainAction(
                            icon: CupertinoIcons.search,
                            label: '结果',
                            onTap: _showContentSearchDialog,
                          ),
                        ),
                        Expanded(
                          child: _buildSearchMenuMainAction(
                            icon: CupertinoIcons.square_grid_2x2,
                            label: '主菜单',
                            onTap: () {
                              _setSearchMenuVisible(false);
                              _setReaderMenuVisible(true);
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildSearchMenuMainAction(
                            icon: CupertinoIcons.clear_circled_solid,
                            label: '退出',
                            onTap: _exitSearchMenu,
                            activeColor: CupertinoColors.destructiveRed
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
              ),
            ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchPreviewText(_ReaderSearchHit hit, Color accent) {
    final before = hit.previewBefore.trimLeft();
    final match = hit.previewMatch.trim();
    final after = hit.previewAfter.trimRight();
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          color: _uiTextSubtle,
          fontSize: 12,
          height: 1.35,
        ),
        children: [
          const TextSpan(text: '...'),
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: after),
          const TextSpan(text: '...'),
        ],
      ),
    );
  }

  Widget _buildSearchTopIconButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: onTap,
      child: Icon(
        icon,
        size: 18,
        color: onTap == null ? _uiTextSubtle : _uiTextStrong,
      ),
      minimumSize: Size(30, 30),
    );
  }

  Widget _buildSearchMenuMainAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? activeColor,
  }) {
    final enabled = onTap != null;
    final color = enabled ? (activeColor ?? _uiTextStrong) : _uiTextSubtle;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 6),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      minimumSize: const Size.square(kMinInteractiveDimensionCupertino),
    );
  }

  Widget _buildSearchSideNavButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
    required Color shadowColor,
    required String semanticsLabel,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: _isUiDark ? 0.78 : 0.85),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _uiBorder.withValues(alpha: 0.6),
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? _uiTextSubtle : _uiTextStrong,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 刷新当前章节
}

// ─── Scroll Content 独立 Widget ───────────────────────────────────────────────

@immutable
class _ScrollContentConfig {
  const _ScrollContentConfig({
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.paragraphIndent,
    required this.textFullJustify,
    required this.textColor,
    required this.fontFamily,
    required this.fontFamilyFallback,
    required this.fontWeight,
    required this.textDecoration,
    required this.titleMode,
    required this.titleSize,
    required this.titleTopSpacing,
    required this.titleBottomSpacing,
    required this.titleTextAlign,
    required this.paddingLeft,
    required this.paddingRight,
    required this.paddingTop,
    required this.paddingBottom,
    required this.paddingDisplayCutouts,
    required this.imageStyle,
    required this.searchHighlightQuery,
    required this.searchHighlightColor,
    required this.searchHighlightTextColor,
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final String paragraphIndent;
  final bool textFullJustify;
  final Color textColor;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final FontWeight fontWeight;
  final TextDecoration? textDecoration;
  final int titleMode;
  final int titleSize;
  final double titleTopSpacing;
  final double titleBottomSpacing;
  final TextAlign titleTextAlign;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final bool paddingDisplayCutouts;
  final String imageStyle;
  final String? searchHighlightQuery;
  final Color? searchHighlightColor;
  final Color? searchHighlightTextColor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ScrollContentConfig) return false;
    return fontSize == other.fontSize &&
        lineHeight == other.lineHeight &&
        letterSpacing == other.letterSpacing &&
        paragraphSpacing == other.paragraphSpacing &&
        paragraphIndent == other.paragraphIndent &&
        textFullJustify == other.textFullJustify &&
        textColor == other.textColor &&
        fontFamily == other.fontFamily &&
        _listEquals(fontFamilyFallback, other.fontFamilyFallback) &&
        fontWeight == other.fontWeight &&
        textDecoration == other.textDecoration &&
        titleMode == other.titleMode &&
        titleSize == other.titleSize &&
        titleTopSpacing == other.titleTopSpacing &&
        titleBottomSpacing == other.titleBottomSpacing &&
        titleTextAlign == other.titleTextAlign &&
        paddingLeft == other.paddingLeft &&
        paddingRight == other.paddingRight &&
        paddingTop == other.paddingTop &&
        paddingBottom == other.paddingBottom &&
        paddingDisplayCutouts == other.paddingDisplayCutouts &&
        imageStyle == other.imageStyle &&
        searchHighlightQuery == other.searchHighlightQuery &&
        searchHighlightColor == other.searchHighlightColor &&
        searchHighlightTextColor == other.searchHighlightTextColor;
  }

  @override
  int get hashCode => Object.hashAll([
        fontSize,
        lineHeight,
        letterSpacing,
        paragraphSpacing,
        paragraphIndent,
        textFullJustify,
        textColor,
        fontFamily,
        fontWeight,
        textDecoration,
        titleMode,
        titleSize,
        titleTopSpacing,
        titleBottomSpacing,
        titleTextAlign,
        paddingLeft,
        paddingRight,
        paddingTop,
        paddingBottom,
        paddingDisplayCutouts,
        imageStyle,
        searchHighlightQuery,
        searchHighlightColor,
        searchHighlightTextColor,
      ]);

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  TextStyle get paragraphStyle => TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        letterSpacing: letterSpacing,
        color: textColor,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: fontWeight,
        decoration: textDecoration,
      );

  TextStyle get titleStyle => TextStyle(
        fontSize: fontSize + titleSize,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
      );

  TextStyle fallbackStyle(double size) => TextStyle(
        fontSize: (size - 2).clamp(10.0, 22.0),
        color: textColor.withValues(alpha: 0.7),
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
      );
}

class _ScrollContentView extends StatefulWidget {
  const _ScrollContentView({
    required this.config,
    required this.scrollInsets,
    required this.segments,
    required this.segmentsVersion,
    required this.scrollController,
    required this.scrollViewportKey,
    required this.onScrollStart,
    required this.onScrollEnd,
    required this.resolveScrollTextLayout,
    required this.resolveSegmentKey,
    required this.resolveImageProvider,
    required this.normalizeImageSrc,
  });

  final _ScrollContentConfig config;
  final EdgeInsets scrollInsets;
  final List<_ScrollSegment> segments;
  final ValueNotifier<int> segmentsVersion;
  final ScrollController scrollController;
  final GlobalKey scrollViewportKey;
  final VoidCallback onScrollStart;
  final VoidCallback onScrollEnd;
  final ScrollTextLayout Function({
    required _ScrollSegmentSeed seed,
    required double maxWidth,
    required TextStyle style,
  }) resolveScrollTextLayout;
  final GlobalKey Function(int chapterIndex) resolveSegmentKey;
  final ImageProvider<Object>? Function(String src) resolveImageProvider;
  final String Function(String raw) normalizeImageSrc;

  @override
  State<_ScrollContentView> createState() => _ScrollContentViewState();
}

class _ScrollContentViewState extends State<_ScrollContentView> {
  _ScrollContentConfig? _lastConfig;
  EdgeInsets? _lastScrollInsets;
  Widget? _cachedContent;

  @override
  void didUpdateWidget(_ScrollContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // config 或 insets 变化时清除缓存，下次 build 重建
    if (widget.config != oldWidget.config ||
        widget.scrollInsets != oldWidget.scrollInsets) {
      _cachedContent = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // config 和 insets 均未变化时直接返回缓存，跳过 layout pass
    if (_cachedContent != null &&
        widget.config == _lastConfig &&
        widget.scrollInsets == _lastScrollInsets) {
      return _cachedContent!;
    }
    _lastConfig = widget.config;
    _lastScrollInsets = widget.scrollInsets;
    _cachedContent = _buildContent();
    return _cachedContent!;
  }

  Widget _buildContent() {
    return Padding(
      padding: widget.scrollInsets,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;
          if (notification is ScrollStartNotification) {
            widget.onScrollStart();
          }
          if (notification is ScrollEndNotification) {
            widget.onScrollEnd();
          }
          return false;
        },
        child: ValueListenableBuilder<int>(
          valueListenable: widget.segmentsVersion,
          builder: (context, _, __) {
            if (widget.segments.isEmpty) {
              return const Center(child: CupertinoActivityIndicator());
            }
            return SingleChildScrollView(
              key: widget.scrollViewportKey,
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.fast,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.segments.length; i++)
                    _buildSegmentBody(
                      widget.segments[i],
                      isTailSegment: i == widget.segments.length - 1,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSegmentBody(_ScrollSegment segment, {required bool isTailSegment}) {
    final cfg = widget.config;
    final bodyWidth = _resolveBodyWidth();
    final imageBlocks = _buildImageRenderBlocks(segment.content);
    final contentBody = imageBlocks == null
        ? ScrollSegmentPaintView(
            layout: widget.resolveScrollTextLayout(
              seed: _ScrollSegmentSeed(
                chapterId: segment.chapterId,
                title: segment.title,
                content: segment.content,
              ),
              maxWidth: bodyWidth,
              style: cfg.paragraphStyle,
            ),
            style: cfg.paragraphStyle,
            highlightQuery: cfg.searchHighlightQuery,
            highlightColor: cfg.searchHighlightColor,
            highlightTextColor: cfg.searchHighlightTextColor,
          )
        : _buildImageAwareBody(
            blocks: imageBlocks,
            bodyWidth: bodyWidth,
          );

    return KeyedSubtree(
      key: widget.resolveSegmentKey(segment.chapterIndex),
      child: Padding(
        padding: EdgeInsets.only(
          left: cfg.paddingLeft,
          right: cfg.paddingRight,
          top: cfg.paddingTop,
          bottom: cfg.paddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cfg.titleMode != 2) ...[
              SizedBox(
                height: cfg.titleTopSpacing > 0 ? cfg.titleTopSpacing : 20,
              ),
              SizedBox(
                width: double.infinity,
                child: Text(
                  segment.title,
                  textAlign: cfg.titleTextAlign,
                  style: cfg.titleStyle,
                ),
              ),
              SizedBox(
                height: cfg.titleBottomSpacing > 0
                    ? cfg.titleBottomSpacing
                    : cfg.paragraphSpacing * 1.5,
              ),
            ],
            contentBody,
            SizedBox(height: isTailSegment ? 80 : 24),
          ],
        ),
      ),
    );
  }

  List<_ReaderRenderBlock>? _buildImageRenderBlocks(String content) {
    final imageStyle = widget.config.imageStyle;
    if (imageStyle == _SimpleReaderViewState._legacyImageStyleText ||
        !_SimpleReaderViewState._legacyImageTagRegex.hasMatch(content)) {
      return null;
    }
    final blocks = <_ReaderRenderBlock>[];
    var cursor = 0;
    for (final match
        in _SimpleReaderViewState._legacyImageTagRegex.allMatches(content)) {
      final before = content.substring(cursor, match.start);
      if (before.trim().isNotEmpty) {
        blocks.add(_ReaderRenderBlock.text(before));
      }
      final rawSrc = (match.group(1) ?? '').trim();
      final src = widget.normalizeImageSrc(rawSrc);
      if (src.isNotEmpty) {
        blocks.add(_ReaderRenderBlock.image(src));
      }
      cursor = match.end;
    }
    if (cursor < content.length) {
      final trailing = content.substring(cursor);
      if (trailing.trim().isNotEmpty) {
        blocks.add(_ReaderRenderBlock.text(trailing));
      }
    }
    if (!blocks.any((b) => b.isImage)) return null;
    return blocks;
  }

  Widget _buildImageAwareBody({
    required List<_ReaderRenderBlock> blocks,
    required double bodyWidth,
  }) {
    final cfg = widget.config;
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.isImage) {
        children.add(_buildImageBlock(src: block.imageSrc ?? '', bodyWidth: bodyWidth));
      } else if ((block.text ?? '').trim().isNotEmpty) {
        children.add(
          LegacyJustifiedTextBlock(
            content: block.text ?? '',
            style: cfg.paragraphStyle,
            justify: cfg.textFullJustify,
            paragraphIndent: cfg.paragraphIndent,
            applyParagraphIndent: true,
            preserveEmptyLines: true,
          ),
        );
      }
      if (i != blocks.length - 1) {
        children.add(SizedBox(
            height: cfg.paragraphSpacing.clamp(4.0, 24.0).toDouble()));
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildImageBlock({required String src, required double bodyWidth}) {
    final cfg = widget.config;
    final request = ReaderImageRequestParser.parse(src);
    final displaySrc =
        request.url.trim().isEmpty ? src.trim() : request.url;
    final imageProvider = widget.resolveImageProvider(src);
    if (imageProvider == null) return _buildImageFallback(displaySrc);

    final forceFullWidth =
        cfg.imageStyle == _SimpleReaderViewState._legacyImageStyleFull ||
            cfg.imageStyle == _SimpleReaderViewState._legacyImageStyleSingle;
    final image = Image(
      image: imageProvider,
      width: forceFullWidth ? bodyWidth : null,
      fit: forceFullWidth ? BoxFit.fitWidth : BoxFit.contain,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildImageFallback(displaySrc),
    );
    final imageBox = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bodyWidth), child: image);

    if (cfg.imageStyle == _SimpleReaderViewState._legacyImageStyleSingle) {
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final singleHeight =
          (viewportHeight - cfg.paddingTop - cfg.paddingBottom)
              .clamp(220.0, 1200.0)
              .toDouble();
      return SizedBox(height: singleHeight, child: Center(child: imageBox));
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical:
                (cfg.paragraphSpacing / 2).clamp(6.0, 20.0).toDouble()),
        child: imageBox,
      ),
    );
  }

  Widget _buildImageFallback(String src) {
    final display = src.trim();
    final message = display.isEmpty ? '图片加载失败' : '图片加载失败：$display';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(message, style: widget.config.fallbackStyle(widget.config.fontSize)),
    );
  }

  double _resolveBodyWidth() {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return 320.0;
    final cfg = widget.config;
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;
    final horizontalSafeInset =
        cfg.paddingDisplayCutouts ? safePadding.left + safePadding.right : 0.0;
    return (screenSize.width -
            horizontalSafeInset -
            cfg.paddingLeft -
            cfg.paddingRight)
        .clamp(1.0, double.infinity)
        .toDouble();
  }
}

/// 全屏图片预览页，支持双指缩放和平移。
class _ImagePreviewPage extends StatelessWidget {
  final ImageProvider imageProvider;

  const _ImagePreviewPage({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.7),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.xmark,
            color: CupertinoColors.white,
          ),
        ),
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8.0,
          child: Center(
            child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                CupertinoIcons.photo,
                color: CupertinoColors.systemGrey,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
