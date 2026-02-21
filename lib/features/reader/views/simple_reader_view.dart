import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
import '../../../core/services/webdav_service.dart';
import '../../../core/utils/chinese_script_converter.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../bookshelf/models/book.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../import/txt_parser.dart';
import '../../replace/views/replace_rule_list_view.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_cover_loader.dart';
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
import '../services/reader_charset_service.dart';
import '../services/reader_key_paging_helper.dart';
import '../services/reader_legacy_quick_action_helper.dart';
import '../services/reader_image_request_parser.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_legacy_menu_helper.dart';
import '../services/reader_search_navigation_helper.dart';
import '../services/reader_source_action_helper.dart';
import '../services/reader_source_switch_helper.dart';
import '../services/reader_system_ui_helper.dart';
import '../services/reader_top_bar_action_helper.dart';
import '../services/reader_tip_selection_helper.dart';
import '../services/read_aloud_service.dart';
import '../services/read_style_import_export_service.dart';
import '../utils/chapter_progress_utils.dart';
import '../widgets/auto_pager.dart';
import '../widgets/click_action_config_dialog.dart';
import '../widgets/paged_reader_widget.dart';
import '../widgets/page_factory.dart';
import '../widgets/reader_menus.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_status_bar.dart';
import '../widgets/legacy_justified_text.dart';
import '../widgets/reader_catalog_sheet.dart';
import '../widgets/reader_color_picker_dialog.dart';
import '../widgets/reader_padding_config_dialog.dart';
import '../widgets/scroll_page_step_calculator.dart';
import '../widgets/scroll_segment_paint_view.dart';
import '../widgets/scroll_text_layout_engine.dart';
import '../widgets/scroll_runtime_helper.dart';
import '../widgets/source_switch_candidate_sheet.dart';

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
  late final WebDavService _webDavService;
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
  final ReaderCharsetService _readerCharsetService = ReaderCharsetService();

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
  late final ReadAloudService _readAloudService;
  ReadAloudStatusSnapshot _readAloudSnapshot =
      const ReadAloudStatusSnapshot.stopped();

  // 当前书籍信息
  String _bookAuthor = '';
  String? _bookCoverUrl;
  String? _currentSourceUrl;
  String? _currentSourceName;
  final Map<String, bool> _chapterVipByUrl = <String, bool>{};
  final Map<String, bool> _chapterPayByUrl = <String, bool>{};
  final Map<String, bool> _chapterSameTitleRemovedById = <String, bool>{};
  bool _tocUiUseReplace = false;
  bool _tocUiLoadWordCount = false;
  bool _tocUiSplitLongChapter = false;
  bool _useReplaceRule = true;
  bool _reSegment = false;
  bool _delRubyTag = false;
  bool _delHTag = false;
  String _imageStyle = _defaultLegacyImageStyle;

  // 翻页模式相关（对标 Legado PageFactory）
  final PageFactory _pageFactory = PageFactory();

  final _replaceStageCache = <String, _ReplaceStageCache>{};
  final _catalogDisplayTitleCacheByChapterId = <String, String>{};
  final Map<String, _ResolvedChapterSnapshot>
      _resolvedChapterSnapshotByChapterId =
      <String, _ResolvedChapterSnapshot>{};
  final Map<String, _ChapterImageMetaSnapshot>
      _chapterImageMetaSnapshotByChapterId =
      <String, _ChapterImageMetaSnapshot>{};
  bool _hasDeferredChapterTransformRefresh = false;

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
  static const List<_TipOption> _chineseConverterOptions = [
    _TipOption(ChineseConverterType.off, '关闭'),
    _TipOption(ChineseConverterType.traditionalToSimplified, '繁转简'),
    _TipOption(ChineseConverterType.simplifiedToTraditional, '简转繁'),
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
  static const List<String> _legacyCharsetOptions =
      ReaderCharsetService.legacyCharsetOptions;
  static const String _defaultLegacyImageStyle = 'DEFAULT';
  static const String _legacyImageStyleFull = 'FULL';
  static const String _legacyImageStyleText = 'TEXT';
  static const String _legacyImageStyleSingle = 'SINGLE';
  static const List<String> _legacyImageStyles = <String>[
    _defaultLegacyImageStyle,
    _legacyImageStyleFull,
    _legacyImageStyleText,
    _legacyImageStyleSingle,
  ];
  static final RegExp _legacyImageTagRegex = RegExp(
    r"""<img[^>]*src=['"]([^'"]*(?:['"][^>]+\})?)['"][^>]*>""",
    caseSensitive: false,
  );
  static final RegExp _cssStyleAttrRegex = RegExp(
    r'''style\s*=\s*(?:"([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  );
  static const int _scrollUiSyncIntervalMs = 16;
  static const int _scrollSaveProgressIntervalMs = 450;
  static const int _scrollPreloadIntervalMs = 80;
  static const double _scrollPreloadExtent = 280.0;
  static const int _chapterLoadImageWarmupMaxProbeCount = 8;
  static const Duration _chapterLoadImageWarmupMaxDuration =
      Duration(milliseconds: 260);
  static const int _prefetchImageWarmupMaxProbeCount = 6;
  static const Duration _prefetchImageWarmupMaxDuration =
      Duration(milliseconds: 180);
  static const int _persistedImageSizeSnapshotMaxEntries = 180;
  static const int _chapterImageMetaSnapshotMaxEntries = 64;
  static const double _longImageAspectRatioThreshold = 1.6;
  static const double _longImageErrorBoostThreshold = 0.22;
  static const List<String> _legacyImageWidthQueryKeys = <String>[
    'w',
    'width',
    'imgw',
    'img_width',
    'imagewidth',
    'ow',
    'origw',
    'srcw',
  ];
  static const List<String> _legacyImageHeightQueryKeys = <String>[
    'h',
    'height',
    'imgh',
    'img_height',
    'imageheight',
    'oh',
    'origh',
    'srch',
  ];
  static final List<RegExp> _legacyImageWidthUrlPatterns = <RegExp>[
    RegExp(
      r'[?&](?:w|width|imgw|img_width|imagewidth|ow|origw|srcw)=([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|[?&,_/\.-])w_([0-9]+(?:\.[0-9]+)?)(?:[?&,_/\.-]|$)',
      caseSensitive: false,
    ),
  ];
  static final List<RegExp> _legacyImageHeightUrlPatterns = <RegExp>[
    RegExp(
      r'[?&](?:h|height|imgh|img_height|imageheight|oh|origh|srch)=([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|[?&,_/\.-])h_([0-9]+(?:\.[0-9]+)?)(?:[?&,_/\.-]|$)',
      caseSensitive: false,
    ),
  ];

  // 章节加载锁（用于翻页模式）
  bool _isLoadingChapter = false;
  bool _isRestoringProgress = false;
  bool _isHydratingChapterFromPageFactory = false;
  int? _activeHydratingChapterFromPageFactoryIndex;
  int? _pendingHydratingChapterFromPageFactoryIndex;
  bool _isCurrentFactoryChapterLoading = false;
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
  bool _pendingImageSizeRepagination = false;
  final Set<String> _imageSizeWarmupInFlight = <String>{};
  Timer? _imageSizeSnapshotPersistTimer;
  final Set<String> _bookImageSizeCacheKeys = <String>{};
  final Map<String, ReaderImageMarkerMeta> _chapterImageMetaByCacheKey =
      <String, ReaderImageMarkerMeta>{};
  double _longImageFirstFrameErrorEma = 0.0;
  int _longImageFirstFrameErrorSamples = 0;
  final Map<String, String> _readerImageCookieHeaderByHost = <String, String>{};
  final Set<String> _readerImageCookieLoadInFlight = <String>{};
  Duration _recentChapterFetchDuration = Duration.zero;
  final Map<String, _ReaderImageWarmupSourceTelemetry>
      _imageWarmupTelemetryBySource =
      <String, _ReaderImageWarmupSourceTelemetry>{};

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
    _webDavService = WebDavService();
    _settings = _settingsService.readingSettings.sanitize();
    _useReplaceRule = _settingsService.getBookUseReplaceRule(
      widget.bookId,
      fallback: _defaultUseReplaceRule(),
    );
    _reSegment = _settingsService.getBookReSegment(
      widget.bookId,
      fallback: false,
    );
    _tocUiSplitLongChapter = _settingsService.getBookSplitLongChapter(
      widget.bookId,
      fallback: true,
    );
    _delRubyTag = _settingsService.getBookDelRubyTag(
      widget.bookId,
      fallback: false,
    );
    _delHTag = _settingsService.getBookDelHTag(
      widget.bookId,
      fallback: false,
    );
    _imageStyle = _settingsService.getBookImageStyle(
      widget.bookId,
      fallback: _defaultLegacyImageStyle,
    );
    _settingsService.readingSettingsListenable
        .addListener(_handleReadingSettingsChanged);
    _warmUpReadStyleBackgroundDirectoryPath();
    _autoPager.setSpeed(_settings.autoReadSpeed);
    _autoPager.setMode(_settings.pageTurnMode == PageTurnMode.scroll
        ? AutoPagerMode.scroll
        : AutoPagerMode.page);
    _readAloudService = ReadAloudService(
      onStateChanged: _handleReadAloudStateChanged,
      onMessage: _handleReadAloudMessage,
      onRequestChapterSwitch: _handleReadAloudChapterSwitchRequest,
    );

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
      _handleAutoPagerNextTick();
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
    await _restoreReaderImageSizeSnapshot();

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

      // 初始化 PageFactory：仅当前/邻近章节使用完整快照，远端章节按需延迟处理，
      // 降低本地书大目录首次进入的阻塞耗时。
      _syncPageFactoryChapters(
        centerIndex: _currentChapterIndex,
        preferCachedForFarChapters: _shouldDeferFarChapterTransforms(),
      );

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
    unawaited(_readAloudService.dispose());
    _keepLightTimer?.cancel();
    _keepLightTimer = null;
    _imageSizeSnapshotPersistTimer?.cancel();
    _imageSizeSnapshotPersistTimer = null;
    unawaited(_persistReaderImageSizeSnapshot(force: true));
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
        _showAutoReadPanel = false;
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
        _showAutoReadPanel = false;
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
            maxProbeCount: _chapterLoadImageWarmupMaxProbeCount,
            maxDuration: _chapterLoadImageWarmupMaxDuration,
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
    final center = _chapters.isEmpty
        ? 0
        : (centerIndex ?? _currentChapterIndex).clamp(0, _chapters.length - 1);
    var deferredFarSnapshotUsed = false;
    final chapterDataList = List<ChapterData>.generate(
      _chapters.length,
      (index) {
        final isNearChapter = (index - center).abs() <= 1;
        final snapshot = preferCachedForFarChapters && !isNearChapter
            ? () {
                final chapterId = _chapters[index].id;
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
      _pageFactory.setChapters(chapterDataList, _currentChapterIndex);
    }
    if (deferredFarSnapshotUsed) {
      _hasDeferredChapterTransformRefresh = true;
    } else if (!preferCachedForFarChapters) {
      _hasDeferredChapterTransformRefresh = false;
    }
  }

  bool _shouldDeferFarChapterTransforms() {
    if (_chapters.length <= 2) return false;
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
    final removeSameTitle =
        _settings.cleanChapterTitle || _isChapterSameTitleRemoved(chapterId);
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
    final activeChapterCount = _chapters.length;
    final shouldPruneResolved =
        _resolvedChapterSnapshotByChapterId.length > activeChapterCount + 8;
    final shouldPruneImageMeta =
        _chapterImageMetaSnapshotByChapterId.length > activeChapterCount + 8;
    if (!shouldPruneResolved && !shouldPruneImageMeta) {
      return;
    }
    final activeChapterIds = _chapters.map((chapter) => chapter.id).toSet();
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
        maxCount: _persistedImageSizeSnapshotMaxEntries,
      ),
    );

    _chapterImageMetaSnapshotByChapterId.remove(snapshot.chapterId);
    _chapterImageMetaSnapshotByChapterId[snapshot.chapterId] = next;
    while (_chapterImageMetaSnapshotByChapterId.length >
        _chapterImageMetaSnapshotMaxEntries) {
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

  Future<void> _prefetchChapterIfNeeded(
    int index, {
    bool showLoading = false,
  }) async {
    if (index < 0 || index >= _chapters.length) return;

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
        maxProbeCount: _prefetchImageWarmupMaxProbeCount,
        maxDuration: _prefetchImageWarmupMaxDuration,
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

  Future<void> _restoreReaderImageSizeSnapshot() async {
    if (widget.isEphemeral) return;
    final rawSnapshot =
        _settingsService.getBookReaderImageSizeSnapshot(widget.bookId);
    if (rawSnapshot == null || rawSnapshot.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(rawSnapshot);
      if (decoded is! Map) {
        return;
      }
      final dynamic rawEntries = decoded['entries'] ?? decoded;
      if (rawEntries is! Map) {
        return;
      }
      final entries = rawEntries.map((key, value) => MapEntry('$key', value));
      ReaderImageMarkerCodec.restoreResolvedSizeCache(
        entries,
        clearBeforeRestore: false,
        maxEntries: _persistedImageSizeSnapshotMaxEntries,
      );
      for (final rawKey in entries.keys) {
        final normalized =
            ReaderImageMarkerCodec.normalizeResolvedSizeKey(rawKey);
        if (normalized.isNotEmpty) {
          _bookImageSizeCacheKeys.add(normalized);
        }
      }
    } catch (_) {
      // 快照解析失败时忽略，不阻断阅读主流程。
    }
  }

  void _schedulePersistReaderImageSizeSnapshot() {
    if (widget.isEphemeral) return;
    _imageSizeSnapshotPersistTimer?.cancel();
    _imageSizeSnapshotPersistTimer =
        Timer(const Duration(milliseconds: 680), () {
      _imageSizeSnapshotPersistTimer = null;
      unawaited(_persistReaderImageSizeSnapshot());
    });
  }

  Future<void> _persistReaderImageSizeSnapshot({bool force = false}) async {
    if (widget.isEphemeral) return;
    if (!force && _bookImageSizeCacheKeys.isEmpty) return;
    try {
      final snapshot = ReaderImageMarkerCodec.snapshotResolvedSizeCache(
        keys: _bookImageSizeCacheKeys,
        maxEntries: _persistedImageSizeSnapshotMaxEntries,
      );
      final payload = snapshot.isEmpty
          ? ''
          : jsonEncode(
              <String, dynamic>{
                'v': 1,
                'entries': snapshot,
              },
            );
      await _settingsService.saveBookReaderImageSizeSnapshot(
        widget.bookId,
        payload,
      );
    } catch (_) {
      // 持久化失败时忽略，不影响阅读链路。
    }
  }

  void _rememberBookImageCacheKey(String src) {
    final normalized = ReaderImageMarkerCodec.normalizeResolvedSizeKey(src);
    if (normalized.isEmpty) return;
    _bookImageSizeCacheKeys.add(normalized);
  }

  ReaderImageMarkerMeta? _lookupCurrentChapterImageMeta(String src) {
    final key = ReaderImageMarkerCodec.normalizeResolvedSizeKey(src);
    if (key.isEmpty) return null;
    return _chapterImageMetaByCacheKey[key];
  }

  void _recordLongImageFirstFrameErrorSample({
    required String src,
    required Size resolvedSize,
    ReaderImageMarkerMeta? hintMeta,
  }) {
    final width = resolvedSize.width;
    final height = resolvedSize.height;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return;
    }
    final actualRatio = height / width;
    if (!actualRatio.isFinite ||
        actualRatio <= _longImageAspectRatioThreshold) {
      return;
    }
    final hintedRatio = _hintMetaAspectRatio(hintMeta);
    final fallbackRatio =
        _fallbackFirstFrameAspectRatio(_normalizeLegacyImageStyle(_imageStyle));
    final expectedRatio = hintedRatio ?? fallbackRatio;
    if (!expectedRatio.isFinite || expectedRatio <= 0) {
      return;
    }
    final error = ((expectedRatio - actualRatio).abs() / actualRatio)
        .clamp(0.0, 1.0)
        .toDouble();
    if (!error.isFinite) return;
    if (_longImageFirstFrameErrorSamples <= 0) {
      _longImageFirstFrameErrorEma = error;
    } else {
      _longImageFirstFrameErrorEma =
          _longImageFirstFrameErrorEma * 0.78 + error * 0.22;
    }
    _longImageFirstFrameErrorSamples =
        (_longImageFirstFrameErrorSamples + 1).clamp(0, 4096).toInt();
    _rememberBookImageCacheKey(src);
  }

  double? _hintMetaAspectRatio(ReaderImageMarkerMeta? meta) {
    if (meta == null || !meta.hasDimensionHints) return null;
    final width = meta.width!;
    final height = meta.height!;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return null;
    }
    final ratio = height / width;
    if (!ratio.isFinite || ratio <= 0) return null;
    return ratio;
  }

  double _fallbackFirstFrameAspectRatio(String imageStyle) {
    switch (imageStyle) {
      case _legacyImageStyleSingle:
        return 1.0;
      case _legacyImageStyleFull:
        return 0.75;
      default:
        return 0.62;
    }
  }

  void _handlePagedImageSizeResolved(String src, Size size) {
    if (!mounted) return;
    _recordLongImageFirstFrameErrorSample(
      src: src,
      resolvedSize: size,
      hintMeta: _lookupCurrentChapterImageMeta(src),
    );
    _schedulePersistReaderImageSizeSnapshot();
  }

  /// 将内容分页（使用 PageFactory 对标 Legado）
  /// 将内容分页（使用 PageFactory 对标 Legado）
  void _paginateContent() {
    if (!mounted) return;
    _paginateContentLogicOnly();
    setState(() {});
  }

  void _handlePagedImageSizeCacheUpdated() {
    if (!mounted) return;
    if (_settings.pageTurnMode == PageTurnMode.scroll) return;
    _schedulePersistReaderImageSizeSnapshot();
    if (_pendingImageSizeRepagination) return;

    _pendingImageSizeRepagination = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingImageSizeRepagination = false;
      if (!mounted) return;
      if (_settings.pageTurnMode == PageTurnMode.scroll) return;

      final chapterProgress = ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: _pageFactory.currentPageIndex,
        totalPages: _pageFactory.totalPages,
      );

      _syncPageFactoryChapters(keepPosition: true);
      _paginateContentLogicOnly();

      if (_pageFactory.totalPages > 0) {
        final targetPage = ChapterProgressUtils.pageIndexFromProgress(
          progress: chapterProgress,
          totalPages: _pageFactory.totalPages,
        );
        if (targetPage != _pageFactory.currentPageIndex) {
          _pageFactory.jumpToPage(targetPage);
          return;
        }
      }
      setState(() {});
    });
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
    final topOffset = showHeader
        ? PagedReaderWidget.resolveHeaderSlotHeight(
            settings: _settings,
            showStatusBar: _settings.showStatusBar,
          )
        : 0.0;
    final bottomOffset = showFooter
        ? PagedReaderWidget.resolveFooterSlotHeight(
            settings: _settings,
          )
        : 0.0;

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
      fontFamilyFallback: _currentFontFamilyFallback,
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
      legacyImageStyle: _imageStyle,
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
    final chineseConverterChanged =
        oldSettings.chineseConverterType != newSettings.chineseConverterType;
    if (chineseConverterChanged) {
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

    final contentTransformChanged =
        oldSettings.cleanChapterTitle != newSettings.cleanChapterTitle ||
            chineseConverterChanged ||
            oldSettings.paragraphIndent != newSettings.paragraphIndent;
    final deferFarChaptersOnTransform = chineseConverterChanged &&
        !modeChanged &&
        newSettings.pageTurnMode != PageTurnMode.scroll;

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
        _currentContent = _postProcessContent(
          content,
          title,
          chapterId: chapter.id,
        );
      }
      if (contentTransformChanged) {
        _syncPageFactoryChapters(
          keepPosition: newSettings.pageTurnMode != PageTurnMode.scroll,
          preferCachedForFarChapters: deferFarChaptersOnTransform,
          centerIndex: _currentChapterIndex,
        );
        if (deferFarChaptersOnTransform) {
          _hasDeferredChapterTransformRefresh = true;
        }
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

  bool get _menuFollowPageTone =>
      _settings.readBarStyleFollowPage && !_readerUsesImageBackground;

  Color get _uiAccent =>
      _isUiDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _uiPanelBg => _menuFollowPageTone
      ? _readerBackgroundBaseColor
      : (_isUiDark
          ? ReaderOverlayTokens.panelDark
          : ReaderOverlayTokens.panelLight);

  Color get _uiCardBg {
    if (_menuFollowPageTone) {
      final overlay = _isUiDark
          ? CupertinoColors.white.withValues(alpha: 0.06)
          : CupertinoColors.black.withValues(alpha: 0.04);
      return Color.alphaBlend(overlay, _uiPanelBg);
    }
    return _isUiDark
        ? ReaderOverlayTokens.cardDark
        : ReaderOverlayTokens.cardLight;
  }

  Color get _uiBorder => _menuFollowPageTone
      ? _uiTextStrong.withValues(alpha: _isUiDark ? 0.2 : 0.16)
      : (_isUiDark
          ? ReaderOverlayTokens.borderDark
          : ReaderOverlayTokens.borderLight);

  Color get _uiTextStrong => _menuFollowPageTone
      ? _currentTheme.text
      : (_isUiDark
          ? ReaderOverlayTokens.textStrongDark
          : ReaderOverlayTokens.textStrongLight);

  Color get _uiTextNormal => _menuFollowPageTone
      ? _currentTheme.text.withValues(alpha: _isUiDark ? 0.72 : 0.7)
      : (_isUiDark
          ? ReaderOverlayTokens.textNormalDark
          : ReaderOverlayTokens.textNormalLight);

  Color get _uiTextSubtle => _menuFollowPageTone
      ? _currentTheme.text.withValues(alpha: _isUiDark ? 0.56 : 0.52)
      : (_isUiDark
          ? ReaderOverlayTokens.textSubtleDark
          : ReaderOverlayTokens.textSubtleLight);

  String? get _activeSearchHighlightQuery {
    if (!_showSearchMenu || _contentSearchHits.isEmpty) {
      return null;
    }
    final query = _contentSearchQuery.trim();
    if (query.isEmpty) return null;
    return query;
  }

  Color get _searchHighlightColor =>
      _uiAccent.withValues(alpha: _isUiDark ? 0.28 : 0.2);

  Color get _searchHighlightTextColor =>
      _isUiDark ? CupertinoColors.white : AppDesignTokens.textStrong;

  /// 获取当前字体
  String? get _currentFontFamily {
    final family = ReadingFontFamily.getFontFamily(_settings.fontFamilyIndex);
    return family.isEmpty ? null : family;
  }

  List<String>? get _currentFontFamilyFallback {
    final fallback =
        ReadingFontFamily.getFontFamilyFallback(_settings.fontFamilyIndex);
    if (fallback.isEmpty) return null;
    return fallback;
  }

  String get _currentFontName =>
      ReadingFontFamily.getFontName(_settings.fontFamilyIndex);

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
    if (_showAutoReadPanel) {
      setState(() {
        _showAutoReadPanel = false;
      });
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
    final key = event.logicalKey;
    if (ReaderKeyPagingHelper.shouldBlockVolumePagingDuringReadAloud(
      key: key,
      readAloudPlaying: _readAloudSnapshot.isPlaying,
      volumeKeyPageOnPlayEnabled: _settings.volumeKeyPageOnPlay,
    )) {
      return;
    }
    _screenOffTimerStart();

    final action = ReaderKeyPagingHelper.resolveKeyDownAction(
      key: key,
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
        if (_autoPager.isRunning) {
          _openAutoReadPanel();
        } else {
          _setReaderMenuVisible(true);
        }
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
        unawaited(_openContentEditFromMenu());
        break;
      case ClickAction.toggleReplaceRule:
        unawaited(_toggleReplaceRuleState());
        break;
      case ClickAction.syncBookProgress:
        if (_isSyncBookProgressEnabled()) {
          unawaited(_pullBookProgressFromWebDav());
        }
        break;
      case ClickAction.readAloudPrevParagraph:
        unawaited(_triggerReadAloudPreviousParagraph());
        break;
      case ClickAction.readAloudNextParagraph:
        unawaited(_triggerReadAloudNextParagraph());
        break;
      case ClickAction.readAloudPauseResume:
        unawaited(_triggerReadAloudPauseResume());
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
        fontFamilyFallback: _currentFontFamilyFallback,
        fontWeight: _currentFontWeight,
        decoration: _currentTextDecoration,
      ),
      titleStyle: TextStyle(
        fontSize: _settings.fontSize + _settings.titleSize,
        fontWeight: FontWeight.w600,
        color: _currentTheme.text,
        fontFamily: _currentFontFamily,
        fontFamilyFallback: _currentFontFamilyFallback,
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

  bool _isChapterSameTitleRemoved(String chapterId) {
    final key = chapterId.trim();
    if (key.isEmpty) return false;
    final cached = _chapterSameTitleRemovedById[key];
    if (cached != null) return cached;
    if (widget.isEphemeral) {
      _chapterSameTitleRemovedById[key] = false;
      return false;
    }
    final enabled = _settingsService.getChapterSameTitleRemoved(
      widget.bookId,
      key,
      fallback: false,
    );
    _chapterSameTitleRemovedById[key] = enabled;
    return enabled;
  }

  bool _isCurrentChapterSameTitleRemoved() {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return false;
    }
    return _isChapterSameTitleRemoved(_chapters[_currentChapterIndex].id);
  }

  String _postProcessContent(
    String content,
    String processedTitle, {
    String? chapterId,
  }) {
    var processed = content;
    final removeSameTitle = _settings.cleanChapterTitle ||
        (chapterId != null && _isChapterSameTitleRemoved(chapterId));
    if (removeSameTitle) {
      processed = _removeDuplicateTitle(processed, processedTitle);
    }
    if (_isCurrentBookEpub()) {
      if (_delRubyTag) {
        processed = _removeRubyTagsLikeLegado(processed);
      }
      if (_delHTag) {
        processed = _removeHTagLikeLegado(processed);
      }
    }
    if (_reSegment) {
      processed = TxtParser.reSegmentLikeLegado(
        processed,
        chapterTitle: processedTitle,
      );
    }
    processed = _convertByChineseConverterType(processed);
    processed = _normalizeContentForLegacyImageStyle(processed);
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

  String _normalizeContentForLegacyImageStyle(String content) {
    if (content.isEmpty || !_legacyImageTagRegex.hasMatch(content)) {
      return content;
    }
    final imageStyle = _normalizeLegacyImageStyle(_imageStyle);
    if (imageStyle == _legacyImageStyleText) {
      return content.replaceAllMapped(
        _legacyImageTagRegex,
        (_) => ReaderImageMarkerCodec.textFallbackPlaceholder,
      );
    }
    if (_settings.pageTurnMode != PageTurnMode.scroll) {
      // 翻页模式保留可逆图片标记，交由分页/渲染层按 legacy 语义处理图片块。
      return content.replaceAllMapped(
        _legacyImageTagRegex,
        (match) {
          final rawSrc = (match.group(1) ?? '').trim();
          final src = _normalizeReaderImageSrc(rawSrc);
          if (src.isEmpty) {
            return ReaderImageMarkerCodec.textFallbackPlaceholder;
          }
          _rememberBookImageCacheKey(src);
          final rawTag = match.group(0) ?? '';
          final hintedSize = _extractImageDimensionHintsFromTag(rawTag) ??
              _extractImageDimensionHintsFromSrcUrl(rawSrc);
          final resolvedSize = ReaderImageMarkerCodec.lookupResolvedSize(src);
          final width = resolvedSize?.width ?? hintedSize?.width;
          final height = resolvedSize?.height ?? hintedSize?.height;
          return '\n${ReaderImageMarkerCodec.encode(
            src,
            width: width,
            height: height,
          )}\n';
        },
      );
    }
    // 滚动模式保留并隔离图片标签，便于后续渲染层按样式分流。
    return content.replaceAllMapped(
      _legacyImageTagRegex,
      (match) => '\n${match.group(0)}\n',
    );
  }

  List<ReaderImageMarkerMeta> _collectUniqueImageMarkerMetas(
    String content, {
    int maxCount = 24,
  }) {
    if (content.isEmpty || !ReaderImageMarkerCodec.containsMarker(content)) {
      return const <ReaderImageMarkerMeta>[];
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final seen = <String>{};
    final metas = <ReaderImageMarkerMeta>[];
    for (final line in lines) {
      if (metas.length >= maxCount) {
        break;
      }
      final meta = ReaderImageMarkerCodec.decodeMetaLine(line);
      if (meta == null) {
        continue;
      }
      final normalizedSrc = _normalizeReaderImageSrc(meta.src);
      final normalizedKey =
          ReaderImageMarkerCodec.normalizeResolvedSizeKey(normalizedSrc);
      if (normalizedSrc.isEmpty ||
          normalizedKey.isEmpty ||
          !seen.add(normalizedKey)) {
        continue;
      }
      _bookImageSizeCacheKeys.add(normalizedKey);
      metas.add(
        ReaderImageMarkerMeta(
          src: normalizedSrc,
          width: meta.width,
          height: meta.height,
        ),
      );
    }
    return metas;
  }

  String _resolveWarmupTelemetrySourceKey(BookSource? source) {
    final sourceUrl = (source?.bookSourceUrl ??
            _currentSourceUrl ??
            widget.effectiveSourceUrl ??
            '')
        .trim();
    if (sourceUrl.isNotEmpty) {
      return sourceUrl;
    }
    return '__global__';
  }

  _ReaderImageWarmupSourceTelemetry _telemetryForSource(BookSource? source) {
    final key = _resolveWarmupTelemetrySourceKey(source);
    final cached = _imageWarmupTelemetryBySource[key];
    if (cached != null) {
      return cached;
    }
    if (_imageWarmupTelemetryBySource.length >= 48) {
      String? staleKey;
      DateTime? staleAt;
      _imageWarmupTelemetryBySource.forEach((mapKey, telemetry) {
        if (staleAt == null || telemetry.updatedAt.isBefore(staleAt!)) {
          staleKey = mapKey;
          staleAt = telemetry.updatedAt;
        }
      });
      if (staleKey != null) {
        _imageWarmupTelemetryBySource.remove(staleKey);
      }
    }
    final created = _ReaderImageWarmupSourceTelemetry();
    _imageWarmupTelemetryBySource[key] = created;
    return created;
  }

  _ReaderImageWarmupSourceTelemetry? _telemetrySnapshotForSource(
    BookSource? source,
  ) {
    final key = _resolveWarmupTelemetrySourceKey(source);
    return _imageWarmupTelemetryBySource[key];
  }

  void _recordWarmupProbeSuccessForSource(BookSource? source) {
    _telemetryForSource(source).recordSuccess();
  }

  void _recordWarmupProbeFailureForSource(
    _ReaderImageWarmupFailureKind kind,
    BookSource? source,
  ) {
    _telemetryForSource(source).recordFailure(kind);
  }

  _ReaderImageWarmupFailureKind _mergeWarmupFailureKind(
    _ReaderImageWarmupFailureKind? current,
    _ReaderImageWarmupFailureKind candidate,
  ) {
    if (current == null) {
      return candidate;
    }
    if (current == _ReaderImageWarmupFailureKind.timeout ||
        candidate == _ReaderImageWarmupFailureKind.timeout) {
      return _ReaderImageWarmupFailureKind.timeout;
    }
    if (current == _ReaderImageWarmupFailureKind.auth ||
        candidate == _ReaderImageWarmupFailureKind.auth) {
      return _ReaderImageWarmupFailureKind.auth;
    }
    if (current == _ReaderImageWarmupFailureKind.decode ||
        candidate == _ReaderImageWarmupFailureKind.decode) {
      return _ReaderImageWarmupFailureKind.decode;
    }
    return _ReaderImageWarmupFailureKind.other;
  }

  _ReaderImageWarmupFailureKind _classifyWarmupProbeError(Object error) {
    if (error is TimeoutException) {
      return _ReaderImageWarmupFailureKind.timeout;
    }
    final statusCode = _extractStatusCodeFromProbeError(error);
    if (statusCode == 401 || statusCode == 403) {
      return _ReaderImageWarmupFailureKind.auth;
    }
    final message = '$error'.toLowerCase();
    if (_looksLikeTimeoutMessage(message)) {
      return _ReaderImageWarmupFailureKind.timeout;
    }
    if (_looksLikeAuthFailureMessage(message)) {
      return _ReaderImageWarmupFailureKind.auth;
    }
    if (_looksLikeDecodeFailureMessage(message)) {
      return _ReaderImageWarmupFailureKind.decode;
    }
    return _ReaderImageWarmupFailureKind.other;
  }

  int? _extractStatusCodeFromProbeError(Object error) {
    try {
      final dynamic dynamicError = error;
      final value = dynamicError.statusCode;
      if (value is int) {
        return value;
      }
    } catch (_) {
      // ignore statusCode extract failure
    }
    return null;
  }

  bool _looksLikeTimeoutMessage(String message) {
    return message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('deadline exceeded');
  }

  bool _looksLikeAuthFailureMessage(String message) {
    return message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('401') ||
        message.contains('403') ||
        message.contains('cookie') ||
        message.contains('referer') ||
        message.contains('origin') ||
        message.contains('login required');
  }

  bool _looksLikeDecodeFailureMessage(String message) {
    return message.contains('decode') ||
        message.contains('codec') ||
        message.contains('unsupported image') ||
        message.contains('invalid image') ||
        message.contains('format exception');
  }

  Future<bool> _warmupPagedImageSizeCache(
    String content, {
    int maxProbeCount = 8,
    Duration maxDuration = const Duration(milliseconds: 260),
  }) async {
    if (_settings.pageTurnMode == PageTurnMode.scroll) return false;
    final imageStyle = _normalizeLegacyImageStyle(_imageStyle);
    if (imageStyle == _legacyImageStyleText) return false;
    final budget = _resolveImageWarmupBudget(
      baseProbeCount: maxProbeCount,
      baseDuration: maxDuration,
    );

    final metas = _collectUniqueImageMarkerMetas(
      content,
      maxCount: budget.probeCount,
    );
    if (metas.isEmpty) return false;

    final deadline = DateTime.now().add(budget.maxDuration);
    final source = _resolveCurrentSource();
    var changed = false;

    for (final meta in metas) {
      final src = meta.src.trim();
      if (src.isEmpty) continue;
      _rememberBookImageCacheKey(src);
      final request = ReaderImageRequestParser.parse(src);

      if (meta.hasDimensionHints) {
        changed = ReaderImageMarkerCodec.rememberResolvedSize(
              src,
              width: meta.width!,
              height: meta.height!,
            ) ||
            changed;
      }

      if (ReaderImageMarkerCodec.lookupResolvedSize(src) != null) {
        continue;
      }

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        break;
      }
      if (_imageSizeWarmupInFlight.contains(src)) {
        continue;
      }

      await _ensureReaderImageCookieHeaderCached(
        request,
        timeout: _clampReaderWarmupDuration(
          remaining,
          max: const Duration(milliseconds: 140),
        ),
      );

      final imageProvider = _resolveReaderImageProviderFromRequest(request);

      _imageSizeWarmupInFlight.add(src);
      try {
        final probeTimeout = _clampReaderWarmupDuration(
          remaining,
          max: budget.perProbeTimeout,
        );
        Size? resolved;
        _ReaderImageWarmupFailureKind? failureKind;
        var attempted = false;
        if (imageProvider != null) {
          final providerProbe = await _resolveImageIntrinsicSize(
            imageProvider,
            timeout: probeTimeout,
          );
          attempted = attempted || providerProbe.attempted;
          resolved = providerProbe.size;
          if (providerProbe.failureKind != null) {
            failureKind = _mergeWarmupFailureKind(
              failureKind,
              providerProbe.failureKind!,
            );
          }
        }
        if (resolved == null) {
          final sourceAwareProbe =
              await _resolveImageIntrinsicSizeFromSourceAwareFetch(
            request,
            timeout: probeTimeout,
          );
          attempted = attempted || sourceAwareProbe.attempted;
          resolved = sourceAwareProbe.size;
          if (sourceAwareProbe.failureKind != null) {
            failureKind = _mergeWarmupFailureKind(
              failureKind,
              sourceAwareProbe.failureKind!,
            );
          }
        }
        if (resolved == null) {
          if (attempted) {
            _recordWarmupProbeFailureForSource(
              failureKind ?? _ReaderImageWarmupFailureKind.other,
              source,
            );
          }
          continue;
        }
        _recordWarmupProbeSuccessForSource(source);
        _recordLongImageFirstFrameErrorSample(
          src: src,
          resolvedSize: resolved,
          hintMeta: meta,
        );
        changed = ReaderImageMarkerCodec.rememberResolvedSize(
              src,
              width: resolved.width,
              height: resolved.height,
            ) ||
            changed;
      } finally {
        _imageSizeWarmupInFlight.remove(src);
      }
    }

    if (changed) {
      _schedulePersistReaderImageSizeSnapshot();
    }
    return changed;
  }

  _ReaderImageWarmupBudget _resolveImageWarmupBudget({
    required int baseProbeCount,
    required Duration baseDuration,
  }) {
    var probeCount = baseProbeCount;
    var durationMs = baseDuration.inMilliseconds;
    final source = _resolveCurrentSource();
    final telemetry = _telemetrySnapshotForSource(source);

    final sampledLatencyMs = _recentChapterFetchDuration.inMilliseconds > 0
        ? _recentChapterFetchDuration.inMilliseconds
        : (source?.respondTime ?? 0);

    if (sampledLatencyMs > 0) {
      final boostedDuration = durationMs + (sampledLatencyMs * 0.6).round();
      durationMs = boostedDuration.clamp(durationMs, 980);
      if (sampledLatencyMs >= 900) {
        probeCount += 3;
      } else if (sampledLatencyMs >= 600) {
        probeCount += 2;
      } else if (sampledLatencyMs >= 350) {
        probeCount += 1;
      }
    }

    if ((source?.loginUrl ?? '').trim().isNotEmpty) {
      durationMs = (durationMs + 120).clamp(baseDuration.inMilliseconds, 980);
      probeCount += 1;
    }

    if (_longImageFirstFrameErrorSamples >= 3 &&
        _longImageFirstFrameErrorEma >= _longImageErrorBoostThreshold) {
      final errorBoostMs =
          (_longImageFirstFrameErrorEma * 320).round().clamp(90, 260);
      durationMs =
          (durationMs + errorBoostMs).clamp(baseDuration.inMilliseconds, 1200);
      probeCount += _longImageFirstFrameErrorEma >= 0.45 ? 3 : 2;
    }

    if (telemetry != null && telemetry.sampleCount >= 3) {
      if (telemetry.timeoutRateEma >= 0.16 || telemetry.timeoutStreak >= 2) {
        final timeoutBoostMs =
            (telemetry.timeoutRateEma * 420).round().clamp(70, 340) +
                telemetry.timeoutStreak * 45;
        durationMs = (durationMs + timeoutBoostMs)
            .clamp(baseDuration.inMilliseconds, 1450);
        probeCount += telemetry.timeoutRateEma >= 0.34 ? 3 : 2;
      }
      if (telemetry.authRateEma >= 0.10 || telemetry.authStreak >= 1) {
        final authBoostMs =
            (120 + telemetry.authRateEma * 210).round().clamp(110, 280);
        durationMs =
            (durationMs + authBoostMs).clamp(baseDuration.inMilliseconds, 1450);
        probeCount += telemetry.authRateEma >= 0.26 ? 2 : 1;
      }
      if (telemetry.decodeRateEma >= 0.16 || telemetry.decodeStreak >= 2) {
        durationMs = (durationMs + 70).clamp(baseDuration.inMilliseconds, 1450);
        probeCount += 1;
      }
      if (telemetry.successRateEma >= 0.78 &&
          telemetry.timeoutRateEma <= 0.06 &&
          telemetry.sampleCount >= 8) {
        probeCount -= 1;
      }
    }

    probeCount = probeCount.clamp(baseProbeCount, 18);
    final maxDuration = Duration(milliseconds: durationMs);
    var perProbeTimeoutMs = (durationMs * 0.46).round();
    if (telemetry != null && telemetry.sampleCount >= 3) {
      if (telemetry.timeoutRateEma >= 0.20 || telemetry.timeoutStreak >= 2) {
        perProbeTimeoutMs += 70;
      }
      if (telemetry.authRateEma >= 0.12) {
        perProbeTimeoutMs += 40;
      }
    }
    final perProbeTimeout = Duration(
      milliseconds: perProbeTimeoutMs.clamp(180, 620),
    );
    return _ReaderImageWarmupBudget(
      probeCount: probeCount,
      maxDuration: maxDuration,
      perProbeTimeout: perProbeTimeout,
    );
  }

  Duration _clampReaderWarmupDuration(
    Duration remaining, {
    required Duration max,
  }) {
    if (remaining <= Duration.zero) return Duration.zero;
    if (remaining < max) return remaining;
    return max;
  }

  Future<_ReaderImageSizeProbeResult>
      _resolveImageIntrinsicSizeFromSourceAwareFetch(
    ReaderImageRequest request, {
    Duration timeout = const Duration(milliseconds: 220),
  }) async {
    if (timeout <= Duration.zero) {
      return const _ReaderImageSizeProbeResult.skipped();
    }
    final source = _resolveCurrentSource();
    if (source == null) {
      return const _ReaderImageSizeProbeResult.skipped();
    }
    final normalizedUrl = request.url.trim();
    if (normalizedUrl.isEmpty) {
      return const _ReaderImageSizeProbeResult.skipped();
    }
    if (normalizedUrl.toLowerCase().startsWith('data:image')) {
      return const _ReaderImageSizeProbeResult.skipped();
    }
    final uri = Uri.tryParse(normalizedUrl);
    if (uri != null && uri.hasScheme && !_isHttpLikeUri(uri)) {
      return const _ReaderImageSizeProbeResult.skipped();
    }

    final rawImageUrl = request.raw.isEmpty ? request.url : request.raw;
    final attemptTimeouts = _buildSourceAwareProbeTimeouts(timeout);
    var attempted = false;
    _ReaderImageWarmupFailureKind? failureKind;
    for (var i = 0; i < attemptTimeouts.length; i++) {
      final probeTimeout = attemptTimeouts[i];
      if (probeTimeout <= Duration.zero) {
        continue;
      }
      attempted = true;

      final bytesProbe = i == 0
          ? await _loadImageBytesFromSourceAwareLoader(
              source: source,
              imageUrl: rawImageUrl,
              timeout: probeTimeout,
            )
          : await _loadImageBytesFromRuleEngine(
              source: source,
              imageUrl: rawImageUrl,
              timeout: probeTimeout,
            );
      if (bytesProbe.failureKind != null) {
        failureKind = _mergeWarmupFailureKind(
          failureKind,
          bytesProbe.failureKind!,
        );
      }
      final bytes = bytesProbe.bytes;
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      final size = await _decodeImageSizeFromBytes(bytes);
      if (size != null) {
        return _ReaderImageSizeProbeResult.success(size);
      }
      failureKind = _mergeWarmupFailureKind(
        failureKind,
        _ReaderImageWarmupFailureKind.decode,
      );
    }
    if (!attempted) {
      return const _ReaderImageSizeProbeResult.skipped();
    }
    return _ReaderImageSizeProbeResult.failure(
      failureKind ?? _ReaderImageWarmupFailureKind.other,
    );
  }

  List<Duration> _buildSourceAwareProbeTimeouts(Duration totalTimeout) {
    final totalMs = totalTimeout.inMilliseconds;
    if (totalMs <= 0) return const <Duration>[];
    if (totalMs <= 240) {
      return <Duration>[Duration(milliseconds: totalMs)];
    }

    int clampInt(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    final attempts = <Duration>[];
    var remainingMs = totalMs;

    void take(int candidateMs) {
      if (remainingMs <= 0) return;
      final bounded = clampInt(candidateMs, 1, remainingMs);
      attempts.add(Duration(milliseconds: bounded));
      remainingMs -= bounded;
    }

    final firstTarget = clampInt((totalMs * 0.44).round(), 140, 260);
    take(firstTarget);
    if (remainingMs <= 0) return attempts;

    final secondTarget = clampInt((totalMs * 0.36).round(), 120, 360);
    if (remainingMs >= 120) {
      take(secondTarget);
    }
    if (remainingMs > 0) {
      take(remainingMs);
    }
    return attempts;
  }

  Future<_ReaderImageBytesProbeResult> _loadImageBytesFromSourceAwareLoader({
    required BookSource source,
    required String imageUrl,
    required Duration timeout,
  }) async {
    try {
      final bytes = await SourceCoverLoader.instance
          .load(
            imageUrl: imageUrl,
            source: source,
          )
          .timeout(timeout);
      if (bytes == null || bytes.isEmpty) {
        return const _ReaderImageBytesProbeResult.failure(
          _ReaderImageWarmupFailureKind.other,
        );
      }
      return _ReaderImageBytesProbeResult.success(bytes);
    } on TimeoutException {
      return const _ReaderImageBytesProbeResult.failure(
        _ReaderImageWarmupFailureKind.timeout,
      );
    } catch (error) {
      return _ReaderImageBytesProbeResult.failure(
        _classifyWarmupProbeError(error),
      );
    }
  }

  Future<_ReaderImageBytesProbeResult> _loadImageBytesFromRuleEngine({
    required BookSource source,
    required String imageUrl,
    required Duration timeout,
  }) async {
    try {
      final bytes = await _ruleEngine
          .fetchCoverBytes(
            source: source,
            imageUrl: imageUrl,
          )
          .timeout(timeout);
      if (bytes == null || bytes.isEmpty) {
        return const _ReaderImageBytesProbeResult.failure(
          _ReaderImageWarmupFailureKind.other,
        );
      }
      return _ReaderImageBytesProbeResult.success(bytes);
    } on TimeoutException {
      return const _ReaderImageBytesProbeResult.failure(
        _ReaderImageWarmupFailureKind.timeout,
      );
    } catch (error) {
      return _ReaderImageBytesProbeResult.failure(
        _classifyWarmupProbeError(error),
      );
    }
  }

  Future<Size?> _decodeImageSizeFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final width = image.width.toDouble();
        final height = image.height.toDouble();
        image.dispose();
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return null;
        }
        return Size(width, height);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  Future<_ReaderImageSizeProbeResult> _resolveImageIntrinsicSize(
    ImageProvider<Object> imageProvider, {
    Duration timeout = const Duration(milliseconds: 220),
  }) async {
    if (timeout <= Duration.zero) {
      return const _ReaderImageSizeProbeResult.skipped();
    }
    final completer = Completer<_ReaderImageSizeProbeResult>();
    final stream = imageProvider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    Timer? timer;

    void finish(_ReaderImageSizeProbeResult value) {
      if (completer.isCompleted) return;
      if (listener != null) {
        stream.removeListener(listener!);
      }
      timer?.cancel();
      completer.complete(value);
    }

    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          finish(
            const _ReaderImageSizeProbeResult.failure(
              _ReaderImageWarmupFailureKind.decode,
            ),
          );
          return;
        }
        finish(_ReaderImageSizeProbeResult.success(Size(width, height)));
      },
      onError: (Object error, StackTrace? stackTrace) {
        finish(
          _ReaderImageSizeProbeResult.failure(
            _classifyWarmupProbeError(error),
          ),
        );
      },
    );

    stream.addListener(listener);
    timer = Timer(
      timeout,
      () => finish(
        const _ReaderImageSizeProbeResult.failure(
          _ReaderImageWarmupFailureKind.timeout,
        ),
      ),
    );
    return completer.future;
  }

  Size? _extractImageDimensionHintsFromTag(String imgTag) {
    if (imgTag.isEmpty) return null;
    var width = _extractImageDimensionFromAttribute(
          imgTag,
          attribute: 'width',
        ) ??
        _extractImageDimensionFromInlineStyle(
          imgTag,
          property: 'width',
        );
    var height = _extractImageDimensionFromAttribute(
          imgTag,
          attribute: 'height',
        ) ??
        _extractImageDimensionFromInlineStyle(
          imgTag,
          property: 'height',
        );
    final aspectRatio = _extractImageAspectRatioFromInlineStyle(imgTag);
    if (aspectRatio != null) {
      if (width != null && height == null) {
        height = width / aspectRatio;
      } else if (height != null && width == null) {
        width = height * aspectRatio;
      }
    }
    if (width == null || height == null) {
      return null;
    }
    return Size(width, height);
  }

  double? _extractImageDimensionFromAttribute(
    String imgTag, {
    required String attribute,
  }) {
    final attrRegex = RegExp(
      '''$attribute\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))''',
      caseSensitive: false,
    );
    final match = attrRegex.firstMatch(imgTag);
    if (match == null) return null;
    final raw = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    return _parseLegacyCssPixelValue(raw);
  }

  double? _extractImageDimensionFromInlineStyle(
    String imgTag, {
    required String property,
  }) {
    final rawValue = _extractInlineStyleProperty(imgTag, property: property);
    if (rawValue == null) return null;
    return _parseLegacyCssPixelValue(rawValue);
  }

  double? _extractImageAspectRatioFromInlineStyle(String imgTag) {
    final rawValue = _extractInlineStyleProperty(
      imgTag,
      property: 'aspect-ratio',
    );
    if (rawValue == null) return null;
    final value = rawValue.trim().toLowerCase();
    if (value.isEmpty || value == 'auto') return null;
    final ratioMatch =
        RegExp(r'^([0-9]+(?:\.[0-9]+)?)\s*/\s*([0-9]+(?:\.[0-9]+)?)$')
            .firstMatch(value);
    if (ratioMatch != null) {
      final numerator = double.tryParse(ratioMatch.group(1) ?? '');
      final denominator = double.tryParse(ratioMatch.group(2) ?? '');
      if (numerator == null ||
          denominator == null ||
          !numerator.isFinite ||
          !denominator.isFinite ||
          numerator <= 0 ||
          denominator <= 0) {
        return null;
      }
      return numerator / denominator;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String? _extractInlineStyleProperty(
    String imgTag, {
    required String property,
  }) {
    final styleMatch = _cssStyleAttrRegex.firstMatch(imgTag);
    if (styleMatch == null) return null;
    final styleText = (styleMatch.group(1) ?? styleMatch.group(2) ?? '').trim();
    if (styleText.isEmpty) return null;
    final propertyRegex = RegExp(
      '''$property\\s*:\\s*([^;]+)''',
      caseSensitive: false,
    );
    final match = propertyRegex.firstMatch(styleText);
    if (match == null) return null;
    return match.group(1)?.trim();
  }

  Size? _extractImageDimensionHintsFromSrcUrl(String rawSrc) {
    final request = ReaderImageRequestParser.parse(rawSrc);
    final normalizedUrl = request.url.trim();
    if (normalizedUrl.isEmpty) return null;
    final uri = Uri.tryParse(normalizedUrl);
    final width = _extractImageDimensionFromUrl(
      uri: uri,
      url: normalizedUrl,
      queryKeys: _legacyImageWidthQueryKeys,
      urlPatterns: _legacyImageWidthUrlPatterns,
    );
    final height = _extractImageDimensionFromUrl(
      uri: uri,
      url: normalizedUrl,
      queryKeys: _legacyImageHeightQueryKeys,
      urlPatterns: _legacyImageHeightUrlPatterns,
    );
    if (width == null || height == null) {
      return null;
    }
    return Size(width, height);
  }

  double? _extractImageDimensionFromUrl({
    required Uri? uri,
    required String url,
    required List<String> queryKeys,
    required List<RegExp> urlPatterns,
  }) {
    if (uri != null && uri.queryParameters.isNotEmpty) {
      final normalizedQuery = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        final normalizedKey = key.trim().toLowerCase();
        final normalizedValue = value.trim();
        if (normalizedKey.isEmpty || normalizedValue.isEmpty) return;
        normalizedQuery[normalizedKey] = normalizedValue;
      });
      for (final key in queryKeys) {
        final value = normalizedQuery[key.toLowerCase()];
        final parsed = _parsePositiveDimensionFromText(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    for (final pattern in urlPatterns) {
      final match = pattern.firstMatch(url);
      if (match == null) continue;
      final parsed = _parsePositiveDimensionFromText(match.group(1));
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double? _parsePositiveDimensionFromText(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(raw.trim());
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1) ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  double? _parseLegacyCssPixelValue(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value.contains('%')) return null;
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)(px)?$').firstMatch(value);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1) ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
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

  String _removeRubyTagsLikeLegado(String content) {
    return content
        .replaceAll(
          RegExp(r'<rt\b[^>]*>.*?</rt>', caseSensitive: false, dotAll: true),
          '',
        )
        .replaceAll(
          RegExp(r'<rp\b[^>]*>.*?</rp>', caseSensitive: false, dotAll: true),
          '',
        )
        .replaceAll(RegExp(r'</?ruby\b[^>]*>', caseSensitive: false), '');
  }

  String _removeHTagLikeLegado(String content) {
    return content.replaceAll(
        RegExp(r'</?h[1-6]\b[^>]*>', caseSensitive: false), '');
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

  int _resolveScrollTipTotalPages() {
    final total = _pageFactory.totalPages;
    return total <= 0 ? 1 : total;
  }

  int _resolveScrollTipCurrentPage(int totalPages) {
    if (totalPages <= 1) return 1;
    final progress = _currentScrollChapterProgress.clamp(0.0, 1.0).toDouble();
    final pageIndex = ChapterProgressUtils.pageIndexFromProgress(
      progress: progress,
      totalPages: totalPages,
    );
    return (pageIndex + 1).clamp(1, totalPages).toInt();
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
    final scrollTipTotalPages = _resolveScrollTipTotalPages();
    final scrollTipCurrentPage = _resolveScrollTipCurrentPage(
      scrollTipTotalPages,
    );

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
                        currentPage: scrollTipCurrentPage,
                        totalPages: scrollTipTotalPages,
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
                        currentPage: scrollTipCurrentPage,
                        totalPages: scrollTipTotalPages,
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
                        onShowSourceActions: _showSourceActionsMenu,
                        onShowMoreMenu: _showReaderActionsMenu,
                        showSourceAction: !_isCurrentBookLocal(),
                        showChapterLink: !_isCurrentBookLocal(),
                        showTitleAddition: _settings.showReadTitleAddition,
                        readBarStyleFollowPage: _menuFollowPageTone,
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
                        onReadAloudLongPress: _openReadAloudDialogFromMenu,
                        onShowInterfaceSettings: _openInterfaceSettingsFromMenu,
                        onShowBehaviorSettings: _openBehaviorSettingsFromMenu,
                        readBarStyleFollowPage: _menuFollowPageTone,
                        readAloudRunning: _readAloudSnapshot.isRunning,
                        readAloudPaused: _readAloudSnapshot.isPaused,
                      ),

                    if (_showSearchMenu) _buildSearchMenuOverlay(),

                    if (_isLoadingChapter || _isCurrentFactoryChapterLoading)
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
                          onShowMainMenu: _openReaderMenuFromAutoReadPanel,
                          onOpenChapterList: _openChapterListFromAutoReadPanel,
                          onOpenPageAnimSettings:
                              _openPageAnimConfigFromAutoReadPanel,
                          onStop: _stopAutoReadFromPanel,
                          onClose: () {
                            setState(() {
                              _showAutoReadPanel = false;
                            });
                            _screenOffTimerStart(force: true);
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
    final bodyWidth = _scrollBodyWidth();
    final imageStyle = _normalizeLegacyImageStyle(_imageStyle);
    final imageBlocks = _buildScrollImageRenderBlocks(
      segment.content,
      imageStyle: imageStyle,
    );
    final contentBody = imageBlocks == null
        ? ScrollSegmentPaintView(
            layout: _resolveScrollTextLayout(
              seed: _ScrollSegmentSeed(
                chapterId: segment.chapterId,
                title: segment.title,
                content: segment.content,
              ),
              maxWidth: bodyWidth,
              style: paragraphStyle,
            ),
            style: paragraphStyle,
            highlightQuery: _activeSearchHighlightQuery,
            highlightColor: _searchHighlightColor,
            highlightTextColor: _searchHighlightTextColor,
          )
        : _buildImageAwareScrollSegmentBody(
            blocks: imageBlocks,
            paragraphStyle: paragraphStyle,
            imageStyle: imageStyle,
            maxWidth: bodyWidth,
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
              SizedBox(
                width: double.infinity,
                child: Text(
                  segment.title,
                  textAlign: _titleTextAlign,
                  style: TextStyle(
                    fontSize: _settings.fontSize + _settings.titleSize,
                    fontWeight: FontWeight.w600,
                    color: _currentTheme.text,
                    fontFamily: _currentFontFamily,
                    fontFamilyFallback: _currentFontFamilyFallback,
                  ),
                ),
              ),
              SizedBox(
                height: _settings.titleBottomSpacing > 0
                    ? _settings.titleBottomSpacing
                    : _settings.paragraphSpacing * 1.5,
              ),
            ],
            contentBody,
            SizedBox(height: isTailSegment ? 80 : 24),
          ],
        ),
      ),
    );
  }

  List<_ReaderRenderBlock>? _buildScrollImageRenderBlocks(
    String content, {
    required String imageStyle,
  }) {
    if (imageStyle == _legacyImageStyleText ||
        !_legacyImageTagRegex.hasMatch(content)) {
      return null;
    }
    final blocks = <_ReaderRenderBlock>[];
    var cursor = 0;
    for (final match in _legacyImageTagRegex.allMatches(content)) {
      final before = content.substring(cursor, match.start);
      if (before.trim().isNotEmpty) {
        blocks.add(_ReaderRenderBlock.text(before));
      }
      final rawSrc = (match.group(1) ?? '').trim();
      final src = _normalizeReaderImageSrc(rawSrc);
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
    if (!blocks.any((block) => block.isImage)) {
      return null;
    }
    return blocks;
  }

  Widget _buildImageAwareScrollSegmentBody({
    required List<_ReaderRenderBlock> blocks,
    required TextStyle paragraphStyle,
    required String imageStyle,
    required double maxWidth,
  }) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.isImage) {
        children.add(
          _buildScrollImageBlock(
            src: block.imageSrc ?? '',
            imageStyle: imageStyle,
            maxWidth: maxWidth,
          ),
        );
      } else if ((block.text ?? '').trim().isNotEmpty) {
        children.add(
          LegacyJustifiedTextBlock(
            content: block.text ?? '',
            style: paragraphStyle,
            justify: _settings.textFullJustify,
            paragraphIndent: _settings.paragraphIndent,
            applyParagraphIndent: true,
            preserveEmptyLines: true,
          ),
        );
      }
      if (i != blocks.length - 1) {
        children.add(
          SizedBox(
            height: _settings.paragraphSpacing.clamp(4.0, 24.0).toDouble(),
          ),
        );
      }
    }
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildScrollImageBlock({
    required String src,
    required String imageStyle,
    required double maxWidth,
  }) {
    final request = ReaderImageRequestParser.parse(src);
    final displaySrc = request.url.trim().isEmpty ? src.trim() : request.url;
    final imageProvider = _resolveReaderImageProviderFromRequest(request);
    if (imageProvider == null) {
      return _buildImageLoadFallback(displaySrc);
    }
    final forceFullWidth = imageStyle == _legacyImageStyleFull ||
        imageStyle == _legacyImageStyleSingle;
    final image = Image(
      image: imageProvider,
      width: forceFullWidth ? maxWidth : null,
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
      errorBuilder: (_, __, ___) => _buildImageLoadFallback(displaySrc),
    );
    final imageBox = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
      ),
      child: image,
    );
    if (imageStyle == _legacyImageStyleSingle) {
      final viewportHeight = MediaQuery.of(context).size.height;
      final singleHeight =
          (viewportHeight - _settings.paddingTop - _settings.paddingBottom)
              .clamp(220.0, 1200.0)
              .toDouble();
      return SizedBox(
        height: singleHeight,
        child: Center(child: imageBox),
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical:
              (_settings.paragraphSpacing / 2).clamp(6.0, 20.0).toDouble(),
        ),
        child: imageBox,
      ),
    );
  }

  Widget _buildImageLoadFallback(String src) {
    final display = src.trim();
    final message = display.isEmpty ? '图片加载失败' : '图片加载失败：$display';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: TextStyle(
          fontSize: (_settings.fontSize - 2).clamp(10.0, 22.0).toDouble(),
          color: _currentTheme.text.withValues(alpha: 0.7),
          fontFamily: _currentFontFamily,
          fontFamilyFallback: _currentFontFamilyFallback,
        ),
      ),
    );
  }

  String _normalizeReaderImageSrc(String raw) {
    return raw.trim();
  }

  ImageProvider<Object>? _resolveReaderImageProvider(String src) {
    final request = ReaderImageRequestParser.parse(src);
    return _resolveReaderImageProviderFromRequest(request);
  }

  ImageProvider<Object>? _resolveReaderImageProviderFromRequest(
    ReaderImageRequest request,
  ) {
    final value = request.url.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower.startsWith('data:image')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex <= 0 || commaIndex >= value.length - 1) {
        return null;
      }
      try {
        final bytes = base64Decode(value.substring(commaIndex + 1));
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    if (!kIsWeb && value.startsWith('file://')) {
      final uri = Uri.tryParse(value);
      if (uri != null) {
        return FileImage(File(uri.toFilePath()));
      }
    }
    if (!kIsWeb && p.isAbsolute(value)) {
      final file = File(value);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !_isHttpLikeUri(uri)) {
      return null;
    }
    final headers = _composeReaderImageHeaders(request, uri: uri);
    if (headers.isEmpty) {
      return NetworkImage(value);
    }
    return NetworkImage(value, headers: headers);
  }

  Map<String, String> _composeReaderImageHeaders(
    ReaderImageRequest request, {
    Uri? uri,
  }) {
    final out = <String, String>{};
    final source = _resolveCurrentSource();
    if (source != null) {
      out.addAll(ReaderImageRequestParser.parseHeaderText(source.header));
    }
    out.addAll(request.headers);

    final targetUri = uri ?? Uri.tryParse(request.url);
    if (targetUri == null || !_isHttpLikeUri(targetUri)) {
      return out;
    }

    final cookieKey = _readerImageCookieCacheKey(targetUri);
    final cachedCookie = _readerImageCookieHeaderByHost[cookieKey];
    if (cachedCookie != null &&
        cachedCookie.isNotEmpty &&
        !_containsHeaderKey(out, 'Cookie')) {
      out['Cookie'] = cachedCookie;
    }

    final referer = _readerImageReferer();
    if (referer != null && referer.isNotEmpty) {
      if (!_containsHeaderKey(out, 'Referer')) {
        out['Referer'] = referer;
      }
      if (!_containsHeaderKey(out, 'Origin')) {
        final refererUri = Uri.tryParse(referer);
        if (refererUri != null && _isHttpLikeUri(refererUri)) {
          out['Origin'] = refererUri.origin;
        }
      }
    }
    return out;
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
    final host = uri.host.toLowerCase();
    final scheme = uri.scheme.toLowerCase();
    final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
    return '$scheme://$host:$port';
  }

  String? _readerImageReferer() {
    final chapterUrl =
        (_currentChapterIndex >= 0 && _currentChapterIndex < _chapters.length)
            ? (_chapters[_currentChapterIndex].url ?? '').trim()
            : '';
    if (chapterUrl.isNotEmpty) {
      final chapterUri = Uri.tryParse(chapterUrl);
      if (chapterUri != null && _isHttpLikeUri(chapterUri)) {
        return chapterUri.toString();
      }
    }
    final sourceUrl = (_currentSourceUrl ?? '').trim();
    if (sourceUrl.isNotEmpty) {
      final sourceUri = Uri.tryParse(sourceUrl);
      if (sourceUri != null && _isHttpLikeUri(sourceUri)) {
        return sourceUri.toString();
      }
    }
    return null;
  }

  bool _isHttpLikeUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  bool _containsHeaderKey(Map<String, String> headers, String name) {
    final lower = name.toLowerCase();
    return headers.keys.any((key) => key.toLowerCase() == lower);
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
              fontFamilyFallback: _currentFontFamilyFallback,
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
    unawaited(_openReadAloudAction());
  }

  void _openReadAloudDialogFromMenu() {
    _closeReaderMenuOverlay();
    _showToast('朗读设置暂未实现');
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
    setState(() {
      _showAutoReadPanel = false;
      _showMenu = true;
      _showSearchMenu = false;
    });
    _syncSystemUiForOverlay();
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

  Future<void> _openPageAnimConfigFromAutoReadPanel() async {
    _screenOffTimerStart(force: true);
    final selectedMode = await showCupertinoModalPopup<PageTurnMode>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('翻页动画'),
        actions: PageTurnModeUi.values(current: _settings.pageTurnMode)
            .map(
              (mode) => CupertinoActionSheetAction(
                onPressed: () {
                  if (PageTurnModeUi.isHidden(mode)) {
                    Navigator.pop(sheetContext);
                    _showToast('仿真2模式已隐藏');
                    return;
                  }
                  Navigator.pop(sheetContext, mode);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      PageTurnModeUi.isHidden(mode)
                          ? '${mode.name}（隐藏）'
                          : mode.name,
                    ),
                    if (_settings.pageTurnMode == mode)
                      Icon(CupertinoIcons.check_mark, color: _uiAccent),
                  ],
                ),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (!mounted || selectedMode == null) return;
    if (selectedMode != _settings.pageTurnMode) {
      _updateSettings(_settings.copyWith(pageTurnMode: selectedMode));
    }
    _screenOffTimerStart(force: true);
  }

  void _stopAutoReadFromPanel() {
    _screenOffTimerStart(force: true);
    if (mounted) {
      _showToast('自动阅读已停止');
    }
  }

  void _stopAutoPagerAtBoundary() {
    if (!_autoPager.isRunning) return;
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
        final hasNextChapter = _currentChapterIndex < _chapters.length - 1;
        if (atBottom && !hasNextChapter) {
          _stopAutoPagerAtBoundary();
          return;
        }
      }
      unawaited(_scrollPage(up: false));
      return;
    }

    final moved = _pageFactory.moveToNext();
    if (!moved) {
      _stopAutoPagerAtBoundary();
    }
  }

  Future<void> _toggleAutoPageFromQuickAction() async {
    _closeReaderMenuOverlay();
    final isRunning = _autoPager.isRunning;
    if (!isRunning) {
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

    if (!_showAutoReadPanel) {
      _openAutoReadPanel();
      _screenOffTimerStart(force: true);
      return;
    }

    _autoPager.stop();
    if (mounted && _showAutoReadPanel) {
      setState(() {
        _showAutoReadPanel = false;
      });
    }
    _showToast('自动阅读已停止');
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
    if (_chapters.isEmpty) return false;
    final step = direction == ReadAloudChapterDirection.next ? 1 : -1;
    final targetIndex = _currentChapterIndex + step;
    if (targetIndex < 0 || targetIndex >= _chapters.length) {
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
    unawaited(
      _readAloudService.updateChapter(
        chapterIndex: _currentChapterIndex,
        chapterTitle: _currentTitle,
        content: _currentContent,
      ),
    );
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
      showWebDavProgressActions: _hasWebDavProgressConfig(),
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
      ReaderLegacyReadMenuAction.sameTitleRemoved =>
        _isCurrentChapterSameTitleRemoved(),
      ReaderLegacyReadMenuAction.reSegment => _reSegment,
      ReaderLegacyReadMenuAction.delRubyTag => _delRubyTag,
      ReaderLegacyReadMenuAction.delHTag => _delHTag,
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
    final normalizedQuery = query.trim();
    if (content.isEmpty || normalizedQuery.isEmpty) return const [];

    final hits = <_ReaderSearchHit>[];
    var from = 0;
    var occurrenceIndex = 0;
    while (from < content.length) {
      final found = content.indexOf(normalizedQuery, from);
      if (found == -1) break;
      final end = found + normalizedQuery.length;
      final previewStart = (found - 20).clamp(0, content.length).toInt();
      final previewEnd = (end + 24).clamp(0, content.length).toInt();
      final previewRaw =
          content.substring(previewStart, previewEnd).replaceAll('\n', ' ');
      final localStart =
          (found - previewStart).clamp(0, previewRaw.length).toInt();
      final localEnd = (localStart + normalizedQuery.length)
          .clamp(localStart, previewRaw.length)
          .toInt();
      final previewBefore = previewRaw.substring(0, localStart);
      final previewMatch = previewRaw.substring(localStart, localEnd);
      final previewAfter = previewRaw.substring(localEnd);
      final pageIndex = _settings.pageTurnMode == PageTurnMode.scroll
          ? null
          : _resolveSearchHitPageIndex(
              contentOffset: found,
              occurrenceIndex: occurrenceIndex,
              query: normalizedQuery,
            );
      hits.add(
        _ReaderSearchHit(
          start: found,
          end: end,
          query: normalizedQuery,
          occurrenceIndex: occurrenceIndex,
          previewBefore: previewBefore,
          previewMatch: previewMatch,
          previewAfter: previewAfter,
          pageIndex: pageIndex,
        ),
      );
      occurrenceIndex += 1;
      from = end;
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

  void _jumpToSearchHit(_ReaderSearchHit hit) {
    if (_settings.pageTurnMode == PageTurnMode.scroll) {
      unawaited(_jumpToSearchHitInScroll(hit));
      return;
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
          duration: const Duration(milliseconds: 220),
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
    final hasHits = _contentSearchHits.isNotEmpty;
    final info = hasHits
        ? '结果 ${_currentSearchHitIndex + 1}/${_contentSearchHits.length} · $_currentTitle'
        : '当前章节未找到结果';
    final location = hasHits && currentHit != null
        ? '位置 ${currentHit.start + 1}/${_currentContent.length}'
        : null;
    final accent = _isUiDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
    final navBtnBg = _uiPanelBg.withValues(alpha: _isUiDark ? 0.94 : 0.95);
    final navBtnShadow = CupertinoColors.black.withValues(
      alpha: _isUiDark ? 0.32 : 0.12,
    );
    final sideButtonTop = MediaQuery.of(context).size.height * 0.42;

    return Stack(
      children: [
        Positioned(
          left: 12,
          top: sideButtonTop,
          child: _buildSearchSideNavButton(
            icon: CupertinoIcons.chevron_left,
            onTap: hasHits ? () => _navigateSearchHit(-1) : null,
            color: navBtnBg,
            shadowColor: navBtnShadow,
            semanticsLabel: '上一个',
          ),
        ),
        Positioned(
          right: 12,
          top: sideButtonTop,
          child: _buildSearchSideNavButton(
            icon: CupertinoIcons.chevron_right,
            onTap: hasHits ? () => _navigateSearchHit(1) : null,
            color: navBtnBg,
            shadowColor: navBtnShadow,
            semanticsLabel: '下一个',
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              decoration: BoxDecoration(
                color: _uiPanelBg.withValues(alpha: 0.97),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
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
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildSearchTopIconButton(
                          icon: CupertinoIcons.chevron_up,
                          onTap: hasHits ? () => _navigateSearchHit(-1) : null,
                        ),
                        _buildSearchTopIconButton(
                          icon: CupertinoIcons.chevron_down,
                          onTap: hasHits ? () => _navigateSearchHit(1) : null,
                        ),
                        const SizedBox(width: 6),
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
                            activeColor: CupertinoColors.destructiveRed,
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
      minSize: 30,
      onPressed: onTap,
      child: Icon(
        icon,
        size: 18,
        color: onTap == null ? _uiTextSubtle : _uiTextStrong,
      ),
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
      minSize: 0,
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
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _uiBorder),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: onTap == null ? _uiTextSubtle : _uiTextStrong,
          ),
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
          color: _uiPanelBg.withValues(alpha: _isUiDark ? 0.78 : 0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _uiBorder),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black
                  .withValues(alpha: _isUiDark ? 0.2 : 0.08),
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
          onTap: () => unawaited(_toggleAutoPageFromQuickAction()),
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
              ? _uiAccent.withValues(alpha: 0.18)
              : _uiPanelBg.withValues(alpha: _isUiDark ? 0.86 : 0.9),
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
    if (kIsWeb) {
      return const _ReadAloudCapability(
        available: false,
        reason: '当前平台暂不支持语音朗读',
      );
    }
    if (_chapters.isEmpty) {
      return const _ReadAloudCapability(
        available: false,
        reason: '当前书籍暂无可朗读章节',
      );
    }
    if (_currentContent.trim().isEmpty) {
      return const _ReadAloudCapability(
        available: false,
        reason: '当前章节暂无可朗读内容',
      );
    }
    return const _ReadAloudCapability(
      available: true,
      reason: '',
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

  String _normalizeLegacyImageStyle(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    if (_legacyImageStyles.contains(normalized)) {
      return normalized;
    }
    return _defaultLegacyImageStyle;
  }

  bool _hasWebDavProgressConfig() {
    final settings = _settingsService.appSettings;
    final rootUrl = _webDavService.buildRootUrl(settings).trim();
    final rootUri = Uri.tryParse(rootUrl);
    if (rootUri == null) return false;
    final scheme = rootUri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return _webDavService.hasValidConfig(settings);
  }

  bool _isSyncBookProgressEnabled() {
    return _settingsService.appSettings.syncBookProgress;
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

  String _progressSyncBookTitle() {
    final bookTitleFromRepo =
        _bookRepo.getBookById(widget.bookId)?.title.trim() ?? '';
    if (bookTitleFromRepo.isNotEmpty) {
      return bookTitleFromRepo;
    }
    final title = widget.bookTitle.trim();
    if (title.isNotEmpty) {
      return title;
    }
    return '未知书名';
  }

  String _progressSyncBookAuthor() {
    final authorFromRepo =
        _bookRepo.getBookById(widget.bookId)?.author.trim() ?? '';
    if (authorFromRepo.isNotEmpty) {
      return authorFromRepo;
    }
    final author = _bookAuthor.trim();
    if (author.isNotEmpty) {
      return author;
    }
    return '未知作者';
  }

  WebDavBookProgress _buildLocalBookProgressPayload() {
    final chapterProgress = _getChapterProgress().clamp(0.0, 1.0).toDouble();
    return WebDavBookProgress(
      name: _progressSyncBookTitle(),
      author: _progressSyncBookAuthor(),
      durChapterIndex: _currentChapterIndex.clamp(0, _chapters.length - 1),
      durChapterPos: (chapterProgress * 10000).round(),
      durChapterTime: DateTime.now().millisecondsSinceEpoch,
      durChapterTitle: _currentTitle,
      chapterProgress: chapterProgress,
      readProgress: _getBookProgress().clamp(0.0, 1.0).toDouble(),
      totalChapters: _chapters.length,
    );
  }

  double _decodeRemoteChapterProgress(WebDavBookProgress remote) {
    final explicit = remote.chapterProgress;
    if (explicit != null) {
      return explicit.clamp(0.0, 1.0).toDouble();
    }
    final pos = remote.durChapterPos;
    if (pos <= 0) return 0.0;
    if (pos <= 10000) {
      return (pos / 10000.0).clamp(0.0, 1.0).toDouble();
    }
    return 0.0;
  }

  double _decodeRemoteBookProgress(WebDavBookProgress remote) {
    final explicit = remote.readProgress;
    if (explicit != null) {
      return explicit.clamp(0.0, 1.0).toDouble();
    }
    final total = (remote.totalChapters ?? _chapters.length).clamp(1, 1 << 20);
    final chapterIndex = remote.durChapterIndex.clamp(0, total - 1);
    final chapterProgress = _decodeRemoteChapterProgress(remote);
    return ((chapterIndex + chapterProgress) / total)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  Future<void> _pushBookProgressToWebDav() async {
    if (!_isSyncBookProgressEnabled()) {
      return;
    }
    if (!_hasWebDavProgressConfig()) {
      _showReaderActionUnavailable('覆盖进度', reason: '请先在备份设置中配置 WebDav 账号与密码');
      return;
    }
    if (_chapters.isEmpty) {
      _showToast('当前目录为空，无法上传阅读进度');
      return;
    }
    try {
      await _saveProgress();
      final progress = _buildLocalBookProgressPayload();
      await _webDavService.uploadBookProgress(
        progress: progress,
        settings: _settingsService.appSettings,
      );
      if (!mounted) return;
      _showToast('上传进度成功');
    } catch (e) {
      if (!mounted) return;
      _showToast('上传进度失败：$e');
    }
  }

  Future<void> _pullBookProgressFromWebDav() async {
    if (!_isSyncBookProgressEnabled()) {
      return;
    }
    if (!_hasWebDavProgressConfig()) {
      _showReaderActionUnavailable('获取进度', reason: '请先在备份设置中配置 WebDav 账号与密码');
      return;
    }
    if (_chapters.isEmpty) {
      _showToast('当前目录为空，无法同步阅读进度');
      return;
    }
    try {
      final remote = await _webDavService.getBookProgress(
        bookTitle: _progressSyncBookTitle(),
        bookAuthor: _progressSyncBookAuthor(),
        settings: _settingsService.appSettings,
      );
      if (remote == null) {
        if (!mounted) return;
        _showToast('云端暂无该书进度');
        return;
      }
      await _applyRemoteBookProgress(remote);
    } catch (e) {
      if (!mounted) return;
      _showToast('获取进度失败：$e');
    }
  }

  Future<void> _applyRemoteBookProgress(WebDavBookProgress remote) async {
    if (_chapters.isEmpty) return;
    final maxIndex = _chapters.length - 1;
    final targetChapterIndex = remote.durChapterIndex.clamp(0, maxIndex);
    final targetChapterProgress = _decodeRemoteChapterProgress(remote);
    final localProgress = _getBookProgress().clamp(0.0, 1.0).toDouble();
    final remoteProgress = _decodeRemoteBookProgress(remote);

    if (remoteProgress < localProgress) {
      final confirmOverride = await showCupertinoDialog<bool>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: const Text('获取进度'),
              content: const Text('\n当前进度超过云端，是否覆盖为云端进度？'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('覆盖'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmOverride) return;
    }

    await _loadChapter(
      targetChapterIndex,
      restoreOffset: true,
      targetChapterProgress: targetChapterProgress,
    );
    await _saveProgress();
    if (!mounted) return;
    final title = remote.durChapterTitle?.trim().isNotEmpty == true
        ? remote.durChapterTitle!.trim()
        : _chapters[targetChapterIndex].title;
    _showToast('已同步云端进度：$title');
  }

  Future<void> _openContentEditFromMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      _showToast('当前章节不存在');
      return;
    }

    final chapterIndex = _currentChapterIndex;
    final chapter = _chapters[chapterIndex];
    final initialRawContent = await _resolveCurrentChapterRawContentForMenu(
      chapter: chapter,
      chapterIndex: chapterIndex,
    );
    if (!mounted) return;

    final payload = await Navigator.of(context).push<_ReaderContentEditPayload>(
      CupertinoPageRoute<_ReaderContentEditPayload>(
        fullscreenDialog: true,
        builder: (_) => _ReaderContentEditorPage(
          initialTitle: chapter.title,
          initialContent: initialRawContent,
          onResetContent: () => _reloadChapterRawContentForEditor(
            chapterIndex: chapterIndex,
          ),
        ),
      ),
    );
    if (payload == null) return;

    final nextTitle =
        payload.title.trim().isEmpty ? chapter.title : payload.title.trim();
    final nextContent = payload.content;
    final updated = chapter.copyWith(
      title: nextTitle,
      content: nextContent,
      isDownloaded: true,
    );
    if (!widget.isEphemeral) {
      await _chapterRepo.addChapters(<Chapter>[updated]);
    }
    if (!mounted) return;
    setState(() {
      _replaceStageCache.remove(chapter.id);
      _catalogDisplayTitleCacheByChapterId.remove(chapter.id);
      _chapterContentInFlight.remove(chapter.id);
      _chapters[chapterIndex] = updated;
    });
    await _loadChapter(chapterIndex, restoreOffset: true);
  }

  Future<String> _reloadChapterRawContentForEditor({
    required int chapterIndex,
  }) async {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) {
      throw StateError('当前章节不存在');
    }
    final chapter = _chapters[chapterIndex];
    final cleared = chapter.copyWith(
      content: null,
      isDownloaded: false,
    );
    if (!widget.isEphemeral) {
      await _chapterRepo.addChapters(<Chapter>[cleared]);
    }
    if (!mounted) {
      return '';
    }
    setState(() {
      _replaceStageCache.remove(chapter.id);
      _catalogDisplayTitleCacheByChapterId.remove(chapter.id);
      _chapterContentInFlight.remove(chapter.id);
      _chapters[chapterIndex] = cleared;
    });

    final resetRawContent = await _resolveCurrentChapterRawContentForMenu(
      chapter: cleared,
      chapterIndex: chapterIndex,
    );
    if (!mounted) {
      return resetRawContent;
    }

    if (resetRawContent.trim().isNotEmpty) {
      final restored = cleared.copyWith(
        content: resetRawContent,
        isDownloaded: true,
      );
      if (!widget.isEphemeral) {
        await _chapterRepo.addChapters(<Chapter>[restored]);
      }
      if (!mounted) {
        return resetRawContent;
      }
      setState(() {
        _replaceStageCache.remove(chapter.id);
        _catalogDisplayTitleCacheByChapterId.remove(chapter.id);
        _chapterContentInFlight.remove(chapter.id);
        _chapters[chapterIndex] = restored;
      });
    }

    await _loadChapter(chapterIndex, restoreOffset: true);
    return resetRawContent;
  }

  Future<void> _toggleReSegmentFromMenu() async {
    final next = !_reSegment;
    if (!widget.isEphemeral) {
      await _settingsService.saveBookReSegment(widget.bookId, next);
    }
    if (!mounted) return;
    setState(() {
      _reSegment = next;
    });
    _syncPageFactoryChapters(
      keepPosition: _settings.pageTurnMode != PageTurnMode.scroll,
    );
    await _loadChapter(_currentChapterIndex, restoreOffset: true);
  }

  Future<void> _openImageStyleFromMenu() async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('图片样式'),
        actions: _legacyImageStyles
            .map(
              (style) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, style),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(style),
                    if (style == _imageStyle)
                      Icon(CupertinoIcons.check_mark, color: _uiAccent),
                  ],
                ),
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
    await _applyImageStyleFromMenu(selected);
  }

  Future<void> _applyImageStyleFromMenu(String style) async {
    final normalized = _normalizeLegacyImageStyle(style);
    if (!widget.isEphemeral) {
      await _settingsService.saveBookImageStyle(widget.bookId, normalized);
    }
    if (!mounted) return;
    setState(() {
      _imageStyle = normalized;
    });

    // 对齐 legado：切换为 SINGLE 时自动回落为覆盖翻页动画。
    if (normalized == _legacyImageStyleSingle &&
        _settings.pageTurnMode != PageTurnMode.cover) {
      _updateSettings(
        _settings.copyWith(pageTurnMode: PageTurnMode.cover),
      );
    }
    await _loadChapter(_currentChapterIndex, restoreOffset: true);
  }

  Future<void> _showCharsetConfigFromMenu() async {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null) {
      _showToast('书籍信息不存在');
      return;
    }

    final currentCharset =
        _readerCharsetService.getBookCharset(widget.bookId) ??
            ReaderCharsetService.defaultCharset;
    final selected = await _showCharsetPicker(currentCharset: currentCharset);
    if (selected == null || selected.trim().isEmpty) return;
    await _applyBookCharsetSetting(
      book: book,
      charset: selected,
    );
  }

  Future<String?> _showCharsetPicker({
    required String currentCharset,
  }) {
    final normalizedCurrent =
        ReaderCharsetService.normalizeCharset(currentCharset) ??
            ReaderCharsetService.defaultCharset;
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('设置编码'),
        actions: _legacyCharsetOptions
            .map(
              (charset) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(popupContext, charset),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(charset),
                    if (charset == normalizedCurrent)
                      Icon(CupertinoIcons.check_mark, color: _uiAccent),
                  ],
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _applyBookCharsetSetting({
    required Book book,
    required String charset,
  }) async {
    final normalized =
        ReaderCharsetService.normalizeCharset(charset) ?? charset.trim();
    await _readerCharsetService.setBookCharset(widget.bookId, normalized);

    if (!_isCurrentBookLocalTxt()) {
      _showToast('编码已保存：$normalized');
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingChapter = true);
    try {
      await _reparseLocalTxtBookWithCharset(
        book: book,
        charset: normalized,
      );
      if (!mounted) return;
      _showToast('编码已切换：$normalized');
    } catch (e) {
      if (!mounted) return;
      _showToast('编码已保存：$normalized（重载失败：$e）');
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
  }

  Future<void> _reparseLocalTxtBookWithCharset({
    required Book book,
    required String charset,
  }) async {
    final localPath = (book.localPath ?? book.bookUrl ?? '').trim();
    if (localPath.isEmpty) {
      throw StateError('缺少本地 TXT 文件路径');
    }

    final previousRawTitle = _chapters.isEmpty
        ? _currentTitle
        : _chapters[_currentChapterIndex.clamp(0, _chapters.length - 1)].title;

    final parsed = await TxtParser.reparseFromFile(
      filePath: localPath,
      bookId: widget.bookId,
      bookName: book.title,
      forcedCharset: charset,
    );
    final newChapters = parsed.chapters;
    if (newChapters.isEmpty) {
      throw StateError('重解析后章节为空');
    }

    final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: newChapters,
      currentChapterTitle: previousRawTitle,
      currentChapterIndex: _currentChapterIndex,
      oldChapterCount: _chapters.length,
    );

    if (!widget.isEphemeral) {
      await _chapterRepo.clearChaptersForBook(widget.bookId);
      await _chapterRepo.addChapters(newChapters);
      await _bookRepo.updateBook(
        book.copyWith(
          totalChapters: newChapters.length,
          latestChapter: newChapters.last.title,
          currentChapter: targetIndex,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _replaceStageCache.clear();
      _catalogDisplayTitleCacheByChapterId.clear();
      _chapterContentInFlight.clear();
      _chapters = newChapters;
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
    });
    await _loadChapter(targetIndex, restoreOffset: true);
  }

  String _reverseContentLikeLegado(String content) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    return lines.reversed.join('\n');
  }

  Future<String> _resolveCurrentChapterRawContentForMenu({
    required Chapter chapter,
    required int chapterIndex,
  }) async {
    var rawContent = chapter.content ?? '';
    if (rawContent.trim().isNotEmpty) {
      return rawContent;
    }

    final book = _bookRepo.getBookById(widget.bookId);
    final chapterUrl = (chapter.url ?? '').trim();
    final canFetchFromSource = chapterUrl.isNotEmpty &&
        (book == null || !book.isLocal) &&
        _resolveActiveSourceUrl(book).isNotEmpty;
    if (canFetchFromSource) {
      rawContent = await _fetchChapterContent(
        chapter: chapter,
        index: chapterIndex,
        book: book,
        showLoading: true,
      );
    }
    if (rawContent.trim().isNotEmpty) {
      return rawContent;
    }
    return _currentContent;
  }

  Future<void> _reverseCurrentChapterContentFromMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      _showToast('当前章节不存在');
      return;
    }
    final chapterIndex = _currentChapterIndex;
    final chapter = _chapters[chapterIndex];
    final rawContent = await _resolveCurrentChapterRawContentForMenu(
      chapter: chapter,
      chapterIndex: chapterIndex,
    );
    if (rawContent.trim().isEmpty) {
      _showToast('当前章节暂无可倒序的正文');
      return;
    }
    final reversed = _reverseContentLikeLegado(rawContent);

    if (!widget.isEphemeral) {
      await _chapterRepo.cacheChapterContent(chapter.id, reversed);
    }

    if (!mounted) return;
    setState(() {
      _replaceStageCache.remove(chapter.id);
      _catalogDisplayTitleCacheByChapterId.remove(chapter.id);
      _chapterContentInFlight.remove(chapter.id);
      _chapters[chapterIndex] = chapter.copyWith(
        content: reversed,
        isDownloaded: true,
      );
    });
    await _loadChapter(chapterIndex, restoreOffset: true);
  }

  Future<void> _openSimulatedReadingFromMenu() async {
    _closeReaderMenuOverlay();
    if (_readAloudSnapshot.isRunning) {
      await _readAloudService.stop();
      if (!mounted) return;
    }
    if (!_autoPager.isRunning) {
      _autoPager.start();
    }
    if (!mounted) return;
    setState(() {
      _showAutoReadPanel = true;
    });
    _showToast('自动阅读已开启');
    _screenOffTimerStart(force: true);
  }

  Future<void> _toggleSameTitleRemovedFromMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      _showToast('当前章节不存在');
      return;
    }
    final chapter = _chapters[_currentChapterIndex];
    final current = _isChapterSameTitleRemoved(chapter.id);
    final next = !current;
    if (next) {
      final deduped = _removeDuplicateTitle(_currentContent, _currentTitle);
      if (deduped == _currentContent) {
        _showToast('未找到可移除的重复标题');
      }
    }
    _chapterSameTitleRemovedById[chapter.id] = next;
    if (!widget.isEphemeral) {
      await _settingsService.saveChapterSameTitleRemoved(
        widget.bookId,
        chapter.id,
        next,
      );
    }
    await _loadChapter(_currentChapterIndex, restoreOffset: true);
  }

  Future<void> _toggleEpubTagCleanupFromMenu({
    required bool ruby,
  }) async {
    if (!_isCurrentBookEpub()) {
      _showToast('当前书籍不是 EPUB');
      return;
    }
    final next = ruby ? !_delRubyTag : !_delHTag;
    if (!widget.isEphemeral) {
      if (ruby) {
        await _settingsService.saveBookDelRubyTag(widget.bookId, next);
      } else {
        await _settingsService.saveBookDelHTag(widget.bookId, next);
      }
    }
    if (!mounted) return;
    setState(() {
      if (ruby) {
        _delRubyTag = next;
      } else {
        _delHTag = next;
      }
    });
    await _clearBookCache();
    await _loadChapter(_currentChapterIndex, restoreOffset: true);
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

  Future<void> _showChangeSourceEntryActions() async {
    final selected =
        await showCupertinoModalPopup<ReaderLegacyChangeSourceMenuAction>(
      context: context,
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

  Future<void> _showRefreshEntryActions() async {
    final selected =
        await showCupertinoModalPopup<ReaderLegacyRefreshMenuAction>(
      context: context,
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
    switch (action) {
      case ReaderLegacyRefreshMenuAction.current:
        await _refreshChapterContentFromSource(
          startIndex: _currentChapterIndex,
          clearFollowing: false,
        );
        return;
      case ReaderLegacyRefreshMenuAction.after:
        await _refreshChapterContentFromSource(
          startIndex: _currentChapterIndex,
          clearFollowing: true,
        );
        return;
      case ReaderLegacyRefreshMenuAction.all:
        await _refreshChapterContentFromSource(
          startIndex: 0,
          clearFollowing: true,
        );
        return;
    }
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
    if (_chapters.isEmpty) return;
    final safeStart = startIndex.clamp(0, _chapters.length - 1).toInt();
    final safeEnd = clearFollowing ? _chapters.length - 1 : safeStart;
    final updates = <Chapter>[];
    final nextChapters = List<Chapter>.from(_chapters, growable: false);
    for (var index = safeStart; index <= safeEnd; index += 1) {
      final original = nextChapters[index];
      final cleared = original.copyWith(
        content: null,
        isDownloaded: false,
      );
      nextChapters[index] = cleared;
      if (original.isDownloaded || (original.content?.isNotEmpty ?? false)) {
        updates.add(cleared);
      }
    }

    if (!widget.isEphemeral && updates.isNotEmpty) {
      await _chapterRepo.addChapters(updates);
    }

    if (!mounted) return;
    setState(() {
      for (var index = safeStart; index <= safeEnd; index += 1) {
        final oldId = _chapters[index].id;
        _replaceStageCache.remove(oldId);
        _catalogDisplayTitleCacheByChapterId.remove(oldId);
        _chapterContentInFlight.remove(oldId);
      }
      _chapters = nextChapters;
    });

    await _loadChapter(
      _currentChapterIndex.clamp(0, _chapters.length - 1).toInt(),
      restoreOffset: true,
    );
  }

  Future<void> _executeLegacyReadMenuAction(
    ReaderLegacyReadMenuAction action,
  ) async {
    switch (action) {
      case ReaderLegacyReadMenuAction.changeSource:
        await _showChangeSourceEntryActions();
        return;
      case ReaderLegacyReadMenuAction.refresh:
        await _showRefreshEntryActions();
        return;
      case ReaderLegacyReadMenuAction.download:
        _showReaderActionUnavailable('离线缓存');
        return;
      case ReaderLegacyReadMenuAction.tocRule:
        _showReaderActionUnavailable('TXT 目录规则');
        return;
      case ReaderLegacyReadMenuAction.setCharset:
        await _showCharsetConfigFromMenu();
        return;
      case ReaderLegacyReadMenuAction.addBookmark:
        await _toggleBookmark();
        return;
      case ReaderLegacyReadMenuAction.editContent:
        await _openContentEditFromMenu();
        return;
      case ReaderLegacyReadMenuAction.pageAnim:
        _openInterfaceSettingsFromMenu();
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

  Future<List<ReaderSourceSwitchCandidate>> _loadSourceSwitchCandidates({
    required Book currentBook,
  }) async {
    final keyword = currentBook.title.trim();
    final authorKeyword = currentBook.author.trim();
    if (keyword.isEmpty) {
      return const <ReaderSourceSwitchCandidate>[];
    }

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

    return ReaderSourceSwitchHelper.buildCandidates(
      currentBook: currentBook,
      enabledSources: sortedEnabledSources,
      searchResults: searchResults,
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

    final candidates =
        await _loadSourceSwitchCandidates(currentBook: currentBook);
    if (!mounted) return;
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

    final candidates =
        await _loadSourceSwitchCandidates(currentBook: currentBook);
    if (!mounted) return;
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

      final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
        newChapters: parsedChapters,
        currentChapterTitle: currentRawTitle,
        currentChapterIndex: currentChapterIndex,
        oldChapterCount: _chapters.length,
      );
      final targetChapter = parsedChapters[targetIndex];
      final nextChapterUrl = targetIndex + 1 < parsedChapters.length
          ? parsedChapters[targetIndex + 1].url
          : null;
      final content = await _ruleEngine.getContent(
        source,
        targetChapter.url ?? '',
        nextChapterUrl: nextChapterUrl,
      );
      if (content.trim().isEmpty) {
        _showToast('章节换源失败：正文为空');
        return;
      }

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
      if (!mounted) return;
      _showToast('已完成章节换源：${source.bookSourceName}');
    } catch (e) {
      if (!mounted) return;
      _showToast('章节换源失败：$e');
    }
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

  void _showReadStyleDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: const Color(0x00000000),
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
              maxHeight: MediaQuery.of(context).size.height * 0.74,
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
                            labelWidget: _buildChineseConverterActionChipLabel(
                              _settings.chineseConverterType,
                            ),
                            onTap: () {
                              final currentType = ChineseConverterType.values
                                      .contains(_settings.chineseConverterType)
                                  ? _settings.chineseConverterType
                                  : ChineseConverterType.off;
                              _showTipOptionPicker(
                                title: '简繁转换',
                                options: _chineseConverterOptions,
                                currentValue: currentType,
                                onSelected: (value) {
                                  _updateSettingsFromSheet(
                                    setPopupState,
                                    _settings.copyWith(
                                      chineseConverterType: value,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const Spacer(),
                          _buildReadStyleActionChip(
                            label: '边距',
                            onTap: () {
                              Navigator.of(popupContext).pop();
                              Future<void>.microtask(() {
                                showReaderPaddingConfigDialog(
                                  this.context,
                                  settings: _settings,
                                  onSettingsChanged: _updateSettings,
                                  isDarkMode: _isUiDark,
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
                        paragraphSpacingProgress,
                      ),
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
                              color: _uiTextSubtle,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showReaderActionUnavailable(
                              '共享布局',
                              reason: '样式切换联动排版参数尚未迁移完成',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _uiCardBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _uiBorder),
                              ),
                              child: Text(
                                '待迁移',
                                style: TextStyle(
                                  color: _uiTextSubtle,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
    return showReaderColorPickerDialog(
      context: context,
      title: title,
      initialColor: initialColor,
      invalidHexMessage: '请输入 6 位十六进制颜色（如 FF6600）',
    );
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
    String? label,
    Widget? labelWidget,
    required VoidCallback onTap,
  }) {
    assert(label != null || labelWidget != null);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: _uiCardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _uiBorder),
        ),
        child: labelWidget ??
            Text(
              label ?? '',
              style: TextStyle(
                color: _uiTextNormal,
                fontSize: 14,
              ),
            ),
      ),
    );
  }

  Widget _buildChineseConverterActionChipLabel(int converterType) {
    final safeType = ChineseConverterType.values.contains(converterType)
        ? converterType
        : ChineseConverterType.off;
    final baseStyle = TextStyle(
      color: _uiTextNormal,
      fontSize: 14,
    );
    final enabledStyle = baseStyle.copyWith(
      color: _uiAccent,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: '简',
            style: safeType == ChineseConverterType.traditionalToSimplified
                ? enabledStyle
                : baseStyle,
          ),
          const TextSpan(text: '/'),
          TextSpan(
            text: '繁',
            style: safeType == ChineseConverterType.simplifiedToTraditional
                ? enabledStyle
                : baseStyle,
          ),
        ],
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
      barrierColor: const Color(0x00000000),
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
      barrierColor: const Color(0x00000000),
      builder: (popupContext) => StatefulBuilder(
        builder: (context, setPopupState) {
          final bottomInset = MediaQuery.of(context).padding.bottom;
          return Container(
            height: MediaQuery.of(context).size.height * 0.74 + bottomInset,
            decoration: BoxDecoration(
              color: _uiPanelBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: SafeArea(
              top: false,
              child: _buildLegacyTipConfigList(setPopupState),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegacyTipConfigList(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('legacy_tip_config'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLegacyTipSectionTitle('正文标题'),
          _buildLegacyTitleModeSegment(setPopupState),
          _buildLegacyTipSliderRow(
            label: '标题字号',
            value: _settings.titleSize.toDouble(),
            min: 0,
            max: 10,
            onChanged: (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(titleSize: value.round()),
              );
            },
            displayFormat: (value) => value.toInt().toString(),
          ),
          _buildLegacyTipSliderRow(
            label: '顶部间距',
            value: _settings.titleTopSpacing,
            min: 0,
            max: 100,
            onChanged: (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(titleTopSpacing: value),
              );
            },
            displayFormat: (value) => value.toInt().toString(),
          ),
          _buildLegacyTipSliderRow(
            label: '底部间距',
            value: _settings.titleBottomSpacing,
            min: 0,
            max: 100,
            onChanged: (value) {
              _updateSettingsFromSheet(
                setPopupState,
                _settings.copyWith(titleBottomSpacing: value),
              );
            },
            displayFormat: (value) => value.toInt().toString(),
          ),
          const SizedBox(height: 8),
          _buildLegacyTipSectionTitle('页眉'),
          _buildLegacyTipOptionRow(
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
          _buildLegacyTipOptionRow(
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
          _buildLegacyTipOptionRow(
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
          _buildLegacyTipOptionRow(
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
          const SizedBox(height: 8),
          _buildLegacyTipSectionTitle('页脚'),
          _buildLegacyTipOptionRow(
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
          _buildLegacyTipOptionRow(
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
          _buildLegacyTipOptionRow(
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
          _buildLegacyTipOptionRow(
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
          const SizedBox(height: 8),
          _buildLegacyTipSectionTitle('页眉页脚'),
          _buildLegacyTipOptionRow(
            '文字颜色',
            _tipColorLabel(_settings.tipColor),
            () {
              _showTipOptionPicker(
                title: '页眉页脚文字颜色',
                options: _tipColorOptions,
                currentValue:
                    _settings.tipColor == ReadingSettings.tipColorFollowContent
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
          _buildLegacyTipOptionRow(
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLegacyTipSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Text(
        title,
        style: TextStyle(
          color: _uiAccent,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLegacyTitleModeSegment(StateSetter setPopupState) {
    final safeGroupValue = _settings.titleMode.clamp(0, 2).toInt();
    final selectedTitleTextColor = _uiAccent.computeLuminance() > 0.55
        ? AppDesignTokens.textStrong
        : CupertinoColors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _uiBorder.withValues(alpha: 0.55)),
        ),
      ),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: safeGroupValue,
        backgroundColor: _uiCardBg,
        thumbColor: _uiAccent,
        children: {
          for (final option in _titleModeOptions)
            option.value: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                option.label,
                style: TextStyle(
                  color: safeGroupValue == option.value
                      ? selectedTitleTextColor
                      : _uiTextNormal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          _updateSettingsFromSheet(
            setPopupState,
            _settings.copyWith(titleMode: value),
          );
        },
      ),
    );
  }

  Widget _buildLegacyTipOptionRow(
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _uiBorder.withValues(alpha: 0.55)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _uiTextStrong,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: _uiTextNormal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyTipSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String Function(double) displayFormat,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _uiBorder.withValues(alpha: 0.55)),
        ),
      ),
      child: _buildSliderSetting(
        label,
        value,
        min,
        max,
        onChanged,
        displayFormat: displayFormat,
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
                        Text('字体: $_currentFontName',
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
                    showReaderPaddingConfigDialog(
                      context,
                      settings: _settings,
                      onSettingsChanged: (newSettings) =>
                          _updateSettingsFromSheet(
                        setPopupState,
                        newSettings,
                      ),
                      isDarkMode: _isUiDark,
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
                  120,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(autoReadSpeed: val.toInt()),
                    );
                  },
                  displayFormat: (v) => '${v.toInt()}s',
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

  Future<void> _showTipColorInputDialog(
    StateSetter setPopupState, {
    required bool forDivider,
  }) async {
    final currentValue =
        forDivider ? _settings.tipDividerColor : _settings.tipColor;
    final parsed = await showReaderColorPickerDialog(
      context: context,
      title: forDivider ? '分割线颜色' : '文字颜色',
      initialColor: currentValue > 0 ? currentValue : 0xFFADADAD,
      invalidHexMessage: '请输入 6 位十六进制颜色（如 FF6600）',
    );
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
      height: 360,
      decoration: BoxDecoration(
        color: _uiPanelBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选择字体',
                    style: TextStyle(
                      color: _uiTextStrong,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 30,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: _uiTextSubtle,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
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
                              fontFamily: font.fontFamily.isEmpty
                                  ? null
                                  : font.fontFamily,
                              fontFamilyFallback: font.fontFamilyFallback,
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

  Future<void> _applyCatalogSplitLongChapterSetting(bool enabled) async {
    final bookId = widget.bookId.trim();
    if (bookId.isNotEmpty && !widget.isEphemeral) {
      await _settingsService.saveBookSplitLongChapter(bookId, enabled);
    }

    if (!_isCurrentBookLocalTxt()) {
      return;
    }

    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null) {
      throw StateError('书籍信息不存在');
    }

    if (!mounted) return;
    setState(() => _isLoadingChapter = true);
    try {
      final charset = _readerCharsetService.getBookCharset(widget.bookId) ??
          ReaderCharsetService.defaultCharset;
      await _reparseLocalTxtBookWithCharset(
        book: book,
        charset: charset,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
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
        onApplySplitLongChapter: _applyCatalogSplitLongChapterSetting,
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

class _ReaderContentEditPayload {
  final String title;
  final String content;

  const _ReaderContentEditPayload({
    required this.title,
    required this.content,
  });
}

class _ReaderContentEditorPage extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final Future<String> Function()? onResetContent;

  const _ReaderContentEditorPage({
    required this.initialTitle,
    required this.initialContent,
    this.onResetContent,
  });

  @override
  State<_ReaderContentEditorPage> createState() =>
      _ReaderContentEditorPageState();
}

class _ReaderContentEditorPageState extends State<_ReaderContentEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _returned = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _popWithPayload() {
    if (_returned || _resetting) return;
    _returned = true;
    Navigator.of(context).pop(
      _ReaderContentEditPayload(
        title: _titleController.text,
        content: _contentController.text,
      ),
    );
  }

  Future<void> _copyAll() async {
    final payload = '${_titleController.text}\n${_contentController.text}';
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('复制全文'),
        content: const Text('\n已复制到剪贴板'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _moveContentCursorToEnd() {
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );
  }

  Future<void> _resetContent() async {
    if (_resetting) return;
    final handler = widget.onResetContent;
    if (handler == null) {
      _contentController.text = widget.initialContent;
      _moveContentCursorToEnd();
      return;
    }
    setState(() {
      _resetting = true;
    });
    try {
      final content = await handler();
      if (!mounted) return;
      _contentController.text = content;
      _moveContentCursorToEnd();
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('重置失败'),
          content: Text('\n$e'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _resetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _resetting) return;
        _popWithPayload();
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('编辑正文'),
          automaticallyImplyLeading: false,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _resetting ? null : _popWithPayload,
            child: const Text('关闭'),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _resetting ? null : _popWithPayload,
            child: const Text('保存'),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: _titleController,
                  placeholder: '章节标题',
                  enabled: !_resetting,
                  clearButtonMode: OverlayVisibilityMode.editing,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      onPressed: _resetting ? null : _resetContent,
                      child: const Text('重置'),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      onPressed: _resetting ? null : _copyAll,
                      child: const Text('复制全文'),
                    ),
                    if (_resetting) ...[
                      const SizedBox(width: 8),
                      const CupertinoActivityIndicator(),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(
                        context,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CupertinoColors.systemGrey4.resolveFrom(context),
                        width: 0.8,
                      ),
                    ),
                    child: CupertinoTextField(
                      controller: _contentController,
                      enabled: !_resetting,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      clearButtonMode: OverlayVisibilityMode.never,
                      padding: const EdgeInsets.all(12),
                      decoration: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

enum _ReaderImageWarmupFailureKind {
  timeout,
  auth,
  decode,
  other,
}

class _ReaderImageSizeProbeResult {
  final Size? size;
  final _ReaderImageWarmupFailureKind? failureKind;
  final bool attempted;

  const _ReaderImageSizeProbeResult._({
    required this.size,
    required this.failureKind,
    required this.attempted,
  });

  const _ReaderImageSizeProbeResult.success(Size value)
      : this._(
          size: value,
          failureKind: null,
          attempted: true,
        );

  const _ReaderImageSizeProbeResult.failure(_ReaderImageWarmupFailureKind kind)
      : this._(
          size: null,
          failureKind: kind,
          attempted: true,
        );

  const _ReaderImageSizeProbeResult.skipped()
      : this._(
          size: null,
          failureKind: null,
          attempted: false,
        );
}

class _ReaderImageBytesProbeResult {
  final Uint8List? bytes;
  final _ReaderImageWarmupFailureKind? failureKind;

  const _ReaderImageBytesProbeResult._({
    required this.bytes,
    required this.failureKind,
  });

  const _ReaderImageBytesProbeResult.success(Uint8List value)
      : this._(
          bytes: value,
          failureKind: null,
        );

  const _ReaderImageBytesProbeResult.failure(_ReaderImageWarmupFailureKind kind)
      : this._(
          bytes: null,
          failureKind: kind,
        );
}

class _ReaderImageWarmupSourceTelemetry {
  int sampleCount = 0;
  int timeoutStreak = 0;
  int authStreak = 0;
  int decodeStreak = 0;
  double successRateEma = 0.0;
  double timeoutRateEma = 0.0;
  double authRateEma = 0.0;
  double decodeRateEma = 0.0;
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  void recordSuccess() {
    _apply(success: true, failureKind: null);
  }

  void recordFailure(_ReaderImageWarmupFailureKind kind) {
    _apply(success: false, failureKind: kind);
  }

  void _apply({
    required bool success,
    required _ReaderImageWarmupFailureKind? failureKind,
  }) {
    final alpha = sampleCount < 8 ? 0.34 : 0.18;
    successRateEma = _ema(successRateEma, success ? 1.0 : 0.0, alpha);
    timeoutRateEma = _ema(
      timeoutRateEma,
      failureKind == _ReaderImageWarmupFailureKind.timeout ? 1.0 : 0.0,
      alpha,
    );
    authRateEma = _ema(
      authRateEma,
      failureKind == _ReaderImageWarmupFailureKind.auth ? 1.0 : 0.0,
      alpha,
    );
    decodeRateEma = _ema(
      decodeRateEma,
      failureKind == _ReaderImageWarmupFailureKind.decode ? 1.0 : 0.0,
      alpha,
    );

    if (success) {
      timeoutStreak = 0;
      authStreak = 0;
      decodeStreak = 0;
    } else {
      switch (failureKind) {
        case _ReaderImageWarmupFailureKind.timeout:
          timeoutStreak = (timeoutStreak + 1).clamp(0, 24).toInt();
          authStreak = 0;
          decodeStreak = 0;
          break;
        case _ReaderImageWarmupFailureKind.auth:
          authStreak = (authStreak + 1).clamp(0, 24).toInt();
          timeoutStreak = 0;
          decodeStreak = 0;
          break;
        case _ReaderImageWarmupFailureKind.decode:
          decodeStreak = (decodeStreak + 1).clamp(0, 24).toInt();
          timeoutStreak = 0;
          authStreak = 0;
          break;
        case _ReaderImageWarmupFailureKind.other:
          timeoutStreak = 0;
          authStreak = 0;
          decodeStreak = 0;
          break;
        case null:
          timeoutStreak = 0;
          authStreak = 0;
          decodeStreak = 0;
          break;
      }
    }

    sampleCount = (sampleCount + 1).clamp(0, 4096).toInt();
    updatedAt = DateTime.now();
  }

  double _ema(double current, double value, double alpha) {
    if (sampleCount <= 0) {
      return value;
    }
    return current * (1 - alpha) + value * alpha;
  }
}

class _ReaderImageWarmupBudget {
  final int probeCount;
  final Duration maxDuration;
  final Duration perProbeTimeout;

  const _ReaderImageWarmupBudget({
    required this.probeCount,
    required this.maxDuration,
    required this.perProbeTimeout,
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

class _ResolvedChapterSnapshot {
  final String chapterId;
  final int postProcessSignature;
  final int baseTitleHash;
  final int baseContentHash;
  final String title;
  final String content;
  final bool isDeferredPlaceholder;

  const _ResolvedChapterSnapshot({
    required this.chapterId,
    required this.postProcessSignature,
    required this.baseTitleHash,
    required this.baseContentHash,
    required this.title,
    required this.content,
    this.isDeferredPlaceholder = false,
  });
}

class _ChapterImageMetaSnapshot {
  final String chapterId;
  final int postProcessSignature;
  final int contentHash;
  final List<ReaderImageMarkerMeta> metas;

  const _ChapterImageMetaSnapshot({
    required this.chapterId,
    required this.postProcessSignature,
    required this.contentHash,
    required this.metas,
  });
}

class _ReaderSearchHit {
  final int start;
  final int end;
  final String query;
  final int occurrenceIndex;
  final String previewBefore;
  final String previewMatch;
  final String previewAfter;
  final int? pageIndex;

  const _ReaderSearchHit({
    required this.start,
    required this.end,
    required this.query,
    required this.occurrenceIndex,
    required this.previewBefore,
    required this.previewMatch,
    required this.previewAfter,
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

class _ReaderRenderBlock {
  final String? text;
  final String? imageSrc;

  const _ReaderRenderBlock._({
    this.text,
    this.imageSrc,
  });

  const _ReaderRenderBlock.text(String value)
      : this._(
          text: value,
        );

  const _ReaderRenderBlock.image(String value)
      : this._(
          imageSrc: value,
        );

  bool get isImage => imageSrc != null;
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
