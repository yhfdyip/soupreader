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
import '../../../core/database/entities/bookmark_entity.dart';
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
import '../../settings/views/reading_tip_settings_view.dart';
import '../models/reading_settings.dart';
import '../services/chapter_title_display_helper.dart';
import '../services/read_style_import_export_service.dart';
import '../services/reader_bookmark_export_service.dart';
import '../services/reader_charset_service.dart';
import '../services/reader_key_paging_helper.dart';
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
import '../widgets/reader_padding_config_dialog.dart';
import '../widgets/reader_style_quick_sheet.dart';
import '../widgets/source_switch_candidate_sheet.dart';
import 'reader_content_editor.dart';
import 'reader_dict_lookup_sheet.dart';

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

class _SimpleReaderViewState extends State<SimpleReaderView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  // 记录自动阅读是否因菜单弹出而被暂停，关闭菜单时仅恢复此类暂停
  bool _autoPagerPausedByMenu = false;
  EdgeInsets? _lastViewPadding;
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
  bool _isAutoChangingSource = false;
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
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewPadding = MediaQuery.viewPaddingOf(context);
    if (_lastViewPadding != null && _lastViewPadding != viewPadding) {
      if (_settings.pageTurnMode != PageTurnMode.scroll) {
        _paginateContentLogicOnly();
      }
    }
    _lastViewPadding = viewPadding;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 对标 legado onPause：切换到后台时停止自动阅读
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_autoPager.isRunning || _autoPager.isPaused) {
        _autoPagerPausedByMenu = false;
        _autoPager.stop();
        if (mounted && _showAutoReadPanel) {
          setState(() => _showAutoReadPanel = false);
        }
        _screenOffTimerStart(force: true);
      }
    }
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
      if (_autoPager.isRunning) {
        _autoPager.pause();
        _autoPagerPausedByMenu = true;
      }
      setState(() {
        _showMenu = true;
        _showSearchMenu = false;
        _showAutoReadPanel = false;
      });
      _menuAnimController.forward();
    } else {
      _menuAnimController.reverse().then((_) {
        if (mounted) {
          setState(() => _showMenu = false);
          _syncSystemUiForOverlay();
          if (_autoPagerPausedByMenu && _autoPager.isPaused) {
            _autoPagerPausedByMenu = false;
            _autoPager.resume();
          }
        }
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
      if (_autoPager.isRunning) {
        _autoPager.pause();
        _autoPagerPausedByMenu = true;
      }
      setState(() {
        _showSearchMenu = true;
        _showMenu = false;
        _showAutoReadPanel = false;
      });
      _searchMenuAnimController.forward();
    } else {
      _searchMenuAnimController.reverse().then((_) {
        if (mounted) {
          setState(() => _showSearchMenu = false);
          _syncSystemUiForOverlay();
          if (_autoPagerPausedByMenu && _autoPager.isPaused) {
            _autoPagerPausedByMenu = false;
            _autoPager.resume();
          }
        }
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
    } catch (e) {
      if (_settings.autoChangeSource && !_isAutoChangingSource) {
        unawaited(_autoChangeSource());
      }
      rethrow;
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
        : viewPadding.bottom;
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
    final rawContentWidth = screenWidth -
        horizontalSafeInset -
        _settings.paddingLeft -
        _settings.paddingRight;
    // 双页模式：每栏宽度减半（对标 legado visibleWidth = viewWidth / 2 - padding）
    final contentWidth = _settings.doublePage
        ? (rawContentWidth / 2).floorToDouble()
        : rawContentWidth;

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

    final doublePageChanged =
        oldSettings.doublePage != newSettings.doublePage;
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
    } else if (doublePageChanged) {
      final total = _pageFactory.totalPages;
      desiredChapterProgress = ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: _pageFactory.currentPageIndex,
        totalPages: total,
      );
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
          oldSettings.doublePage != newSettings.doublePage ||
          oldSettings.showStatusBar != newSettings.showStatusBar ||
          oldSettings.hideNavigationBar != newSettings.hideNavigationBar ||
          oldSettings.headerMode != newSettings.headerMode ||
          oldSettings.footerMode != newSettings.footerMode ||
          oldSettings.paddingDisplayCutouts != newSettings.paddingDisplayCutouts ||
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
    } else if (doublePageChanged && desiredChapterProgress != null) {
      final progress = desiredChapterProgress;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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
    final action = _resolveClickAction(details.localPosition);
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
      final moved =
          next ? _pagedReaderController.turnNextPage() : _pagedReaderController.turnPrevPage();
      if (!moved && mounted) {
        _showToast(next ? '已到最后一页' : '已到第一页');
      }
      return;
    }
    final moved = _settings.doublePage
        ? (next ? _pageFactory.moveToNextDouble() : _pageFactory.moveToPrevDouble())
        : (next ? _pageFactory.moveToNext() : _pageFactory.moveToPrev());
    if (!mounted) return;
    if (!moved) {
      _showToast(next ? '已到最后一页' : '已到第一页');
      return;
    }
    setState(() {});
  }

  int _resolveClickAction(Offset position) {
    final size = (context.findRenderObject() as RenderBox?)?.size
        ?? MediaQuery.sizeOf(context);
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
          // 对标 legado：返回键优先停止自动阅读
          if (_autoPager.isRunning || _autoPager.isPaused) {
            _autoPagerPausedByMenu = false;
            _autoPager.stop();
            if (mounted && _showAutoReadPanel) {
              setState(() => _showAutoReadPanel = false);
            }
            _screenOffTimerStart(force: true);
            return;
          }
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

                    // 底部菜单（章节进度 + 高频设置 + 导航）
                    if (_showMenu)
                      ReaderBottomMenuNew(
                        currentChapterIndex: _currentChapterIndex,
                        totalChapters: _effectiveReadableChapterCount(),
                        currentPageIndex: _pageFactory.currentPageIndex,
                        totalPages: _pageFactory.totalPages.clamp(1, 999999),
                        settings: _settings,
                        currentTheme: _currentTheme,
                        onChapterChanged: (index) => _loadChapter(index),
                        onSeekChapterProgress: _seekByChapterProgress,
                        onSeekPageProgress: _seekByPageProgress,
                        onSettingsChanged: (settings) =>
                            _updateSettings(settings),
                        onShowChapterList: _openChapterListFromMenu,
                        onShowReadAloud: _openReadAloudFromMenu,
                        onReadAloudLongPress: _openReadAloudDialogFromMenu,
                        onShowInterfaceSettings: _openInterfaceSettingsFromMenu,
                        onShowBehaviorSettings: _openBehaviorSettingsFromMenu,
                        onToggleAutoPage: _toggleAutoPageFromQuickAction,
                        onSearchContent: _showContentSearchDialog,
                        onToggleReplaceRule: _openReplaceRuleListFromMenu,
                        onToggleNightMode: _toggleDayNightThemeFromQuickAction,
                        autoPageRunning: _autoPager.isRunning,
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
                          onSetTimer: () => unawaited(_showReadAloudTimerPicker()),
                          onOpenChapterList: _openChapterListFromAutoReadPanel,
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

                    // 翻页模式自动阅读进度线（对标 legado AutoPager.onDraw）
                    if (_autoPager.isRunning &&
                        _settings.pageTurnMode != PageTurnMode.scroll)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AutoPageProgressLine(
                            autoPager: _autoPager,
                            color: _uiAccent,
                          ),
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
                          onPause: () => _screenOffTimerStart(force: true),
                          onResume: () => _screenOffTimerStart(force: true),
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



  // --- from simple_reader_view_build.dart ---
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
      shaderBackgroundColor: _readerBackgroundBaseColor,
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
      // 选文功能
      selectTextEnabled: _settings.selectText && !_settings.doublePage,
      onCopySelectedText: _onCopySelectedText,
      onBookmarkSelectedText: _onBookmarkSelectedText,
      onReadAloudSelectedText: _onReadAloudSelectedText,
      onDictSelectedText: _onDictSelectedText,
      onSearchSelectedText: _onSearchSelectedText,
      onShareSelectedText: _onShareSelectedText,
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

  // === 选文功能回调 ===

  void _onCopySelectedText(String text) {
    _showToast('已复制');
  }

  Future<void> _onBookmarkSelectedText(String text) async {
    await _openBookmarkEditorFromSelectedText(text);
  }

  Future<void> _onReadAloudSelectedText(String text) async {
    await _handleSelectedTextReadAloud(text);
  }

  Future<void> _onDictSelectedText(String text) async {
    await _openDictDialogFromSelectedText(text);
  }

  Future<void> _onSearchSelectedText(String text) async {
    await _searchSelectedTextInContent(text);
  }

  Future<void> _onShareSelectedText(String text) async {
    await _shareSelectedText(text);
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
      restoreOffset: true,
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
        : viewPadding.bottom;
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
        styleConfigs: _activeReadStyleConfigs,
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
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => const ReplaceRuleListView(),
      ),
    );
    if (!mounted) return;
    if (changed != true) return;
    _replaceStageCache.clear();
    await _loadChapter(
      _currentChapterIndex,
      restoreOffset: true,
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
        restoreOffset: true,
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

  // 对齐 Legado progressBarBehavior="page"：松手直接跳页，无需确认
  void _seekByPageProgress(int targetPageIndex) {
    final totalPages = _pageFactory.totalPages;
    if (totalPages <= 0) return;
    final clamped = targetPageIndex.clamp(0, totalPages - 1);
    if (clamped == _pageFactory.currentPageIndex) return;
    _pageFactory.jumpToPage(clamped);
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
      pages: _pageFactory.currentPages.map((p) => p.text).toList(),
      query: query,
      occurrenceIndex: occurrenceIndex,
      chapterTitle: _currentTitle,
      trimFirstPageTitlePrefix: _settings.titleMode != 2,
    );
  }

  int? _resolveSearchHitPageIndexByOffset(int contentOffset) {
    return ReaderSearchNavigationHelper.resolvePageIndexByOffset(
      pages: _pageFactory.currentPages.map((p) => p.text).toList(),
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

  // --- from simple_reader_view_actions.dart ---
  void _refreshChapter() {
    _closeReaderMenuOverlay();
    _loadChapter(_currentChapterIndex);
  }

  void _showToast(String message) {
    showCupertinoBottomDialog<void>(
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

  void _showCopyToast(String message) {
    if (!mounted) return;
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        }));
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context)
                        .resolveFrom(context)
                        .withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    if (_SimpleReaderViewState._legacyImageStyles.contains(normalized)) {
      return normalized;
    }
    return _SimpleReaderViewState._defaultLegacyImageStyle;
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
    final readableChapterCount = _effectiveReadableChapterCount();
    final safeChapterIndex = readableChapterCount > 0
        ? _currentChapterIndex.clamp(0, readableChapterCount - 1).toInt()
        : 0;
    return WebDavBookProgress(
      name: _progressSyncBookTitle(),
      author: _progressSyncBookAuthor(),
      durChapterIndex: safeChapterIndex,
      durChapterPos: (chapterProgress * 10000).round(),
      durChapterTime: DateTime.now().millisecondsSinceEpoch,
      durChapterTitle: _currentTitle,
      chapterProgress: chapterProgress,
      readProgress: _getBookProgress().clamp(0.0, 1.0).toDouble(),
      totalChapters: readableChapterCount,
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

  Future<void> _pushBookProgressToWebDav() async {
    if (!_isSyncBookProgressEnabled()) {
      return;
    }
    if (!_hasWebDavProgressConfig()) {
      return;
    }
    if (_chapters.isEmpty) {
      return;
    }
    final bookTitle = _progressSyncBookTitle();
    final bookAuthor = _progressSyncBookAuthor();
    try {
      await _saveProgress();
      final progress = _buildLocalBookProgressPayload();
      await _webDavService.uploadBookProgress(
        progress: progress,
        settings: _settingsService.appSettings,
      );
      if (!mounted) return;
      _showToast('上传成功');
    } catch (error, stackTrace) {
      final reason = _normalizeReaderErrorMessage(error);
      ExceptionLogService().record(
        node: 'reader.menu.cover_progress.failed',
        message: '上传阅读进度失败《$bookTitle》\n$reason',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': bookTitle,
          'bookAuthor': bookAuthor,
          'syncBookProgress': _settingsService.appSettings.syncBookProgress,
          'sourceUrl': _currentSourceUrl,
        },
      );
      if (!mounted) return;
      _showToast('上传进度失败\n$reason');
    }
  }

  Future<void> _pullBookProgressFromWebDav() async {
    if (!_isSyncBookProgressEnabled()) {
      return;
    }
    if (!_hasWebDavProgressConfig()) {
      return;
    }
    if (_chapters.isEmpty) {
      return;
    }
    final bookTitle = _progressSyncBookTitle();
    final bookAuthor = _progressSyncBookAuthor();
    try {
      final remote = await _webDavService.getBookProgress(
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
        settings: _settingsService.appSettings,
      );
      if (remote == null) return;
      await _applyRemoteBookProgress(
        remote,
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
      );
    } catch (error, stackTrace) {
      final reason = _normalizeReaderErrorMessage(error);
      ExceptionLogService().record(
        node: 'reader.menu.get_progress.failed',
        message: '拉取阅读进度失败《$bookTitle》\n$reason',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'bookAuthor': _bookAuthor,
          'syncBookProgress': _settingsService.appSettings.syncBookProgress,
          'sourceUrl': _currentSourceUrl,
        },
      );
    }
  }

  Future<void> _applyRemoteBookProgress(
    WebDavBookProgress remote, {
    required String bookTitle,
    required String bookAuthor,
  }) async {
    final readableChapterCount = _effectiveReadableChapterCount();
    if (readableChapterCount <= 0) return;
    final maxIndex = readableChapterCount - 1;
    final targetChapterIndex = remote.durChapterIndex;
    if (targetChapterIndex < 0 || targetChapterIndex > maxIndex) {
      return;
    }
    var targetChapterProgress = _decodeRemoteChapterProgress(remote);
    final remotePos = remote.durChapterPos;
    final hasLegacyRawPos = remote.chapterProgress == null && remotePos > 10000;
    if (hasLegacyRawPos && targetChapterProgress <= 0) {
      final chapterContent =
          (_chapters[targetChapterIndex].content ?? '').trim();
      if (chapterContent.isNotEmpty) {
        targetChapterProgress =
            (remotePos / chapterContent.length).clamp(0.0, 1.0).toDouble();
      }
    }
    final localChapterIndex = _currentChapterIndex.clamp(0, maxIndex).toInt();
    final localChapterProgress =
        _getChapterProgress().clamp(0.0, 1.0).toDouble();
    final remoteBehindLocal = targetChapterIndex < localChapterIndex ||
        (targetChapterIndex == localChapterIndex &&
            targetChapterProgress < localChapterProgress);

    if (remoteBehindLocal) {
      if (!mounted) return;
      final confirmOverride = await showCupertinoBottomDialog<bool>(
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

    final chapterProgressDelta =
        (targetChapterProgress - localChapterProgress).abs();
    final remoteEqualsLocal = targetChapterIndex == localChapterIndex &&
        chapterProgressDelta <= 0.0001;
    if (remoteEqualsLocal) {
      if (!remoteBehindLocal) {
        final syncedTitle = (remote.durChapterTitle ?? '').trim();
        final suffix = syncedTitle.isEmpty ? '' : ' $syncedTitle';
        ExceptionLogService().record(
          node: 'reader.menu.get_progress.synced',
          message: '自动同步阅读进度成功《$bookTitle》$suffix',
          context: <String, dynamic>{
            'bookId': widget.bookId,
            'bookTitle': bookTitle,
            'bookAuthor': bookAuthor,
            'chapterIndex': targetChapterIndex,
            'chapterTitle': remote.durChapterTitle,
            'sourceUrl': _currentSourceUrl,
          },
        );
      }
      return;
    }

    await _loadChapter(
      targetChapterIndex,
      restoreOffset: true,
      targetChapterProgress: targetChapterProgress,
    );
    await _saveProgress();
    if (remoteBehindLocal) {
      return;
    }

    final syncedTitle = (remote.durChapterTitle ?? '').trim();
    final suffix = syncedTitle.isEmpty ? '' : ' $syncedTitle';
    ExceptionLogService().record(
      node: 'reader.menu.get_progress.synced',
      message: '自动同步阅读进度成功《$bookTitle》$suffix',
      context: <String, dynamic>{
        'bookId': widget.bookId,
        'bookTitle': bookTitle,
        'bookAuthor': bookAuthor,
        'chapterIndex': targetChapterIndex,
        'chapterTitle': remote.durChapterTitle,
        'sourceUrl': _currentSourceUrl,
      },
    );
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
      actionTag: 'edit_content',
      showFetchFailureToast: true,
    );
    if (!mounted) return;

    final payload = await Navigator.of(context).push<ReaderContentEditPayload>(
      CupertinoPageRoute<ReaderContentEditPayload>(
        fullscreenDialog: true,
        builder: (_) => ReaderContentEditorPage(
          initialTitle: chapter.title,
          initialContent: initialRawContent,
          onResetContent: () => _reloadChapterRawContentForEditor(
            chapterIndex: chapterIndex,
          ),
        ),
      ),
    );
    if (payload == null) return;

    final nextContent = payload.content;
    final nextTitle =
        payload.title.trim().isEmpty ? chapter.title : payload.title.trim();
    final shouldPersistContent = nextContent.isNotEmpty;
    final nextStoredContent =
        shouldPersistContent ? nextContent : chapter.content;
    final nextIsDownloaded = shouldPersistContent ? true : chapter.isDownloaded;
    final hasChanges = nextTitle != chapter.title ||
        nextStoredContent != chapter.content ||
        nextIsDownloaded != chapter.isDownloaded;
    if (!hasChanges) {
      return;
    }
    final updated = chapter.copyWith(
      title: nextTitle,
      content: nextStoredContent,
      isDownloaded: nextIsDownloaded,
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

    late final String resetRawContent;
    try {
      final book = _bookRepo.getBookById(widget.bookId);
      if (book != null && book.isLocal) {
        resetRawContent = await _reloadLocalChapterRawContentForEditor(
          chapter: chapter,
          chapterIndex: chapterIndex,
          book: book,
        );
      } else {
        resetRawContent = await _resolveCurrentChapterRawContentForMenu(
          chapter: cleared,
          chapterIndex: chapterIndex,
          actionTag: 'edit_content_reset',
          fallbackToCurrentContent: false,
          rethrowFetchFailure: true,
        );
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.edit_content_reset.failed',
        message: '重置正文失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'chapterId': chapter.id,
          'chapterIndex': chapterIndex,
          'chapterTitle': chapter.title,
          'sourceUrl': _currentSourceUrl,
        },
      );
      rethrow;
    }
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

    try {
      await _loadChapter(chapterIndex, restoreOffset: true);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.edit_content_reset.reload_failed',
        message: '重置正文后刷新章节失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'chapterId': chapter.id,
          'chapterIndex': chapterIndex,
          'chapterTitle': chapter.title,
          'sourceUrl': _currentSourceUrl,
        },
      );
    }
    return resetRawContent;
  }

  Future<String> _reloadLocalChapterRawContentForEditor({
    required Chapter chapter,
    required int chapterIndex,
    required Book book,
  }) async {
    final preferredTxtCharset = _isCurrentBookLocalTxt()
        ? (_readerCharsetService.getBookCharset(widget.bookId) ??
            ReaderCharsetService.defaultCharset)
        : null;
    final refreshed = await SearchBookInfoRefreshHelper.refreshLocalBook(
      book: book,
      preferredTxtCharset: preferredTxtCharset,
      splitLongChapter: _settingsService.getBookSplitLongChapter(widget.bookId),
      txtTocRuleRegex: _settingsService.getBookTxtTocRule(widget.bookId),
    );
    final refreshedChapters = refreshed.chapters;
    if (refreshedChapters.isEmpty) {
      return '';
    }
    final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: refreshedChapters,
      currentChapterTitle: chapter.title,
      currentChapterIndex: chapterIndex,
      oldChapterCount: _chapters.length,
    );
    if (targetIndex < 0 || targetIndex >= refreshedChapters.length) {
      return '';
    }
    return refreshedChapters[targetIndex].content ?? '';
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
    if (_chapters.isEmpty) return;
    await _saveProgress();
    final targetIndex = _clampChapterIndexToReadableRange(_currentChapterIndex);
    await _loadChapter(
      targetIndex,
      restoreOffset: true,
    );
  }

  Future<void> _openImageStyleFromMenu() async {
    final selected = await showOptionPickerSheet<String>(
      context: context,
      title: '图片样式',
      currentValue: _imageStyle,
      accentColor: _uiAccent,
      items: _SimpleReaderViewState._legacyImageStyles
          .map(
            (style) => OptionPickerItem<String>(
              value: style,
              label: style,
            ),
          )
          .toList(growable: false),
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

    // 对齐 legado：切换为 SINGLE 时，仅当前书籍强制覆盖翻页动画。
    if (normalized == _SimpleReaderViewState._legacyImageStyleSingle) {
      await _applyBookPageAnimFromMenu(0);
      if (!mounted) return;
    }
    await _loadChapter(_currentChapterIndex, restoreOffset: true);
  }

  String? _resolveBookTxtTocRuleRegex() {
    final regex = _settingsService.getBookTxtTocRule(widget.bookId);
    if (regex == null) return null;
    final normalized = regex.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  Future<List<TxtTocRuleOption>> _loadTxtTocRuleOptions() async {
    final enabledRules = await _txtTocRuleStore.loadEnabledRules();
    if (enabledRules.isEmpty) {
      return TxtParser.defaultTocRuleOptions;
    }
    return enabledRules
        .map(
          (rule) => TxtTocRuleOption(
            name: rule.name,
            rule: rule.rule,
            example: (rule.example ?? '').trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<String?> _pickTxtTocRuleRegex({
    required String currentRegex,
  }) async {
    final options = await _loadTxtTocRuleOptions();
    if (!mounted) return null;
    return ReaderTxtTocRuleDialog.show(
      context: context,
      currentRegex: currentRegex,
      options: options,
      accentColor: _uiAccent,
    );
  }

  Future<void> _showTxtTocRuleDialogFromMenu() async {
    if (!_isCurrentBookLocalTxt()) return;
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || !book.isLocal) return;

    final selectedRegex = await _pickTxtTocRuleRegex(
      currentRegex: _resolveBookTxtTocRuleRegex() ?? '',
    );
    if (selectedRegex == null) return;
    final normalizedRegex = selectedRegex.trim();
    await _settingsService.saveBookTxtTocRule(
      widget.bookId,
      normalizedRegex.isEmpty ? null : normalizedRegex,
    );

    if (!mounted) return;
    setState(() => _isLoadingChapter = true);
    try {
      final charset = _readerCharsetService.getBookCharset(widget.bookId) ??
          ReaderCharsetService.defaultCharset;
      final splitLongChapter =
          _settingsService.getBookSplitLongChapter(widget.bookId);
      await _reparseLocalTxtBookWithCharset(
        book: book,
        charset: charset,
        splitLongChapter: splitLongChapter,
      );
    } catch (e) {
      if (!mounted) return;
      _showToast('LoadTocError:$e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
  }

  Future<void> _showCharsetConfigFromMenu() async {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || !book.isLocal) {
      return;
    }

    final currentCharset =
        _readerCharsetService.getBookCharset(widget.bookId) ?? '';
    final selected =
        await _showCharsetInputDialog(initialValue: currentCharset);
    if (selected == null) return;
    await _applyBookCharsetSetting(
      book: book,
      charset: selected,
    );
  }

  Future<String?> _showCharsetInputDialog({
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showCupertinoBottomDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置编码'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: controller,
                placeholder: 'charset',
              ),
              const SizedBox(height: 10),
              Text(
                _SimpleReaderViewState._legacyCharsetOptions.join(' / '),
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 11,
                  color: _uiTextSubtle,
                ),
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
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _applyBookCharsetSetting({
    required Book book,
    required String charset,
  }) async {
    final normalized =
        ReaderCharsetService.normalizeCharset(charset) ?? charset.trim();
    await _readerCharsetService.setBookCharset(widget.bookId, normalized);

    if (!_isCurrentBookLocal()) {
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingChapter = true);
    try {
      if (_isCurrentBookLocalTxt()) {
        final splitLongChapter =
            _settingsService.getBookSplitLongChapter(widget.bookId);
        await _reparseLocalTxtBookWithCharset(
          book: book,
          charset: normalized,
          splitLongChapter: splitLongChapter,
        );
      } else {
        await _reloadLocalCatalogAfterCharsetChanged(book: book);
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('LoadTocError:$e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
  }

  Future<void> _reloadLocalCatalogAfterCharsetChanged({
    required Book book,
  }) async {
    final refreshed = await SearchBookInfoRefreshHelper.refreshLocalBook(
      book: book,
    );
    final newChapters = refreshed.chapters;
    if (newChapters.isEmpty) {
      throw StateError('重解析后章节为空');
    }

    final previousRawTitle = _chapters.isEmpty
        ? _currentTitle
        : _chapters[_currentChapterIndex.clamp(0, _chapters.length - 1)].title;
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
        refreshed.book.copyWith(
          totalChapters: newChapters.length,
          latestChapter: newChapters.last.title,
          currentChapter: targetIndex,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _bookAuthor = refreshed.book.author;
      _bookCoverUrl = refreshed.book.coverUrl;
      _replaceStageCache.clear();
      _catalogDisplayTitleCacheByChapterId.clear();
      _chapterContentInFlight.clear();
      _chapters = newChapters;
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
    });
    await _loadChapter(
      _clampChapterIndexToReadableRange(targetIndex),
      restoreOffset: true,
    );
  }

  Future<void> _reparseLocalTxtBookWithCharset({
    required Book book,
    required String charset,
    required bool splitLongChapter,
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
      splitLongChapter: splitLongChapter,
      tocRuleRegex: _settingsService.getBookTxtTocRule(widget.bookId),
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
    await _loadChapter(
      _clampChapterIndexToReadableRange(targetIndex),
      restoreOffset: true,
    );
  }

  String _reverseContentLikeLegado(String content) {
    if (content.isEmpty) return content;
    final codePoints = content.runes.toList(growable: false);
    if (codePoints.length <= 1) return content;
    return String.fromCharCodes(codePoints.reversed);
  }

  Future<String> _resolveCurrentChapterRawContentForMenu({
    required Chapter chapter,
    required int chapterIndex,
    required String actionTag,
    bool showFetchFailureToast = false,
    bool fallbackToCurrentContent = true,
    bool rethrowFetchFailure = false,
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
      try {
        rawContent = await _fetchChapterContent(
          chapter: chapter,
          index: chapterIndex,
          book: book,
          showLoading: true,
        );
      } catch (error, stackTrace) {
        ExceptionLogService().record(
          node: 'reader.menu.$actionTag.fetch_content_failed',
          message: '阅读页菜单正文拉取失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'bookId': widget.bookId,
            'bookTitle': widget.bookTitle,
            'chapterId': chapter.id,
            'chapterIndex': chapterIndex,
            'chapterUrl': chapterUrl,
            'actionTag': actionTag,
            'currentSourceUrl': _resolveActiveSourceUrl(book),
          },
        );
        if (rethrowFetchFailure) {
          rethrow;
        }
        if (showFetchFailureToast && mounted) {
          _showToast('获取正文失败，已回退当前显示内容');
        }
      }
    }
    if (rawContent.trim().isNotEmpty) {
      return rawContent;
    }
    if (fallbackToCurrentContent) {
      return _currentContent;
    }
    return '';
  }

  Future<void> _reverseCurrentChapterContentFromMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return;
    }
    final chapterIndex = _currentChapterIndex;
    final chapter = _chapters[chapterIndex];
    final rawContent = chapter.content ?? '';
    if (rawContent.isEmpty) {
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
    final input = await _showSimulatedReadingInputDialog();
    if (input == null) return;

    final startRaw = input.startChapter.trim();
    final dailyRaw = input.dailyChapters.trim();
    final startChapter = startRaw.isEmpty ? 0 : int.tryParse(startRaw);
    final dailyChapters =
        dailyRaw.isEmpty ? _chapters.length : int.tryParse(dailyRaw);
    if (startChapter == null) {
      _showToast('起始章节输入无效');
      return;
    }
    if (dailyChapters == null) {
      _showToast('每日章节输入无效');
      return;
    }

    await _settingsService.saveBookSimulatedReadingConfig(
      widget.bookId,
      enabled: input.enabled,
      startChapter: startChapter,
      dailyChapters: dailyChapters,
      startDate: _normalizeDateOnly(input.startDate),
    );

    _replaceStageCache.clear();
    _catalogDisplayTitleCacheByChapterId.clear();
    _chapterContentInFlight.clear();

    final readableChapterCount = _effectiveReadableChapterCount();
    if (readableChapterCount <= 0) {
      if (!mounted) return;
      setState(() {
        _currentChapterIndex = 0;
        _currentTitle = '';
        _currentContent = '';
        _invalidateScrollLayoutSnapshot();
      });
      _syncPageFactoryChapters();
      return;
    }

    final targetIndex =
        _currentChapterIndex.clamp(0, readableChapterCount - 1).toInt();
    await _loadChapter(
      _clampChapterIndexToReadableRange(targetIndex),
      restoreOffset: true,
    );
  }

  Future<_ReaderSimulatedReadingInput?>
      _showSimulatedReadingInputDialog() async {
    var enabled = _isSimulatedReadingEnabled();
    var startDate = _simulatedStartDateOrToday();
    final startController = TextEditingController(
      text: _simulatedStartChapterForDialogDefault().toString(),
    );
    final dailyController = TextEditingController(
      text: _simulatedDailyChaptersForDialogDefault().toString(),
    );
    try {
      return await showCupertinoBottomDialog<_ReaderSimulatedReadingInput>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return CupertinoAlertDialog(
                title: const Text('模拟追读'),
                content: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('启用'),
                          const Spacer(),
                          CupertinoSwitch(
                            value: enabled,
                            onChanged: (value) {
                              setDialogState(() {
                                enabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: startController,
                        placeholder: '起始章节',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: dailyController,
                        placeholder: '每日章节',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                      ),
                      const SizedBox(height: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final picked =
                              await _pickSimulatedReadingStartDate(startDate);
                          if (picked == null) return;
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            startDate = picked;
                          });
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '开始日期：${_formatDateOnly(startDate)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
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
                        _ReaderSimulatedReadingInput(
                          enabled: enabled,
                          startChapter: startController.text,
                          dailyChapters: dailyController.text,
                          startDate: startDate,
                        ),
                      );
                    },
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      startController.dispose();
      dailyController.dispose();
    }
  }

  Future<DateTime?> _pickSimulatedReadingStartDate(DateTime initialDate) async {
    var selected = _normalizeDateOnly(initialDate);
    return await showCupertinoBottomSheetDialog<DateTime>(
      context: context,
      builder: (sheetContext) {
        return Container(
          height: 300,
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.systemBackground.resolveFrom(context),
            sheetContext,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('取消'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selected,
                  maximumDate: DateTime(9999, 12, 31),
                  minimumDate: DateTime(1970, 1, 1),
                  onDateTimeChanged: (value) {
                    selected = _normalizeDateOnly(value);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleSameTitleRemovedFromMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return;
    }
    final chapter = _chapters[_currentChapterIndex];
    final enabled = _isChapterSameTitleRemovalEnabled(chapter.id);
    final sameTitleRemoved = _isCurrentChapterSameTitleRemoved();
    if (!sameTitleRemoved && enabled) {
      _showToast('未找到可移除的重复标题');
    }
    final nextEnabled = !sameTitleRemoved;
    _chapterSameTitleRemovedById[chapter.id] = nextEnabled;
    if (!widget.isEphemeral) {
      await _settingsService.saveChapterSameTitleRemoved(
        widget.bookId,
        chapter.id,
        nextEnabled,
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
    await _clearLocalCatalogCacheBeforeRefresh();
    await _loadChapter(
      _clampChapterIndexToReadableRange(_currentChapterIndex),
      restoreOffset: true,
    );
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

  // --- from simple_reader_view_source_switch.dart ---
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
      currentSourceUrl: _resolveActiveSourceUrl(currentBook),
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
      currentSourceUrl: _resolveActiveSourceUrl(currentBook),
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





















  Future<Directory> _resolveReadStyleBackgroundDirectory() async {
    final docsDirectory = await getApplicationDocumentsDirectory();
    return Directory(p.join(docsDirectory.path, 'reader', 'bg'));
  }














  /// Aa（排版）主面板：对标专业阅读器的“高频项集中”
  ///
  /// 原则：
  /// - 第一屏优先：字号/行距/段距/缩进/对齐
  /// - 字体与装饰留在同页下方
  /// - 边距给预设 + “高级”入口，避免用户在四个滑条里迷路












































  /// 以 legado 同义语义添加书签：打开编辑弹窗，确认后落库。

  /// 章节加载失败时自动换源（对标 legado autoChangeSource）。
  ///
  /// 静默搜索所有启用书源，取第一个匹配结果直接切换，无需用户交互。
  Future<void> _autoChangeSource() async {
    if (_isAutoChangingSource) return;
    if (!mounted) return;
    setState(() => _isAutoChangingSource = true);
    try {
      final currentBook = _buildCurrentBookForSourceSwitch();
      if (currentBook.title.trim().isEmpty) return;
      final enabledSourceCount =
          _sourceRepo.getAllSources().where((s) => s.enabled).length;
      if (enabledSourceCount <= 0) return;

      _showToast('正在自动换源...');

      final token = CancelToken();
      _sourceSwitchCandidateSearchCancelToken = token;
      List<ReaderSourceSwitchCandidate> candidates;
      try {
        candidates = await _loadSourceSwitchCandidates(
          currentBook: currentBook,
          loadInfoEnabled: false,
          loadWordCountEnabled: false,
          loadTocEnabled: false,
          sourceDelaySeconds: 0,
          cancelToken: token,
        );
      } finally {
        if (identical(_sourceSwitchCandidateSearchCancelToken, token)) {
          _sourceSwitchCandidateSearchCancelToken = null;
        }
      }

      if (!mounted) return;
      if (candidates.isEmpty) {
        _showToast('自动换源失败：未找到匹配书源');
        return;
      }

      await _switchToSourceCandidate(candidates.first);
      if (mounted) _showToast('已自动换源：${candidates.first.source.bookSourceName}');
    } catch (e) {
      if (mounted) _showToast('自动换源失败');
    } finally {
      if (mounted) setState(() => _isAutoChangingSource = false);
    }
  }

  // --- from simple_reader_view_bookmark.dart ---
  Future<void> _openAddBookmarkDialog() async {
    final draft = _buildBookmarkDraft();
    await _openBookmarkEditorFromDraft(draft);
  }

  Future<void> _openBookmarkEditorFromSelectedText(String selectedText) async {
    final baseDraft = _buildBookmarkDraft();
    if (baseDraft == null) {
      _showToast('创建书签失败');
      return;
    }
    final draft = _ReaderBookmarkDraft(
      chapterTitle: baseDraft.chapterTitle,
      chapterPos: baseDraft.chapterPos,
      pageText: selectedText.trim(),
    );
    await _openBookmarkEditorFromDraft(draft);
  }

  Future<void> _openBookmarkEditorFromDraft(_ReaderBookmarkDraft? draft) async {
    if (draft == null || !mounted) return;
    final result = await _showBookmarkEditorDialog(draft);
    if (result == null) return;

    try {
      await _bookmarkRepo.addBookmark(
        bookId: widget.bookId,
        bookName: widget.bookTitle,
        bookAuthor: _bookAuthor,
        chapterIndex: _currentChapterIndex,
        chapterTitle: draft.chapterTitle,
        chapterPos: draft.chapterPos,
        content: _composeBookmarkPreview(
          bookText: result.bookText,
          note: result.note,
        ),
      );
      _updateBookmarkStatus();
    } catch (e) {
      if (!mounted) return;
      _showToast('书签操作失败：$e');
    }
  }

  _ReaderBookmarkDraft? _buildBookmarkDraft() {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return null;
    }
    final fallbackTitle = _chapters[_currentChapterIndex].title.trim();
    final chapterTitle =
        _currentTitle.trim().isNotEmpty ? _currentTitle.trim() : fallbackTitle;
    return _ReaderBookmarkDraft(
      chapterTitle: chapterTitle.isEmpty
          ? '第 ${_currentChapterIndex + 1} 章'
          : chapterTitle,
      chapterPos: _encodeCurrentBookmarkChapterPos(),
      pageText: _resolveCurrentBookmarkText(),
    );
  }

  Future<_ReaderBookmarkEditResult?> _showBookmarkEditorDialog(
    _ReaderBookmarkDraft draft,
  ) async {
    final bookTextController = TextEditingController(text: draft.pageText);
    final noteController = TextEditingController();
    final result = await showCupertinoBottomDialog<_ReaderBookmarkEditResult>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('书签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              draft.chapterTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: bookTextController,
              placeholder: '内容',
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: noteController,
              placeholder: '备注',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(
                dialogContext,
                _ReaderBookmarkEditResult(
                  bookText: bookTextController.text,
                  note: noteController.text,
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    bookTextController.dispose();
    noteController.dispose();
    return result;
  }

  String _resolveCurrentBookmarkText() {
    final pageText = _pageFactory.curPage.trim();
    if (pageText.isNotEmpty) {
      return pageText;
    }
    final content = _currentContent.trim();
    if (content.isEmpty) {
      return '';
    }
    final progress = _getChapterProgress().clamp(0.0, 1.0).toDouble();
    final center =
        (content.length * progress).round().clamp(0, content.length).toInt();
    final start = (center - 90).clamp(0, content.length).toInt();
    final end = (start + 180).clamp(0, content.length).toInt();
    return content.substring(start, end).trim();
  }

  String _composeBookmarkPreview({
    required String bookText,
    required String note,
  }) {
    final trimmedText = bookText.trim();
    final trimmedNote = note.trim();
    if (trimmedText.isEmpty) {
      return trimmedNote;
    }
    if (trimmedNote.isEmpty) {
      return trimmedText;
    }
    return '$trimmedText\n\n笔记：$trimmedNote';
  }

  int _encodeCurrentBookmarkChapterPos() {
    return (_getChapterProgress().clamp(0.0, 1.0) * 10000).round();
  }

  double _decodeBookmarkChapterProgress(int chapterPos) {
    return (chapterPos / 10000.0).clamp(0.0, 1.0).toDouble();
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

  String _normalizeReaderErrorMessage(Object error) {
    final raw = error.toString().trim();
    const stateErrorPrefix = 'Bad state:';
    if (raw.startsWith(stateErrorPrefix)) {
      final message = raw.substring(stateErrorPrefix.length).trim();
      return message.isEmpty ? raw : message;
    }
    return raw;
  }

  String _legacyUpdateTocErrorMessage({
    required bool isLocalBook,
    required Object error,
  }) {
    if (!isLocalBook) {
      return '加载目录失败';
    }
    final message = _normalizeReaderErrorMessage(error);
    if (message.isEmpty) {
      return 'LoadTocError:unknown';
    }
    if (message.startsWith('LoadTocError:')) {
      return message;
    }
    return 'LoadTocError:$message';
  }

  String _extractCatalogUpdateFailureReason(List<String> failedDetails) {
    if (failedDetails.isEmpty) return '加载目录失败';
    final raw = failedDetails.first.trim();
    final separatorIndex = raw.indexOf('：');
    if (separatorIndex <= -1 || separatorIndex >= raw.length - 1) {
      return raw.isEmpty ? '加载目录失败' : raw;
    }
    final reason = raw.substring(separatorIndex + 1).trim();
    return reason.isEmpty ? '加载目录失败' : reason;
  }

  String _resolveLocalBookFileExtension(Book book) {
    final localPath = (book.localPath ?? '').trim();
    if (localPath.isNotEmpty) {
      return p.extension(localPath).toLowerCase();
    }

    final rawBookUrl = (book.bookUrl ?? '').trim();
    if (rawBookUrl.isEmpty) return '';
    final uri = Uri.tryParse(rawBookUrl);
    if (uri != null && uri.hasScheme && uri.scheme == 'file') {
      final filePath = uri.toFilePath();
      if (filePath.trim().isNotEmpty) {
        return p.extension(filePath).toLowerCase();
      }
    }
    return p.extension(rawBookUrl).toLowerCase();
  }

  Future<void> _clearLocalCatalogCacheBeforeRefresh() async {
    if (!widget.isEphemeral) {
      await _chapterRepo.clearDownloadedCacheForBook(widget.bookId);
    }

    if (!mounted || _chapters.isEmpty) {
      return;
    }

    setState(() {
      _replaceStageCache.clear();
      _catalogDisplayTitleCacheByChapterId.clear();
      _chapterContentInFlight.clear();
      _chapters = _chapters
          .map(
            (chapter) => chapter.copyWith(
              isDownloaded: false,
              content: null,
            ),
          )
          .toList(growable: false);
    });
    _syncPageFactoryChapters(
      keepPosition: _settings.pageTurnMode != PageTurnMode.scroll,
    );
  }

  Future<List<Chapter>> _applyLocalRefreshedCatalog({
    required SearchBookInfoLocalRefreshResult refreshed,
  }) async {
    final newChapters = refreshed.chapters;
    if (newChapters.isEmpty) {
      throw StateError('LoadTocError:重解析后章节为空');
    }

    final previousRawTitle = _chapters.isEmpty
        ? _currentTitle
        : _chapters[_currentChapterIndex.clamp(0, _chapters.length - 1)].title;
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
        refreshed.book.copyWith(
          totalChapters: newChapters.length,
          latestChapter: newChapters.last.title,
          currentChapter: targetIndex,
        ),
      );
    }

    if (!mounted) return newChapters;
    setState(() {
      _bookAuthor = refreshed.book.author;
      _bookCoverUrl = refreshed.book.coverUrl;
      _replaceStageCache.clear();
      _catalogDisplayTitleCacheByChapterId.clear();
      _chapterContentInFlight.clear();
      _chapters = newChapters;
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
    });
    await _loadChapter(
      _clampChapterIndexToReadableRange(targetIndex),
      restoreOffset: true,
    );
    return newChapters;
  }

  Future<List<Chapter>> _refreshLocalCatalogFromSource(Book book) async {
    try {
      final extension = _resolveLocalBookFileExtension(book);
      if (extension == '.epub' || extension == '.mobi') {
        await _clearLocalCatalogCacheBeforeRefresh();
      }

      final preferredCharset = _readerCharsetService.getBookCharset(
            widget.bookId,
          ) ??
          ReaderCharsetService.defaultCharset;
      final refreshed = await SearchBookInfoRefreshHelper.refreshLocalBook(
        book: book,
        preferredTxtCharset: preferredCharset,
        splitLongChapter: _settingsService.getBookSplitLongChapter(
          widget.bookId,
        ),
        txtTocRuleRegex: _settingsService.getBookTxtTocRule(widget.bookId),
      );
      return _applyLocalRefreshedCatalog(refreshed: refreshed);
    } catch (error) {
      final message = _normalizeReaderErrorMessage(error);
      if (message.startsWith('LoadTocError:')) {
        throw StateError(message);
      }
      throw StateError(
        message.isEmpty ? 'LoadTocError:unknown' : 'LoadTocError:$message',
      );
    }
  }

  Future<List<Chapter>> _refreshCatalogFromSource() async {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null) {
      throw StateError('书籍信息不存在');
    }
    if (book.isLocal) {
      return _refreshLocalCatalogFromSource(book);
    }

    final summary = await _catalogUpdateService.updateBooks([book]);
    if (summary.failedCount > 0) {
      final reason = _extractCatalogUpdateFailureReason(summary.failedDetails);
      ExceptionLogService().record(
        node: 'reader.menu.update_toc.online_failed',
        message: '阅读页在线更新目录失败',
        error: reason,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'sourceUrl': _currentSourceUrl,
          'failedDetails': summary.failedDetails,
        },
      );
      throw StateError('加载目录失败');
    }
    if (summary.updateCandidateCount <= 0) {
      throw StateError('加载目录失败');
    }

    final updated = _chapterRepo.getChaptersForBook(widget.bookId);
    if (updated.isEmpty) {
      throw StateError('加载目录失败');
    }

    if (!mounted) return updated;

    final maxChapter = updated.length - 1;
    final refreshedBook = _bookRepo.getBookById(widget.bookId);
    setState(() {
      _chapters = updated;
      _currentChapterIndex = _currentChapterIndex.clamp(0, maxChapter).toInt();
      _currentTitle = _postProcessTitle(updated[_currentChapterIndex].title);
      if (refreshedBook != null) {
        _bookAuthor = refreshedBook.author;
        _bookCoverUrl = refreshedBook.coverUrl;
        _currentSourceUrl =
            (refreshedBook.sourceUrl ?? refreshedBook.sourceId ?? '').trim();
      }
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
    });
    _refreshCurrentSourceName();
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
        splitLongChapter: enabled,
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
    showCupertinoBottomSheetDialog(
      context: context,
      builder: (popupContext) => ReaderCatalogSheet(
        bookId: widget.bookId,
        bookTitle: widget.bookTitle,
        bookAuthor: _bookAuthor,
        coverUrl: _bookCoverUrl,
        chapters: _effectiveReadableChapters(),
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
          final progress = _decodeBookmarkChapterProgress(bookmark.chapterPos);
          _loadChapter(
            bookmark.chapterIndex,
            restoreOffset: true,
            targetChapterProgress: progress,
          );
        },
        onDeleteBookmark: (bookmark) async {
          await _bookmarkRepo.removeBookmark(bookmark.id);
          _updateBookmarkStatus();
        },
        onEditBookmark: (bookmark) async {
          await _openEditBookmarkDialog(bookmark);
        },
        isLocalTxtBook: _isCurrentBookLocalTxt(),
        initialUseReplace: _tocUiUseReplace,
        initialLoadWordCount: _tocUiLoadWordCount,
        initialSplitLongChapter: _tocUiSplitLongChapter,
        onUseReplaceChanged: (value) {
          _tocUiUseReplace = value;
          _catalogDisplayTitleCacheByChapterId.clear();
          unawaited(_settingsService.saveTocUiUseReplace(value));
        },
        onLoadWordCountChanged: (value) {
          _tocUiLoadWordCount = value;
          unawaited(_settingsService.saveTocUiLoadWordCount(value));
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
          Navigator.pop(popupContext);
          unawaited(_showTxtTocRuleDialogFromMenu());
        },
        initialDisplayTitlesByIndex: _buildCatalogInitialDisplayTitlesByIndex(),
        resolveDisplayTitle: _resolveCatalogDisplayTitle,
      ),
    );
  }

  /// 编辑书签（对标 legado BookmarkDialog）
  Future<void> _openEditBookmarkDialog(BookmarkEntity bookmark) async {
    final controller = TextEditingController(text: bookmark.content);
    final result = await showCupertinoBottomDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(bookmark.chapterTitle, maxLines: 1,
            overflow: TextOverflow.ellipsis),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '书签内容',
            maxLines: 4,
            minLines: 2,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await _bookmarkRepo.removeBookmark(bookmark.id);
              _updateBookmarkStatus();
              if (ctx.mounted) Navigator.pop(ctx, 'deleted');
            },
            child: const Text('删除'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, 'saved'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != 'saved') return;
    await _bookmarkRepo.addBookmark(
      bookId: bookmark.bookId,
      bookName: bookmark.bookName,
      bookAuthor: bookmark.bookAuthor,
      chapterIndex: bookmark.chapterIndex,
      chapterTitle: bookmark.chapterTitle,
      chapterPos: bookmark.chapterPos,
      content: controller.text.trim(),
    );
    _updateBookmarkStatus();
  }
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
              errorBuilder: (_, __, ___) => Icon(
                CupertinoIcons.photo,
                color: CupertinoColors.systemGrey.resolveFrom(context),
                size: 64,
              ),
            ),
          ),
        ),
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

class _ReaderOfflineCacheInput {
  final String startChapter;
  final String endChapter;

  const _ReaderOfflineCacheInput({
    required this.startChapter,
    required this.endChapter,
  });
}

class _ReaderOfflineCacheRange {
  final int startIndex;
  final int endIndex;

  const _ReaderOfflineCacheRange({
    required this.startIndex,
    required this.endIndex,
  });
}

enum _ReaderTextActionMenuAction {
  replace,
  copy,
  bookmark,
  readAloud,
  dict,
  searchContent,
  browser,
  share,
  processText,
  more,
  collapse,
}

enum _ReaderAudioPlayMenuAction {
  login,
  changeSource,
  copyAudioUrl,
  editSource,
  wakeLock,
  log,
}

class _DuplicateTitleRemovalResult {
  final String content;
  final bool removed;

  const _DuplicateTitleRemovalResult({
    required this.content,
    required this.removed,
  });
}

class _ReaderSimulatedReadingInput {
  final bool enabled;
  final String startChapter;
  final String dailyChapters;
  final DateTime startDate;

  const _ReaderSimulatedReadingInput({
    required this.enabled,
    required this.startChapter,
    required this.dailyChapters,
    required this.startDate,
  });
}

class _ReaderBookmarkDraft {
  final String chapterTitle;
  final int chapterPos;
  final String pageText;

  const _ReaderBookmarkDraft({
    required this.chapterTitle,
    required this.chapterPos,
    required this.pageText,
  });
}

class _ReaderBookmarkEditResult {
  final String bookText;
  final String note;

  const _ReaderBookmarkEditResult({
    required this.bookText,
    required this.note,
  });
}



class _TipOption {
  final int value;
  final String label;

  const _TipOption(this.value, this.label);
}

class _EffectiveReplaceMenuEntry {
  final String label;
  final ReplaceRule? rule;
  final bool isChineseConverter;

  const _EffectiveReplaceMenuEntry._({
    required this.label,
    required this.rule,
    required this.isChineseConverter,
  });

  const _EffectiveReplaceMenuEntry.rule({
    required String label,
    required ReplaceRule rule,
  }) : this._(
          label: label,
          rule: rule,
          isChineseConverter: false,
        );

  const _EffectiveReplaceMenuEntry.chineseConverter({
    required String label,
  }) : this._(
          label: label,
          rule: null,
          isChineseConverter: true,
        );
}

class _ReplaceStageCache {
  final String rawTitle;
  final String rawContent;
  final String title;
  final String content;
  final List<ReplaceRule> effectiveContentReplaceRules;

  const _ReplaceStageCache({
    required this.rawTitle,
    required this.rawContent,
    required this.title,
    required this.content,
    required this.effectiveContentReplaceRules,
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
  final int chapterIndex;
  final String chapterTitle;
  final int chapterContentLength;
  final int start;
  final int end;
  final String query;
  final int occurrenceIndex;
  final String previewBefore;
  final String previewMatch;
  final String previewAfter;
  final int? pageIndex;

  const _ReaderSearchHit({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.chapterContentLength,
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

class _ReaderSearchProgressSnapshot {
  final int chapterIndex;
  final double chapterProgress;

  const _ReaderSearchProgressSnapshot({
    required this.chapterIndex,
    required this.chapterProgress,
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

class _ScrollTipData {
  final String title;
  final String bookTitle;
  final double bookProgress;
  final double chapterProgress;
  final int currentPage;
  final int totalPages;
  final String currentTime;

  const _ScrollTipData({
    required this.title,
    required this.bookTitle,
    required this.bookProgress,
    required this.chapterProgress,
    required this.currentPage,
    required this.totalPages,
    required this.currentTime,
  });

  const _ScrollTipData.empty()
      : title = '',
        bookTitle = '',
        bookProgress = 0.0,
        chapterProgress = 0.0,
        currentPage = 1,
        totalPages = 1,
        currentTime = '';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ScrollTipData &&
        other.title == title &&
        other.bookTitle == bookTitle &&
        other.bookProgress == bookProgress &&
        other.chapterProgress == chapterProgress &&
        other.currentPage == currentPage &&
        other.totalPages == totalPages &&
        other.currentTime == currentTime;
  }

  @override
  int get hashCode => Object.hash(
        title,
        bookTitle,
        bookProgress,
        chapterProgress,
        currentPage,
        totalPages,
        currentTime,
      );
}
