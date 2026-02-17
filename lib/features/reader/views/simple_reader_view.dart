import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/keep_screen_on_service.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../bookshelf/models/book.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/reading_settings.dart';
import '../services/reader_source_switch_helper.dart';
import '../utils/chapter_progress_utils.dart';
import '../widgets/auto_pager.dart';
import '../widgets/click_action_config_dialog.dart';
import '../widgets/legacy_justified_text.dart';
import '../widgets/paged_reader_widget.dart';
import '../widgets/page_factory.dart';
import '../widgets/reader_menus.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_status_bar.dart';
import '../widgets/reader_catalog_sheet.dart';
import '../widgets/scroll_page_step_calculator.dart';
import '../widgets/scroll_runtime_helper.dart';
import '../widgets/typography_settings_dialog.dart';

/// 简洁阅读器 - Cupertino 风格 (增强版)
class SimpleReaderView extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int initialChapter;
  final List<Chapter>? initialChapters;
  final String? initialSourceUrl;
  final String? initialSourceName;
  final String? initialBookAuthor;
  final String? initialBookCoverUrl;

  const SimpleReaderView({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.initialChapter = 0,
    this.initialChapters,
    this.initialSourceUrl,
    this.initialSourceName,
    this.initialBookAuthor,
    this.initialBookCoverUrl,
  });

  const SimpleReaderView.ephemeral({
    super.key,
    required String sessionId,
    required this.bookTitle,
    required this.initialChapters,
    required this.initialSourceUrl,
    this.initialSourceName,
    this.initialBookAuthor,
    this.initialBookCoverUrl,
    this.initialChapter = 0,
  }) : bookId = sessionId;

  bool get isEphemeral => initialChapters != null;
  String get readingKey => bookId;

  String? get effectiveSourceUrl => initialSourceUrl;
  String? get effectiveSourceName => initialSourceName;
  String? get effectiveBookAuthor => initialBookAuthor;
  String? get effectiveBookCoverUrl => initialBookCoverUrl;

  List<Chapter>? get effectiveInitialChapters => initialChapters;

  @override
  State<SimpleReaderView> createState() => _SimpleReaderViewState();
}

class _SimpleReaderViewState extends State<SimpleReaderView> {
  late final ChapterRepository _chapterRepo;
  late final BookRepository _bookRepo;
  late final SourceRepository _sourceRepo;
  late final ReplaceRuleService _replaceService;
  late final SettingsService _settingsService;
  final ScreenBrightnessService _brightnessService =
      ScreenBrightnessService.instance;
  final KeepScreenOnService _keepScreenOnService = KeepScreenOnService.instance;
  final RuleParserEngine _ruleEngine = RuleParserEngine();

  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  String _currentContent = '';
  String _currentTitle = '';

  // 阅读设置
  late ReadingSettings _settings;

  // UI 状态
  bool _showMenu = false;
  bool _showSearchMenu = false;
  SystemUiMode? _appliedSystemUiMode;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  final FocusNode _keyboardFocusNode = FocusNode();

  // 书签系统
  late final BookmarkRepository _bookmarkRepo;
  bool _hasBookmarkAtCurrent = false;

  // 自动阅读
  final AutoPager _autoPager = AutoPager();
  bool _showAutoReadPanel = false;

  // 当前书籍信息
  String _bookAuthor = '';
  String? _bookCoverUrl;
  String? _currentSourceUrl;
  String? _currentSourceName;

  // 翻页模式相关（对标 Legado PageFactory）
  final PageFactory _pageFactory = PageFactory();

  final _replaceStageCache = <String, _ReplaceStageCache>{};

  static const List<_TipOption> _headerTipOptions = [
    _TipOption(0, '书名'),
    _TipOption(1, '章节名'),
    _TipOption(2, '无'),
    _TipOption(3, '时间'),
    _TipOption(4, '电量'),
    _TipOption(5, '进度'),
    _TipOption(6, '页码'),
    _TipOption(7, '章节进度'),
    _TipOption(8, '页码/总页'),
    _TipOption(9, '时间+电量'),
  ];

  static const List<_TipOption> _footerTipOptions = [
    _TipOption(0, '进度'),
    _TipOption(1, '页码'),
    _TipOption(2, '时间'),
    _TipOption(3, '电量'),
    _TipOption(4, '无'),
    _TipOption(5, '章节名'),
    _TipOption(6, '书名'),
    _TipOption(7, '章节进度'),
    _TipOption(8, '页码/总页'),
    _TipOption(9, '时间+电量'),
  ];
  static const int _scrollUiSyncIntervalMs = 16;
  static const int _scrollSaveProgressIntervalMs = 450;
  static const int _scrollPreloadIntervalMs = 80;
  static const double _scrollPreloadExtent = 280.0;

  // 章节加载锁（用于翻页模式）
  bool _isLoadingChapter = false;
  bool _isRestoringProgress = false;
  bool _isHydratingChapterFromPageFactory = false;
  bool _chapterSeekConfirmed = false;
  final Map<String, Future<String>> _chapterContentInFlight =
      <String, Future<String>>{};
  ScrollLayoutSnapshot? _scrollLayoutSnapshot;
  int? _scrollLayoutChapterIndex;
  int _scrollLayoutFingerprint = 0;
  String _contentSearchQuery = '';
  List<_ReaderSearchHit> _contentSearchHits = <_ReaderSearchHit>[];
  int _currentSearchHitIndex = -1;
  final List<_ScrollSegment> _scrollSegments = <_ScrollSegment>[];
  final Map<int, GlobalKey> _scrollSegmentKeys = <int, GlobalKey>{};
  final Map<int, double> _scrollSegmentHeights = <int, double>{};
  final List<_ScrollSegmentOffsetRange> _scrollSegmentOffsetRanges =
      <_ScrollSegmentOffsetRange>[];
  final GlobalKey _scrollViewportKey =
      GlobalKey(debugLabel: 'reader_scroll_viewport');
  bool _scrollAppending = false;
  bool _scrollPrepending = false;
  bool _syncingScrollVisibleChapter = false;
  int? _pendingScrollTargetChapterIndex;
  double? _pendingScrollTargetChapterProgress;
  bool _pendingScrollJumpToEnd = false;
  int _pendingScrollJumpRetry = 0;
  double _currentScrollChapterProgress = 0.0;
  DateTime _lastScrollProgressSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastScrollUiSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastScrollPreloadCheckAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _programmaticScrollInFlight = false;
  double _scrollAnchorWithinViewport = 32.0;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _chapterRepo = ChapterRepository(db);
    _bookRepo = BookRepository(db);
    _sourceRepo = SourceRepository(db);
    _replaceService = ReplaceRuleService(db);
    _bookmarkRepo = BookmarkRepository();
    _settingsService = SettingsService();
    _settings = _settingsService.readingSettings.sanitize();
    _autoPager.setSpeed(_settings.autoReadSpeed);
    _autoPager.setMode(_settings.pageTurnMode == PageTurnMode.scroll
        ? AutoPagerMode.scroll
        : AutoPagerMode.page);

    _currentChapterIndex = widget.initialChapter;
    unawaited(() async {
      try {
        await _bookmarkRepo.init();
      } catch (_) {
        // ignore bookmark init failure; reader should still be usable
      }
      await _initReader();
    }());

    // 应用亮度设置（首帧后，避免部分机型窗口未就绪）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNativeBrightnessForSettings(
        const ReadingSettings(),
        _settings,
        force: true,
      );
      unawaited(_syncNativeKeepScreenOn(_settings));
    });

    // 初始化自动翻页器
    _autoPager.setScrollController(_scrollController);
    _scrollController.addListener(_handleScrollControllerTick);
    _autoPager.setOnNextPage(() {
      if (_settings.pageTurnMode == PageTurnMode.scroll) {
        unawaited(_scrollPage(up: false));
        return;
      }
      if (_currentChapterIndex < _chapters.length - 1) {
        _loadChapter(_currentChapterIndex + 1);
      }
    });

    // 全屏沉浸
    _applySystemUiMode(SystemUiMode.immersiveSticky, force: true);
  }

  Future<void> _initReader() async {
    final book = _bookRepo.getBookById(widget.bookId);
    _bookAuthor = widget.effectiveBookAuthor ?? book?.author ?? _bookAuthor;
    _bookCoverUrl = widget.effectiveBookCoverUrl ?? book?.coverUrl;
    _currentSourceUrl =
        (widget.effectiveSourceUrl ?? book?.sourceUrl ?? book?.sourceId)
            ?.trim();
    _currentSourceName = widget.effectiveSourceName?.trim().isNotEmpty == true
        ? widget.effectiveSourceName!.trim()
        : null;
    _refreshCurrentSourceName();

    if (widget.effectiveInitialChapters != null &&
        widget.effectiveInitialChapters!.isNotEmpty) {
      _chapters = widget.effectiveInitialChapters!.toList(growable: false)
        ..sort((a, b) => a.index.compareTo(b.index));
    } else {
      _chapters = _chapterRepo.getChaptersForBook(widget.bookId);
    }
    if (_chapters.isNotEmpty) {
      if (_currentChapterIndex >= _chapters.length) {
        _currentChapterIndex = 0;
      }

      final source = _sourceRepo.getSourceByUrl(_currentSourceUrl ?? '');
      _currentSourceName = source?.bookSourceName;

      // 初始化 PageFactory：设置章节数据
      final chapterDataList = _chapters
          .map((c) => ChapterData(
                title: c.title,
                content: _postProcessContent(c.content ?? '', c.title),
              ))
          .toList();
      _pageFactory.setChapters(chapterDataList, _currentChapterIndex);

      // 监听章节变化
      _pageFactory.addContentChangedListener(
        _handlePageFactoryContentChanged,
      );

      await _loadChapter(_currentChapterIndex, restoreOffset: true);
    }
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _pageFactory.removeContentChangedListener(_handlePageFactoryContentChanged);
    _saveProgress();
    _scrollController.removeListener(_handleScrollControllerTick);
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    _autoPager.dispose();
    // 离开阅读器时恢复系统亮度（iOS 还原原始亮度；Android 还原窗口亮度为跟随系统）
    unawaited(_brightnessService.resetToSystem());
    unawaited(_syncNativeKeepScreenOn(const ReadingSettings()));
    _applySystemUiMode(SystemUiMode.edgeToEdge, force: true);
    super.dispose();
  }

  void _applySystemUiMode(SystemUiMode mode, {bool force = false}) {
    if (!force && _appliedSystemUiMode == mode) return;
    _appliedSystemUiMode = mode;
    SystemChrome.setEnabledSystemUIMode(mode);
  }

  void _syncSystemUiForOverlay() {
    final hasOverlay = _showMenu || _showSearchMenu;
    _applySystemUiMode(
      hasOverlay ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _setReaderMenuVisible(bool visible) {
    if (_showMenu == visible) {
      _syncSystemUiForOverlay();
      return;
    }
    setState(() {
      _showMenu = visible;
      if (visible) {
        _showSearchMenu = false;
      }
    });
    _syncSystemUiForOverlay();
  }

  void _setSearchMenuVisible(bool visible) {
    if (_showSearchMenu == visible) {
      _syncSystemUiForOverlay();
      return;
    }
    setState(() {
      _showSearchMenu = visible;
      if (visible) {
        _showMenu = false;
      }
    });
    _syncSystemUiForOverlay();
  }

  void _toggleReaderMenuVisible() {
    _setReaderMenuVisible(!_showMenu);
  }

  double _safeBrightnessValue(double value, {double fallback = 1.0}) {
    final safeRaw = value.isFinite ? value : fallback;
    return safeRaw.clamp(0.0, 1.0).toDouble();
  }

  double _safeSliderValue(
    double value, {
    required double min,
    required double max,
    double? fallback,
  }) {
    final safeMin = min.isFinite ? min : 0.0;
    final safeMax = max.isFinite && max > safeMin ? max : safeMin + 1.0;
    final safeFallback = fallback ?? safeMin;
    final safeRaw = value.isFinite ? value : safeFallback;
    return safeRaw.clamp(safeMin, safeMax).toDouble();
  }

  void _syncNativeBrightnessForSettings(
    ReadingSettings oldSettings,
    ReadingSettings newSettings, {
    bool force = false,
  }) {
    if (!_brightnessService.supportsNative) return;

    final systemChanged =
        oldSettings.useSystemBrightness != newSettings.useSystemBrightness;
    final valueChanged = oldSettings.brightness != newSettings.brightness;

    if (!force && !systemChanged && !valueChanged) return;

    if (newSettings.useSystemBrightness) {
      unawaited(_brightnessService.resetToSystem());
      return;
    }

    // 手动亮度：仅在关闭“跟随系统”时生效
    unawaited(
      _brightnessService.setBrightness(
        _safeBrightnessValue(newSettings.brightness),
      ),
    );
  }

  Future<void> _syncNativeKeepScreenOn(ReadingSettings settings) async {
    await _keepScreenOnService.setEnabled(settings.keepScreenOn);
  }

  /// 保存进度：章节 + 滚动偏移
  Future<void> _saveProgress() async {
    if (_chapters.isEmpty) return;

    final progress = (_currentChapterIndex + 1) / _chapters.length;
    final chapterProgress = _getChapterProgress();

    // 保存到书籍库
    await _bookRepo.updateReadProgress(
      widget.bookId,
      currentChapter: _currentChapterIndex,
      readProgress: progress,
    );

    // 保存滚动偏移量
    if (_scrollController.hasClients) {
      await _settingsService.saveScrollOffset(
        widget.bookId,
        _scrollController.offset,
        chapterIndex: _currentChapterIndex,
      );
    }

    await _settingsService.saveChapterPageProgress(
      widget.bookId,
      chapterIndex: _currentChapterIndex,
      progress: chapterProgress,
    );
  }

  GlobalKey _scrollSegmentKeyFor(int chapterIndex) {
    return _scrollSegmentKeys.putIfAbsent(
      chapterIndex,
      () => GlobalKey(debugLabel: 'scroll_segment_$chapterIndex'),
    );
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
    final processedContent = _postProcessContent(stage.content, stage.title);

    return _ScrollSegment(
      chapterIndex: chapterIndex,
      chapterId: chapter.id,
      title: stage.title,
      content: processedContent,
    );
  }

  Future<void> _initializeScrollSegments({
    required int centerIndex,
    required bool restoreOffset,
    required bool goToLastPage,
    double? targetChapterProgress,
  }) async {
    if (_chapters.isEmpty) return;
    final start = (centerIndex - 1).clamp(0, _chapters.length - 1);
    final end = (centerIndex + 1).clamp(0, _chapters.length - 1);
    final segments = <_ScrollSegment>[];
    for (var i = start; i <= end; i++) {
      segments.add(
        await _loadScrollSegment(
          i,
          showLoading: i == centerIndex,
        ),
      );
    }
    if (!mounted) return;
    final centerSegment = segments.firstWhere(
      (segment) => segment.chapterIndex == centerIndex,
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
      chapterIndex: centerIndex,
    );
    final preferredProgress = targetChapterProgress ??
        (restoreOffset ? savedProgress : (goToLastPage ? null : 0.0));

    _pendingScrollTargetChapterIndex = centerIndex;
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
    final fallbackHeight = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
            .clamp(1.0, double.infinity)
            .toDouble()
        : 600.0;
    var cursor = 0.0;
    for (final segment in _scrollSegments) {
      final measuredHeight = _scrollSegmentHeights[segment.chapterIndex];
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
    final topInset = MediaQuery.of(context).padding.top;
    final targetGlobalAnchor = topInset + 110.0;
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
      minIntervalMs: _scrollUiSyncIntervalMs,
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
      minIntervalMs: _scrollPreloadIntervalMs,
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
    if (metrics.maxScrollExtent - metrics.pixels <= _scrollPreloadExtent) {
      unawaited(_appendNextScrollSegmentIfNeeded());
    }
    if (metrics.pixels - metrics.minScrollExtent <= _scrollPreloadExtent) {
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

      setState(() {
        _currentChapterIndex = chosen.chapterIndex;
        _currentTitle = chosen.title;
        _currentContent = chosen.content;
        _currentScrollChapterProgress = chosenProgress;
      });
      if (chapterChanged) {
        _updateBookmarkStatus();
      }

      if (saveProgress) {
        final now = DateTime.now();
        if (now.difference(_lastScrollProgressSyncAt).inMilliseconds >=
            _scrollSaveProgressIntervalMs) {
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
    final lastIndex = _scrollSegments.last.chapterIndex;
    if (lastIndex >= _chapters.length - 1) return;
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
    if (index < 0 || index >= _chapters.length) return;

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
        _syncPageFactoryChapters();
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
    final processedContent = _postProcessContent(stage.content, stage.title);
    setState(() {
      _currentChapterIndex = index;
      _currentTitle = stage.title;
      _currentContent = processedContent;
      _invalidateScrollLayoutSnapshot();
    });
    _updateBookmarkStatus();

    _syncPageFactoryChapters();
    unawaited(_prefetchNeighborChapters(centerIndex: index));

    // 如果是非滚动模式，需要在build后进行分页
    _isRestoringProgress = restoreOffset;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_settings.pageTurnMode != PageTurnMode.scroll) {
        _paginateContent();

        // 使用PageFactory跳转章节（自动处理goToLastPage）
        _pageFactory.jumpToChapter(index, goToLastPage: goToLastPage);

        if (restoreOffset && !goToLastPage) {
          final savedChapterProgress = _settingsService.getChapterPageProgress(
            widget.bookId,
            chapterIndex: index,
          );
          final totalPages = _pageFactory.totalPages;
          if (totalPages > 0) {
            final targetPage = ChapterProgressUtils.pageIndexFromProgress(
              progress: savedChapterProgress,
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

  void _syncPageFactoryChapters({bool keepPosition = false}) {
    final chapterDataList = _chapters.map((chapter) {
      final cached = _replaceStageCache[chapter.id];
      final title = cached?.title ?? chapter.title;
      final content = cached?.content ?? (chapter.content ?? '');
      return ChapterData(
        title: title,
        content: _postProcessContent(content, title),
      );
    }).toList();
    if (keepPosition) {
      _pageFactory.replaceChaptersKeepingPosition(chapterDataList);
    } else {
      _pageFactory.setChapters(chapterDataList, _currentChapterIndex);
    }
  }

  void _handlePageFactoryContentChanged() {
    if (!mounted || _chapters.isEmpty) return;

    final factoryChapterIndex = _pageFactory.currentChapterIndex;
    if (factoryChapterIndex < 0 || factoryChapterIndex >= _chapters.length) {
      return;
    }

    final chapterChanged = factoryChapterIndex != _currentChapterIndex;
    setState(() {
      _currentChapterIndex = factoryChapterIndex;
      _currentTitle = _pageFactory.currentChapterTitle;
    });
    unawaited(_saveProgress());
    if (chapterChanged) {
      unawaited(_prefetchNeighborChapters(centerIndex: factoryChapterIndex));
    }

    if (!chapterChanged || _isHydratingChapterFromPageFactory) return;

    final chapter = _chapters[factoryChapterIndex];
    final hasContent = (chapter.content ?? '').trim().isNotEmpty;
    if (hasContent) return;
    if (_chapterContentInFlight.containsKey(chapter.id)) return;

    unawaited(_hydrateCurrentFactoryChapter(factoryChapterIndex));
  }

  Future<void> _hydrateCurrentFactoryChapter(int index) async {
    if (_isHydratingChapterFromPageFactory) return;
    if (index < 0 || index >= _chapters.length) return;

    _isHydratingChapterFromPageFactory = true;
    try {
      await _loadChapter(index);
    } finally {
      _isHydratingChapterFromPageFactory = false;
    }
  }

  Future<void> _prefetchNeighborChapters({required int centerIndex}) async {
    if (centerIndex < 0 || centerIndex >= _chapters.length) return;

    final tasks = <Future<void>>[];
    final prevIndex = centerIndex - 1;
    if (prevIndex >= 0) {
      tasks.add(_prefetchChapterIfNeeded(prevIndex));
    }
    final nextIndex = centerIndex + 1;
    if (nextIndex < _chapters.length) {
      tasks.add(_prefetchChapterIfNeeded(nextIndex));
    }
    if (tasks.isEmpty) return;

    await Future.wait(tasks);
  }

  Future<void> _prefetchChapterIfNeeded(int index) async {
    if (index < 0 || index >= _chapters.length) return;

    final chapter = _chapters[index];
    if ((chapter.content ?? '').trim().isNotEmpty) return;
    if (_chapterContentInFlight.containsKey(chapter.id)) return;

    final book = _bookRepo.getBookById(widget.bookId);
    final chapterUrl = (chapter.url ?? '').trim();
    final canFetchFromSource = chapterUrl.isNotEmpty &&
        (book == null || !book.isLocal) &&
        _resolveActiveSourceUrl(book).isNotEmpty;
    if (!canFetchFromSource) return;

    try {
      final content = await _fetchChapterContent(
        chapter: chapter,
        index: index,
        book: book,
        showLoading: false,
      );
      if (content.trim().isEmpty) return;

      await _computeReplaceStage(
        chapterId: chapter.id,
        rawTitle: chapter.title,
        rawContent: content,
      );

      if (!mounted) return;
      _syncPageFactoryChapters(keepPosition: true);
      if (_settings.pageTurnMode != PageTurnMode.scroll) {
        _paginateContentLogicOnly();
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
    try {
      return await task;
    } finally {
      if (identical(_chapterContentInFlight[chapter.id], task)) {
        _chapterContentInFlight.remove(chapter.id);
      }
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

    _currentSourceUrl = source.bookSourceUrl;
    _currentSourceName = source.bookSourceName;

    if (showLoading && mounted) {
      setState(() => _isLoadingChapter = true);
    }

    String content = chapter.content ?? '';
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

  /// 将内容分页（使用 PageFactory 对标 Legado）
  /// 将内容分页（使用 PageFactory 对标 Legado）
  void _paginateContent() {
    if (!mounted) return;
    _paginateContentLogicOnly();
    setState(() {});
  }

  /// 仅执行分页计算逻辑，不触发 setState (用于在 setState 内部调用)
  void _paginateContentLogicOnly() {
    // 获取屏幕可用尺寸
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeArea = MediaQuery.of(context).padding;

    // 对标 flutter_reader 的布局计算
    final showHeader = _settings.showStatusBar && !_settings.hideHeader;
    final showFooter = _settings.showStatusBar && !_settings.hideFooter;
    final topOffset = showHeader ? PagedReaderWidget.topOffset : 0.0;
    final bottomOffset = showFooter ? PagedReaderWidget.bottomOffset : 0.0;

    final contentHeight = screenHeight -
        safeArea.top -
        topOffset -
        safeArea.bottom -
        bottomOffset -
        _settings.paddingTop -
        _settings.paddingBottom;
    final contentWidth =
        screenWidth - _settings.paddingLeft - _settings.paddingRight;

    // 防止宽度过小导致死循环或异常
    if (contentWidth < 50 || contentHeight < 100) return;

    // 使用 PageFactory 进行三章节分页
    _pageFactory.setLayoutParams(
      contentHeight: contentHeight,
      contentWidth: contentWidth,
      fontSize: _settings.fontSize,
      lineHeight: _settings.lineHeight,
      letterSpacing: _settings.letterSpacing,
      paragraphSpacing: _settings.paragraphSpacing, // 传递段间距
      fontFamily: _currentFontFamily,
      // 对标 legado：缩进属于“排版参数”，由分页排版层统一处理
      paragraphIndent: _settings.paragraphIndent,
      textAlign: _bodyTextAlign,
      titleFontSize: _settings.fontSize + _settings.titleSize,
      titleAlign: _titleTextAlign,
      titleTopSpacing:
          _settings.titleTopSpacing > 0 ? _settings.titleTopSpacing : 20,
      titleBottomSpacing: _settings.titleBottomSpacing > 0
          ? _settings.titleBottomSpacing
          : _settings.paragraphSpacing * 1.5,
      fontWeight: _currentFontWeight,
      underline: _settings.underline,
      showTitle: _settings.titleMode != 2,
    );
    _pageFactory.paginateAll();
  }

  /// 更新设置
  void _updateSettings(ReadingSettings newSettings) {
    newSettings = newSettings.sanitize();

    // 产品约束：除“滚动”外一律水平翻页；滚动模式固定纵向滚动。
    if (newSettings.pageTurnMode == PageTurnMode.scroll) {
      if (newSettings.pageDirection != PageDirection.vertical) {
        newSettings =
            newSettings.copyWith(pageDirection: PageDirection.vertical);
      }
    } else {
      if (newSettings.pageDirection != PageDirection.horizontal) {
        newSettings =
            newSettings.copyWith(pageDirection: PageDirection.horizontal);
      }
    }

    final oldSettings = _settings;
    final oldMode = oldSettings.pageTurnMode;
    final newMode = newSettings.pageTurnMode;
    final modeChanged = oldMode != newMode;

    double? desiredChapterProgress;
    if (modeChanged) {
      if (oldMode == PageTurnMode.scroll) {
        desiredChapterProgress =
            _currentScrollChapterProgress.clamp(0.0, 1.0).toDouble();
      } else {
        final total = _pageFactory.totalPages;
        desiredChapterProgress = ChapterProgressUtils.pageProgressFromIndex(
          pageIndex: _pageFactory.currentPageIndex,
          totalPages: total,
        );
      }
    }
    // 检查是否需要重新分页
    // 1. 从滚动模式切换到翻页模式
    // 2. 也是翻页模式且排版参数变更
    bool needRepaginate = false;

    final contentTransformChanged =
        oldSettings.cleanChapterTitle != newSettings.cleanChapterTitle ||
            oldSettings.chineseTraditional != newSettings.chineseTraditional ||
            oldSettings.paragraphIndent != newSettings.paragraphIndent;

    if (oldSettings.pageTurnMode == PageTurnMode.scroll &&
        newSettings.pageTurnMode != PageTurnMode.scroll) {
      needRepaginate = true;
    } else if (newSettings.pageTurnMode != PageTurnMode.scroll) {
      if (oldSettings.fontSize != newSettings.fontSize ||
          oldSettings.lineHeight != newSettings.lineHeight ||
          oldSettings.letterSpacing != newSettings.letterSpacing ||
          oldSettings.paragraphSpacing !=
              newSettings.paragraphSpacing || // 监听段间距变化
          oldSettings.paddingLeft != newSettings.paddingLeft ||
          oldSettings.paddingRight != newSettings.paddingRight ||
          oldSettings.paddingTop != newSettings.paddingTop ||
          oldSettings.paddingBottom != newSettings.paddingBottom ||
          oldSettings.paragraphIndent != newSettings.paragraphIndent ||
          oldSettings.textFullJustify != newSettings.textFullJustify ||
          oldSettings.titleMode != newSettings.titleMode ||
          oldSettings.titleSize != newSettings.titleSize ||
          oldSettings.titleTopSpacing != newSettings.titleTopSpacing ||
          oldSettings.titleBottomSpacing != newSettings.titleBottomSpacing ||
          oldSettings.textBold != newSettings.textBold ||
          oldSettings.underline != newSettings.underline ||
          oldSettings.fontFamilyIndex != newSettings.fontFamilyIndex ||
          // fontFamily 变化通常意味着需要全量刷新，但也需要重排
          oldSettings.themeIndex !=
              newSettings.themeIndex || // 主题变化可能影响字体? 暂时不用
          contentTransformChanged) {
        needRepaginate = true;
      }
    }

    setState(() {
      _settings = newSettings;
      if (contentTransformChanged && _chapters.isNotEmpty) {
        final chapter = _chapters[_currentChapterIndex];
        final cached = _replaceStageCache[chapter.id];
        final title = cached?.title ?? chapter.title;
        final content = cached?.content ?? (chapter.content ?? '');
        _currentTitle = title;
        _currentContent = _postProcessContent(content, title);
      }
      if (contentTransformChanged) {
        _syncPageFactoryChapters(
          keepPosition: newSettings.pageTurnMode != PageTurnMode.scroll,
        );
      }
      if (needRepaginate) {
        _paginateContentLogicOnly();
      }
      _invalidateScrollLayoutSnapshot();
    });
    if (oldSettings.autoReadSpeed != newSettings.autoReadSpeed) {
      _autoPager.setSpeed(newSettings.autoReadSpeed);
    }
    if (oldSettings.pageTurnMode != newSettings.pageTurnMode) {
      _autoPager.setMode(newSettings.pageTurnMode == PageTurnMode.scroll
          ? AutoPagerMode.scroll
          : AutoPagerMode.page);
    }
    _syncNativeBrightnessForSettings(oldSettings, newSettings);
    if (oldSettings.keepScreenOn != newSettings.keepScreenOn) {
      unawaited(_syncNativeKeepScreenOn(newSettings));
    }
    unawaited(_settingsService.saveReadingSettings(newSettings));
    if (!modeChanged && contentTransformChanged) {
      _syncScrollSegmentsAfterTransformChange();
    }

    if (modeChanged) {
      final progress = desiredChapterProgress ?? 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (newMode == PageTurnMode.scroll) {
          unawaited(
            _loadChapter(
              _currentChapterIndex,
              restoreOffset: false,
              targetChapterProgress: progress,
            ),
          );
          return;
        }

        final total = _pageFactory.totalPages;
        if (total <= 0) return;
        final target = ChapterProgressUtils.pageIndexFromProgress(
          progress: progress,
          totalPages: total,
        );
        if (target != _pageFactory.currentPageIndex) {
          _pageFactory.jumpToPage(target);
        }
      });
    }
  }

  /// 获取当前主题
  ReadingThemeColors get _currentTheme {
    final index = _settings.themeIndex;
    if (index >= 0 && index < AppColors.readingThemes.length) {
      return AppColors.readingThemes[index];
    }
    return AppColors.readingThemes[0];
  }

  bool get _isUiDark => _currentTheme.isDark;

  Color get _uiAccent =>
      _isUiDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _uiPanelBg =>
      _isUiDark ? const Color(0xFF1C1C1E) : AppDesignTokens.surfaceLight;

  Color get _uiCardBg => _isUiDark
      ? CupertinoColors.white.withValues(alpha: 0.1)
      : AppDesignTokens.pageBgLight.withValues(alpha: 0.9);

  Color get _uiBorder => _isUiDark
      ? CupertinoColors.white.withValues(alpha: 0.12)
      : AppDesignTokens.borderLight;

  Color get _uiTextStrong =>
      _isUiDark ? CupertinoColors.white : AppDesignTokens.textStrong;

  Color get _uiTextNormal => _isUiDark
      ? CupertinoColors.white.withValues(alpha: 0.7)
      : AppDesignTokens.textNormal;

  Color get _uiTextSubtle => _isUiDark
      ? CupertinoColors.white.withValues(alpha: 0.54)
      : AppDesignTokens.textMuted;

  /// 获取当前字体
  String? get _currentFontFamily {
    final family = ReadingFontFamily.getFontFamily(_settings.fontFamilyIndex);
    return family.isEmpty ? null : family;
  }

  FontWeight get _currentFontWeight {
    switch (_settings.textBold) {
      case 1:
        return FontWeight.w600;
      case 2:
        return FontWeight.w300;
      default:
        return FontWeight.w400;
    }
  }

  TextDecoration get _currentTextDecoration =>
      _settings.underline ? TextDecoration.underline : TextDecoration.none;

  TextAlign get _bodyTextAlign =>
      _settings.textFullJustify ? TextAlign.justify : TextAlign.left;

  TextAlign get _titleTextAlign =>
      _settings.titleMode == 1 ? TextAlign.center : TextAlign.left;

  EdgeInsets get _contentPadding => EdgeInsets.fromLTRB(
        _settings.paddingLeft,
        _settings.paddingTop,
        _settings.paddingRight,
        _settings.paddingBottom,
      );

  Map<String, int> get _clickActions {
    final config = Map<String, int>.from(ClickAction.defaultZoneConfig);
    config.addAll(_settings.clickActions);
    return config;
  }

  /// 左右点击翻页处理
  void _handleTap(TapUpDetails details) {
    if (_showSearchMenu) {
      _setSearchMenuVisible(false);
      return;
    }
    if (_showMenu) {
      _setReaderMenuVisible(false);
      return;
    }
    final action = _resolveClickAction(details.globalPosition);
    _handleClickAction(action);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_settings.volumeKeyPage) return;
    if (_showMenu || _showSearchMenu || _showAutoReadPanel) return;
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.audioVolumeDown ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      _handlePageStep(next: true);
    } else if (key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      _handlePageStep(next: false);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (_showMenu || _showSearchMenu || _showAutoReadPanel) return;
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scrollEvent = resolved as PointerScrollEvent;
      final dy = scrollEvent.scrollDelta.dy;
      if (dy > 0) {
        _handlePageStep(next: true);
      } else if (dy < 0) {
        _handlePageStep(next: false);
      }
    });
  }

  void _handlePageStep({required bool next}) {
    if (_settings.pageTurnMode == PageTurnMode.scroll) {
      _scrollPage(up: !next);
      return;
    }
    final moved = next ? _pageFactory.moveToNext() : _pageFactory.moveToPrev();
    if (moved && mounted) {
      setState(() {});
    }
  }

  int _resolveClickAction(Offset position) {
    final size = MediaQuery.of(context).size;
    final col = (position.dx / size.width * 3).floor().clamp(0, 2);
    final row = (position.dy / size.height * 3).floor().clamp(0, 2);
    const zones = [
      ['tl', 'tc', 'tr'],
      ['ml', 'mc', 'mr'],
      ['bl', 'bc', 'br'],
    ];
    final zone = zones[row][col];
    return _clickActions[zone] ?? ClickAction.showMenu;
  }

  void _handleClickAction(int action) {
    switch (action) {
      case ClickAction.showMenu:
        _setReaderMenuVisible(true);
        break;
      case ClickAction.nextPage:
        _handlePageStep(next: true);
        break;
      case ClickAction.prevPage:
        _handlePageStep(next: false);
        break;
      case ClickAction.nextChapter:
        _nextChapter();
        break;
      case ClickAction.prevChapter:
        _previousChapter();
        break;
      case ClickAction.addBookmark:
        _toggleBookmark();
        break;
      case ClickAction.openChapterList:
        _showChapterList();
        break;
      default:
        _setReaderMenuVisible(true);
    }
  }

  void _nextChapter() {
    if (_chapters.isEmpty) return;
    if (_currentChapterIndex < _chapters.length - 1) {
      _loadChapter(_currentChapterIndex + 1);
    }
  }

  void _previousChapter() {
    if (_chapters.isEmpty) return;
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    }
  }

  void _invalidateScrollLayoutSnapshot() {
    _scrollLayoutSnapshot = null;
    _scrollLayoutChapterIndex = null;
    _scrollLayoutFingerprint = 0;
  }

  int _buildScrollLayoutFingerprint(double contentWidth) {
    return Object.hashAll([
      _currentChapterIndex,
      _currentTitle.hashCode,
      _currentContent.hashCode,
      contentWidth.toStringAsFixed(2),
      _settings.fontSize,
      _settings.lineHeight,
      _settings.letterSpacing,
      _settings.paragraphSpacing,
      _settings.paragraphIndent,
      _settings.titleMode,
      _settings.titleSize,
      _settings.titleTopSpacing,
      _settings.titleBottomSpacing,
      _settings.paddingTop,
      _settings.paddingBottom,
      _settings.textBold,
      _settings.underline,
      _settings.fontFamilyIndex,
      _settings.textFullJustify,
      _settings.showStatusBar,
    ]);
  }

  ScrollLayoutSnapshot _ensureScrollLayoutSnapshot(double contentWidth) {
    if (contentWidth <= 1) {
      return const ScrollLayoutSnapshot.empty();
    }
    final fingerprint = _buildScrollLayoutFingerprint(contentWidth);
    final cached = _scrollLayoutSnapshot;
    if (cached != null &&
        _scrollLayoutChapterIndex == _currentChapterIndex &&
        _scrollLayoutFingerprint == fingerprint) {
      return cached;
    }

    final titleTopSpacing =
        _settings.titleTopSpacing > 0 ? _settings.titleTopSpacing : 20.0;
    final titleBottomSpacing = _settings.titleBottomSpacing > 0
        ? _settings.titleBottomSpacing
        : _settings.paragraphSpacing * 1.5;

    final snapshot = ScrollPageStepCalculator.buildLayoutSnapshot(
      title: _currentTitle,
      content: _currentContent,
      showTitle: _settings.titleMode != 2,
      maxWidth: contentWidth,
      paddingTop: _settings.paddingTop,
      paddingBottom:
          _settings.showStatusBar ? 30.0 : _settings.paddingBottom.toDouble(),
      paragraphSpacing: _settings.paragraphSpacing,
      titleTopSpacing: titleTopSpacing,
      titleBottomSpacing: titleBottomSpacing,
      // 对齐滚动正文尾部结构（章节导航与留白）
      trailingSpacing: 192.0,
      paragraphStyle: TextStyle(
        fontSize: _settings.fontSize,
        height: _settings.lineHeight,
        color: _currentTheme.text,
        letterSpacing: _settings.letterSpacing,
        fontFamily: _currentFontFamily,
        fontWeight: _currentFontWeight,
        decoration: _currentTextDecoration,
      ),
      titleStyle: TextStyle(
        fontSize: _settings.fontSize + _settings.titleSize,
        fontWeight: FontWeight.w600,
        color: _currentTheme.text,
        fontFamily: _currentFontFamily,
      ),
      paragraphTextAlign: _bodyTextAlign,
      titleTextAlign: _titleTextAlign,
    );

    _scrollLayoutSnapshot = snapshot;
    _scrollLayoutChapterIndex = _currentChapterIndex;
    _scrollLayoutFingerprint = fingerprint;
    return snapshot;
  }

  Future<void> _scrollPage({required bool up}) async {
    if (!_scrollController.hasClients) return;

    final viewportHeight = _scrollController.position.viewportDimension;
    if (viewportHeight <= 1) return;
    final currentOffset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;

    final screenSize = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;
    final contentWidth = screenSize.width -
        safePadding.left -
        safePadding.right -
        _settings.paddingLeft -
        _settings.paddingRight;
    final snapshot = _ensureScrollLayoutSnapshot(contentWidth);
    final stepResult = up
        ? ScrollPageStepCalculator.computePrevStep(
            snapshot: snapshot,
            visibleTop: currentOffset,
            viewportHeight: viewportHeight,
          )
        : ScrollPageStepCalculator.computeNextStep(
            snapshot: snapshot,
            visibleTop: currentOffset,
            viewportHeight: viewportHeight,
          );
    final step = stepResult.step.clamp(1.0, viewportHeight).toDouble();
    final targetOffset = up ? currentOffset - step : currentOffset + step;

    final autoPagingRunning = _autoPager.isRunning;
    if (autoPagingRunning) {
      _autoPager.pause();
    }

    if (!up && targetOffset >= maxOffset - 1) {
      await _appendNextScrollSegmentIfNeeded();
    } else if (up && targetOffset <= 1) {
      await _prependPrevScrollSegmentIfNeeded();
    }

    if (!_scrollController.hasClients) {
      if (autoPagingRunning && mounted) {
        _autoPager.start();
      }
      return;
    }

    final minOffset = _scrollController.position.minScrollExtent;
    final latestMaxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset =
        targetOffset.clamp(minOffset, latestMaxOffset).toDouble();
    _programmaticScrollInFlight = true;
    try {
      if (_settings.noAnimScrollPage) {
        _scrollController.jumpTo(clampedOffset);
      } else {
        await _scrollController.animateTo(
          clampedOffset,
          duration: Duration(
            milliseconds: _settings.pageAnimDuration <= 0
                ? 1
                : _settings.pageAnimDuration,
          ),
          curve: Curves.linear,
        );
      }
    } finally {
      _programmaticScrollInFlight = false;
    }

    if (mounted) {
      _syncCurrentChapterFromScroll(saveProgress: true);
    }
    if (autoPagingRunning && mounted) {
      _autoPager.start();
    }
  }

  /// 获取当前时间字符串
  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _postProcessContent(String content, String processedTitle) {
    var processed = content;
    if (_settings.cleanChapterTitle) {
      processed = _removeDuplicateTitle(processed, processedTitle);
    }
    if (_settings.chineseTraditional) {
      processed = _convertToTraditional(processed);
    }
    processed = _formatContentLikeLegado(processed);
    return processed;
  }

  Future<_ReplaceStageCache> _computeReplaceStage({
    required String chapterId,
    required String rawTitle,
    required String rawContent,
  }) async {
    final cached = _replaceStageCache[chapterId];
    if (cached != null &&
        cached.rawTitle == rawTitle &&
        cached.rawContent == rawContent) {
      return cached;
    }

    final title = await _replaceService.applyTitle(
      rawTitle,
      bookName: widget.bookTitle,
      sourceUrl: _currentSourceUrl,
    );
    final content = await _replaceService.applyContent(
      rawContent,
      bookName: widget.bookTitle,
      sourceUrl: _currentSourceUrl,
    );

    final stage = _ReplaceStageCache(
      rawTitle: rawTitle,
      rawContent: rawContent,
      title: title,
      content: content,
    );
    _replaceStageCache[chapterId] = stage;
    return stage;
  }

  /// 参考 Legado 的正文处理方式，对章节内容进行“段落化”格式化：
  /// - 清理段落首尾空白
  /// - 压缩多余换行（段落之间仅保留一个换行）
  ///
  /// 额外兼容：清理常见 HTML 空白实体（&emsp; 等），避免缩进显示异常。
  ///
  /// 注意：段首缩进不在这里“改文本”完成，而是交给渲染层按 `ReadingSettings.paragraphIndent`
  /// 做“首行缩进”。原因：
  /// - Flutter 的 `TextAlign.justify` 等对“前导空格”显示不稳定，容易出现看起来不缩进
  /// - 对标 legado：其翻页排版会根据配置计算缩进宽度，而不是依赖文本里塞空格
  String _formatContentLikeLegado(String content) {
    var text = content;

    // 兼容常见 HTML 空白实体（部分书源会残留在纯文本中）
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&ensp;', ' ')
        .replaceAll('&emsp;', ' ')
        .replaceAll('&thinsp;', '')
        .replaceAll('&zwnj;', '')
        .replaceAll('&zwj;', '')
        // 对应 Legado 的 noPrintRegex 中的几个常见字符
        .replaceAll('\u2009', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '');

    text = text.replaceAll('\r\n', '\n');

    // 等价于 Legado HtmlFormatter 的 `\\s*\\n+\\s*`：忽略多余空白与多换行
    final rawParagraphs = text.split(RegExp(r'\s*\n+\s*'));
    final paragraphs = rawParagraphs
        // 对齐 legado：trim 规则不仅去掉常规空白，也要去掉全角空格（U+3000，常用于缩进）
        .map(_trimParagraphLikeLegado)
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    if (paragraphs.isEmpty) return '';
    return paragraphs.join('\n');
  }

  /// 对齐 legado 的段落 trim 行为：
  /// - 去掉两端的 ASCII 控制字符/空格（<= 0x20）
  /// - 去掉两端的全角空格 `　`（U+3000）
  ///
  /// 说明：部分书源/EPUB 章节会把缩进写成全角空格；如果不清理，会导致“缩进叠加/段首错位”。
  String _trimParagraphLikeLegado(String input) {
    if (input.isEmpty) return '';
    var start = 0;
    var end = input.length;
    while (start < end) {
      final ch = input[start];
      final code = input.codeUnitAt(start);
      if (code <= 0x20 || ch == '　') {
        start++;
      } else {
        break;
      }
    }
    while (end > start) {
      final ch = input[end - 1];
      final code = input.codeUnitAt(end - 1);
      if (code <= 0x20 || ch == '　') {
        end--;
      } else {
        break;
      }
    }
    return input.substring(start, end);
  }

  String _removeDuplicateTitle(String content, String title) {
    if (content.isEmpty) return content;
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final trimmedTitle = title.trim();
    final index = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (index != -1) {
      final firstLine = lines[index].trim();
      if (firstLine == trimmedTitle || firstLine.contains(trimmedTitle)) {
        lines.removeAt(index);
      }
    }
    return lines.join('\n');
  }

  String _convertToTraditional(String content) {
    // TODO: 接入繁简转换库后替换为真实转换逻辑
    return content;
  }

  /// 计算章节内进度
  double _getChapterProgress() {
    if (_settings.pageTurnMode != PageTurnMode.scroll) {
      return ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: _pageFactory.currentPageIndex,
        totalPages: _pageFactory.totalPages,
      );
    }

    return _currentScrollChapterProgress.clamp(0.0, 1.0).toDouble();
  }

  double _getBookProgress() {
    if (_chapters.isEmpty) return 0;
    final chapterProgress = _getChapterProgress();
    return ((_currentChapterIndex + chapterProgress) / _chapters.length)
        .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return CupertinoPageScaffold(
        backgroundColor: _currentTheme.background,
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    // 获取屏幕尺寸，确保固定全屏布局
    final screenSize = MediaQuery.of(context).size;
    final isScrollMode = _settings.pageTurnMode == PageTurnMode.scroll;

    // 阅读模式时阻止 iOS 边缘滑动返回（菜单显示时允许返回）
    return PopScope(
      canPop: _showMenu || _showSearchMenu,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showSearchMenu) {
          _setSearchMenuVisible(false);
          return;
        }
        if (!_showMenu) {
          // 如果阻止了 pop 且菜单未显示，则显示菜单
          _setReaderMenuVisible(true);
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: _currentTheme.background,
        child: KeyboardListener(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: GestureDetector(
              // 只有滚动模式才使用外层的点击处理
              onTapUp: isScrollMode ? _handleTap : null,
              child: SizedBox(
                width: screenSize.width,
                height: screenSize.height,
                child: Stack(
                  children: [
                    // 阅读内容 - 固定全屏
                    Positioned.fill(
                      child: _buildReadingContent(),
                    ),

                    // 菜单打开时添加轻遮罩，提升层级感并支持点击空白关闭。
                    if (_showMenu || _showSearchMenu)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _showSearchMenu
                              ? () => _setSearchMenuVisible(false)
                              : _closeReaderMenuOverlay,
                          child: Container(
                            color:
                                const Color(0xFF000000).withValues(alpha: 0.14),
                          ),
                        ),
                      ),

                    // 底部状态栏 - 只在滚动模式显示（翻页模式由PagedReaderWidget内部处理）
                    if (_settings.showStatusBar &&
                        !_showMenu &&
                        !_showSearchMenu &&
                        !_showAutoReadPanel &&
                        isScrollMode)
                      ReaderStatusBar(
                        settings: _settings,
                        currentTheme: _currentTheme,
                        currentTime: _getCurrentTime(),
                        title: _currentTitle,
                        bookTitle: widget.bookTitle,
                        bookProgress: _getBookProgress(),
                        chapterProgress: _getChapterProgress(),
                        currentPage: 1,
                        totalPages: 1,
                      ),

                    // 顶部状态栏（滚动模式）
                    if (_settings.showStatusBar &&
                        !_showMenu &&
                        !_showSearchMenu &&
                        !_showAutoReadPanel &&
                        isScrollMode)
                      ReaderHeaderBar(
                        settings: _settings,
                        currentTheme: _currentTheme,
                        currentTime: _getCurrentTime(),
                        title: _currentTitle,
                        bookTitle: widget.bookTitle,
                        bookProgress: _getBookProgress(),
                        chapterProgress: _getChapterProgress(),
                        currentPage: 1,
                        totalPages: 1,
                      ),

                    // 顶部菜单
                    if (_showMenu)
                      ReaderTopMenu(
                        bookTitle: widget.bookTitle,
                        chapterTitle: _currentTitle,
                        sourceName: _currentSourceName,
                        onShowChapterList: _showChapterList,
                        onSearchContent: _showContentSearchDialog,
                        onSwitchSource: _showSwitchSourceMenu,
                        onToggleCleanChapterTitle:
                            _toggleCleanChapterTitleFromTopMenu,
                        onRefreshChapter: _refreshChapter,
                        onShowMoreMenu: _showReaderActionsMenu,
                        cleanChapterTitleEnabled: _settings.cleanChapterTitle,
                      ),

                    // 右侧悬浮快捷栏（对标同类阅读器）
                    if (_showMenu) _buildFloatingActionRail(),

                    // 底部菜单（章节进度 + 高频设置 + 导航）
                    if (_showMenu)
                      ReaderBottomMenuNew(
                        currentChapterIndex: _currentChapterIndex,
                        totalChapters: _chapters.length,
                        currentPageIndex: _pageFactory.currentPageIndex,
                        totalPages: _pageFactory.totalPages.clamp(1, 9999),
                        settings: _settings,
                        currentTheme: _currentTheme,
                        onChapterChanged: (index) => _loadChapter(index),
                        onPageChanged: (pageIndex) {
                          setState(() {
                            while (_pageFactory.currentPageIndex < pageIndex) {
                              if (!_pageFactory.moveToNext()) break;
                            }
                            while (_pageFactory.currentPageIndex > pageIndex) {
                              if (!_pageFactory.moveToPrev()) break;
                            }
                          });
                        },
                        onSeekChapterProgress: _seekByChapterProgress,
                        onSettingsChanged: (settings) =>
                            _updateSettings(settings),
                        onShowChapterList: _openChapterListFromMenu,
                        onShowReadAloud: _openReadAloudFromMenu,
                        onShowInterfaceSettings: _openInterfaceSettingsFromMenu,
                        onShowBehaviorSettings: _openBehaviorSettingsFromMenu,
                      ),

                    if (_showSearchMenu) _buildSearchMenuOverlay(),

                    if (_isLoadingChapter)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 12,
                        right: 16,
                        child: const CupertinoActivityIndicator(),
                      ),

                    // 自动阅读控制面板
                    if (_showAutoReadPanel)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AutoReadPanel(
                          autoPager: _autoPager,
                          onSpeedChanged: (speed) {
                            _updateSettings(
                              _settings.copyWith(autoReadSpeed: speed),
                            );
                          },
                          onClose: () {
                            setState(() {
                              _showAutoReadPanel = false;
                            });
                          },
                        ),
                      ),
                    Positioned.fill(
                      child: _buildBrightnessOverlay(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadingContent() {
    // 根据翻页模式选择渲染方式
    if (_settings.pageTurnMode != PageTurnMode.scroll) {
      return _buildPagedContent();
    }

    // 滚动模式
    return _buildScrollContent();
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
      pageFactory: _pageFactory,
      pageTurnMode: _settings.pageTurnMode,
      textStyle: TextStyle(
        fontSize: _settings.fontSize,
        height: _settings.lineHeight,
        color: _currentTheme.text,
        letterSpacing: _settings.letterSpacing,
        fontFamily: _currentFontFamily,
        fontWeight: _currentFontWeight,
        decoration: _currentTextDecoration,
      ),
      backgroundColor: _currentTheme.background,
      padding: _contentPadding,
      enableGestures: !_showMenu && !_showSearchMenu, // 菜单显示时禁止翻页手势
      onTap: () {
        if (_showSearchMenu) {
          _setSearchMenuVisible(false);
          return;
        }
        _toggleReaderMenuVisible();
      },
      showStatusBar: _settings.showStatusBar,
      settings: _settings,
      bookTitle: widget.bookTitle,
      // 翻页动画增强参数
      animDuration: _settings.pageAnimDuration,
      pageDirection: _settings.pageDirection,
      pageTouchSlop: _settings.pageTouchSlop,
      onAction: _handleClickAction,
      clickActions: _clickActions,
    );
  }

  /// 滚动模式内容（跨章节连续滚动，对齐 legado）
  Widget _buildScrollContent() {
    if (_scrollSegments.isEmpty) {
      return const SafeArea(
        bottom: false,
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) {
            return false;
          }

          if (notification is ScrollEndNotification && !_isRestoringProgress) {
            _syncCurrentChapterFromScroll(saveProgress: true);
            unawaited(_saveProgress());
          }
          return false;
        },
        child: SingleChildScrollView(
          key: _scrollViewportKey,
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _scrollSegments.length; i++)
                _buildScrollSegmentBody(
                  _scrollSegments[i],
                  isTailSegment: i == _scrollSegments.length - 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollSegmentBody(
    _ScrollSegment segment, {
    required bool isTailSegment,
  }) {
    final paragraphs = segment.content.split(RegExp(r'\n\s*\n|\n'));
    final paragraphStyle = TextStyle(
      fontSize: _settings.fontSize,
      height: _settings.lineHeight,
      color: _currentTheme.text,
      letterSpacing: _settings.letterSpacing,
      fontFamily: _currentFontFamily,
      fontWeight: _currentFontWeight,
      decoration: _currentTextDecoration,
    );

    return KeyedSubtree(
      key: _scrollSegmentKeyFor(segment.chapterIndex),
      child: Padding(
        padding: EdgeInsets.only(
          left: _settings.paddingLeft,
          right: _settings.paddingRight,
          top: _settings.paddingTop,
          bottom: isTailSegment
              ? (_settings.showStatusBar ? 30 : _settings.paddingBottom)
              : _settings.paddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_settings.titleMode != 2) ...[
              SizedBox(
                height: _settings.titleTopSpacing > 0
                    ? _settings.titleTopSpacing
                    : 20,
              ),
              Text(
                segment.title,
                textAlign: _titleTextAlign,
                style: TextStyle(
                  fontSize: _settings.fontSize + _settings.titleSize,
                  fontWeight: FontWeight.w600,
                  color: _currentTheme.text,
                  fontFamily: _currentFontFamily,
                ),
              ),
              SizedBox(
                height: _settings.titleBottomSpacing > 0
                    ? _settings.titleBottomSpacing
                    : _settings.paragraphSpacing * 1.5,
              ),
            ],
            ...paragraphs.map((paragraph) {
              final paragraphText = paragraph.trimRight();
              if (paragraphText.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(bottom: _settings.paragraphSpacing),
                child: _buildParagraphWithFirstLineIndent(
                  paragraphText,
                  style: paragraphStyle,
                ),
              );
            }),
            SizedBox(height: isTailSegment ? 80 : 24),
          ],
        ),
      ),
    );
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
  // ignore: unused_element
  Widget _buildFormattedContent() {
    // 按段落分割
    final paragraphs = _currentContent.split(RegExp(r'\n\s*\n|\n'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        final trimmed = paragraph.trim();
        if (trimmed.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(bottom: _settings.paragraphSpacing),
          child: Text(
            '　　$trimmed', // 首行缩进两个中文字符
            style: TextStyle(
              fontSize: _settings.fontSize,
              height: _settings.lineHeight,
              color: _currentTheme.text,
              letterSpacing: _settings.letterSpacing,
              fontFamily: _currentFontFamily,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 段落渲染（首行缩进，对标 legado 的 `paragraphIndent` 体验）
  Widget _buildParagraphWithFirstLineIndent(
    String paragraph, {
    required TextStyle style,
  }) {
    return LegacyJustifiedTextBlock(
      content: paragraph,
      style: style,
      justify: _settings.textFullJustify,
      paragraphIndent: _settings.paragraphIndent,
      applyParagraphIndent: true,
      preserveEmptyLines: false,
    );
  }

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
    _showReadingSettingsSheet(
      title: '界面',
      initialTab: 1,
      allowedTabs: const [0, 1],
    );
  }

  void _openBehaviorSettingsFromMenu() {
    _closeReaderMenuOverlay();
    _showReadingSettingsSheet(
      title: '设置',
      initialTab: 2,
      allowedTabs: const [2, 3],
    );
  }

  void _openReadAloudFromMenu() {
    _closeReaderMenuOverlay();
    final capability = _detectReadAloudCapability();
    if (!capability.available) {
      _showToast(capability.reason);
      return;
    }
    // 后续接入真实朗读流程时，从这里进入。
    _showToast('语音朗读即将上线');
  }

  Future<void> _seekByChapterProgress(int targetChapterIndex) async {
    if (_chapters.isEmpty) return;
    if (targetChapterIndex < 0 || targetChapterIndex >= _chapters.length) {
      return;
    }
    if (targetChapterIndex == _currentChapterIndex) return;

    if (_settings.progressBarBehavior == ProgressBarBehavior.chapter &&
        _settings.confirmSkipChapter &&
        !_chapterSeekConfirmed) {
      final confirmed = await showCupertinoDialog<bool>(
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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('阅读操作'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _showContentSearchDialog();
            },
            child: const Text('搜索正文'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              setState(() {
                _showAutoReadPanel = true;
              });
              _autoPager.toggle();
            },
            child: Text(_autoPager.isRunning ? '停止自动翻页' : '开始自动翻页'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              unawaited(_toggleBookmark());
            },
            child: Text(_hasBookmarkAtCurrent ? '移除书签' : '添加书签'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _refreshChapter();
            },
            child: const Text('刷新当前章节'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _showSwitchSourceMenu();
            },
            child: const Text('换源'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              try {
                final updated = await _refreshCatalogFromSource();
                if (!mounted) return;
                _showToast('目录已更新，共 ${updated.length} 章');
              } catch (e) {
                if (!mounted) return;
                _showToast('更新目录失败：$e');
              }
            },
            child: const Text('更新目录'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showContentSearchDialog() {
    if (_showMenu) {
      _closeReaderMenuOverlay();
    }
    final controller = TextEditingController(text: _contentSearchQuery);
    showCupertinoDialog<void>(
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
              _applyContentSearch(query);
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
              _applyContentSearch(query);
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _applyContentSearch(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      _showToast('请输入搜索关键词');
      return;
    }

    final hits = _collectContentSearchHits(normalized);
    if (hits.isEmpty) {
      _showToast('当前章节未找到匹配内容');
      return;
    }

    setState(() {
      _contentSearchQuery = normalized;
      _contentSearchHits = hits;
      _currentSearchHitIndex = 0;
    });
    _setSearchMenuVisible(true);
    _jumpToSearchHit(hits.first);
  }

  List<_ReaderSearchHit> _collectContentSearchHits(String query) {
    final content = _currentContent;
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (lowerContent.isEmpty || lowerQuery.isEmpty) return const [];

    final hits = <_ReaderSearchHit>[];
    var from = 0;
    while (from < lowerContent.length) {
      final found = lowerContent.indexOf(lowerQuery, from);
      if (found == -1) break;
      final end = found + lowerQuery.length;
      final previewStart = (found - 16).clamp(0, content.length).toInt();
      final previewEnd = (end + 18).clamp(0, content.length).toInt();
      final preview =
          content.substring(previewStart, previewEnd).replaceAll('\n', ' ');
      final pageIndex = _settings.pageTurnMode == PageTurnMode.scroll
          ? null
          : _resolveSearchHitPageIndex(found);
      hits.add(
        _ReaderSearchHit(
          start: found,
          end: end,
          preview: preview,
          pageIndex: pageIndex,
        ),
      );
      from = end;
    }
    return hits;
  }

  int? _resolveSearchHitPageIndex(int contentOffset) {
    final pages = _pageFactory.currentPages;
    if (pages.isEmpty) return null;

    var cursor = 0;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final nextCursor = cursor + page.length;
      if (contentOffset < nextCursor) {
        return i;
      }
      cursor = nextCursor;
    }
    return pages.length - 1;
  }

  void _jumpToSearchHit(_ReaderSearchHit hit) {
    if (_settings.pageTurnMode == PageTurnMode.scroll) {
      if (!_scrollController.hasClients) return;
      final maxOffset = _scrollController.position.maxScrollExtent;
      if (maxOffset <= 0 || _currentContent.isEmpty) return;
      final ratio = (hit.start / _currentContent.length).clamp(0.0, 1.0);
      final target = (maxOffset * ratio).clamp(0.0, maxOffset).toDouble();
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }

    final totalPages = _pageFactory.totalPages;
    if (totalPages <= 0) return;
    final targetPage = (hit.pageIndex ?? 0).clamp(0, totalPages - 1);
    _pageFactory.jumpToPage(targetPage);
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateSearchHit(int delta) {
    if (_contentSearchHits.isEmpty) return;
    final size = _contentSearchHits.length;
    var nextIndex = _currentSearchHitIndex + delta;
    while (nextIndex < 0) {
      nextIndex += size;
    }
    nextIndex %= size;
    setState(() {
      _currentSearchHitIndex = nextIndex;
    });
    _jumpToSearchHit(_contentSearchHits[nextIndex]);
  }

  void _exitSearchMenu() {
    setState(() {
      _showSearchMenu = false;
      _contentSearchHits = <_ReaderSearchHit>[];
      _currentSearchHitIndex = -1;
      _contentSearchQuery = '';
    });
    _syncSystemUiForOverlay();
  }

  Widget _buildSearchMenuOverlay() {
    final currentHit = (_currentSearchHitIndex >= 0 &&
            _currentSearchHitIndex < _contentSearchHits.length)
        ? _contentSearchHits[_currentSearchHitIndex]
        : null;
    final info = _contentSearchHits.isEmpty
        ? '未找到结果'
        : '结果 ${_currentSearchHitIndex + 1}/${_contentSearchHits.length} · 章节：$_currentTitle';
    final preview = currentHit?.preview.trim();
    final accent = _isUiDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;

    return Stack(
      children: [
        Positioned(
          left: 16,
          top: MediaQuery.of(context).size.height * 0.45,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _contentSearchHits.isEmpty
                ? null
                : () => _navigateSearchHit(-1),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _uiCardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _uiBorder),
              ),
              child: Icon(CupertinoIcons.chevron_left, color: _uiTextStrong),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: MediaQuery.of(context).size.height * 0.45,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed:
                _contentSearchHits.isEmpty ? null : () => _navigateSearchHit(1),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _uiCardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _uiBorder),
              ),
              child: Icon(CupertinoIcons.chevron_right, color: _uiTextStrong),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: _uiPanelBg.withValues(alpha: 0.98),
                border: Border(top: BorderSide(color: _uiBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      info,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _uiTextNormal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (preview != null && preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '...$preview...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _uiTextSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSearchMenuAction(
                          icon: CupertinoIcons.search,
                          label: '结果',
                          onTap: _showContentSearchDialog,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSearchMenuAction(
                          icon: CupertinoIcons.square_grid_2x2,
                          label: '主菜单',
                          onTap: () {
                            _setSearchMenuVisible(false);
                            _setReaderMenuVisible(true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSearchMenuAction(
                          icon: CupertinoIcons.clear_circled,
                          label: '退出',
                          onTap: _exitSearchMenu,
                          activeColor: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSearchMenuAction(
                          icon: CupertinoIcons.chevron_up,
                          label: '上一个',
                          onTap: _contentSearchHits.isEmpty
                              ? null
                              : () => _navigateSearchHit(-1),
                          activeColor: accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSearchMenuAction(
                          icon: CupertinoIcons.chevron_down,
                          label: '下一个',
                          onTap: _contentSearchHits.isEmpty
                              ? null
                              : () => _navigateSearchHit(1),
                          activeColor: accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchMenuAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? activeColor,
  }) {
    final enabled = onTap != null;
    final color = activeColor ?? _uiTextStrong;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: _uiCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _uiBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: enabled ? color : _uiTextSubtle,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? color : _uiTextSubtle,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionRail() {
    final topOffset = MediaQuery.of(context).padding.top + 86;
    return Positioned(
      right: 10,
      top: topOffset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF000000).withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: CupertinoColors.white.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildFloatingActionButton(
              icon: CupertinoIcons.search,
              onTap: _showContentSearchDialog,
            ),
            const SizedBox(height: 8),
            _buildFloatingActionButton(
              icon: _hasBookmarkAtCurrent
                  ? CupertinoIcons.bookmark_solid
                  : CupertinoIcons.bookmark,
              active: _hasBookmarkAtCurrent,
              onTap: () => unawaited(_toggleBookmark()),
            ),
            const SizedBox(height: 8),
            _buildFloatingActionButton(
              icon: CupertinoIcons.list_bullet,
              onTap: _openChapterListFromMenu,
            ),
            const SizedBox(height: 8),
            _buildFloatingActionButton(
              icon: CupertinoIcons.speaker_2_fill,
              onTap: _openReadAloudFromMenu,
            ),
            const SizedBox(height: 8),
            _buildFloatingActionButton(
              icon: CupertinoIcons.circle_grid_3x3,
              onTap: _openInterfaceSettingsFromMenu,
            ),
            const SizedBox(height: 8),
            _buildFloatingActionButton(
              icon: CupertinoIcons.gear,
              onTap: _openBehaviorSettingsFromMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? _uiAccent.withValues(alpha: 0.22)
              : const Color(0xFF000000).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _uiAccent : _uiBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? _uiAccent : _uiTextStrong,
        ),
      ),
    );
  }

  /// 刷新当前章节
  void _refreshChapter() {
    _closeReaderMenuOverlay();
    _loadChapter(_currentChapterIndex);
  }

  void _showToast(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  _ReadAloudCapability _detectReadAloudCapability() {
    // 当前版本尚未接入 TTS 引擎；保留入口并给出明确可观测提示。
    return const _ReadAloudCapability(
      available: false,
      reason: '语音朗读（TTS）暂未实现',
    );
  }

  void _refreshCurrentSourceName() {
    final sourceUrl = _currentSourceUrl;
    if (sourceUrl == null || sourceUrl.trim().isEmpty) {
      _currentSourceName = widget.effectiveSourceName ?? _currentSourceName;
      return;
    }
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    _currentSourceName = source?.bookSourceName ??
        widget.effectiveSourceName ??
        _currentSourceName;
  }

  Future<void> _toggleCleanChapterTitleFromTopMenu() async {
    _updateSettings(
      _settings.copyWith(cleanChapterTitle: !_settings.cleanChapterTitle),
    );
    if (!mounted) return;
    _showToast(_settings.cleanChapterTitle ? '已开启净化章节标题' : '已关闭净化章节标题');
  }

  Future<void> _showSwitchSourceMenu() async {
    final currentBook = _bookRepo.getBookById(widget.bookId) ??
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

    final keyword = currentBook.title.trim();
    final authorKeyword = currentBook.author.trim();
    if (keyword.isEmpty) {
      _showToast('书名为空，无法换源');
      return;
    }

    final enabledSources = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled)
        .toList(growable: false);
    if (enabledSources.isEmpty) {
      _showToast('没有可用书源');
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

    final searchResults = <SearchResult>[];
    for (final source in sortedEnabledSources) {
      try {
        final list = await _ruleEngine.search(
          source,
          keyword,
          filter: (name, author) {
            if (name != keyword) return false;
            if (authorKeyword.isEmpty) return true;
            return author.contains(authorKeyword);
          },
        );
        searchResults.addAll(list);
      } catch (_) {
        // 单源失败隔离
      }
    }

    if (!mounted) return;

    final candidates = ReaderSourceSwitchHelper.buildCandidates(
      currentBook: currentBook,
      enabledSources: sortedEnabledSources,
      searchResults: searchResults,
    );
    if (candidates.isEmpty) {
      _showToast('未找到可切换的匹配书源');
      return;
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text('换源（$keyword）'),
        message: const Text('按“书名匹配 + 作者优先”筛选候选'),
        actions: [
          for (final candidate in candidates.take(12))
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _switchToSourceCandidate(candidate);
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${candidate.source.bookSourceName} · ${candidate.book.author}',
                  textAlign: TextAlign.left,
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
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
        currentChapterTitle: previousTitle,
        currentChapterIndex: previousChapterIndex,
      );

      if (!mounted) return;
      setState(() {
        _chapters = newChapters;
        _currentSourceUrl = source.bookSourceUrl;
        _currentSourceName = source.bookSourceName;
      });

      await _loadChapter(targetIndex, restoreOffset: true);
      if (!mounted) return;
      _showToast('已切换到：${source.bookSourceName}');
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
          _chapters = previousChapters;
          _currentSourceUrl = previousSourceUrl;
          _currentSourceName = previousSourceName;
        });
      }
      if (!mounted) return;
      _showToast('换源失败：$e');
    }
  }

  void _showReadingSettingsSheet({
    String title = '阅读设置',
    int initialTab = 0,
    List<int>? allowedTabs,
  }) {
    final tabs = (allowedTabs == null || allowedTabs.isEmpty)
        ? <int>[0, 1, 2, 3]
        : allowedTabs.toSet().toList()
      ..sort();
    int selectedTab = tabs.contains(initialTab) ? initialTab : tabs.first;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: BoxDecoration(
            color: _uiPanelBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _isUiDark
                          ? CupertinoColors.white.withValues(alpha: 0.24)
                          : AppDesignTokens.textMuted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: _uiTextStrong,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: _uiTextSubtle,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tabs.length > 1) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSettingsTabs(
                      selectedTab,
                      tabs,
                      (value) {
                        setPopupState(() => selectedTab = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  const SizedBox(height: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildSettingsTabBody(selectedTab, setPopupState),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTabs(
    int selectedTab,
    List<int> tabs,
    ValueChanged<int> onChanged,
  ) {
    const labels = <int, String>{
      0: '排版',
      1: '界面',
      2: '翻页',
      3: '其他',
    };

    Widget buildTab(String label, bool isSelected) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _uiTextStrong : _uiTextNormal,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: selectedTab,
        backgroundColor: _uiCardBg,
        thumbColor: _uiAccent,
        children: {
          for (final tab in tabs)
            tab: buildTab(labels[tab] ?? '设置', selectedTab == tab),
        },
        onValueChanged: (value) {
          if (value == null) return;
          onChanged(value);
        },
      ),
    );
  }

  Widget _buildSettingsTabBody(int tab, StateSetter setPopupState) {
    switch (tab) {
      case 0:
        return _buildTypographyMainTab(setPopupState);
      case 1:
        return _buildThemeSettingsTab(setPopupState);
      case 2:
        return _buildPageSettingsTab(setPopupState);
      case 3:
      default:
        return _buildMoreSettingsTab(setPopupState);
    }
  }

  /// Aa（排版）主面板：对标专业阅读器的“高频项集中”
  ///
  /// 原则：
  /// - 第一屏优先：字号/行距/段距/缩进/对齐
  /// - 字体与装饰留在同页下方
  /// - 边距给预设 + “高级”入口，避免用户在四个滑条里迷路
  Widget _buildTypographyMainTab(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('typography'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            title: '高频排版',
            child: Column(
              children: [
                _buildSliderSetting(
                  '字号',
                  _settings.fontSize,
                  10,
                  40,
                  (val) => _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(fontSize: val),
                  ),
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '行距',
                  _settings.lineHeight,
                  1.0,
                  3.0,
                  (val) => _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(lineHeight: val),
                  ),
                  displayFormat: (v) => v.toStringAsFixed(1),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '段距',
                  _settings.paragraphSpacing,
                  0,
                  50,
                  (val) => _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(paragraphSpacing: val),
                  ),
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '字距',
                  _settings.letterSpacing,
                  -2,
                  5,
                  (val) => _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(letterSpacing: val),
                  ),
                  displayFormat: (v) => v.toStringAsFixed(1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleBtn(
                        label: '两端对齐',
                        isActive: _settings.textFullJustify,
                        onTap: () => _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(
                            textFullJustify: !_settings.textFullJustify,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggleBtn(
                        label: '段首缩进',
                        isActive: _settings.paragraphIndent.isNotEmpty,
                        onTap: () {
                          final hasIndent =
                              _settings.paragraphIndent.isNotEmpty;
                          _updateSettingsFromSheet(
                            setPopupState,
                            _settings.copyWith(
                              paragraphIndent: hasIndent ? '' : '　　',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleBtn(
                        label: '底部对齐',
                        isActive: _settings.textBottomJustify,
                        onTap: () => _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(
                            textBottomJustify: !_settings.textBottomJustify,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '字体与装饰',
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (ctx) => _buildFontSelectDialog(setPopupState),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _uiCardBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('字体: ${_currentFontFamily ?? "系统默认"}',
                            style: TextStyle(color: _uiTextStrong)),
                        Icon(CupertinoIcons.chevron_right,
                            color: _uiTextSubtle, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _settings.textBold,
                    backgroundColor: _uiCardBg,
                    thumbColor: _uiAccent,
                    children: {
                      2: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text('细体',
                            style: TextStyle(
                                color: _uiTextNormal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      0: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text('正常',
                            style: TextStyle(
                                color: _uiTextNormal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      1: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text('粗体',
                            style: TextStyle(
                                color: _uiTextNormal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(textBold: value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleBtn(
                        label: '下划线',
                        isActive: _settings.underline,
                        onTap: () => _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(underline: !_settings.underline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggleBtn(
                        label: '字距归零',
                        isActive: _settings.letterSpacing.abs() >= 0.1,
                        onTap: () => _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(letterSpacing: 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '边距',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleBtn(
                        label: '窄',
                        isActive: _settings.paddingLeft <= 12,
                        onTap: () => _applyPaddingPreset(
                          setPopupState,
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildToggleBtn(
                        label: '标准',
                        isActive: _settings.paddingLeft > 12 &&
                            _settings.paddingLeft < 24,
                        onTap: () => _applyPaddingPreset(
                          setPopupState,
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildToggleBtn(
                        label: '宽',
                        isActive: _settings.paddingLeft >= 24,
                        onTap: () => _applyPaddingPreset(
                          setPopupState,
                          horizontal: 28,
                          vertical: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    showTypographySettingsDialog(
                      context,
                      settings: _settings,
                      onSettingsChanged: (newSettings) {
                        _updateSettingsFromSheet(setPopupState, newSettings);
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _uiCardBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('高级排版与边距', style: TextStyle(color: _uiTextStrong)),
                        Icon(CupertinoIcons.chevron_right,
                            color: _uiTextSubtle, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _applyPaddingPreset(
    StateSetter setPopupState, {
    required double horizontal,
    required double vertical,
  }) {
    _updateSettingsFromSheet(
      setPopupState,
      _settings.copyWith(
        paddingLeft: horizontal,
        paddingRight: horizontal,
        paddingTop: vertical,
        paddingBottom: vertical,
        marginHorizontal: horizontal,
        marginVertical: vertical,
      ),
    );
  }

  Widget _buildThemeSettingsTab(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('theme'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            title: '界面设置',
            child: Column(
              children: [
                _buildSwitchRow(
                  '跟随系统亮度',
                  _settings.useSystemBrightness,
                  (value) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(useSystemBrightness: value),
                    );
                  },
                ),
                IgnorePointer(
                  ignoring: _settings.useSystemBrightness,
                  child: Opacity(
                    opacity: _settings.useSystemBrightness ? 0.4 : 1.0,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.sun_min,
                            color: _uiTextSubtle, size: 20),
                        Expanded(
                          child: CupertinoSlider(
                            value: _safeBrightnessValue(_settings.brightness),
                            min: 0.0,
                            max: 1.0,
                            activeColor: _uiAccent,
                            onChanged: (value) {
                              _updateSettingsFromSheet(
                                setPopupState,
                                _settings.copyWith(brightness: value),
                              );
                            },
                          ),
                        ),
                        Icon(CupertinoIcons.sun_max,
                            color: _uiTextSubtle, size: 20),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${(_safeBrightnessValue(_settings.brightness) * 100).round()}%',
                            textAlign: TextAlign.end,
                            style:
                                TextStyle(color: _uiTextNormal, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '阅读主题',
            child: SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppColors.readingThemes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final theme = AppColors.readingThemes[index];
                  final isSelected = _settings.themeIndex == index;
                  return GestureDetector(
                    onTap: () {
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(themeIndex: index),
                      );
                    },
                    child: Container(
                      width: 70,
                      height: 90,
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _uiAccent : _uiBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              theme.name,
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                color: _uiAccent,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildSettingsCard(
            title: '内容边距（常用）',
            child: Column(
              children: [
                _buildSliderSetting(
                  '上边',
                  _settings.paddingTop,
                  0,
                  80,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(
                        paddingTop: val,
                        marginVertical: val,
                      ),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '下边',
                  _settings.paddingBottom,
                  0,
                  80,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(
                        paddingBottom: val,
                        marginVertical: val,
                      ),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '左边',
                  _settings.paddingLeft,
                  0,
                  80,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(
                        paddingLeft: val,
                        marginHorizontal: val,
                      ),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '右边',
                  _settings.paddingRight,
                  0,
                  80,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(
                        paddingRight: val,
                        marginHorizontal: val,
                      ),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '页眉页脚',
            child: Column(
              children: [
                _buildSwitchRow('显示页眉', !_settings.hideHeader, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(hideHeader: !value),
                  );
                }),
                _buildSwitchRow('页眉分割线', _settings.showHeaderLine, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(showHeaderLine: value),
                  );
                }),
                _buildOptionRow(
                  '页眉左侧',
                  _headerTipLabel(_settings.headerLeftContent),
                  () {
                    _showTipOptionPicker(
                      title: '页眉左侧',
                      options: _headerTipOptions,
                      currentValue: _settings.headerLeftContent,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(headerLeftContent: value),
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '页眉中间',
                  _headerTipLabel(_settings.headerCenterContent),
                  () {
                    _showTipOptionPicker(
                      title: '页眉中间',
                      options: _headerTipOptions,
                      currentValue: _settings.headerCenterContent,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(headerCenterContent: value),
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '页眉右侧',
                  _headerTipLabel(_settings.headerRightContent),
                  () {
                    _showTipOptionPicker(
                      title: '页眉右侧',
                      options: _headerTipOptions,
                      currentValue: _settings.headerRightContent,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(headerRightContent: value),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 4),
                _buildSwitchRow('显示页脚', !_settings.hideFooter, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(hideFooter: !value),
                  );
                }),
                _buildSwitchRow('页脚分割线', _settings.showFooterLine, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(showFooterLine: value),
                  );
                }),
                _buildOptionRow(
                  '页脚左侧',
                  _footerTipLabel(_settings.footerLeftContent),
                  () {
                    _showTipOptionPicker(
                      title: '页脚左侧',
                      options: _footerTipOptions,
                      currentValue: _settings.footerLeftContent,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(footerLeftContent: value),
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '页脚中间',
                  _footerTipLabel(_settings.footerCenterContent),
                  () {
                    _showTipOptionPicker(
                      title: '页脚中间',
                      options: _footerTipOptions,
                      currentValue: _settings.footerCenterContent,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(footerCenterContent: value),
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '页脚右侧',
                  _footerTipLabel(_settings.footerRightContent),
                  () {
                    _showTipOptionPicker(
                      title: '页脚右侧',
                      options: _footerTipOptions,
                      currentValue: _settings.footerRightContent,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(footerRightContent: value),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPageSettingsTab(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('page'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            title: '翻页模式与动画',
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      PageTurnModeUi.values(current: _settings.pageTurnMode)
                          .map((mode) {
                    final isSelected = _settings.pageTurnMode == mode;
                    final isHiddenMode = PageTurnModeUi.isHidden(mode);
                    return Opacity(
                      opacity: isHiddenMode ? 0.5 : 1,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: isHiddenMode
                            ? null
                            : () {
                                _updateSettingsFromSheet(
                                  setPopupState,
                                  _settings.copyWith(pageTurnMode: mode),
                                );
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _uiAccent.withValues(alpha: 0.2)
                                : _uiCardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? _uiAccent : _uiBorder,
                            ),
                          ),
                          child: Text(
                            isHiddenMode ? '${mode.name}（隐藏）' : mode.name,
                            style: TextStyle(
                              color: isSelected ? _uiAccent : _uiTextNormal,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _buildSliderSetting(
                  '动画',
                  _settings.pageAnimDuration.toDouble(),
                  100,
                  600,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(pageAnimDuration: val.toInt()),
                    );
                  },
                  displayFormat: (v) => '${v.toInt()}ms',
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '翻页操作',
            child: Column(
              children: [
                _buildOptionRow(
                  '进度条',
                  _settings.progressBarBehavior.label,
                  () {
                    final next = _settings.progressBarBehavior ==
                            ProgressBarBehavior.page
                        ? ProgressBarBehavior.chapter
                        : ProgressBarBehavior.page;
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(progressBarBehavior: next),
                    );
                  },
                ),
                _buildSwitchRow('章节跳转确认', _settings.confirmSkipChapter,
                    (value) {
                  if (!value) {
                    _chapterSeekConfirmed = false;
                  }
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(confirmSkipChapter: value),
                  );
                }),
                _buildSwitchRow('音量键翻页', _settings.volumeKeyPage, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(volumeKeyPage: value),
                  );
                }),
                if (_settings.pageTurnMode == PageTurnMode.scroll)
                  _buildSwitchRow(
                    '滚动翻页无动画',
                    _settings.noAnimScrollPage,
                    (value) {
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(noAnimScrollPage: value),
                      );
                    },
                  ),
                _buildSwitchRow('净化章节标题', _settings.cleanChapterTitle, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(cleanChapterTitle: value),
                  );
                }),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '翻页手感',
            child: Column(
              children: [
                _buildSliderSetting(
                  '灵敏',
                  _settings.pageTouchSlop.toDouble(),
                  0,
                  100,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(pageTouchSlop: val.toInt()),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMoreSettingsTab(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('more'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            title: '状态栏与显示',
            child: Column(
              children: [
                _buildSwitchRow('显示状态栏', _settings.showStatusBar, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(showStatusBar: value),
                  );
                }),
                _buildSwitchRow('显示章节进度', _settings.showChapterProgress,
                    (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(showChapterProgress: value),
                  );
                }),
                _buildSwitchRow('显示时间', _settings.showTime, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(showTime: value),
                  );
                }),
                _buildSwitchRow('显示进度', _settings.showProgress, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(showProgress: value),
                  );
                }),
                _buildSwitchRow('显示电量', _settings.showBattery, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(showBattery: value),
                  );
                }),
                _buildSwitchRow('显示亮度条', _settings.showBrightnessView, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(showBrightnessView: value),
                  );
                }),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '点击与自动阅读',
            child: Column(
              children: [
                _buildOptionRow('点击区域', '配置', () {
                  showClickActionConfigDialog(
                    context,
                    currentConfig: _settings.clickActions,
                    onSave: (newConfig) {
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(clickActions: newConfig),
                      );
                    },
                  );
                }),
                _buildSliderSetting(
                  '速度',
                  _settings.autoReadSpeed.toDouble(),
                  1,
                  100,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(autoReadSpeed: val.toInt()),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '其他设置',
            child: Column(
              children: [
                _buildSwitchRow('屏幕常亮', _settings.keepScreenOn, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(keepScreenOn: value),
                  );
                }),
                _buildSwitchRow('繁体显示', _settings.chineseTraditional, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(chineseTraditional: value),
                  );
                }),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '恢复默认',
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: CupertinoColors.destructiveRed.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _confirmResetReadingSettings(setPopupState),
                child: const Text(
                  '恢复为默认阅读配置',
                  style: TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _confirmResetReadingSettings(StateSetter setPopupState) async {
    final shouldReset = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('恢复默认阅读配置'),
            content: const Text('\n将恢复为 legado 风格默认值，当前修改会立即生效。'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('恢复'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldReset) return;
    _updateSettingsFromSheet(setPopupState, const ReadingSettings());
  }

  void _updateSettingsFromSheet(
      StateSetter setPopupState, ReadingSettings newSettings) {
    _updateSettings(newSettings);
    setPopupState(() {});
  }

  Widget _buildSettingsCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _uiCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _uiBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: _uiTextStrong, fontSize: 14)),
            Row(
              children: [
                Text(value,
                    style: TextStyle(color: _uiTextNormal, fontSize: 13)),
                const SizedBox(width: 6),
                Icon(CupertinoIcons.chevron_right,
                    color: _uiTextSubtle, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTipOptionPicker({
    required String title,
    required List<_TipOption> options,
    required int currentValue,
    required ValueChanged<int> onSelected,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: options
            .map(
              (option) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  onSelected(option.value);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(option.label),
                    if (option.value == currentValue)
                      Icon(CupertinoIcons.check_mark, color: _uiAccent),
                  ],
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  String _headerTipLabel(int value) {
    return _headerTipOptions
        .firstWhere((option) => option.value == value,
            orElse: () => _headerTipOptions[2])
        .label;
  }

  String _footerTipLabel(int value) {
    return _footerTipOptions
        .firstWhere((option) => option.value == value,
            orElse: () => _footerTipOptions[4])
        .label;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _uiTextSubtle,
        fontSize: 13,
      ),
    );
  }

  Widget _buildSliderSetting(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {String Function(double)? displayFormat}) {
    final safeMin = min.isFinite ? min : 0.0;
    final safeMax = max.isFinite && max > safeMin ? max : safeMin + 1.0;
    final safeValue = _safeSliderValue(
      value,
      min: safeMin,
      max: safeMax,
      fallback: safeMin,
    );
    final canSlide = max.isFinite && min.isFinite && max > min;

    return Row(
      children: [
        SizedBox(
            width: 40,
            child: Text(label,
                style: TextStyle(color: _uiTextNormal, fontSize: 13))),
        Expanded(
          child: CupertinoSlider(
            value: safeValue,
            min: safeMin,
            max: safeMax,
            activeColor: _uiAccent,
            onChanged: canSlide ? onChanged : null,
          ),
        ),
        SizedBox(
            width: 56,
            child: Text(
              displayFormat?.call(safeValue) ?? safeValue.toStringAsFixed(1),
              style: TextStyle(color: _uiTextNormal, fontSize: 13),
              textAlign: TextAlign.end,
            )),
      ],
    );
  }

  Widget _buildToggleBtn(
      {required String label,
      required bool isActive,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _uiAccent.withValues(alpha: 0.2) : _uiCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? _uiAccent : _uiBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: isActive ? _uiAccent : _uiTextNormal, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSelectDialog(StateSetter parentSetState) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: _uiPanelBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('选择字体',
              style: TextStyle(
                  color: _uiTextStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: ReadingFontFamily.presets.length,
              itemBuilder: (ctx, index) {
                final font = ReadingFontFamily.presets[index];
                final isSelected = _settings.fontFamilyIndex == index;
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _updateSettings(_settings.copyWith(fontFamilyIndex: index));
                    parentSetState(() {}); // Ensure sheet updates
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _uiBorder.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            font.name,
                            style: TextStyle(
                              color: isSelected ? _uiAccent : _uiTextStrong,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(CupertinoIcons.checkmark, color: _uiAccent),
                      ],
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

  Widget _buildSwitchRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _uiTextStrong, fontSize: 16)),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: _uiAccent,
          ),
        ],
      ),
    );
  }

  /// 切换当前位置的书签
  Future<void> _toggleBookmark() async {
    try {
      if (_hasBookmarkAtCurrent) {
        // 删除书签
        final bookmark =
            _bookmarkRepo.getBookmarkAt(widget.bookId, _currentChapterIndex, 0);
        if (bookmark != null) {
          await _bookmarkRepo.removeBookmark(bookmark.id);
        }
      } else {
        // 添加书签
        await _bookmarkRepo.addBookmark(
          bookId: widget.bookId,
          bookName: widget.bookTitle,
          bookAuthor: _bookAuthor,
          chapterIndex: _currentChapterIndex,
          chapterTitle: _currentTitle,
          chapterPos: 0,
          content:
              _currentContent.substring(0, _currentContent.length.clamp(0, 50)),
        );
      }
      _updateBookmarkStatus();
    } catch (e) {
      if (!mounted) return;
      _showToast('书签操作失败：$e');
    }
  }

  /// 更新书签状态
  void _updateBookmarkStatus() {
    if (!mounted) return;
    bool hasBookmark = false;
    try {
      hasBookmark =
          _bookmarkRepo.hasBookmark(widget.bookId, _currentChapterIndex);
    } catch (_) {
      hasBookmark = false;
    }
    if (_hasBookmarkAtCurrent == hasBookmark) return;
    setState(() {
      _hasBookmarkAtCurrent = hasBookmark;
    });
  }

  Future<ChapterCacheInfo> _clearBookCache() async {
    final info = await _chapterRepo.clearDownloadedCacheForBook(widget.bookId);

    if (!mounted) return info;

    setState(() {
      // 保持当前阅读不中断：不强行清空当前章节的内存内容，但把“已下载标记”与缓存阶段清空。
      _replaceStageCache.clear();

      final currentId =
          _chapters.isNotEmpty ? _chapters[_currentChapterIndex].id : null;
      _chapters = _chapters.map((chapter) {
        if (!chapter.isDownloaded) return chapter;
        final keepContent = chapter.id == currentId ? chapter.content : null;
        return chapter.copyWith(isDownloaded: false, content: keepContent);
      }).toList(growable: false);
    });

    _syncPageFactoryChapters(
      keepPosition: _settings.pageTurnMode != PageTurnMode.scroll,
    );
    return info;
  }

  SearchResult? _pickBestUpdateTarget({
    required Book book,
    required List<SearchResult> results,
  }) {
    final titleKey = ReaderSourceSwitchHelper.normalizeForCompare(book.title);
    final authorKey = ReaderSourceSwitchHelper.normalizeForCompare(book.author);

    SearchResult? authorMatched;
    SearchResult? fallback;

    for (final item in results) {
      final itemTitleKey =
          ReaderSourceSwitchHelper.normalizeForCompare(item.name);
      if (itemTitleKey != titleKey) continue;

      fallback ??= item;
      final itemAuthorKey =
          ReaderSourceSwitchHelper.normalizeForCompare(item.author);
      if (authorKey.isNotEmpty &&
          itemAuthorKey.isNotEmpty &&
          itemAuthorKey == authorKey) {
        authorMatched = item;
        break;
      }
    }

    return authorMatched ?? fallback;
  }

  bool _isUrlPrefix(List<String> prefix, List<String> full) {
    if (prefix.length > full.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != full[i]) return false;
    }
    return true;
  }

  Future<List<Chapter>> _refreshCatalogFromSource() async {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null) {
      throw StateError('书籍信息不存在');
    }
    if (book.isLocal) {
      throw StateError('本地书籍不支持检查更新');
    }

    final sourceUrl = (book.sourceUrl ?? book.sourceId ?? '').trim();
    if (sourceUrl.isEmpty) {
      throw StateError('缺少书源信息，无法检查更新');
    }
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) {
      throw StateError('书源不存在或已被删除');
    }

    final keyword = book.title.trim();
    if (keyword.isEmpty) {
      throw StateError('书名为空，无法检查更新');
    }

    var targetBookUrl = (book.bookUrl ?? '').trim();
    if (targetBookUrl.isEmpty) {
      final results = await _ruleEngine.search(source, keyword);
      final target = _pickBestUpdateTarget(book: book, results: results);
      if (target == null) {
        throw StateError('未在当前书源搜索到匹配书籍');
      }
      targetBookUrl = target.bookUrl.trim();
    }
    if (targetBookUrl.isEmpty) {
      throw StateError('详情链接为空，无法检查更新');
    }

    final detail = await _ruleEngine.getBookInfo(
      source,
      targetBookUrl,
      clearRuntimeVariables: true,
    );
    final tocUrl = detail?.tocUrl.trim().isNotEmpty == true
        ? detail!.tocUrl.trim()
        : targetBookUrl;
    if (tocUrl.isEmpty) {
      throw StateError('目录地址为空（可能详情解析失败）');
    }

    final toc = await _ruleEngine.getToc(
      source,
      tocUrl,
      clearRuntimeVariables: false,
    );
    if (toc.isEmpty) {
      throw StateError('目录为空（可能是 ruleToc 不匹配）');
    }

    final existing = _chapters;
    final existingUrls = <String>[];
    for (final chapter in existing) {
      final url = (chapter.url ?? '').trim();
      if (url.isEmpty) {
        throw StateError('当前目录存在空章节链接，暂不支持自动检查更新');
      }
      existingUrls.add(url);
    }

    final newUrls = <String>[];
    final newTitleByUrl = <String, String>{};
    final seen = <String>{};
    for (final item in toc) {
      final url = item.url.trim();
      if (url.isEmpty) continue;
      if (!seen.add(url)) continue;
      newUrls.add(url);
      newTitleByUrl[url] = item.name.trim();
    }
    if (newUrls.isEmpty) {
      throw StateError('目录解析失败：章节链接为空');
    }

    if (!_isUrlPrefix(existingUrls, newUrls)) {
      throw StateError('目录结构变化较大，暂不自动合并（可尝试换源或重新加入书架）');
    }

    if (newUrls.length <= existingUrls.length) {
      return _chapters;
    }

    final uuid = const Uuid();
    final toAdd = <Chapter>[];
    for (var i = existingUrls.length; i < newUrls.length; i++) {
      final url = newUrls[i];
      final title = (newTitleByUrl[url] ?? '').trim();
      final safeTitle = title.isNotEmpty ? title : '第${i + 1}章';
      final id = uuid.v5(Namespace.url.value, '${widget.bookId}|$i|$url');
      toAdd.add(
        Chapter(
          id: id,
          bookId: widget.bookId,
          title: safeTitle,
          url: url,
          index: i,
          isDownloaded: false,
          content: null,
        ),
      );
    }

    if (toAdd.isEmpty) return _chapters;

    await _chapterRepo.addChapters(toAdd);
    final updated = _chapterRepo.getChaptersForBook(widget.bookId);

    await _bookRepo.updateBook(
      book.copyWith(
        bookUrl: targetBookUrl,
        totalChapters: updated.length,
        latestChapter:
            updated.isNotEmpty ? updated.last.title : book.latestChapter,
      ),
    );

    if (!mounted) return updated;

    setState(() {
      _chapters = updated;
    });
    _syncPageFactoryChapters(
      keepPosition: _settings.pageTurnMode != PageTurnMode.scroll,
    );

    return updated;
  }

  void _showChapterList() {
    if (_showSearchMenu) {
      _setSearchMenuVisible(false);
    }
    if (_showMenu) {
      _setReaderMenuVisible(false);
    }
    showCupertinoModalPopup(
      context: context,
      builder: (popupContext) => ReaderCatalogSheet(
        bookId: widget.bookId,
        bookTitle: widget.bookTitle,
        bookAuthor: _bookAuthor,
        coverUrl: _bookCoverUrl,
        chapters: _chapters,
        currentChapterIndex: _currentChapterIndex,
        bookmarks: _bookmarkRepo.getBookmarksForBook(widget.bookId),
        onClearBookCache: _clearBookCache,
        onRefreshCatalog: _refreshCatalogFromSource,
        onChapterSelected: (index) {
          Navigator.pop(popupContext);
          _loadChapter(index);
        },
        onBookmarkSelected: (bookmark) {
          Navigator.pop(popupContext);
          _loadChapter(bookmark.chapterIndex, restoreOffset: true);
        },
        onDeleteBookmark: (bookmark) async {
          await _bookmarkRepo.removeBookmark(bookmark.id);
          _updateBookmarkStatus();
        },
      ),
    );
  }
}

class _ReadAloudCapability {
  final bool available;
  final String reason;

  const _ReadAloudCapability({
    required this.available,
    required this.reason,
  });
}

class _TipOption {
  final int value;
  final String label;

  const _TipOption(this.value, this.label);
}

class _ReplaceStageCache {
  final String rawTitle;
  final String rawContent;
  final String title;
  final String content;

  const _ReplaceStageCache({
    required this.rawTitle,
    required this.rawContent,
    required this.title,
    required this.content,
  });
}

class _ReaderSearchHit {
  final int start;
  final int end;
  final String preview;
  final int? pageIndex;

  const _ReaderSearchHit({
    required this.start,
    required this.end,
    required this.preview,
    required this.pageIndex,
  });
}

class _ScrollSegment {
  final int chapterIndex;
  final String chapterId;
  final String title;
  final String content;

  const _ScrollSegment({
    required this.chapterIndex,
    required this.chapterId,
    required this.title,
    required this.content,
  });
}

class _ScrollSegmentOffsetRange {
  final _ScrollSegment segment;
  final double start;
  final double end;
  final double height;

  const _ScrollSegmentOffsetRange({
    required this.segment,
    required this.start,
    required this.end,
    required this.height,
  });
}
