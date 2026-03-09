import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, listEquals;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/migration_exclusions.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/js_runtime.dart';
import '../../../core/services/keep_screen_on_service.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/services/webdav_service.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/utils/chinese_script_converter.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../bookshelf/models/book.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../import/txt_parser.dart';
import '../../replace/models/replace_rule.dart';
import '../../replace/views/replace_rule_list_view.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../replace/views/replace_rule_edit_view.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_cover_loader.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../source/services/source_login_ui_helper.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_edit_view.dart';
import '../../source/views/source_list_view.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_login_webview_view.dart';
import '../../source/views/source_web_verify_view.dart';
import '../../search/services/search_book_info_refresh_helper.dart';
import '../../search/models/search_scope.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../../search/views/search_book_info_view.dart';
import '../../settings/views/app_help_dialog.dart';
import '../../settings/views/app_log_dialog.dart';
import '../../settings/views/exception_logs_view.dart';
import '../../settings/views/reading_behavior_settings_hub_view.dart';
import '../models/reading_settings.dart';
import '../services/chapter_title_display_helper.dart';
import '../services/reader_bookmark_export_service.dart';
import '../services/reader_charset_service.dart';
import '../services/reader_key_paging_helper.dart';
import '../services/reader_legacy_quick_action_helper.dart';
import '../services/reader_image_request_parser.dart';
import '../services/reader_image_resolver.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_legacy_menu_helper.dart';
import '../services/reader_refresh_scope_helper.dart';
import '../services/reader_search_navigation_helper.dart';
import '../services/reader_source_action_helper.dart';
import '../services/reader_source_switch_helper.dart';
import '../services/reader_system_ui_helper.dart';
import '../services/reader_theme_mode_helper.dart';
import '../services/reader_top_bar_action_helper.dart';
import '../services/http_tts_engine.dart';
import '../services/http_tts_rule_store.dart';
import '../services/read_aloud_service.dart';
import '../services/txt_toc_rule_store.dart';
import '../utils/chapter_progress_utils.dart';
import '../widgets/auto_pager.dart';
import '../widgets/paged_reader_widget.dart';
import '../widgets/page_factory.dart';
import '../widgets/reader_menus.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_status_bar.dart';
import '../widgets/legacy_justified_text.dart';
import '../widgets/reader_catalog_sheet.dart';
import '../widgets/scroll_page_step_calculator.dart';
import '../widgets/scroll_segment_paint_view.dart';
import '../widgets/scroll_text_layout_engine.dart';
import '../widgets/scroll_runtime_helper.dart';
import '../widgets/reader_txt_toc_rule_dialog.dart';
import '../widgets/reader_read_aloud_bar.dart';
import '../widgets/reader_more_config_sheet.dart';
import '../widgets/reader_style_quick_sheet.dart';
import '../widgets/source_switch_candidate_sheet.dart';
import 'reader_content_editor.dart';
import 'reader_dict_lookup_sheet.dart';

/// 简洁阅读器 - Cupertino 风格 (增强版)
part 'simple_reader_view_build.dart';
part 'simple_reader_view_actions.dart';
part 'simple_reader_view_source_switch.dart';
part 'simple_reader_view_bookmark.dart';
part 'simple_reader_view_data.dart';

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

class _SimpleReaderViewState extends State<SimpleReaderView>
    with TickerProviderStateMixin {
  late final ChapterRepository _chapterRepo;
  late final BookRepository _bookRepo;
  late final SourceRepository _sourceRepo;
  late final ReplaceRuleRepository _replaceRuleRepo;
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
  final ReaderCharsetService _readerCharsetService = ReaderCharsetService();
  final TxtTocRuleStore _txtTocRuleStore = TxtTocRuleStore();

  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  String _currentContent = '';
  String _currentTitle = '';

  // 阅读设置
  late ReadingSettings _settings;

  // UI 状态
  bool _showMenu = false;
  bool _showSearchMenu = false;

  // 菜单动画
  late final AnimationController _menuAnimController;
  late final Animation<double> _menuFadeAnim;
  late final Animation<Offset> _topMenuSlideAnim;
  late final Animation<Offset> _bottomMenuSlideAnim;
  late final Animation<Offset> _railSlideAnim;

  // 搜索菜单动画
  late final AnimationController _searchMenuAnimController;
  late final Animation<double> _searchMenuFadeAnim;
  late final Animation<Offset> _searchMenuSlideAnim;
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
  final HttpTtsRuleStore _httpTtsRuleStore = HttpTtsRuleStore();
  bool _showAutoReadPanel = false;
  ReadAloudService? _readAloudServiceOrNull;
  ReadAloudService get _readAloudService =>
      _readAloudServiceOrNull ??= ReadAloudService(
        onStateChanged: _handleReadAloudStateChanged,
        onMessage: _handleReadAloudMessage,
        onRequestChapterSwitch: _handleReadAloudChapterSwitchRequest,
      );
  ReadAloudStatusSnapshot _readAloudSnapshot =
      const ReadAloudStatusSnapshot.stopped();
  int _readAloudSpeechRate = 10;
  FlutterTts? _contentSelectReadAloudTts;
  bool _contentSelectReadAloudTtsReady = false;
  bool _showingReadAloudExclusionDialog = false;

  /// 迁移排除：朗读（TTS）入口提示文案（与全局排除口径一致）。
  // ignore: unused_field
  static const String _readAloudExclusionHint =
      '迁移排除：朗读（TTS）功能暂不开放\n该入口仅保留锚点，不可操作';

  // 当前书籍信息
  String _bookAuthor = '';
  String? _bookCoverUrl;
  String? _currentSourceUrl;
  String? _currentSourceName;
  final Map<String, bool> _chapterVipByUrl = <String, bool>{};
  final Map<String, bool> _chapterPayByUrl = <String, bool>{};
  final Map<String, bool> _chapterSameTitleRemovedById = <String, bool>{};
  bool _tocUiUseReplace = false;
  bool _tocUiLoadWordCount = true;
  bool _changeSourceCheckAuthor = false;
  bool _changeSourceLoadInfo = false;
  bool _changeSourceLoadWordCount = false;
  bool _changeSourceLoadToc = false;
  String _changeSourceGroup = '';
  int _changeSourceDelaySeconds = 0;
  CancelToken? _sourceSwitchCandidateSearchCancelToken;
  bool _tocUiSplitLongChapter = false;
  bool _useReplaceRule = true;
  bool _reSegment = false;
  bool _delRubyTag = false;
  bool _delHTag = false;
  bool _audioPlayUseWakeLock = false;
  int _contentSelectSpeakMode = 0;
  bool _contentSelectMenuLongPressHandled = false;
  Timer? _contentSelectMenuLongPressResetTimer;
  String _imageStyle = _defaultLegacyImageStyle;
  int? _bookPageAnimOverride;

  // 翻页模式相关（对标 Legado PageFactory）
  final PageFactory _pageFactory = PageFactory();
  final PagedReaderController _pagedReaderController = PagedReaderController();

  final _replaceStageCache = <String, _ReplaceStageCache>{};
  final _catalogDisplayTitleCacheByChapterId = <String, String>{};
  final Map<String, _ResolvedChapterSnapshot>
      _resolvedChapterSnapshotByChapterId =
      <String, _ResolvedChapterSnapshot>{};
  final Map<String, _ChapterImageMetaSnapshot>
      _chapterImageMetaSnapshotByChapterId =
      <String, _ChapterImageMetaSnapshot>{};
  bool _hasDeferredChapterTransformRefresh = false;


  static const List<_TipOption> _chineseConverterOptions = [
    _TipOption(ChineseConverterType.off, '关闭'),
    _TipOption(ChineseConverterType.traditionalToSimplified, '繁转简'),
    _TipOption(ChineseConverterType.simplifiedToTraditional, '简转繁'),
  ];
  static const List<String> _legacyCharsetOptions =
      ReaderCharsetService.legacyCharsetOptions;
  static const String _defaultLegacyImageStyle = 'DEFAULT';
  static const String _legacyImageStyleFull = 'FULL';
  static const String _legacyImageStyleText = 'TEXT';
  static const String _legacyImageStyleSingle = 'SINGLE';
  static const int _legacyBookPageAnimDefault = -1;
  static const List<MapEntry<int, String>> _legacyBookPageAnimOptions =
      <MapEntry<int, String>>[
    MapEntry(_legacyBookPageAnimDefault, '默认'),
    MapEntry(0, '覆盖'),
    MapEntry(1, '滑动'),
    MapEntry(2, '仿真'),
    MapEntry(3, '滚动'),
    MapEntry(4, '无'),
  ];
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
  static final RegExp _readAloudSpeakablePattern =
      RegExp(r'[\u4E00-\u9FFFA-Za-z0-9]');
  static final RegExp _cssStyleAttrRegex = RegExp(
    r'''style\s*=\s*(?:"([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  );
  static const int _scrollUiSyncIntervalMs = 100;
  static const int _scrollSaveProgressIntervalMs = 450;
  static const int _readRecordPersistIntervalMs = 5000;
  static const int _readRecordPersistMinChunkMs = 1000;
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
  bool _offlineCacheRunning = false;
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
  bool _isSearchingContent = false;
  bool _contentSearchUseReplace = false;
  _ReaderSearchProgressSnapshot? _searchProgressSnapshot;
  int _contentSearchTaskToken = 0;
  final List<_ScrollSegment> _scrollSegments = <_ScrollSegment>[];
  final Map<int, GlobalKey> _scrollSegmentKeys = <int, GlobalKey>{};
  final Map<int, double> _scrollSegmentHeights = <int, double>{};
  final List<_ScrollSegmentOffsetRange> _scrollSegmentOffsetRanges =
      <_ScrollSegmentOffsetRange>[];
  final GlobalKey _scrollViewportKey =
      GlobalKey(debugLabel: 'reader_scroll_viewport');
  // Notifier：章节 tip 信息（供 Header/Footer 局部重建）
  final _scrollTipNotifier = ValueNotifier<_ScrollTipData>(const _ScrollTipData.empty());
  // Notifier：segment 列表版本号（供 scroll content 局部重建）
  final _scrollSegmentsVersion = ValueNotifier<int>(0);

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
  DateTime _lastReadRecordAccumulatedAt = DateTime.now();
  DateTime _lastReadRecordPersistAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _pendingReadRecordDurationMs = 0;
  bool _programmaticScrollInFlight = false;
  double _scrollAnchorWithinViewport = 32.0;
  String? _readStyleBackgroundDirectoryPath;
  String? _readerCustomFontFamily;
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
  final ReaderImageResolver _readerImageResolver =
      const ReaderImageResolver(isWeb: kIsWeb);
  Duration _recentChapterFetchDuration = Duration.zero;
  final Map<String, _ReaderImageWarmupSourceTelemetry>
      _imageWarmupTelemetryBySource =
      <String, _ReaderImageWarmupSourceTelemetry>{};

  @override
  void initState() {
    super.initState();
    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _menuFadeAnim = CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _topMenuSlideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _bottomMenuSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _railSlideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _searchMenuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _searchMenuFadeAnim = CurvedAnimation(
      parent: _searchMenuAnimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _searchMenuSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _searchMenuAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    final db = DatabaseService();
    _chapterRepo = ChapterRepository(db);
    _bookRepo = BookRepository(db);
    _sourceRepo = SourceRepository(db);
    _replaceRuleRepo = ReplaceRuleRepository(db);
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
    _tocUiUseReplace = _settingsService.getTocUiUseReplace();
    _tocUiLoadWordCount = _settingsService.getTocUiLoadWordCount();
    _changeSourceCheckAuthor = _settingsService.getChangeSourceCheckAuthor();
    _changeSourceLoadInfo = _settingsService.getChangeSourceLoadInfo();
    _changeSourceLoadWordCount =
        _settingsService.getChangeSourceLoadWordCount();
    _changeSourceLoadToc = _settingsService.getChangeSourceLoadToc();
    _changeSourceGroup = _settingsService.getChangeSourceGroup();
    _changeSourceDelaySeconds = _settingsService.getBatchChangeSourceDelay();
    _audioPlayUseWakeLock = _settingsService.getAudioPlayUseWakeLock();
    _contentSelectSpeakMode = _settingsService.getContentSelectSpeakMode();
    _webDavService = WebDavService();
    final baseReadingSettings =
        _readSettingsWithExclusions(_settingsService.readingSettings);
    _bookPageAnimOverride = _settingsService.getBookPageAnim(widget.bookId);
    _settings = _effectiveSettingsWithBookPageAnim(
      base: baseReadingSettings,
      bookPageAnimOverride: _bookPageAnimOverride,
    );
    _maybeNormalizeFollowSystemReaderThemes();
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
    _settingsService.appSettingsListenable
        .addListener(_handleAppSettingsChanged);
    _warmUpReadStyleBackgroundDirectoryPath();
    _autoPager.setSpeed(_settings.autoReadSpeed);
    _autoPager.setMode(_settings.pageTurnMode == PageTurnMode.scroll
        ? AutoPagerMode.scroll
        : AutoPagerMode.page);
    _lastReadRecordAccumulatedAt = DateTime.now();
    _lastReadRecordPersistAt = DateTime.fromMillisecondsSinceEpoch(0);
    _pendingReadRecordDurationMs = 0;
    unawaited(_initReadAloudService());

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
      _requestReaderKeyboardFocus();
    });

    // 初始化自动翻页器
    _autoPager.setScrollController(_scrollController);
    _scrollController.addListener(_handleScrollControllerTick);
    _autoPager.setOnNextPage(() {
      _handleAutoPagerNextTick();
    });

    _syncSystemUiForOverlay(force: true);
  }

  void _maybeNormalizeFollowSystemReaderThemes() {
    final appSettings = _settingsService.appSettings;
    if (appSettings.appearanceMode != AppAppearanceMode.followSystem) {
      return;
    }

    final styles = _activeReadStyleConfigs;
    if (styles.isEmpty) return;

    int clampIndex(int index) {
      return index.clamp(0, styles.length - 1).toInt();
    }

    bool isDarkIndex(int index) {
      final safeIndex = clampIndex(index);
      return Color(styles[safeIndex].backgroundColor).computeLuminance() < 0.5;
    }

    int? firstLightIndex;
    int? firstDarkIndex;
    for (var i = 0; i < styles.length; i++) {
      final isDark = Color(styles[i].backgroundColor).computeLuminance() < 0.5;
      if (!isDark && firstLightIndex == null) {
        firstLightIndex = i;
      }
      if (isDark && firstDarkIndex == null) {
        firstDarkIndex = i;
      }
      if (firstLightIndex != null && firstDarkIndex != null) break;
    }

    var nextThemeIndex = clampIndex(_settings.themeIndex);
    var nextNightThemeIndex = clampIndex(_settings.nightThemeIndex);

    final dayIsDark = isDarkIndex(nextThemeIndex);
    final nightIsDark = isDarkIndex(nextNightThemeIndex);
    if (dayIsDark && !nightIsDark) {
      final tmp = nextThemeIndex;
      nextThemeIndex = nextNightThemeIndex;
      nextNightThemeIndex = tmp;
    }

    if (firstLightIndex != null && isDarkIndex(nextThemeIndex)) {
      nextThemeIndex = firstLightIndex;
    }
    if (firstDarkIndex != null && !isDarkIndex(nextNightThemeIndex)) {
      nextNightThemeIndex = firstDarkIndex;
    }

    if (_settings.themeIndex == nextThemeIndex &&
        _settings.nightThemeIndex == nextNightThemeIndex) {
      return;
    }

    final next = _settings.copyWith(
      themeIndex: nextThemeIndex,
      nightThemeIndex: nextNightThemeIndex,
    );
    _settings = next;
    unawaited(_settingsService.saveReadingSettings(next));
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
      final readableChapterCount = _effectiveReadableChapterCount();
      if (readableChapterCount > 0) {
        _currentChapterIndex =
            _currentChapterIndex.clamp(0, readableChapterCount - 1).toInt();
      } else {
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

      if (readableChapterCount > 0) {
        await _loadChapter(_currentChapterIndex, restoreOffset: true);
      }
    }
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _menuAnimController.dispose();
    _searchMenuAnimController.dispose();
    _stopSourceSwitchCandidateSearch();
    _settingsService.readingSettingsListenable
        .removeListener(_handleReadingSettingsChanged);
    _settingsService.appSettingsListenable
        .removeListener(_handleAppSettingsChanged);
    _pageFactory.removeContentChangedListener(_handlePageFactoryContentChanged);
    unawaited(_saveProgress(forcePersistReadRecord: true));
    _scrollController.removeListener(_handleScrollControllerTick);
    _scrollController.dispose();
    _scrollTipNotifier.dispose();
    _scrollSegmentsVersion.dispose();
    _keyboardFocusNode.dispose();
    _autoPager.dispose();
    unawaited(_readAloudServiceOrNull?.dispose());
    unawaited(_disposeContentSelectReadAloudTts());
    _contentSelectMenuLongPressResetTimer?.cancel();
    _contentSelectMenuLongPressResetTimer = null;
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

  Future<void> _initReadAloudService() async {
    final selectedRuleId = await _httpTtsRuleStore.loadSelectedRuleId();
    final speechRate = await _httpTtsRuleStore.loadSpeechRate();
    if (!mounted) return;

    ReadAloudEngine engine;
    if (selectedRuleId != null) {
      final rules = await _httpTtsRuleStore.loadRules();
      final rule = rules.where((r) => r.id == selectedRuleId).firstOrNull;
      engine = rule != null
          ? HttpTtsReadAloudEngine(rule: rule, speechRate: speechRate)
          : FlutterReadAloudEngine();
    } else {
      engine = FlutterReadAloudEngine();
    }

    _readAloudServiceOrNull = ReadAloudService(
      engine: engine,
      onStateChanged: _handleReadAloudStateChanged,
      onMessage: _handleReadAloudMessage,
      onRequestChapterSwitch: _handleReadAloudChapterSwitchRequest,
    );
    setState(() => _readAloudSpeechRate = speechRate);
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
      if (!visible) {
        _requestReaderKeyboardFocus();
      }
      return;
    }
    if (visible) {
      setState(() {
        _showMenu = true;
        _showSearchMenu = false;
        _showAutoReadPanel = false;
      });
      _menuAnimController.forward();
    } else {
      _menuAnimController.reverse().then((_) {
        if (mounted) setState(() => _showMenu = false);
      });
    }
    _syncSystemUiForOverlay();
    if (!visible) {
      _requestReaderKeyboardFocus();
    }
  }

  void _setSearchMenuVisible(bool visible) {
    if (_showSearchMenu == visible) {
      _syncSystemUiForOverlay();
      if (!visible) {
        _requestReaderKeyboardFocus();
      }
      return;
    }
    if (visible) {
      setState(() {
        _showSearchMenu = true;
        _showMenu = false;
        _showAutoReadPanel = false;
      });
      _searchMenuAnimController.forward();
    } else {
      _searchMenuAnimController.reverse().then((_) {
        if (mounted) setState(() => _showSearchMenu = false);
      });
    }
    _syncSystemUiForOverlay();
    if (!visible) {
      _requestReaderKeyboardFocus();
    }
  }

  void _requestReaderKeyboardFocus() {
    if (!mounted || _keyboardFocusNode.hasFocus) return;
    FocusScope.of(context).requestFocus(_keyboardFocusNode);
  }

  void _toggleReaderMenuVisible() {
    _setReaderMenuVisible(!_showMenu);
  }

  double _safeBrightnessValue(double value, {double fallback = 1.0}) {
    final safeRaw = value.isFinite ? value : fallback;
    return safeRaw.clamp(0.0, 1.0).toDouble();
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
    final latest = _effectiveSettingsWithBookPageAnim(
      base: _readSettingsWithExclusions(_settingsService.readingSettings),
      bookPageAnimOverride: _bookPageAnimOverride,
    );
    if (_isSameReadingSettings(_settings, latest)) return;
    _updateSettings(latest, persist: false);
  }

  /// 监听全局设置变化（外观模式、系统文本处理开关等）。
  ///
  /// 说明：
  /// - 本页菜单项可见性依赖 `AppSettings.processText`；
  /// - 主题模式解析依赖全局外观设置，变更后需要触发重建。
  void _handleAppSettingsChanged() {
    if (!mounted) return;
    final appSettings = _settingsService.appSettings;
    final resolvedMode = ReaderThemeModeHelper.resolveMode(
      appearanceMode: appSettings.appearanceMode,
      effectiveBrightness: _effectiveBrightnessForReaderThemeMode(),
    );
    debugPrint(
      '[reader] appSettings changed: '
      'appearance=${appSettings.appearanceMode.name}, '
      'mode=${resolvedMode.name}, '
      'processText=${appSettings.processText}',
    );
    setState(() {});
  }

  bool _isSameReadingSettings(ReadingSettings a, ReadingSettings b) {
    return json.encode(a.toJson()) == json.encode(b.toJson());
  }

  DateTime _normalizeDateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDateOnly(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  bool _isSimulatedReadingEnabled() {
    return _settingsService.getBookReadSimulating(
      widget.bookId,
      fallback: false,
    );
  }

  DateTime _simulatedStartDateOrToday() {
    return _normalizeDateOnly(
      _settingsService.getBookSimulatedStartDate(widget.bookId) ??
          DateTime.now(),
    );
  }

  int _simulatedStartChapterForDialogDefault() {
    final fallback = _isSimulatedReadingEnabled() ? 0 : _currentChapterIndex;
    return _settingsService.getBookSimulatedStartChapter(
      widget.bookId,
      fallback: fallback,
    );
  }

  int _simulatedDailyChaptersForDialogDefault() {
    return _settingsService.getBookSimulatedDailyChapters(
      widget.bookId,
      fallback: 3,
    );
  }

  int _legacyPeriodDays(DateTime start, DateTime end) {
    final startDate = _normalizeDateOnly(start);
    final endDate = _normalizeDateOnly(end);
    return endDate.difference(startDate).inDays;
  }

  int _effectiveReadableChapterCount() {
    final totalChapters = _chapters.length;
    if (totalChapters <= 0) return 0;
    if (!_isSimulatedReadingEnabled()) return totalChapters;

    final startChapter = _simulatedStartChapterForDialogDefault();
    final dailyChapters = _simulatedDailyChaptersForDialogDefault();
    final startDate = _simulatedStartDateOrToday();
    final today = _normalizeDateOnly(DateTime.now());
    final daysPassed = _legacyPeriodDays(startDate, today) + 1;
    final chaptersToUnlock = startChapter + daysPassed * dailyChapters;
    final normalized = chaptersToUnlock < 0 ? 0 : chaptersToUnlock;
    if (normalized > totalChapters) return totalChapters;
    return normalized;
  }

  int _effectiveReadableMaxChapterIndex() {
    return _effectiveReadableChapterCount() - 1;
  }

  int _clampChapterIndexToReadableRange(
    int index, {
    int fallback = 0,
  }) {
    final maxReadableIndex = _effectiveReadableMaxChapterIndex();
    if (maxReadableIndex < 0) return fallback;
    return index.clamp(0, maxReadableIndex).toInt();
  }

  List<Chapter> _effectiveReadableChapters() {
    final count = _effectiveReadableChapterCount();
    if (count <= 0) return const <Chapter>[];
    if (count >= _chapters.length) return _chapters;
    return _chapters.sublist(0, count);
  }

  Future<void> _collectReadRecordDuration({
    required bool enableReadRecord,
    bool forcePersist = false,
  }) async {
    final now = DateTime.now();
    final elapsedMs =
        now.difference(_lastReadRecordAccumulatedAt).inMilliseconds;
    _lastReadRecordAccumulatedAt = now;
    if (enableReadRecord && elapsedMs > 0) {
      _pendingReadRecordDurationMs += elapsedMs;
    }

    if (_pendingReadRecordDurationMs <= 0) {
      return;
    }

    final reachedPersistInterval =
        now.difference(_lastReadRecordPersistAt).inMilliseconds >=
            _readRecordPersistIntervalMs;
    final reachedMinChunk =
        _pendingReadRecordDurationMs >= _readRecordPersistMinChunkMs;
    if (!forcePersist && !(reachedPersistInterval && reachedMinChunk)) {
      return;
    }

    final durationToPersist = _pendingReadRecordDurationMs;
    _pendingReadRecordDurationMs = 0;
    _lastReadRecordPersistAt = now;
    await _settingsService.addBookReadRecordDurationMs(
      widget.bookId,
      durationToPersist,
    );
  }

  /// 保存进度：章节 + 滚动偏移
  Future<void> _saveProgress({bool forcePersistReadRecord = false}) async {
    final enableReadRecord = _settingsService.enableReadRecord;
    await _collectReadRecordDuration(
      enableReadRecord: enableReadRecord,
      forcePersist: forcePersistReadRecord,
    );

    final totalReadableChapters = _effectiveReadableChapterCount();
    if (totalReadableChapters <= 0) return;

    final readableMaxIndex = totalReadableChapters - 1;
    final safeChapterIndex =
        _currentChapterIndex.clamp(0, readableMaxIndex).toInt();
    final progress = (safeChapterIndex + 1) / totalReadableChapters;
    final chapterProgress = _getChapterProgress();

    // 保存到书籍库
    await _bookRepo.updateReadProgress(
      widget.bookId,
      currentChapter: safeChapterIndex,
      readProgress: progress,
      updateLastReadTime: enableReadRecord,
    );

    // 保存滚动偏移量
    if (_scrollController.hasClients) {
      await _settingsService.saveScrollOffset(
        widget.bookId,
        _scrollController.offset,
        chapterIndex: safeChapterIndex,
      );
    }

    await _settingsService.saveChapterPageProgress(
      widget.bookId,
      chapterIndex: safeChapterIndex,
      progress: chapterProgress,
    );
  }

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

    _scrollSegments
      ..clear()
      ..addAll(segments);
    _currentChapterIndex = centerSegment.chapterIndex;
    _currentTitle = centerSegment.title;
    _currentContent = centerSegment.content;
    _currentScrollChapterProgress = 0.0;
    _invalidateScrollLayoutSnapshot();
    _scrollSegmentsVersion.value++;
    _updateScrollTipNotifier();

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

  bool _scrollTickCallbackPending = false;

  void _handleScrollControllerTick() {
    if (!mounted) return;
    if (_settings.pageTurnMode != PageTurnMode.scroll) return;
    if (!_scrollController.hasClients) return;

    if (!_scrollTickCallbackPending) {
      _scrollTickCallbackPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollTickCallbackPending = false;
        if (!mounted) return;
        _scheduleScrollPreload();
        if (!_programmaticScrollInFlight && _shouldSyncScrollUiNow()) {
          _syncCurrentChapterFromScroll();
        }
      });
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

      // 直接赋值，不触发主 State 重建
      _currentChapterIndex = chosen.chapterIndex;
      _currentTitle = chosen.title;
      _currentContent = chosen.content;
      _currentScrollChapterProgress = chosenProgress;

      // 通知 Header/Footer 局部重建
      _updateScrollTipNotifier();

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

  void _updateScrollTipNotifier() {
    final totalPages = _resolveScrollTipTotalPages();
    final currentPage = _resolveScrollTipCurrentPage(totalPages);
    final newTip = _ScrollTipData(
      title: _currentTitle,
      bookTitle: widget.bookTitle,
      bookProgress: _getBookProgress(),
      chapterProgress: _getChapterProgress(),
      currentPage: currentPage,
      totalPages: totalPages,
      currentTime: _getCurrentTime(),
    );
    if (_scrollTipNotifier.value != newTip) {
      _scrollTipNotifier.value = newTip;
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

      _scrollSegments.add(segment);
      _scrollSegmentsVersion.value++;
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

      _scrollSegments.insert(0, segment);
      _scrollSegmentsVersion.value++;

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
      _scrollSegmentsVersion.value++;
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
    newSettings = _readSettingsWithExclusions(newSettings);

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

  ReaderThemeMode get _currentReaderThemeMode {
    return ReaderThemeModeHelper.resolveMode(
      appearanceMode: _settingsService.appSettings.appearanceMode,
      effectiveBrightness: _effectiveBrightnessForReaderThemeMode(),
    );
  }

  Brightness _effectiveBrightnessForReaderThemeMode() {
    final themeBrightness = CupertinoTheme.of(context).brightness;
    if (themeBrightness != null) return themeBrightness;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null) return mediaQuery.platformBrightness;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  int _themeIndexForMode(ReaderThemeMode mode) {
    return ReaderThemeModeHelper.resolveThemeIndex(
      settings: _settings,
      mode: mode,
    );
  }


  int get _activeReadStyleIndex {
    final styles = _activeReadStyleConfigs;
    if (styles.isEmpty) return 0;
    final index = _themeIndexForMode(_currentReaderThemeMode);
    return index.clamp(0, styles.length - 1).toInt();
  }

  String _readStyleDisplayName(ReadStyleConfig config) {
    final trimmed = config.name.trim();
    return trimmed.isEmpty ? '文字' : trimmed;
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
      CupertinoColors.label.resolveFrom(context);

  /// 获取当前字体
  String? get _currentFontFamily {
    final customFamily = _readerCustomFontFamily?.trim();
    if (customFamily != null && customFamily.isNotEmpty) {
      return customFamily;
    }
    final family = ReadingFontFamily.getFontFamily(_settings.fontFamilyIndex);
    return family.isEmpty ? null : family;
  }

  List<String>? get _currentFontFamilyFallback {
    if (_readerCustomFontFamily?.trim().isNotEmpty == true) {
      return null;
    }
    final fallback =
        ReadingFontFamily.getFontFamilyFallback(_settings.fontFamilyIndex);
    if (fallback.isEmpty) return null;
    return fallback;
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
    return ClickAction.normalizeConfigForExclusions(
      _settings.clickActions,
      excludeTts: MigrationExclusions.excludeTts,
    );
  }

  bool get _supportsVolumeKeyPaging {
    if (kIsWeb) return false;
    return defaultTargetPlatform != TargetPlatform.iOS;
  }

  bool get _supportsCustomPageKeyMapping {
    if (kIsWeb) return false;
    return defaultTargetPlatform != TargetPlatform.iOS;
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
      customPrevKeys: _settings.prevKeys,
      customNextKeys: _settings.nextKeys,
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
    if (_pagedReaderController.isAttached) {
      if (next) {
        _pagedReaderController.turnNextPage();
      } else {
        _pagedReaderController.turnPrevPage();
      }
      return;
    }
    final moved = next ? _pageFactory.moveToNext() : _pageFactory.moveToPrev();
    if (!moved || !mounted) return;
    setState(() {});
  }

  int _resolveClickAction(Offset position) {
    final size = MediaQuery.sizeOf(context);
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
        unawaited(_openAddBookmarkDialog());
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
        if (MigrationExclusions.excludeTts) break;
        unawaited(_triggerReadAloudPreviousParagraph());
        break;
      case ClickAction.readAloudNextParagraph:
        if (MigrationExclusions.excludeTts) break;
        unawaited(_triggerReadAloudNextParagraph());
        break;
      case ClickAction.readAloudPauseResume:
        if (MigrationExclusions.excludeTts) break;
        unawaited(_triggerReadAloudPauseResume());
        break;
      default:
        break;
    }
  }

  void _nextChapter() {
    final maxReadableIndex = _effectiveReadableMaxChapterIndex();
    if (maxReadableIndex < 0) return;
    if (_currentChapterIndex < maxReadableIndex) {
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
      _settings.hideNavigationBar,
      _settings.paddingDisplayCutouts,
      _settings.headerMode,
      _settings.footerMode,
      _settings.headerPaddingTop,
      _settings.headerPaddingBottom,
      _settings.footerPaddingTop,
      _settings.footerPaddingBottom,
      _settings.showHeaderLine,
      _settings.showFooterLine,
      _resolveScrollHeaderSlotHeight().toStringAsFixed(2),
      _resolveScrollFooterSlotHeight().toStringAsFixed(2),
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
      paddingBottom: _settings.paddingBottom.toDouble(),
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

    final contentWidth = _scrollBodyWidth();
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

  bool _isChapterSameTitleRemovalEnabled(String chapterId) {
    final key = chapterId.trim();
    if (key.isEmpty) return false;
    final cached = _chapterSameTitleRemovedById[key];
    if (cached != null) return cached;
    if (widget.isEphemeral) {
      _chapterSameTitleRemovedById[key] = true;
      return true;
    }
    final enabled = _settingsService.getChapterSameTitleRemoved(
      widget.bookId,
      key,
      fallback: true,
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
    final chapter = _chapters[_currentChapterIndex];
    final removeSameTitle = _settings.cleanChapterTitle ||
        _isChapterSameTitleRemovalEnabled(chapter.id);
    if (!removeSameTitle) return false;
    final stage = _replaceStageCache[chapter.id];
    final baseTitle = stage?.title ?? chapter.title;
    final baseContent = stage?.content ?? (chapter.content ?? '');
    final removal = _removeDuplicateTitle(baseContent, baseTitle);
    return removal.removed;
  }

  String _postProcessContent(
    String content,
    String processedTitle, {
    String? chapterId,
  }) {
    var processed = content;
    final removeSameTitle = _settings.cleanChapterTitle ||
        (chapterId != null && _isChapterSameTitleRemovalEnabled(chapterId));
    if (removeSameTitle) {
      processed = _removeDuplicateTitle(processed, processedTitle).content;
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
    final contentTrace = _useReplaceRule
        ? await _replaceService.applyContentWithTrace(
            rawContent,
            bookName: widget.bookTitle,
            sourceUrl: _currentSourceUrl,
          )
        : ReplaceContentApplyTrace(
            output: rawContent,
            appliedRules: const <ReplaceRule>[],
          );

    final stage = _ReplaceStageCache(
      rawTitle: rawTitle,
      rawContent: rawContent,
      title: title,
      content: contentTrace.output,
      effectiveContentReplaceRules: contentTrace.appliedRules,
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
        stream.removeListener(listener);
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

  _DuplicateTitleRemovalResult _removeDuplicateTitle(
    String content,
    String title,
  ) {
    if (content.isEmpty) {
      return _DuplicateTitleRemovalResult(content: content, removed: false);
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final trimmedTitle = title.trim();
    final index = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (index != -1) {
      final firstLine = lines[index].trim();
      if (firstLine == trimmedTitle || firstLine.contains(trimmedTitle)) {
        lines.removeAt(index);
        return _DuplicateTitleRemovalResult(
          content: lines.join('\n'),
          removed: true,
        );
      }
    }
    return _DuplicateTitleRemovalResult(
        content: lines.join('\n'), removed: false);
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
        );
  }

  String _removeHTagLikeLegado(String content) {
    final withoutHeaderBlocks = content.replaceAll(
      RegExp(
        r'<h[1-6]\b[^>]*>.*?</h[1-6]\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    return withoutHeaderBlocks.replaceAll(
      RegExp(r'<h[1-6]\b[^>]*/>', caseSensitive: false),
      '',
    );
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
    final totalReadableChapters = _effectiveReadableChapterCount();
    if (totalReadableChapters <= 0) return 0;
    final chapterProgress = _getChapterProgress();
    final safeChapterIndex =
        _currentChapterIndex.clamp(0, totalReadableChapters - 1).toInt();
    return ((safeChapterIndex + chapterProgress) / totalReadableChapters)
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
    final screenSize = MediaQuery.sizeOf(context);
    final isScrollMode = _settings.pageTurnMode == PageTurnMode.scroll;

    // 阅读模式时阻止 iOS 边缘滑动返回（菜单显示时允许返回）
    return PopScope(
      canPop: _showMenu,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showSearchMenu) {
          unawaited(_handleBackFromSearchMenu());
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
                        child: FadeTransition(
                          opacity: _showMenu
                              ? _menuFadeAnim
                              : const AlwaysStoppedAnimation(1.0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _showSearchMenu
                                ? () => _setSearchMenuVisible(false)
                                : _closeReaderMenuOverlay,
                            child: Container(
                              color: const Color(0xFF000000)
                                  .withValues(alpha: 0.14),
                            ),
                          ),
                        ),
                      ),

                    // 底部状态栏 - 只在滚动模式显示（翻页模式由PagedReaderWidget内部处理）
                    if (!_showMenu &&
                        !_showSearchMenu &&
                        !_showAutoReadPanel &&
                        isScrollMode &&
                        _settings.shouldShowFooter())
                      ValueListenableBuilder<_ScrollTipData>(
                        valueListenable: _scrollTipNotifier,
                        builder: (context, tip, _) => ReaderStatusBar(
                          settings: _settings,
                          currentTheme: _currentTheme,
                          currentTime: tip.currentTime,
                          title: tip.title,
                          bookTitle: tip.bookTitle,
                          bookProgress: tip.bookProgress,
                          chapterProgress: tip.chapterProgress,
                          currentPage: tip.currentPage,
                          totalPages: tip.totalPages,
                        ),
                      ),

                    // 顶部状态栏（滚动模式）
                    if (!_showMenu &&
                        !_showSearchMenu &&
                        !_showAutoReadPanel &&
                        isScrollMode &&
                        _settings.shouldShowHeader(
                          showStatusBar: _settings.showStatusBar,
                        ))
                      ValueListenableBuilder<_ScrollTipData>(
                        valueListenable: _scrollTipNotifier,
                        builder: (context, tip, _) => ReaderHeaderBar(
                          settings: _settings,
                          currentTheme: _currentTheme,
                          currentTime: tip.currentTime,
                          title: tip.title,
                          bookTitle: tip.bookTitle,
                          bookProgress: tip.bookProgress,
                          chapterProgress: tip.chapterProgress,
                          currentPage: tip.currentPage,
                          totalPages: tip.totalPages,
                        ),
                      ),

                    // 顶部菜单
                    if (_showMenu)
                      ReaderTopMenu(
                        onBack: () => unawaited(_handleReaderBack()),
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
                        onChangeSource: () =>
                            unawaited(_handleTopMenuChangeSourceTap()),
                        onChangeSourceLongPress: () =>
                            unawaited(_handleTopMenuChangeSourceLongPress()),
                        onRefresh: () => unawaited(_handleTopMenuRefreshTap()),
                        onRefreshLongPress: () =>
                            unawaited(_handleTopMenuRefreshLongPress()),
                        onOfflineCache: () =>
                            unawaited(_handleTopMenuOfflineCacheTap()),
                        onTocRule: () => unawaited(_handleTopMenuTocRuleTap()),
                        onSetCharset: () =>
                            unawaited(_handleTopMenuSetCharsetTap()),
                        onShowSourceActions: _showSourceActionsMenu,
                        onShowMoreMenu: _showReaderActionsMenu,
                        showChangeSourceAction: !_isCurrentBookLocal(),
                        showRefreshAction: !_isCurrentBookLocal(),
                        showDownloadAction: !_isCurrentBookLocal(),
                        showTocRuleAction: _isCurrentBookLocalTxt(),
                        showSetCharsetAction: _isCurrentBookLocal(),
                        showSourceAction: !_isCurrentBookLocal(),
                        showChapterLink: !_isCurrentBookLocal(),
                        showTitleAddition: _settings.showReadTitleAddition,
                        readBarStyleFollowPage: _menuFollowPageTone,
                        menuFadeAnimation: _menuFadeAnim,
                        menuSlideAnimation: _topMenuSlideAnim,
                      ),

                    // 右侧悬浮快捷栏（对标 legado 快捷动作区）
                    if (_showMenu) _buildFloatingActionRail(),

                    // 底部菜单（章节进度 + 高频设置 + 导航）
                    if (_showMenu)
                      ReaderBottomMenuNew(
                        currentChapterIndex: _currentChapterIndex,
                        totalChapters: _effectiveReadableChapterCount(),
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
                        onToggleAutoPage: _toggleAutoPageFromQuickAction,
                        onSearchContent: _showContentSearchDialog,
                        onToggleReplaceRule: _toggleReplaceRuleState,
                        onToggleNightMode: _toggleDayNightThemeFromQuickAction,
                        autoPageRunning: _autoPager.isRunning,
                        replaceRuleEnabled: _useReplaceRule,
                        isNightMode: _isUiDark,
                        showReadAloud: !MigrationExclusions.excludeTts,
                        readBarStyleFollowPage: _menuFollowPageTone,
                        readAloudRunning: _readAloudSnapshot.isRunning,
                        readAloudPaused: _readAloudSnapshot.isPaused,
                        menuFadeAnimation: _menuFadeAnim,
                        menuSlideAnimation: _bottomMenuSlideAnim,
                      ),

                    if (_showSearchMenu) _buildSearchMenuOverlay(),

                    if (_isLoadingChapter || _isCurrentFactoryChapterLoading)
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 12,
                        right: 16,
                        child: const CupertinoActivityIndicator(),
                      ),

                    // 朗读控制浮层
                    if (_readAloudSnapshot.isRunning)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ReaderReadAloudBar(
                          snapshot: _readAloudSnapshot,
                          speechRate: _readAloudSpeechRate,
                          bgColor: _uiPanelBg,
                          fgColor: _uiTextStrong,
                          accentColor: _uiAccent,
                          onPreviousParagraph: () =>
                              unawaited(_readAloudService.previousParagraph()),
                          onTogglePauseResume: () =>
                              unawaited(_readAloudService.togglePauseResume()),
                          onNextParagraph: () =>
                              unawaited(_readAloudService.nextParagraph()),
                          onStop: () => unawaited(_readAloudService.stop()),
                          onSpeechRateChanged: (rate) {
                            setState(() => _readAloudSpeechRate = rate);
                            unawaited(_readAloudService.updateSpeechRate(rate));
                            unawaited(_httpTtsRuleStore.saveSpeechRate(rate));
                          },
                          onPreviousChapter: _currentChapterIndex > 0
                              ? () => unawaited(
                                    _loadChapter(_currentChapterIndex - 1),
                                  )
                              : null,
                          onNextChapter: _currentChapterIndex <
                                  _effectiveReadableMaxChapterIndex()
                              ? () => unawaited(
                                    _loadChapter(_currentChapterIndex + 1),
                                  )
                              : null,
                        ),
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

}
