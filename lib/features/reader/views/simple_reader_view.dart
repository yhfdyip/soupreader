import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/js_runtime.dart';
import '../../../core/services/keep_screen_on_service.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/chinese_script_converter.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../bookshelf/models/book.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../replace/views/replace_rule_list_view.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../source/services/source_login_ui_helper.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_edit_legacy_view.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_web_verify_view.dart';
import '../../search/views/search_book_info_view.dart';
import '../../settings/views/exception_logs_view.dart';
import '../models/reading_settings.dart';
import '../services/chapter_title_display_helper.dart';
import '../services/reader_bookmark_export_service.dart';
import '../services/reader_key_paging_helper.dart';
import '../services/reader_legacy_quick_action_helper.dart';
import '../services/reader_legacy_menu_helper.dart';
import '../services/reader_source_action_helper.dart';
import '../services/reader_source_switch_helper.dart';
import '../services/reader_system_ui_helper.dart';
import '../services/reader_top_bar_action_helper.dart';
import '../services/reader_tip_selection_helper.dart';
import '../services/read_style_import_export_service.dart';
import '../utils/chapter_progress_utils.dart';
import '../widgets/auto_pager.dart';
import '../widgets/click_action_config_dialog.dart';
import '../widgets/paged_reader_widget.dart';
import '../widgets/page_factory.dart';
import '../widgets/reader_menus.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_status_bar.dart';
import '../widgets/reader_catalog_sheet.dart';
import '../widgets/scroll_page_step_calculator.dart';
import '../widgets/scroll_segment_paint_view.dart';
import '../widgets/scroll_text_layout_engine.dart';
import '../widgets/scroll_runtime_helper.dart';
import '../widgets/source_switch_candidate_sheet.dart';
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
  late final BookshelfCatalogUpdateService _catalogUpdateService;
  late final ReplaceRuleService _replaceService;
  late final ChapterTitleDisplayHelper _chapterTitleDisplayHelper;
  late final SettingsService _settingsService;
  final ScreenBrightnessService _brightnessService =
      ScreenBrightnessService.instance;
  final KeepScreenOnService _keepScreenOnService = KeepScreenOnService.instance;
  final RuleParserEngine _ruleEngine = RuleParserEngine();
  final ScrollTextLayoutEngine _scrollTextLayoutEngine =
      ScrollTextLayoutEngine.instance;
  final ChineseScriptConverter _chineseScriptConverter =
      ChineseScriptConverter.instance;
  final ReaderBookmarkExportService _bookmarkExportService =
      ReaderBookmarkExportService();
  final ReadStyleImportExportService _readStyleImportExportService =
      ReadStyleImportExportService();

  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  String _currentContent = '';
  String _currentTitle = '';

  // 阅读设置
  late ReadingSettings _settings;

  // UI 状态
  bool _showMenu = false;
  bool _showSearchMenu = false;
  ReaderSystemUiConfig? _appliedSystemUiConfig;
  List<DeviceOrientation>? _appliedPreferredOrientations;
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
  final Map<String, bool> _chapterVipByUrl = <String, bool>{};
  final Map<String, bool> _chapterPayByUrl = <String, bool>{};
  bool _tocUiUseReplace = false;
  bool _tocUiLoadWordCount = false;
  bool _tocUiSplitLongChapter = false;
  bool _useReplaceRule = true;

  // 翻页模式相关（对标 Legado PageFactory）
  final PageFactory _pageFactory = PageFactory();

  final _replaceStageCache = <String, _ReplaceStageCache>{};
  final _catalogDisplayTitleCacheByChapterId = <String, String>{};

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
  static const List<_TipOption> _titleModeOptions = [
    _TipOption(0, '居左'),
    _TipOption(1, '居中'),
    _TipOption(2, '隐藏'),
  ];
  static const int _customColorPickerValue = -2;
  static const List<_TipOption> _headerModeOptions = [
    _TipOption(ReadingSettings.headerModeHideWhenStatusBarShown, '显示状态栏时隐藏'),
    _TipOption(ReadingSettings.headerModeShow, '显示'),
    _TipOption(ReadingSettings.headerModeHide, '隐藏'),
  ];
  static const List<_TipOption> _footerModeOptions = [
    _TipOption(ReadingSettings.footerModeShow, '显示'),
    _TipOption(ReadingSettings.footerModeHide, '隐藏'),
  ];
  static const List<_TipOption> _screenOrientationOptions = [
    _TipOption(ReadingSettings.screenOrientationUnspecified, '跟随系统'),
    _TipOption(ReadingSettings.screenOrientationPortrait, '竖屏'),
    _TipOption(ReadingSettings.screenOrientationLandscape, '横屏'),
    _TipOption(ReadingSettings.screenOrientationSensor, '自动旋转'),
    _TipOption(ReadingSettings.screenOrientationReversePortrait, '反向竖屏'),
  ];
  static const List<_TipOption> _keepLightOptions = [
    _TipOption(ReadingSettings.keepLightFollowSystem, '默认'),
    _TipOption(ReadingSettings.keepLightOneMinute, '1分钟'),
    _TipOption(ReadingSettings.keepLightFiveMinutes, '5分钟'),
    _TipOption(ReadingSettings.keepLightTenMinutes, '10分钟'),
    _TipOption(ReadingSettings.keepLightAlways, '常亮'),
  ];
  static const List<_TipOption> _progressBarBehaviorOptions = [
    _TipOption(0, '页内进度'),
    _TipOption(1, '章节进度'),
  ];
  static const List<_TipOption> _tipColorOptions = [
    _TipOption(ReadingSettings.tipColorFollowContent, '同正文颜色'),
    _TipOption(_customColorPickerValue, '自定义'),
  ];
  static const List<_TipOption> _tipDividerColorOptions = [
    _TipOption(ReadingSettings.tipDividerColorDefault, '默认'),
    _TipOption(ReadingSettings.tipDividerColorFollowContent, '同正文颜色'),
    _TipOption(_customColorPickerValue, '自定义'),
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
  String? _readStyleBackgroundDirectoryPath;
  Timer? _keepLightTimer;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _chapterRepo = ChapterRepository(db);
    _bookRepo = BookRepository(db);
    _sourceRepo = SourceRepository(db);
    _catalogUpdateService = BookshelfCatalogUpdateService(
      engine: _ruleEngine,
      sourceRepo: _sourceRepo,
      bookRepo: _bookRepo,
      chapterRepo: _chapterRepo,
    );
    _replaceService = ReplaceRuleService(db);
    _chapterTitleDisplayHelper = ChapterTitleDisplayHelper(
      replaceRuleService: _replaceService,
    );
    _bookmarkRepo = BookmarkRepository();
    _settingsService = SettingsService();
    _settings = _settingsService.readingSettings.sanitize();
    _useReplaceRule = _settingsService.getBookUseReplaceRule(
      widget.bookId,
      fallback: _defaultUseReplaceRule(),
    );
    _settingsService.readingSettingsListenable
        .addListener(_handleReadingSettingsChanged);
    _warmUpReadStyleBackgroundDirectoryPath();
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
      _screenOffTimerStart(force: true);
      unawaited(_applyPreferredOrientations(_settings, force: true));
      _syncSystemUiForOverlay(force: true);
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

    _syncSystemUiForOverlay(force: true);
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
                title: _postProcessTitle(c.title),
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
    _settingsService.readingSettingsListenable
        .removeListener(_handleReadingSettingsChanged);
    _pageFactory.removeContentChangedListener(_handlePageFactoryContentChanged);
    _saveProgress();
    _scrollController.removeListener(_handleScrollControllerTick);
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    _autoPager.dispose();
    _keepLightTimer?.cancel();
    _keepLightTimer = null;
    // 离开阅读器时恢复系统亮度（iOS 还原原始亮度；Android 还原窗口亮度为跟随系统）
    unawaited(_brightnessService.resetToSystem());
    unawaited(_syncNativeKeepScreenOn(const ReadingSettings()));
    unawaited(_restoreSystemUiAndOrientation());
    super.dispose();
  }

  Future<void> _applyPreferredOrientations(
    ReadingSettings settings, {
    bool force = false,
  }) async {
    final next = ReaderSystemUiHelper.resolvePreferredOrientations(
      settings.screenOrientation,
    );
    if (!force && listEquals(_appliedPreferredOrientations, next)) {
      return;
    }
    _appliedPreferredOrientations = List<DeviceOrientation>.from(next);
    await SystemChrome.setPreferredOrientations(next);
  }

  Future<void> _restoreSystemUiAndOrientation() async {
    _appliedSystemUiConfig = ReaderSystemUiHelper.appDefault;
    _appliedPreferredOrientations = const <DeviceOrientation>[];
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    await SystemChrome.setEnabledSystemUIMode(
      ReaderSystemUiHelper.appDefault.mode,
      overlays: ReaderSystemUiHelper.appDefault.overlays,
    );
  }

  void _syncSystemUiForOverlay({bool force = false}) {
    final next = ReaderSystemUiHelper.resolveReaderUiConfig(
      settings: _settings,
      showOverlay: _showMenu || _showSearchMenu,
    );
    final sameMode = _appliedSystemUiConfig?.mode == next.mode;
    final sameOverlays = listEquals(
      _appliedSystemUiConfig?.overlays,
      next.overlays,
    );
    if (!force && sameMode && sameOverlays) {
      return;
    }
    _appliedSystemUiConfig = next;
    SystemChrome.setEnabledSystemUIMode(next.mode, overlays: next.overlays);
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

  int _effectiveKeepLightSeconds(ReadingSettings settings) {
    final keepLight = settings.keepLightSeconds;
    if (keepLight == ReadingSettings.keepLightFollowSystem ||
        keepLight == ReadingSettings.keepLightOneMinute ||
        keepLight == ReadingSettings.keepLightFiveMinutes ||
        keepLight == ReadingSettings.keepLightTenMinutes ||
        keepLight == ReadingSettings.keepLightAlways) {
      return keepLight;
    }
    return settings.keepScreenOn
        ? ReadingSettings.keepLightAlways
        : ReadingSettings.keepLightFollowSystem;
  }

  Future<void> _syncNativeKeepScreenOn(ReadingSettings settings) async {
    _keepLightTimer?.cancel();
    _keepLightTimer = null;

    if (!_keepScreenOnService.supportsNative) {
      return;
    }

    if (_autoPager.isRunning) {
      await _keepScreenOnService.setEnabled(true);
      return;
    }

    final keepLightSeconds = _effectiveKeepLightSeconds(settings);
    if (keepLightSeconds == ReadingSettings.keepLightAlways) {
      await _keepScreenOnService.setEnabled(true);
      return;
    }

    if (keepLightSeconds <= ReadingSettings.keepLightFollowSystem) {
      await _keepScreenOnService.setEnabled(false);
      return;
    }

    await _keepScreenOnService.setEnabled(true);
    _keepLightTimer = Timer(Duration(seconds: keepLightSeconds), () {
      _keepLightTimer = null;
      unawaited(_keepScreenOnService.setEnabled(false));
    });
  }

  void _screenOffTimerStart({bool force = false}) {
    if (!_keepScreenOnService.supportsNative) return;
    if (!mounted && !force) return;
    unawaited(_syncNativeKeepScreenOn(_settings));
  }

  void _handleReadingSettingsChanged() {
    if (!mounted) return;
    final latest = _settingsService.readingSettings.sanitize();
    if (_isSameReadingSettings(_settings, latest)) return;
    _updateSettings(latest, persist: false);
  }

  bool _isSameReadingSettings(ReadingSettings a, ReadingSettings b) {
    return json.encode(a.toJson()) == json.encode(b.toJson());
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
    final processedTitle = _postProcessTitle(stage.title);
    final processedContent = _postProcessContent(stage.content, stage.title);
    final seed = _ScrollSegmentSeed(
      chapterId: chapter.id,
      title: processedTitle,
      content: processedContent,
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
    final processedTitle = _postProcessTitle(stage.title);
    final processedContent = _postProcessContent(stage.content, stage.title);
    setState(() {
      _currentChapterIndex = index;
      _currentTitle = processedTitle;
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
        title: _postProcessTitle(title),
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
    _screenOffTimerStart();

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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final safeArea = mediaQuery.padding;
    final viewPadding = mediaQuery.viewPadding;
    final topSafeInset = _settings.showStatusBar
        ? safeArea.top
        : (_settings.paddingDisplayCutouts ? viewPadding.top : 0.0);
    final bottomSafeInset = _settings.hideNavigationBar
        ? (_settings.paddingDisplayCutouts ? viewPadding.bottom : 0.0)
        : safeArea.bottom;
    final horizontalSafeInset =
        _settings.paddingDisplayCutouts ? safeArea.left + safeArea.right : 0.0;

    // 对标 flutter_reader 的布局计算
    final showHeader =
        _settings.shouldShowHeader(showStatusBar: _settings.showStatusBar);
    final showFooter = _settings.shouldShowFooter();
    final topOffset = showHeader ? PagedReaderWidget.topOffset : 0.0;
    final bottomOffset = showFooter ? PagedReaderWidget.bottomOffset : 0.0;

    final contentHeight = screenHeight -
        topSafeInset -
        topOffset -
        bottomSafeInset -
        bottomOffset -
        _settings.paddingTop -
        _settings.paddingBottom;
    final contentWidth = screenWidth -
        horizontalSafeInset -
        _settings.paddingLeft -
        _settings.paddingRight;

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
  void _updateSettings(ReadingSettings newSettings, {bool persist = true}) {
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

    if (_isSameReadingSettings(_settings, newSettings)) {
      return;
    }

    final oldSettings = _settings;
    final oldMode = oldSettings.pageTurnMode;
    final newMode = newSettings.pageTurnMode;
    final modeChanged = oldMode != newMode;
    if (oldSettings.chineseConverterType != newSettings.chineseConverterType) {
      _catalogDisplayTitleCacheByChapterId.clear();
    }

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

    final contentTransformChanged = oldSettings.cleanChapterTitle !=
            newSettings.cleanChapterTitle ||
        oldSettings.chineseConverterType != newSettings.chineseConverterType ||
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
        _currentTitle = _postProcessTitle(title);
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
    if (oldSettings.keepLightSeconds != newSettings.keepLightSeconds ||
        oldSettings.keepScreenOn != newSettings.keepScreenOn) {
      unawaited(_syncNativeKeepScreenOn(newSettings));
    }
    if (oldSettings.screenOrientation != newSettings.screenOrientation) {
      unawaited(_applyPreferredOrientations(newSettings));
    }
    if (oldSettings.showStatusBar != newSettings.showStatusBar ||
        oldSettings.hideNavigationBar != newSettings.hideNavigationBar) {
      _syncSystemUiForOverlay(force: true);
    }
    if (persist) {
      unawaited(_settingsService.saveReadingSettings(newSettings));
    }
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

  List<ReadStyleConfig> get _defaultReadStyleConfigs => AppColors.readingThemes
      .map(
        (theme) => ReadStyleConfig(
          name: theme.name,
          backgroundColor: theme.background.toARGB32(),
          textColor: theme.text.toARGB32(),
        ),
      )
      .toList(growable: false);

  List<ReadStyleConfig> get _activeReadStyleConfigs {
    final configured = _settings.readStyleConfigs;
    if (configured.isNotEmpty) {
      return configured
          .map((config) => config.sanitize())
          .toList(growable: false);
    }
    return _defaultReadStyleConfigs;
  }

  List<ReadingThemeColors> get _activeReadStyles {
    return _activeReadStyleConfigs
        .map(
          (config) => ReadingThemeColors(
            background: Color(config.backgroundColor),
            text: Color(config.textColor),
            name: _readStyleDisplayName(config),
          ),
        )
        .toList(growable: false);
  }

  int get _activeReadStyleIndex {
    final styles = _activeReadStyleConfigs;
    if (styles.isEmpty) return 0;
    return _settings.themeIndex.clamp(0, styles.length - 1).toInt();
  }

  String _readStyleDisplayName(ReadStyleConfig config) {
    final trimmed = config.name.trim();
    return trimmed.isEmpty ? '文字' : trimmed;
  }

  List<ReadStyleConfig> _copyActiveReadStyleConfigs() {
    final current = _activeReadStyleConfigs;
    return current.map((config) => config.copyWith()).toList();
  }

  ReadStyleConfig _createLegacyReadStyleTemplate() {
    return const ReadStyleConfig(
      name: '',
      backgroundColor: ReadStyleConfig.legacyDefaultBackgroundColor,
      textColor: ReadStyleConfig.legacyDefaultTextColor,
    );
  }

  ReadStyleConfig get _currentReadStyleConfig {
    final styles = _activeReadStyleConfigs;
    if (styles.isEmpty) {
      return _createLegacyReadStyleTemplate();
    }
    return styles[_activeReadStyleIndex].sanitize();
  }

  Color get _readerBackgroundBaseColor =>
      Color(_currentReadStyleConfig.backgroundColor);

  bool get _readerUsesImageBackground {
    final bgType = _currentReadStyleConfig.bgType;
    return bgType == ReadStyleConfig.bgTypeAsset ||
        bgType == ReadStyleConfig.bgTypeFile;
  }

  Color get _readerContentBackgroundColor => _readerUsesImageBackground
      ? const Color(0x00000000)
      : _readerBackgroundBaseColor;

  /// 获取当前主题
  ReadingThemeColors get _currentTheme {
    final styles = _activeReadStyles;
    if (styles.isEmpty) {
      return AppColors.readingThemes.first;
    }
    final safeIndex = _activeReadStyleIndex;
    return styles[safeIndex];
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
    return ClickAction.normalizeConfig(_settings.clickActions);
  }

  /// 左右点击翻页处理
  void _handleTap(TapUpDetails details) {
    _screenOffTimerStart();
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
    if (_showMenu || _showSearchMenu || _showAutoReadPanel) return;
    final isRepeat = event is KeyRepeatEvent;
    final isKeyDown = event is KeyDownEvent || isRepeat;
    if (!isKeyDown) return;
    if (isRepeat && !_settings.keyPageOnLongPress) return;
    _screenOffTimerStart();

    final action = ReaderKeyPagingHelper.resolveKeyDownAction(
      key: event.logicalKey,
      volumeKeyPageEnabled: _settings.volumeKeyPage,
    );
    switch (action) {
      case ReaderKeyPagingAction.next:
        _handlePageStep(next: true);
        break;
      case ReaderKeyPagingAction.prev:
        _handlePageStep(next: false);
        break;
      case ReaderKeyPagingAction.none:
        break;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (_showMenu || _showSearchMenu || _showAutoReadPanel) return;
    if (!_settings.mouseWheelPage) return;
    if (event is! PointerScrollEvent) return;
    _screenOffTimerStart();
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
    _screenOffTimerStart();
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
    _screenOffTimerStart();
    switch (action) {
      case ClickAction.off:
        break;
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
      case ClickAction.searchContent:
        _showContentSearchDialog();
        break;
      case ClickAction.editContent:
        _showToast('正文编辑暂未实现');
        break;
      case ClickAction.toggleReplaceRule:
        unawaited(_toggleReplaceRuleState());
        break;
      case ClickAction.syncBookProgress:
        _showToast('云端进度同步暂未实现');
        break;
      case ClickAction.readAloudPrevParagraph:
      case ClickAction.readAloudNextParagraph:
      case ClickAction.readAloudPauseResume:
        _openReadAloudAction();
        break;
      default:
        break;
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
      _settings.headerMode,
      _settings.footerMode,
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
    final showFooter = _settings.shouldShowFooter();

    final snapshot = ScrollPageStepCalculator.buildLayoutSnapshot(
      title: _currentTitle,
      content: _currentContent,
      showTitle: _settings.titleMode != 2,
      maxWidth: contentWidth,
      paddingTop: _settings.paddingTop,
      paddingBottom: showFooter ? 30.0 : _settings.paddingBottom.toDouble(),
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
            milliseconds: ReadingSettings.legacyPageAnimDuration,
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
    processed = _convertByChineseConverterType(processed);
    processed = _formatContentLikeLegado(processed);
    return processed;
  }

  String _postProcessTitle(String title) {
    return _convertByChineseConverterType(title);
  }

  String? _catalogDisplaySourceUrl() {
    final sourceUrl = _currentSourceUrl?.trim();
    if (sourceUrl == null || sourceUrl.isEmpty) return null;
    return sourceUrl;
  }

  Map<int, String> _buildCatalogInitialDisplayTitlesByIndex() {
    if (_chapters.isEmpty || _catalogDisplayTitleCacheByChapterId.isEmpty) {
      return const <int, String>{};
    }
    final initial = <int, String>{};
    for (final chapter in _chapters) {
      final cached = _catalogDisplayTitleCacheByChapterId[chapter.id];
      if (cached == null || cached.trim().isEmpty) continue;
      initial[chapter.index] = cached;
    }
    return initial;
  }

  Future<String> _resolveCatalogDisplayTitle(Chapter chapter) async {
    final cached = _catalogDisplayTitleCacheByChapterId[chapter.id];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }
    final resolved = await _chapterTitleDisplayHelper.buildDisplayTitle(
      rawTitle: chapter.title,
      bookName: widget.bookTitle,
      sourceUrl: _catalogDisplaySourceUrl(),
      chineseConverterType: _settings.chineseConverterType,
      useReplaceRule: _tocUiUseReplace && _useReplaceRule,
    );
    final safeTitle = resolved.trim().isEmpty ? chapter.title : resolved;
    _catalogDisplayTitleCacheByChapterId[chapter.id] = safeTitle;
    return safeTitle;
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

    final title = _useReplaceRule
        ? await _replaceService.applyTitle(
            rawTitle,
            bookName: widget.bookTitle,
            sourceUrl: _currentSourceUrl,
          )
        : rawTitle;
    final content = _useReplaceRule
        ? await _replaceService.applyContent(
            rawContent,
            bookName: widget.bookTitle,
            sourceUrl: _currentSourceUrl,
          )
        : rawContent;

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

  String _convertByChineseConverterType(String text) {
    switch (_settings.chineseConverterType) {
      case ChineseConverterType.traditionalToSimplified:
        return _chineseScriptConverter.traditionalToSimplified(text);
      case ChineseConverterType.simplifiedToTraditional:
        return _chineseScriptConverter.simplifiedToTraditional(text);
      case ChineseConverterType.off:
      default:
        return text;
    }
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
        backgroundColor: _readerBackgroundBaseColor,
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
          if (_settings.disableReturnKey) {
            return;
          }
          // 如果阻止了 pop 且菜单未显示，则显示菜单
          _setReaderMenuVisible(true);
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: _readerBackgroundBaseColor,
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
                    Positioned.fill(
                      child: _buildReaderBackgroundLayer(),
                    ),

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
                    if (!_showMenu &&
                        !_showSearchMenu &&
                        !_showAutoReadPanel &&
                        isScrollMode &&
                        _settings.shouldShowFooter())
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
                    if (!_showMenu &&
                        !_showSearchMenu &&
                        !_showAutoReadPanel &&
                        isScrollMode &&
                        _settings.shouldShowHeader(
                          showStatusBar: _settings.showStatusBar,
                        ))
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
                        chapterUrl: _resolvedCurrentChapterUrlForTopMenu(),
                        sourceName: _currentSourceName,
                        currentTheme: _currentTheme,
                        onOpenBookInfo: () =>
                            unawaited(_openBookInfoFromTopMenu()),
                        onOpenChapterLink: () =>
                            unawaited(_openChapterLinkFromTopMenu()),
                        onToggleChapterLinkOpenMode: () =>
                            unawaited(_toggleChapterLinkOpenModeFromTopMenu()),
                        onShowChapterList: _showChapterList,
                        onSearchContent: _showContentSearchDialog,
                        onShowSourceActions: _showSourceActionsMenu,
                        onToggleCleanChapterTitle:
                            _toggleCleanChapterTitleFromTopMenu,
                        onRefreshChapter: _refreshChapter,
                        onShowMoreMenu: _showReaderActionsMenu,
                        cleanChapterTitleEnabled: _settings.cleanChapterTitle,
                        showSourceAction: !_isCurrentBookLocal(),
                        showChapterLink: !_isCurrentBookLocal(),
                        showTitleAddition: _settings.showReadTitleAddition,
                        readBarStyleFollowPage:
                            _settings.readBarStyleFollowPage,
                      ),

                    // 右侧悬浮快捷栏（对标 legado 快捷动作区）
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
                        readBarStyleFollowPage:
                            _settings.readBarStyleFollowPage,
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
      showStatusBar: _settings.showStatusBar,
      settings: _settings,
      paddingDisplayCutouts: _settings.paddingDisplayCutouts,
      bookTitle: widget.bookTitle,
      // 对标 legado：翻页动画时长固定 300ms
      animDuration: ReadingSettings.legacyPageAnimDuration,
      pageDirection: _settings.pageDirection,
      pageTouchSlop: _settings.pageTouchSlop,
      onAction: _handleClickAction,
      clickActions: _clickActions,
    );
  }

  /// 滚动模式内容（跨章节连续滚动，对齐 legado）
  Widget _buildScrollContent() {
    final applyCutoutPadding = _settings.paddingDisplayCutouts;
    final safeAreaTop = _settings.showStatusBar || applyCutoutPadding;
    if (_scrollSegments.isEmpty) {
      return SafeArea(
        top: safeAreaTop,
        left: applyCutoutPadding,
        right: applyCutoutPadding,
        bottom: false,
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return SafeArea(
      top: safeAreaTop,
      left: applyCutoutPadding,
      right: applyCutoutPadding,
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) {
            return false;
          }

          if (notification is ScrollStartNotification) {
            _screenOffTimerStart();
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

    return KeyedSubtree(
      key: _scrollSegmentKeyFor(segment.chapterIndex),
      child: Padding(
        padding: EdgeInsets.only(
          left: _settings.paddingLeft,
          right: _settings.paddingRight,
          top: _settings.paddingTop,
          bottom: isTailSegment
              ? (_settings.shouldShowFooter() ? 30 : _settings.paddingBottom)
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
            ScrollSegmentPaintView(
              layout: layout,
              style: paragraphStyle,
            ),
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
    _showReadStyleDialog();
  }

  void _openBehaviorSettingsFromMenu() {
    _closeReaderMenuOverlay();
    _showLegacyMoreConfigDialog();
  }

  void _openReadAloudFromMenu() {
    _closeReaderMenuOverlay();
    _openReadAloudAction();
  }

  void _toggleAutoPageFromQuickAction() {
    _closeReaderMenuOverlay();
    _autoPager.toggle();
    _screenOffTimerStart(force: true);
  }

  Future<void> _openReplaceRuleFromMenu() async {
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
          _currentChapterIndex.clamp(0, _chapters.length - 1).toInt();
      await _loadChapter(
        targetIndex,
        restoreOffset: true,
      );
    }
    if (!mounted) return;
    _showToast(nextUseReplaceRule ? '已开启替换规则' : '已关闭替换规则');
  }

  void _toggleDayNightThemeFromQuickAction() {
    final targetIndex = ReaderLegacyQuickActionHelper.resolveToggleThemeIndex(
      currentIndex: _settings.themeIndex,
      themes: _activeReadStyles,
    );
    if (targetIndex == _settings.themeIndex) {
      return;
    }
    _updateSettings(_settings.copyWith(themeIndex: targetIndex));
  }

  void _openReadAloudAction() {
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
    final isLocal = _isCurrentBookLocal();
    final actions = ReaderLegacyMenuHelper.buildReadMenuActions(
      isOnline: !isLocal,
      isLocalTxt: _isCurrentBookLocalTxt(),
      isEpub: _isCurrentBookEpub(),
    );
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('阅读操作'),
        actions: actions
            .map(
              (action) => CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _executeLegacyReadMenuAction(action);
                },
                child: Text(_readerActionLabel(action)),
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

  String _readerActionLabel(ReaderLegacyReadMenuAction action) {
    final raw = ReaderLegacyMenuHelper.readMenuLabel(action);
    final checked = switch (action) {
      ReaderLegacyReadMenuAction.enableReplace => _useReplaceRule,
      _ => false,
    };
    return checked ? '✓ $raw' : raw;
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
    final navBtnBg = _uiPanelBg.withValues(alpha: _isUiDark ? 0.88 : 0.94);
    final navBtnShadow = CupertinoColors.black.withValues(
      alpha: _isUiDark ? 0.32 : 0.12,
    );
    final sideButtonTop = MediaQuery.of(context).size.height * 0.44;

    return Stack(
      children: [
        Positioned(
          left: 16,
          top: sideButtonTop,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _contentSearchHits.isEmpty
                ? null
                : () => _navigateSearchHit(-1),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: navBtnBg,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: _uiBorder),
                boxShadow: [
                  BoxShadow(
                    color: navBtnShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(CupertinoIcons.chevron_left, color: _uiTextStrong),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: sideButtonTop,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed:
                _contentSearchHits.isEmpty ? null : () => _navigateSearchHit(1),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: navBtnBg,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: _uiBorder),
                boxShadow: [
                  BoxShadow(
                    color: navBtnShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              decoration: BoxDecoration(
                color: _uiPanelBg.withValues(alpha: 0.97),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                border: Border.all(color: _uiBorder),
                boxShadow: [
                  BoxShadow(
                    color: navBtnShadow,
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _uiCardBg.withValues(alpha: _isUiDark ? 0.82 : 0.96),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _uiBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: enabled ? color : _uiTextSubtle,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? color : _uiTextSubtle,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionRail() {
    final topOffset = MediaQuery.of(context).padding.top + 92;
    final actionOrder = ReaderLegacyQuickActionHelper.legacyOrder;
    return Positioned(
      right: 8,
      top: topOffset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: _uiPanelBg.withValues(alpha: _isUiDark ? 0.64 : 0.84),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _uiBorder),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black
                  .withValues(alpha: _isUiDark ? 0.24 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: List<Widget>.generate(actionOrder.length * 2 - 1, (index) {
            if (index.isOdd) {
              return const SizedBox(height: 6);
            }
            final action = actionOrder[index ~/ 2];
            return _buildLegacyQuickActionButton(action);
          }),
        ),
      ),
    );
  }

  Widget _buildLegacyQuickActionButton(ReaderLegacyQuickAction action) {
    switch (action) {
      case ReaderLegacyQuickAction.searchContent:
        return _buildFloatingActionButton(
          icon: CupertinoIcons.search,
          semanticLabel: '搜索正文',
          onTap: _showContentSearchDialog,
        );
      case ReaderLegacyQuickAction.autoPage:
        final running = _autoPager.isRunning;
        return _buildFloatingActionButton(
          icon: running ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
          semanticLabel: running ? '停止自动翻页' : '自动翻页',
          active: running,
          onTap: _toggleAutoPageFromQuickAction,
        );
      case ReaderLegacyQuickAction.replaceRule:
        return _buildFloatingActionButton(
          icon: CupertinoIcons.refresh,
          semanticLabel: '替换规则',
          onTap: () => unawaited(_openReplaceRuleFromMenu()),
        );
      case ReaderLegacyQuickAction.toggleDayNightTheme:
        final isDark = _currentTheme.isDark;
        return _buildFloatingActionButton(
          icon: isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon_fill,
          semanticLabel: isDark ? '切换日间模式' : '切换夜间模式',
          onTap: _toggleDayNightThemeFromQuickAction,
        );
    }
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? _uiAccent.withValues(alpha: 0.22)
              : _uiPanelBg.withValues(alpha: _isUiDark ? 0.62 : 0.8),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: active ? _uiAccent : _uiBorder,
          ),
        ),
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Icon(
            icon,
            size: 19,
            color: active ? _uiAccent : _uiTextStrong,
          ),
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

  String _normalizeChapterUrl(String? url) {
    return ReaderTopBarActionHelper.normalizeChapterUrl(url);
  }

  bool _isCurrentBookLocal() {
    if (widget.isEphemeral) return false;
    return _bookRepo.getBookById(widget.bookId)?.isLocal ?? false;
  }

  bool _isCurrentBookLocalTxt() {
    if (widget.isEphemeral) return false;
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || !book.isLocal) return false;
    final lower = ((book.localPath ?? book.bookUrl ?? '')).toLowerCase();
    return lower.endsWith('.txt');
  }

  bool _isCurrentBookEpub() {
    if (widget.isEphemeral) return false;
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || !book.isLocal) return false;
    final lower = ((book.localPath ?? book.bookUrl ?? '')).toLowerCase();
    return lower.endsWith('.epub');
  }

  bool _defaultUseReplaceRule() {
    // 对齐 legado：epub（以及图片类）默认关闭替换规则；
    // 当前项目暂无图片阅读模式，先按 epub 分支对齐默认语义。
    if (_isCurrentBookEpub()) {
      return false;
    }
    return true;
  }

  Future<void> _openExceptionLogsFromReader() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ExceptionLogsView(),
      ),
    );
  }

  void _showReaderActionUnavailable(
    String label, {
    String? reason,
  }) {
    final suffix =
        reason?.trim().isNotEmpty == true ? '：${reason!.trim()}' : '：当前版本暂未支持';
    _showToast('$label$suffix');
  }

  Future<void> _exportBookmarksFromReader({
    required bool markdown,
  }) async {
    final bookmarks = _bookmarkRepo.getBookmarksForBook(widget.bookId);
    final result = markdown
        ? await _bookmarkExportService.exportMarkdown(
            bookTitle: widget.bookTitle,
            bookAuthor: _bookAuthor,
            bookmarks: bookmarks,
          )
        : await _bookmarkExportService.exportJson(
            bookTitle: widget.bookTitle,
            bookAuthor: _bookAuthor,
            bookmarks: bookmarks,
          );
    if (!mounted) return;
    if (result.success) {
      final path = result.outputPath?.trim();
      if (path != null && path.isNotEmpty) {
        _showToast('导出成功：$path');
      } else {
        _showToast(result.message ?? '导出成功');
      }
      return;
    }
    if (result.cancelled) return;
    _showToast(result.message ?? '导出失败');
  }

  Future<void> _executeLegacyReadMenuAction(
    ReaderLegacyReadMenuAction action,
  ) async {
    switch (action) {
      case ReaderLegacyReadMenuAction.changeSource:
        await _showSwitchSourceMenu();
        return;
      case ReaderLegacyReadMenuAction.refresh:
        _refreshChapter();
        return;
      case ReaderLegacyReadMenuAction.download:
        _showReaderActionUnavailable('离线缓存');
        return;
      case ReaderLegacyReadMenuAction.tocRule:
        _showReaderActionUnavailable('TXT 目录规则');
        return;
      case ReaderLegacyReadMenuAction.setCharset:
        _showReaderActionUnavailable(
          '设置编码',
          reason: '书籍级编码覆盖尚未接入正文解析链路',
        );
        return;
      case ReaderLegacyReadMenuAction.addBookmark:
        await _toggleBookmark();
        return;
      case ReaderLegacyReadMenuAction.editContent:
        _showReaderActionUnavailable('编辑正文');
        return;
      case ReaderLegacyReadMenuAction.pageAnim:
        _openInterfaceSettingsFromMenu();
        return;
      case ReaderLegacyReadMenuAction.getProgress:
        _showReaderActionUnavailable('获取进度');
        return;
      case ReaderLegacyReadMenuAction.coverProgress:
        _showReaderActionUnavailable('覆盖进度');
        return;
      case ReaderLegacyReadMenuAction.reverseContent:
        _showReaderActionUnavailable('正文倒序');
        return;
      case ReaderLegacyReadMenuAction.simulatedReading:
        _showReaderActionUnavailable('模拟阅读');
        return;
      case ReaderLegacyReadMenuAction.enableReplace:
        await _toggleReplaceRuleState();
        return;
      case ReaderLegacyReadMenuAction.sameTitleRemoved:
        _showReaderActionUnavailable('同名标题去重');
        return;
      case ReaderLegacyReadMenuAction.reSegment:
        _showReaderActionUnavailable('重新分段');
        return;
      case ReaderLegacyReadMenuAction.delRubyTag:
        _showReaderActionUnavailable('删除 ruby 标签');
        return;
      case ReaderLegacyReadMenuAction.delHTag:
        _showReaderActionUnavailable('删除 h 标签');
        return;
      case ReaderLegacyReadMenuAction.imageStyle:
        _showReaderActionUnavailable('图片样式');
        return;
      case ReaderLegacyReadMenuAction.updateToc:
        try {
          final updated = await _refreshCatalogFromSource();
          if (!mounted) return;
          _showToast('目录已更新，共 ${updated.length} 章');
        } catch (e) {
          if (!mounted) return;
          _showToast('更新目录失败：$e');
        }
        return;
      case ReaderLegacyReadMenuAction.effectiveReplaces:
        await _openReplaceRuleFromMenu();
        return;
      case ReaderLegacyReadMenuAction.log:
        await _openExceptionLogsFromReader();
        return;
      case ReaderLegacyReadMenuAction.help:
        _showToast('阅读菜单帮助：顶部为书籍与书源动作，底部可进入目录/朗读/界面/设置。');
        return;
    }
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

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(initialUrl: chapterUrl),
      ),
    );
  }

  Future<void> _toggleChapterLinkOpenModeFromTopMenu() async {
    if (_isCurrentBookLocal()) {
      _showToast('本地书籍不支持章节链接打开');
      return;
    }

    final currentOpenInBrowser = _settingsService.readerChapterUrlOpenInBrowser;
    final nextOpenInBrowser = await showCupertinoDialog<bool>(
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

  Future<void> _toggleCleanChapterTitleFromTopMenu() async {
    _updateSettings(
      _settings.copyWith(cleanChapterTitle: !_settings.cleanChapterTitle),
    );
    if (!mounted) return;
    _showToast(_settings.cleanChapterTitle ? '已开启净化章节标题' : '已关闭净化章节标题');
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

    final hasLogin = ReaderSourceActionHelper.hasLoginUrl(source.loginUrl);
    final hasPayAction =
        ReaderSourceActionHelper.hasPayAction(source.ruleContent?.payAction);
    final showChapterPay = ReaderSourceActionHelper.shouldShowChapterPay(
      hasLoginUrl: hasLogin,
      hasPayAction: hasPayAction,
      currentChapterIsVip: _resolveCurrentChapterIsVip(),
      currentChapterIsPay: _resolveCurrentChapterIsPay(),
    );

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        message: Text(source.bookSourceUrl),
        actions: [
          if (hasLogin)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _openSourceLoginFromReader(source);
              },
              child: const Text('登录'),
            ),
          if (showChapterPay)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _triggerChapterPayAction(source);
              },
              child: const Text('章节购买'),
            ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _openSourceEditorFromReader(source);
            },
            child: const Text('编辑书源'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(sheetContext);
              await _disableSourceFromReader(source);
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

  Future<void> _openSourceLoginFromReader(BookSource source) async {
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
        builder: (_) => SourceWebVerifyView(initialUrl: resolvedUrl),
      ),
    );
  }

  Future<void> _triggerChapterPayAction(BookSource source) async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      _showToast('当前章节不存在');
      return;
    }
    final chapter = _chapters[_currentChapterIndex];
    final payAction = (source.ruleContent?.payAction ?? '').trim();
    if (payAction.isEmpty) {
      _showToast('当前书源未配置购买动作');
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('章节购买'),
            content: Text('\n${chapter.title}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('购买'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final output = _evaluateChapterPayAction(
      source: source,
      chapter: chapter,
      payAction: payAction,
    );
    if (output.startsWith('__SR_CHAPTER_PAY_ERR__')) {
      final reason = output.replaceFirst('__SR_CHAPTER_PAY_ERR__', '').trim();
      _showToast(reason.isEmpty ? '章节购买执行失败' : '章节购买执行失败：$reason');
      return;
    }

    final result = ReaderSourceActionHelper.resolvePayActionOutput(output);
    switch (result.type) {
      case ReaderSourcePayActionResultType.url:
        final payUrl = result.url;
        if (payUrl == null || payUrl.isEmpty) {
          _showToast('章节购买地址为空');
          return;
        }
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => SourceWebVerifyView(initialUrl: payUrl),
          ),
        );
        return;
      case ReaderSourcePayActionResultType.success:
        await _reloadCurrentChapterAfterPurchase();
        if (!mounted) return;
        _showToast('章节购买完成，已刷新当前章节');
        return;
      case ReaderSourcePayActionResultType.noop:
        _showToast('章节购买未返回可执行结果');
        return;
      case ReaderSourcePayActionResultType.unsupported:
        _showToast('章节购买动作返回暂不支持的结果');
        return;
    }
  }

  String _evaluateChapterPayAction({
    required BookSource source,
    required Chapter chapter,
    required String payAction,
  }) {
    final runtime = createJsRuntime();
    final chapterUrl = (chapter.url ?? '').trim();
    final book = _bookRepo.getBookById(widget.bookId);
    final script = '''
      (function() {
        try {
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
            index: $_currentChapterIndex,
            isVip: ${jsonEncode(_resolveCurrentChapterIsVip())},
            isPay: ${jsonEncode(_resolveCurrentChapterIsPay())}
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
        } catch (e) {
          return '__SR_CHAPTER_PAY_ERR__' + String(e);
        }
      })()
    ''';
    return runtime.evaluate(script).trim();
  }

  Future<void> _reloadCurrentChapterAfterPurchase() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return;
    }
    final chapterIndex = _currentChapterIndex;
    final previousChapter = _chapters[chapterIndex];
    final nextChapters = List<Chapter>.from(_chapters, growable: false);
    nextChapters[chapterIndex] = previousChapter.copyWith(
      content: null,
      isDownloaded: false,
    );
    if (mounted) {
      setState(() {
        _chapters = nextChapters;
      });
    } else {
      _chapters = nextChapters;
    }
    _replaceStageCache.remove(previousChapter.id);
    await _loadChapter(
      chapterIndex,
      restoreOffset: _settings.pageTurnMode == PageTurnMode.scroll,
    );
  }

  Future<void> _openSourceEditorFromReader(BookSource source) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditLegacyView.fromSource(
          source,
          rawJson: _sourceRepo.getRawJsonByUrl(source.bookSourceUrl),
        ),
      ),
    );
    _refreshCurrentSourceName();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _disableSourceFromReader(BookSource source) async {
    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('禁用书源'),
            content: Text('\n确定禁用 ${source.bookSourceName}？'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('禁用'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    await _sourceRepo.updateSource(
      source.copyWith(enabled: false),
    );
    if (!mounted) return;
    _showToast('已禁用书源：${source.bookSourceName}');
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

    final selected = await showSourceSwitchCandidateSheet(
      context: context,
      keyword: keyword,
      candidates: candidates,
    );
    if (selected == null) return;
    await _switchToSourceCandidate(selected);
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
    return ((progress - 50) / 100).toStringAsFixed(1);
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

  void _showReadStyleDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => StatefulBuilder(
        builder: (context, setPopupState) {
          final textSizeProgress = _legacyTextSizeProgress();
          final letterSpacingProgress = _legacyLetterSpacingProgress();
          final lineSpacingProgress = _legacyLineSpacingProgress();
          final paragraphSpacingProgress = _legacyParagraphSpacingProgress();
          final pageAnimMode = _legacyStyleDialogPageAnimMode();
          final pageAnimItems = const <MapEntry<PageTurnMode, String>>[
            MapEntry(PageTurnMode.cover, '覆盖'),
            MapEntry(PageTurnMode.slide, '滑动'),
            MapEntry(PageTurnMode.simulation, '仿真'),
            MapEntry(PageTurnMode.scroll, '滚动'),
            MapEntry(PageTurnMode.none, '无'),
          ];
          final readStyles = _activeReadStyles;
          final styleConfigs = _activeReadStyleConfigs;
          final styleCount = readStyles.length;
          final activeThemeIndex = _activeReadStyleIndex;
          final indentOptions = const <String>['', '　', '　　', '　　　'];
          final currentIndentIndex =
              indentOptions.indexOf(_settings.paragraphIndent);
          final safeIndentIndex =
              currentIndentIndex < 0 ? 2 : currentIndentIndex;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: _uiPanelBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          _buildReadStyleActionChip(
                            label: '粗细',
                            onTap: () => _updateSettingsFromSheet(
                              setPopupState,
                              _settings.copyWith(
                                textBold:
                                    _nextTextBoldValue(_settings.textBold),
                              ),
                            ),
                          ),
                          const Spacer(),
                          _buildReadStyleActionChip(
                            label: '字体',
                            onTap: () => showCupertinoModalPopup<void>(
                              context: context,
                              builder: (_) =>
                                  _buildFontSelectDialog(setPopupState),
                            ),
                          ),
                          const Spacer(),
                          _buildReadStyleActionChip(
                            label: '缩进',
                            onTap: () {
                              final nextIndex =
                                  (safeIndentIndex + 1) % indentOptions.length;
                              _updateSettingsFromSheet(
                                setPopupState,
                                _settings.copyWith(
                                  paragraphIndent: indentOptions[nextIndex],
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          _buildReadStyleActionChip(
                            label: '简繁',
                            onTap: () {
                              final modes = ChineseConverterType.values;
                              final currentModeIndex =
                                  modes.indexOf(_settings.chineseConverterType);
                              final safeModeIndex =
                                  currentModeIndex < 0 ? 0 : currentModeIndex;
                              final nextMode =
                                  modes[(safeModeIndex + 1) % modes.length];
                              _updateSettingsFromSheet(
                                setPopupState,
                                _settings.copyWith(
                                  chineseConverterType: nextMode,
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          _buildReadStyleActionChip(
                            label: '边距',
                            onTap: () {
                              Navigator.of(popupContext).pop();
                              Future<void>.microtask(() {
                                showTypographySettingsDialog(
                                  this.context,
                                  settings: _settings,
                                  onSettingsChanged: _updateSettings,
                                );
                              });
                            },
                          ),
                          const Spacer(),
                          _buildReadStyleActionChip(
                            label: '信息',
                            onTap: () {
                              _showLegacyTipConfigDialog();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReadStyleSeekBar(
                      title: '字号',
                      progress: textSizeProgress,
                      max: 45,
                      valueLabel: '${textSizeProgress + 5}',
                      onChanged: (progress) => _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(fontSize: (progress + 5).toDouble()),
                      ),
                    ),
                    _buildReadStyleSeekBar(
                      title: '字距',
                      progress: letterSpacingProgress,
                      max: 100,
                      valueLabel:
                          _legacyLetterSpacingLabel(letterSpacingProgress),
                      onChanged: (progress) => _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(
                          letterSpacing: (progress - 50) / 100,
                        ),
                      ),
                    ),
                    _buildReadStyleSeekBar(
                      title: '行距',
                      progress: lineSpacingProgress,
                      max: 20,
                      valueLabel: _legacyLineSpacingLabel(lineSpacingProgress),
                      onChanged: (progress) => _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(
                          lineHeight: (1.0 + (progress - 10) / 10).toDouble(),
                        ),
                      ),
                    ),
                    _buildReadStyleSeekBar(
                      title: '段距',
                      progress: paragraphSpacingProgress,
                      max: 20,
                      valueLabel: _legacyParagraphSpacingLabel(
                          paragraphSpacingProgress),
                      onChanged: (progress) => _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(
                          paragraphSpacing: progress.toDouble(),
                        ),
                      ),
                    ),
                    Container(
                      height: 0.8,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: _uiBorder.withValues(alpha: 0.9),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        '翻页动画',
                        style: TextStyle(
                          color: _uiTextStrong.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      child: Row(
                        children: pageAnimItems.map((item) {
                          final isSelected = pageAnimMode == item.key;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: GestureDetector(
                                onTap: () => _updateSettingsFromSheet(
                                  setPopupState,
                                  _settings.copyWith(pageTurnMode: item.key),
                                ),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _uiCardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? _uiAccent : _uiBorder,
                                    ),
                                  ),
                                  child: Text(
                                    item.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected
                                          ? _uiAccent
                                          : _uiTextNormal,
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ),
                    Container(
                      height: 0.8,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: _uiBorder.withValues(alpha: 0.9),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '背景文字样式',
                              style: TextStyle(
                                color: _uiTextStrong.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '共享布局',
                            style: TextStyle(
                              color: _uiTextNormal,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _updateSettingsFromSheet(
                              setPopupState,
                              _settings.copyWith(
                                shareLayout: !_settings.shareLayout,
                              ),
                            ),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _settings.shareLayout
                                    ? _uiAccent
                                    : _uiCardBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _settings.shareLayout
                                      ? _uiAccent
                                      : _uiBorder,
                                ),
                              ),
                              child: _settings.shareLayout
                                  ? const Icon(
                                      CupertinoIcons.check_mark,
                                      size: 14,
                                      color: CupertinoColors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: styleCount + 1,
                        itemBuilder: (context, index) {
                          if (index == styleCount) {
                            return GestureDetector(
                              onTap: () => _addReadStyleFromDialog(
                                setPopupState,
                              ),
                              child: Container(
                                width: 72,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: _uiCardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _uiBorder),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  CupertinoIcons.add,
                                  color: _uiTextNormal,
                                  size: 20,
                                ),
                              ),
                            );
                          }

                          final theme = readStyles[index];
                          final config = styleConfigs[index];
                          final isSelected = activeThemeIndex == index;
                          return GestureDetector(
                            onTap: () => _updateSettingsFromSheet(
                              setPopupState,
                              _settings.copyWith(themeIndex: index),
                            ),
                            onLongPress: () => _editReadStyleFromDialog(
                              setPopupState,
                              styleIndex: index,
                            ),
                            child: Container(
                              width: 72,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _uiCardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? _uiAccent : _uiBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _readStyleDisplayName(config),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addReadStyleFromDialog(StateSetter setPopupState) async {
    final styles = _copyActiveReadStyleConfigs();
    styles.add(_createLegacyReadStyleTemplate());
    final createdIndex = styles.length - 1;
    _updateSettingsFromSheet(
      setPopupState,
      _settings.copyWith(
        readStyleConfigs: styles,
        themeIndex: createdIndex,
      ),
    );
    await _editReadStyleFromDialog(
      setPopupState,
      styleIndex: createdIndex,
    );
  }

  Future<void> _editReadStyleFromDialog(
    StateSetter setPopupState, {
    required int styleIndex,
  }) async {
    if (styleIndex < 0) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setEditorState) {
          final styles = _activeReadStyleConfigs;
          if (styles.isEmpty || styleIndex >= styles.length) {
            return const SizedBox.shrink();
          }
          final style = styles[styleIndex];
          final canDelete = styles.length > ReadStyleConfig.minEditableCount;
          final defaultStyles = _defaultReadStyleConfigs;

          Future<void> applyStyle(ReadStyleConfig next) async {
            final nextStyles = _copyActiveReadStyleConfigs();
            if (styleIndex < 0 || styleIndex >= nextStyles.length) {
              return;
            }
            nextStyles[styleIndex] = next.sanitize();
            _updateSettingsFromSheet(
              setPopupState,
              _settings.copyWith(
                readStyleConfigs: nextStyles,
                themeIndex: styleIndex,
              ),
            );
            setEditorState(() {});
          }

          Future<void> onDelete() async {
            if (!canDelete) {
              _showToast('数量已是最少,不能删除.');
              return;
            }
            final confirmed = await showCupertinoDialog<bool>(
              context: dialogContext,
              builder: (confirmContext) => CupertinoAlertDialog(
                title: const Text('删除样式'),
                content: const Text('\n确定删除当前样式吗？'),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(confirmContext, false),
                    child: const Text('取消'),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () => Navigator.pop(confirmContext, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirmed != true) {
              return;
            }
            final nextStyles = _copyActiveReadStyleConfigs();
            if (styleIndex < 0 || styleIndex >= nextStyles.length) {
              return;
            }
            nextStyles.removeAt(styleIndex);
            if (nextStyles.isEmpty) {
              nextStyles.add(_createLegacyReadStyleTemplate());
            }
            var nextIndex = _settings.themeIndex;
            if (styleIndex <= nextIndex) {
              nextIndex -= 1;
            }
            nextIndex = nextIndex.clamp(0, nextStyles.length - 1).toInt();
            _updateSettingsFromSheet(
              setPopupState,
              _settings.copyWith(
                readStyleConfigs: nextStyles,
                themeIndex: nextIndex,
              ),
            );
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
            }
          }

          Future<void> onImportFromFile() async {
            final result = await _readStyleImportExportService.importFromFile();
            if (result.cancelled) {
              return;
            }
            if (!result.success || result.style == null) {
              _showToast(result.message ?? '导入失败');
              return;
            }
            await applyStyle(result.style!);
            final warning = result.warning?.trim();
            if (warning != null && warning.isNotEmpty) {
              _showToast('导入成功（$warning）');
              return;
            }
            _showToast(result.message ?? '导入成功');
          }

          Future<void> onImportFromUrl() async {
            final url = await _showReadStyleImportUrlInputDialog();
            if (url == null || url.trim().isEmpty) {
              return;
            }
            final result =
                await _readStyleImportExportService.importFromUrl(url);
            if (result.cancelled) {
              return;
            }
            if (!result.success || result.style == null) {
              _showToast(result.message ?? '导入失败');
              return;
            }
            await applyStyle(result.style!);
            final warning = result.warning?.trim();
            if (warning != null && warning.isNotEmpty) {
              _showToast('导入成功（$warning）');
              return;
            }
            _showToast(result.message ?? '导入成功');
          }

          Future<void> onExport() async {
            final result =
                await _readStyleImportExportService.exportStyle(style);
            if (result.cancelled) {
              return;
            }
            if (!result.success) {
              _showToast(result.message ?? '导出失败');
              return;
            }
            final path = result.outputPath?.trim();
            if (path != null && path.isNotEmpty) {
              _showToast('导出成功：$path');
              return;
            }
            _showToast(result.message ?? '导出成功');
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.66,
            ),
            decoration: BoxDecoration(
              color: _uiPanelBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                            '背景文字样式',
                            style: TextStyle(
                              color: _uiTextStrong,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 30,
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: _uiTextSubtle,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          _buildOptionRow(
                            '样式名称',
                            _readStyleDisplayName(style),
                            () async {
                              final editedName =
                                  await _showReadStyleNameInputDialog(
                                initialValue: style.name,
                              );
                              if (editedName == null) return;
                              await applyStyle(
                                  style.copyWith(name: editedName));
                            },
                          ),
                          _buildOptionRow(
                            '文字颜色',
                            '#${_hexRgb(style.textColor)}',
                            () async {
                              final nextColor =
                                  await _showReadStyleColorInputDialog(
                                title: '文字颜色',
                                initialColor: style.textColor,
                              );
                              if (nextColor == null) return;
                              await applyStyle(
                                style.copyWith(textColor: nextColor),
                              );
                            },
                          ),
                          _buildOptionRow(
                            '背景颜色',
                            '#${_hexRgb(style.backgroundColor)}',
                            () async {
                              final nextColor =
                                  await _showReadStyleColorInputDialog(
                                title: '背景颜色',
                                initialColor:
                                    style.bgType == ReadStyleConfig.bgTypeColor
                                        ? style.backgroundColor
                                        : 0xFF015A86,
                              );
                              if (nextColor == null) return;
                              await applyStyle(
                                style.copyWith(
                                  backgroundColor: nextColor,
                                  bgType: ReadStyleConfig.bgTypeColor,
                                  bgStr: '#${_hexRgb(nextColor)}',
                                ),
                              );
                            },
                          ),
                          _buildOptionRow(
                            '背景图片',
                            _readStyleBackgroundValueLabel(style),
                            () async {
                              final next =
                                  await _showReadStyleBackgroundSourceDialog(
                                style: style,
                              );
                              if (next == null) {
                                return;
                              }
                              await applyStyle(next);
                            },
                          ),
                          _buildReadStyleSeekBar(
                            title: '透明度',
                            progress: style.bgAlpha.clamp(0, 100).toInt(),
                            max: 100,
                            valueLabel:
                                '${style.bgAlpha.clamp(0, 100).toInt()}%',
                            onChanged: (progress) {
                              unawaited(
                                applyStyle(style.copyWith(bgAlpha: progress)),
                              );
                            },
                          ),
                          _buildOptionRow(
                            '恢复预设',
                            '选择',
                            () async {
                              final presetIndex =
                                  await _showReadStylePresetPicker(
                                defaultStyles: defaultStyles,
                              );
                              if (presetIndex == null ||
                                  presetIndex < 0 ||
                                  presetIndex >= defaultStyles.length) {
                                return;
                              }
                              await applyStyle(
                                defaultStyles[presetIndex].copyWith(),
                              );
                            },
                          ),
                          _buildOptionRow(
                            '导入配置',
                            '选择文件',
                            () => unawaited(onImportFromFile()),
                          ),
                          _buildOptionRow(
                            '网络导入',
                            '输入地址',
                            () => unawaited(onImportFromUrl()),
                          ),
                          _buildOptionRow(
                            '导出配置',
                            '保存文件',
                            () => unawaited(onExport()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: canDelete
                            ? CupertinoColors.systemRed.withValues(alpha: 0.16)
                            : _uiCardBg,
                        onPressed: onDelete,
                        child: Text(
                          '删除样式',
                          style: TextStyle(
                            color: canDelete
                                ? CupertinoColors.systemRed
                                : _uiTextSubtle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String?> _showReadStyleNameInputDialog({
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('样式名称'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '请输入样式名称',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<int?> _showReadStyleColorInputDialog({
    required String title,
    required int initialColor,
  }) async {
    final controller = TextEditingController(text: _hexRgb(initialColor));
    final parsed = await showCupertinoDialog<int>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            placeholder: '输入 6 位十六进制，如 FF6600',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final value = _parseRgbColor(controller.text);
              if (value == null) {
                _showToast('请输入 6 位十六进制颜色（如 FF6600）');
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return parsed;
  }

  Future<int?> _showReadStylePresetPicker({
    required List<ReadStyleConfig> defaultStyles,
  }) {
    if (defaultStyles.isEmpty) {
      return Future<int?>.value(null);
    }
    return showCupertinoModalPopup<int>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('选择预设布局'),
        actions: List<Widget>.generate(defaultStyles.length, (index) {
          final name = _readStyleDisplayName(defaultStyles[index]);
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(popupContext, index),
            child: Text(name),
          );
        }),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  String _readStyleBackgroundValueLabel(ReadStyleConfig style) {
    final safeStyle = style.sanitize();
    switch (safeStyle.bgType) {
      case ReadStyleConfig.bgTypeAsset:
        final name = _readStyleBackgroundDisplayName(safeStyle.bgStr);
        return name.isEmpty ? '内置背景' : '内置:$name';
      case ReadStyleConfig.bgTypeFile:
        final name = _readStyleBackgroundDisplayName(safeStyle.bgStr);
        return name.isEmpty ? '本地图片' : '本地:$name';
      case ReadStyleConfig.bgTypeColor:
      default:
        return '无';
    }
  }

  String _readStyleBackgroundDisplayName(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final normalized = value.replaceAll('\\', '/');
    final baseName = p.basename(normalized);
    final withoutExt = p.basenameWithoutExtension(baseName).trim();
    if (withoutExt.isNotEmpty) {
      return withoutExt;
    }
    return baseName.trim();
  }

  Future<ReadStyleConfig?> _showReadStyleBackgroundSourceDialog({
    required ReadStyleConfig style,
  }) async {
    final selectedAction = await showCupertinoModalPopup<_ReadStyleBgAction>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('背景图片'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(popupContext, _ReadStyleBgAction.asset),
            child: const Text('选择内置背景'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(popupContext, _ReadStyleBgAction.file),
            child: const Text('选择本地图片'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(popupContext, _ReadStyleBgAction.clear),
            child: const Text('使用纯色背景'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );

    switch (selectedAction) {
      case _ReadStyleBgAction.asset:
        final assetName = await _showReadStyleAssetBackgroundPicker();
        if (assetName == null || assetName.trim().isEmpty) {
          return null;
        }
        return style.copyWith(
          bgType: ReadStyleConfig.bgTypeAsset,
          bgStr: assetName.trim(),
        );
      case _ReadStyleBgAction.file:
        final filePath = await _pickReadStyleBackgroundImageFromDevice();
        if (filePath == null || filePath.trim().isEmpty) {
          return null;
        }
        return style.copyWith(
          bgType: ReadStyleConfig.bgTypeFile,
          bgStr: filePath.trim(),
        );
      case _ReadStyleBgAction.clear:
        return style.copyWith(
          bgType: ReadStyleConfig.bgTypeColor,
          bgStr: '#${_hexRgb(style.backgroundColor)}',
        );
      case null:
        return null;
    }
  }

  Future<String?> _showReadStyleAssetBackgroundPicker() async {
    final assetNames = await _loadBundledReadStyleAssetNames();
    if (assetNames.isEmpty) {
      _showToast('当前未配置内置背景图');
      return null;
    }
    if (!mounted) {
      return null;
    }
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('选择内置背景'),
        actions: List<Widget>.generate(assetNames.length, (index) {
          final name = assetNames[index];
          final displayName = _readStyleBackgroundDisplayName(name);
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(popupContext, name),
            child: Text(displayName.isEmpty ? name : displayName),
          );
        }),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<List<String>> _loadBundledReadStyleAssetNames() async {
    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final decoded = json.decode(manifestRaw);
      if (decoded is! Map) {
        return const <String>[];
      }
      final names = <String>{};
      for (final key in decoded.keys) {
        final assetPath = '$key'.trim();
        if (!assetPath.startsWith('assets/bg/')) {
          continue;
        }
        final name = assetPath.substring('assets/bg/'.length).trim();
        if (name.isEmpty) {
          continue;
        }
        names.add(name);
      }
      final sorted = names.toList()..sort();
      return sorted;
    } catch (_) {
      return const <String>[];
    }
  }

  Future<String?> _pickReadStyleBackgroundImageFromDevice() async {
    if (kIsWeb) {
      _showToast('当前平台暂不支持选择本地背景图');
      return null;
    }
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty) {
        return null;
      }

      final selected = picked.files.first;
      final sourcePath = selected.path?.trim();
      if (sourcePath == null || sourcePath.isEmpty) {
        _showToast('无法读取图片路径');
        return null;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        _showToast('图片文件不存在');
        return null;
      }

      final bgDirectory = await _resolveReadStyleBackgroundDirectory();
      if (!await bgDirectory.exists()) {
        await bgDirectory.create(recursive: true);
      }

      final originalName = selected.name.trim().isNotEmpty
          ? selected.name.trim()
          : p.basename(sourcePath);
      final normalizedName =
          originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final fallbackName =
          normalizedName.isNotEmpty ? normalizedName : 'bg.jpg';
      final extension = p.extension(fallbackName).toLowerCase();
      final safeExtension = extension.isEmpty ? '.jpg' : extension;
      final baseName = p.basenameWithoutExtension(fallbackName).trim();
      final safeBaseName = baseName.isEmpty ? 'bg' : baseName;
      final targetName =
          '${safeBaseName}_${DateTime.now().millisecondsSinceEpoch}$safeExtension';
      final targetPath = p.join(bgDirectory.path, targetName);
      final saved = await sourceFile.copy(targetPath);
      return saved.path;
    } catch (e) {
      _showToast('选择背景图失败: $e');
      return null;
    }
  }

  Future<Directory> _resolveReadStyleBackgroundDirectory() async {
    final docsDirectory = await getApplicationDocumentsDirectory();
    return Directory(p.join(docsDirectory.path, 'reader', 'bg'));
  }

  Future<String?> _showReadStyleImportUrlInputDialog() async {
    final controller = TextEditingController();
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('网络导入'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '请输入 zip 下载地址',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _buildReadStyleActionChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: _uiCardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _uiBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _uiTextNormal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildReadStyleSeekBar({
    required String title,
    required int progress,
    required int max,
    required String valueLabel,
    required ValueChanged<int> onChanged,
  }) {
    final safeMax = max < 1 ? 1 : max;
    final safeProgress = progress.clamp(0, safeMax).toInt();
    final sliderValue = safeProgress.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _uiTextStrong,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 24,
              onPressed:
                  safeProgress > 0 ? () => onChanged(safeProgress - 1) : null,
              child: Icon(
                CupertinoIcons.minus,
                size: 18,
                color: safeProgress > 0 ? _uiTextStrong : _uiTextSubtle,
              ),
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: sliderValue,
              min: 0,
              max: safeMax.toDouble(),
              activeColor: _uiAccent,
              onChanged: (value) => onChanged(value.round()),
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 24,
              onPressed: safeProgress < safeMax
                  ? () => onChanged(safeProgress + 1)
                  : null,
              child: Icon(
                CupertinoIcons.add,
                size: 18,
                color: safeProgress < safeMax ? _uiTextStrong : _uiTextSubtle,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _uiTextNormal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
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

  void _showLegacyMoreConfigDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => StatefulBuilder(
        builder: (context, setPopupState) {
          final bottomInset = MediaQuery.of(context).padding.bottom;
          return Container(
            height: 360 + bottomInset,
            decoration: BoxDecoration(
              color: _uiPanelBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: SafeArea(
              top: false,
              child: _buildLegacyMoreConfigPreferenceList(setPopupState),
            ),
          );
        },
      ),
    );
  }

  void _showLegacyTipConfigDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: BoxDecoration(
            color: _uiPanelBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
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
                          '信息',
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
                Expanded(
                  child: _buildLegacyTipConfigList(setPopupState),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegacyTipConfigList(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('legacy_tip_config'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSettingsCard(
            title: '正文标题',
            child: Column(
              children: [
                _buildOptionRow(
                  '显示隐藏',
                  _titleModeLabel(_settings.titleMode),
                  () {
                    _showTipOptionPicker(
                      title: '章节标题位置',
                      options: _titleModeOptions,
                      currentValue: _settings.titleMode,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(titleMode: value),
                        );
                      },
                    );
                  },
                ),
                _buildSliderSetting(
                  '标题字号',
                  _settings.titleSize.toDouble(),
                  0,
                  10,
                  (value) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(titleSize: value.round()),
                    );
                  },
                  displayFormat: (value) => value.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '顶部间距',
                  _settings.titleTopSpacing,
                  0,
                  100,
                  (value) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(titleTopSpacing: value),
                    );
                  },
                  displayFormat: (value) => value.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '底部间距',
                  _settings.titleBottomSpacing,
                  0,
                  100,
                  (value) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(titleBottomSpacing: value),
                    );
                  },
                  displayFormat: (value) => value.toInt().toString(),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '页眉',
            child: Column(
              children: [
                _buildOptionRow(
                  '显示隐藏',
                  _headerModeLabel(_settings.headerMode),
                  () {
                    _showTipOptionPicker(
                      title: '页眉显示',
                      options: _headerModeOptions,
                      currentValue: _settings.headerMode,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(headerMode: value),
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '左边',
                  _headerTipLabel(_settings.headerLeftContent),
                  () {
                    _showTipOptionPicker(
                      title: '页眉左侧',
                      options: _headerTipOptions,
                      currentValue: _settings.headerLeftContent,
                      onSelected: (value) {
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.headerLeft,
                          value: value,
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '中间',
                  _headerTipLabel(_settings.headerCenterContent),
                  () {
                    _showTipOptionPicker(
                      title: '页眉中间',
                      options: _headerTipOptions,
                      currentValue: _settings.headerCenterContent,
                      onSelected: (value) {
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.headerCenter,
                          value: value,
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '右边',
                  _headerTipLabel(_settings.headerRightContent),
                  () {
                    _showTipOptionPicker(
                      title: '页眉右侧',
                      options: _headerTipOptions,
                      currentValue: _settings.headerRightContent,
                      onSelected: (value) {
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.headerRight,
                          value: value,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '页脚',
            child: Column(
              children: [
                _buildOptionRow(
                  '显示隐藏',
                  _footerModeLabel(_settings.footerMode),
                  () {
                    _showTipOptionPicker(
                      title: '页脚显示',
                      options: _footerModeOptions,
                      currentValue: _settings.footerMode,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(footerMode: value),
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '左边',
                  _footerTipLabel(_settings.footerLeftContent),
                  () {
                    _showTipOptionPicker(
                      title: '页脚左侧',
                      options: _footerTipOptions,
                      currentValue: _settings.footerLeftContent,
                      onSelected: (value) {
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.footerLeft,
                          value: value,
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '中间',
                  _footerTipLabel(_settings.footerCenterContent),
                  () {
                    _showTipOptionPicker(
                      title: '页脚中间',
                      options: _footerTipOptions,
                      currentValue: _settings.footerCenterContent,
                      onSelected: (value) {
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.footerCenter,
                          value: value,
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '右边',
                  _footerTipLabel(_settings.footerRightContent),
                  () {
                    _showTipOptionPicker(
                      title: '页脚右侧',
                      options: _footerTipOptions,
                      currentValue: _settings.footerRightContent,
                      onSelected: (value) {
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.footerRight,
                          value: value,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '页眉页脚',
            child: Column(
              children: [
                _buildOptionRow(
                  '文字颜色',
                  _tipColorLabel(_settings.tipColor),
                  () {
                    _showTipOptionPicker(
                      title: '页眉页脚文字颜色',
                      options: _tipColorOptions,
                      currentValue: _settings.tipColor ==
                              ReadingSettings.tipColorFollowContent
                          ? ReadingSettings.tipColorFollowContent
                          : _customColorPickerValue,
                      onSelected: (value) {
                        if (value == _customColorPickerValue) {
                          unawaited(
                            _showTipColorInputDialog(
                              setPopupState,
                              forDivider: false,
                            ),
                          );
                          return;
                        }
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(tipColor: value),
                        );
                      },
                    );
                  },
                ),
                _buildOptionRow(
                  '分割线颜色',
                  _tipDividerColorLabel(_settings.tipDividerColor),
                  () {
                    _showTipOptionPicker(
                      title: '页眉页脚分割线颜色',
                      options: _tipDividerColorOptions,
                      currentValue: _settings.tipDividerColor ==
                                  ReadingSettings.tipDividerColorDefault ||
                              _settings.tipDividerColor ==
                                  ReadingSettings.tipDividerColorFollowContent
                          ? _settings.tipDividerColor
                          : _customColorPickerValue,
                      onSelected: (value) {
                        if (value == _customColorPickerValue) {
                          unawaited(
                            _showTipColorInputDialog(
                              setPopupState,
                              forDivider: true,
                            ),
                          );
                          return;
                        }
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(tipDividerColor: value),
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

  Widget _buildLegacyMoreConfigPreferenceList(StateSetter setPopupState) {
    final progressBehaviorValue =
        _settings.progressBarBehavior == ProgressBarBehavior.chapter ? 1 : 0;
    final keepLightValue = _effectiveKeepLightSeconds(_settings);
    return SingleChildScrollView(
      key: const ValueKey('legacy_more_config'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _uiCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _uiBorder),
        ),
        child: Column(
          children: [
            _buildOptionRow(
              '屏幕方向',
              ReaderScreenOrientation.label(_settings.screenOrientation),
              () => _showTipOptionPicker(
                title: '屏幕方向',
                options: _screenOrientationOptions,
                currentValue: _settings.screenOrientation,
                onSelected: (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(screenOrientation: value),
                  );
                },
              ),
            ),
            _buildOptionRow(
              '亮屏时长',
              _keepLightLabel(_settings.keepLightSeconds),
              () => _showTipOptionPicker(
                title: '亮屏时长',
                options: _keepLightOptions,
                currentValue: keepLightValue,
                onSelected: (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(keepLightSeconds: value),
                  );
                },
              ),
            ),
            _buildSwitchRow('隐藏状态栏', !_settings.showStatusBar, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(showStatusBar: !value),
              );
            }),
            _buildSwitchRow('隐藏导航栏', _settings.hideNavigationBar, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(hideNavigationBar: value),
              );
            }),
            _buildSwitchRow('刘海屏留边', _settings.paddingDisplayCutouts, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(paddingDisplayCutouts: value),
              );
            }),
            _buildOptionRow(
              '进度条行为',
              _settings.progressBarBehavior.label,
              () => _showTipOptionPicker(
                title: '进度条行为',
                options: _progressBarBehaviorOptions,
                currentValue: progressBehaviorValue,
                onSelected: (value) {
                  final behavior = value == 1
                      ? ProgressBarBehavior.chapter
                      : ProgressBarBehavior.page;
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(progressBarBehavior: behavior),
                  );
                },
              ),
            ),
            _buildSwitchRow('章节跳转确认', _settings.confirmSkipChapter, (value) {
              if (!value) {
                _chapterSeekConfirmed = false;
              }
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(confirmSkipChapter: value),
              );
            }),
            _buildSwitchRow('两端对齐', _settings.textFullJustify, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(textFullJustify: value),
              );
            }),
            _buildSwitchRow('底部对齐', _settings.textBottomJustify, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(textBottomJustify: value),
              );
            }),
            _buildSwitchRow('鼠标滚轮翻页', _settings.mouseWheelPage, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(mouseWheelPage: value),
              );
            }),
            _buildSwitchRow('音量键翻页', _settings.volumeKeyPage, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(volumeKeyPage: value),
              );
            }),
            _buildSwitchRow(
              '朗读时音量键翻页',
              _settings.volumeKeyPageOnPlay,
              (value) {
                _updateSettingsFromSheet(
                  setPopupState,
                  _settings.copyWith(volumeKeyPageOnPlay: value),
                );
              },
            ),
            _buildSwitchRow('长按按键翻页', _settings.keyPageOnLongPress, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(keyPageOnLongPress: value),
              );
            }),
            _buildOptionRow(
              '翻页触发阈值',
              _touchSlopLabel(_settings.pageTouchSlop),
              () => _showPageTouchSlopPicker(setPopupState),
            ),
            _buildSwitchRow('显示亮度条', _settings.showBrightnessView, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(showBrightnessView: value),
              );
            }),
            _buildSwitchRow(
              '显示阅读标题附加信息',
              _settings.showReadTitleAddition,
              (value) {
                _updateSettingsFromSheet(
                  setPopupState,
                  _settings.copyWith(showReadTitleAddition: value),
                );
              },
            ),
            _buildSwitchRow(
              '阅读菜单样式随页面',
              _settings.readBarStyleFollowPage,
              (value) {
                _updateSettingsFromSheet(
                  setPopupState,
                  _settings.copyWith(readBarStyleFollowPage: value),
                );
              },
            ),
            _buildSwitchRow('滚动翻页无动画', _settings.noAnimScrollPage, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(noAnimScrollPage: value),
              );
            }),
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
            _buildSwitchRow('禁用返回键', _settings.disableReturnKey, (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(disableReturnKey: value),
              );
            }),
            _buildOptionRow('翻页按键', '配置', () {
              _showReaderActionUnavailable(
                '翻页按键',
                reason: '当前平台按键映射能力待补齐',
              );
            }),
          ],
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
            title: '翻页模式',
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
    final readStyles = _activeReadStyles;
    final activeStyleIndex = _activeReadStyleIndex;
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
                itemCount: readStyles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final theme = readStyles[index];
                  final isSelected = activeStyleIndex == index;
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
            title: '章节标题',
            child: Column(
              children: [
                _buildOptionRow(
                  '标题显示',
                  _titleModeLabel(_settings.titleMode),
                  () {
                    _showTipOptionPicker(
                      title: '章节标题位置',
                      options: _titleModeOptions,
                      currentValue: _settings.titleMode,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(titleMode: value),
                        );
                      },
                    );
                  },
                ),
                _buildSliderSetting(
                  '字号偏移',
                  _settings.titleSize.toDouble(),
                  0,
                  10,
                  (value) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(titleSize: value.round()),
                    );
                  },
                  displayFormat: (value) => value.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '上边距',
                  _settings.titleTopSpacing,
                  0,
                  100,
                  (value) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(titleTopSpacing: value),
                    );
                  },
                  displayFormat: (value) => value.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '下边距',
                  _settings.titleBottomSpacing,
                  0,
                  100,
                  (value) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(titleBottomSpacing: value),
                    );
                  },
                  displayFormat: (value) => value.toInt().toString(),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '页眉页脚',
            child: Column(
              children: [
                _buildOptionRow(
                  '页眉显示',
                  _headerModeLabel(_settings.headerMode),
                  () {
                    _showTipOptionPicker(
                      title: '页眉显示',
                      options: _headerModeOptions,
                      currentValue: _settings.headerMode,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(headerMode: value),
                        );
                      },
                    );
                  },
                ),
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
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.headerLeft,
                          value: value,
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
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.headerCenter,
                          value: value,
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
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.headerRight,
                          value: value,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 4),
                _buildOptionRow(
                  '页脚显示',
                  _footerModeLabel(_settings.footerMode),
                  () {
                    _showTipOptionPicker(
                      title: '页脚显示',
                      options: _footerModeOptions,
                      currentValue: _settings.footerMode,
                      onSelected: (value) {
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(footerMode: value),
                        );
                      },
                    );
                  },
                ),
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
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.footerLeft,
                          value: value,
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
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.footerCenter,
                          value: value,
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
                        _applyTipSelectionFromSheet(
                          setPopupState,
                          slot: ReaderTipSlot.footerRight,
                          value: value,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 4),
                _buildOptionRow('文字颜色', _tipColorLabel(_settings.tipColor), () {
                  _showTipOptionPicker(
                    title: '页眉页脚文字颜色',
                    options: _tipColorOptions,
                    currentValue: _settings.tipColor ==
                            ReadingSettings.tipColorFollowContent
                        ? ReadingSettings.tipColorFollowContent
                        : _customColorPickerValue,
                    onSelected: (value) {
                      if (value == _customColorPickerValue) {
                        unawaited(
                          _showTipColorInputDialog(
                            setPopupState,
                            forDivider: false,
                          ),
                        );
                        return;
                      }
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(tipColor: value),
                      );
                    },
                  );
                }),
                _buildOptionRow(
                    '分割线颜色', _tipDividerColorLabel(_settings.tipDividerColor),
                    () {
                  _showTipOptionPicker(
                    title: '页眉页脚分割线颜色',
                    options: _tipDividerColorOptions,
                    currentValue: _settings.tipDividerColor ==
                                ReadingSettings.tipDividerColorDefault ||
                            _settings.tipDividerColor ==
                                ReadingSettings.tipDividerColorFollowContent
                        ? _settings.tipDividerColor
                        : _customColorPickerValue,
                    onSelected: (value) {
                      if (value == _customColorPickerValue) {
                        unawaited(
                          _showTipColorInputDialog(
                            setPopupState,
                            forDivider: true,
                          ),
                        );
                        return;
                      }
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(tipDividerColor: value),
                      );
                    },
                  );
                }),
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
                _buildSwitchRow('鼠标滚轮翻页', _settings.mouseWheelPage, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(mouseWheelPage: value),
                  );
                }),
                _buildSwitchRow('长按按键翻页', _settings.keyPageOnLongPress,
                    (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(keyPageOnLongPress: value),
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
              ],
            ),
          ),
          _buildSettingsCard(
            title: '翻页手感',
            child: Column(
              children: [
                _buildOptionRow(
                  '翻页触发阈值',
                  _touchSlopLabel(_settings.pageTouchSlop),
                  () => _showPageTouchSlopPicker(setPopupState),
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
                _buildSwitchRow('隐藏导航栏', _settings.hideNavigationBar, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(hideNavigationBar: value),
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
                _buildSwitchRow(
                    '屏幕常亮',
                    _settings.keepLightSeconds ==
                        ReadingSettings.keepLightAlways, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(
                      keepLightSeconds: value
                          ? ReadingSettings.keepLightAlways
                          : ReadingSettings.keepLightFollowSystem,
                    ),
                  );
                }),
                _buildOptionRow(
                  '屏幕方向',
                  ReaderScreenOrientation.label(_settings.screenOrientation),
                  () => _showTipOptionPicker(
                    title: '屏幕方向',
                    options: _screenOrientationOptions,
                    currentValue: _settings.screenOrientation,
                    onSelected: (value) {
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(screenOrientation: value),
                      );
                    },
                  ),
                ),
                _buildSwitchRow('禁用返回键', _settings.disableReturnKey, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(disableReturnKey: value),
                  );
                }),
                _buildSwitchRow('净化章节标题', _settings.cleanChapterTitle, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(cleanChapterTitle: value),
                  );
                }),
                const SizedBox(height: 8),
                _buildChineseConverterTypeSegment(
                  currentType: _settings.chineseConverterType,
                  onChanged: (value) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(chineseConverterType: value),
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

  void _updateSettingsFromSheet(
      StateSetter setPopupState, ReadingSettings newSettings) {
    _updateSettings(newSettings);
    setPopupState(() {});
  }

  void _applyTipSelectionFromSheet(
    StateSetter setPopupState, {
    required ReaderTipSlot slot,
    required int value,
  }) {
    _updateSettingsFromSheet(
      setPopupState,
      ReaderTipSelectionHelper.applySelection(
        settings: _settings,
        slot: slot,
        selectedValue: value,
      ),
    );
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

  Future<void> _showPageTouchSlopPicker(StateSetter setPopupState) async {
    final controller =
        TextEditingController(text: _settings.pageTouchSlop.toString());
    final result = await showCupertinoDialog<int>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('翻页触发阈值'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '0 - 9999（0=系统默认）',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final raw = int.tryParse(controller.text.trim());
              Navigator.pop(dialogContext, raw);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    _updateSettingsFromSheet(
      setPopupState,
      _settings.copyWith(pageTouchSlop: result.clamp(0, 9999)),
    );
  }

  String _touchSlopLabel(int value) {
    return value == 0 ? '系统默认' : value.toString();
  }

  String _keepLightLabel(int keepLightSeconds) {
    switch (keepLightSeconds) {
      case ReadingSettings.keepLightOneMinute:
        return '1分钟';
      case ReadingSettings.keepLightFiveMinutes:
        return '5分钟';
      case ReadingSettings.keepLightTenMinutes:
        return '10分钟';
      case ReadingSettings.keepLightAlways:
        return '常亮';
      case ReadingSettings.keepLightFollowSystem:
      default:
        return '默认';
    }
  }

  String _titleModeLabel(int value) {
    switch (value) {
      case 1:
        return '居中';
      case 2:
        return '隐藏';
      case 0:
      default:
        return '居左';
    }
  }

  String _headerModeLabel(int value) {
    switch (value) {
      case ReadingSettings.headerModeShow:
        return '显示';
      case ReadingSettings.headerModeHide:
        return '隐藏';
      case ReadingSettings.headerModeHideWhenStatusBarShown:
      default:
        return '显示状态栏时隐藏';
    }
  }

  String _footerModeLabel(int value) {
    switch (value) {
      case ReadingSettings.footerModeHide:
        return '隐藏';
      case ReadingSettings.footerModeShow:
      default:
        return '显示';
    }
  }

  String _tipColorLabel(int value) {
    if (value == ReadingSettings.tipColorFollowContent) {
      return '同正文颜色';
    }
    return '#${_hexRgb(value)}';
  }

  String _tipDividerColorLabel(int value) {
    if (value == ReadingSettings.tipDividerColorDefault) {
      return '默认';
    }
    if (value == ReadingSettings.tipDividerColorFollowContent) {
      return '同正文颜色';
    }
    return '#${_hexRgb(value)}';
  }

  String _hexRgb(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  int? _parseRgbColor(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('#')) {
      text = text.substring(1);
    }
    if (text.startsWith('0x') || text.startsWith('0X')) {
      text = text.substring(2);
    }
    if (text.length != 6) return null;
    final rgb = int.tryParse(text, radix: 16);
    if (rgb == null) return null;
    return 0xFF000000 | rgb;
  }

  Future<void> _showTipColorInputDialog(
    StateSetter setPopupState, {
    required bool forDivider,
  }) async {
    final currentValue =
        forDivider ? _settings.tipDividerColor : _settings.tipColor;
    final initialHex = currentValue > 0 ? _hexRgb(currentValue) : '';
    final controller = TextEditingController(text: initialHex);
    final title = forDivider ? '分割线颜色' : '文字颜色';
    final parsed = await showCupertinoDialog<int>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            placeholder: '输入 6 位十六进制，如 FF6600',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final value = _parseRgbColor(controller.text);
              if (value == null) {
                _showToast('请输入 6 位十六进制颜色（如 FF6600）');
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (parsed == null) return;
    _updateSettingsFromSheet(
      setPopupState,
      forDivider
          ? _settings.copyWith(tipDividerColor: parsed)
          : _settings.copyWith(tipColor: parsed),
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

  Widget _buildChineseConverterTypeSegment({
    required int currentType,
    required ValueChanged<int> onChanged,
  }) {
    final safeType = ChineseConverterType.values.contains(currentType)
        ? currentType
        : ChineseConverterType.off;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('简繁转换', style: TextStyle(color: _uiTextStrong, fontSize: 16)),
        const SizedBox(height: 8),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: safeType,
          backgroundColor: _uiCardBg,
          thumbColor: _uiAccent,
          children: {
            for (final mode in ChineseConverterType.values)
              mode: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  ChineseConverterType.label(mode),
                  style: TextStyle(
                    color: _uiTextNormal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          },
          onValueChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
        ),
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

  String _extractCatalogUpdateFailureReason(List<String> failedDetails) {
    if (failedDetails.isEmpty) return '更新目录失败';
    final raw = failedDetails.first.trim();
    final separatorIndex = raw.indexOf('：');
    if (separatorIndex <= -1 || separatorIndex >= raw.length - 1) {
      return raw.isEmpty ? '更新目录失败' : raw;
    }
    final reason = raw.substring(separatorIndex + 1).trim();
    return reason.isEmpty ? '更新目录失败' : reason;
  }

  Future<List<Chapter>> _refreshCatalogFromSource() async {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null) {
      throw StateError('书籍信息不存在');
    }
    if (book.isLocal) {
      throw StateError('本地书籍不支持检查更新');
    }

    final summary = await _catalogUpdateService.updateBooks([book]);
    if (summary.failedCount > 0) {
      throw StateError(
        _extractCatalogUpdateFailureReason(summary.failedDetails),
      );
    }
    if (summary.updateCandidateCount <= 0) {
      throw StateError('本地书籍不支持更新目录');
    }

    final updated = _chapterRepo.getChaptersForBook(widget.bookId);
    if (updated.isEmpty) {
      throw StateError('目录为空（可能是 ruleToc 不匹配）');
    }

    if (!mounted) return updated;

    final maxChapter = updated.length - 1;
    setState(() {
      _chapters = updated;
      _currentChapterIndex = _currentChapterIndex.clamp(0, maxChapter).toInt();
      _currentTitle = _postProcessTitle(updated[_currentChapterIndex].title);
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
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
        isLocalTxtBook: _isCurrentBookLocalTxt(),
        initialUseReplace: _tocUiUseReplace,
        initialLoadWordCount: _tocUiLoadWordCount,
        initialSplitLongChapter: _tocUiSplitLongChapter,
        onUseReplaceChanged: (value) {
          _tocUiUseReplace = value;
          _catalogDisplayTitleCacheByChapterId.clear();
        },
        onLoadWordCountChanged: (value) {
          _tocUiLoadWordCount = value;
        },
        onSplitLongChapterChanged: (value) {
          _tocUiSplitLongChapter = value;
        },
        onOpenLogs: _openExceptionLogsFromReader,
        onExportBookmark: () async {
          await _exportBookmarksFromReader(markdown: false);
        },
        onExportBookmarkMarkdown: () async {
          await _exportBookmarksFromReader(markdown: true);
        },
        onEditTocRule: () {
          _showReaderActionUnavailable('TXT 目录规则');
        },
        initialDisplayTitlesByIndex: _buildCatalogInitialDisplayTitlesByIndex(),
        resolveDisplayTitle: _resolveCatalogDisplayTitle,
      ),
    );
  }
}

enum _ReadStyleBgAction {
  asset,
  file,
  clear,
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

class _ScrollSegmentSeed {
  final String chapterId;
  final String title;
  final String content;

  const _ScrollSegmentSeed({
    required this.chapterId,
    required this.title,
    required this.content,
  });
}

class _ScrollSegment {
  final int chapterIndex;
  final String chapterId;
  final String title;
  final String content;
  final double estimatedHeight;

  const _ScrollSegment({
    required this.chapterIndex,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.estimatedHeight,
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
