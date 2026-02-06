import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'
    hide Slider; // 隐藏 Slider 以避免与 Cupertino 冲突
import 'package:flutter/services.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../bookshelf/models/book.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/reading_settings.dart';
import '../widgets/auto_pager.dart';
import '../widgets/bookmark_dialog.dart';
import '../widgets/click_action_config_dialog.dart';
import '../widgets/paged_reader_widget.dart';
import '../widgets/page_factory.dart';
import '../widgets/reader_menus.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_status_bar.dart';
import '../widgets/typography_settings_dialog.dart';
import '../widgets/reader_quick_settings_sheet.dart';

/// 简洁阅读器 - Cupertino 风格 (增强版)
class SimpleReaderView extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int initialChapter;

  const SimpleReaderView({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.initialChapter = 0,
  });

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
  final RuleParserEngine _ruleEngine = RuleParserEngine();

  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  String _currentContent = '';
  String _currentTitle = '';

  // 阅读设置
  late ReadingSettings _settings;

  // UI 状态
  bool _showMenu = false;
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
  final String _bookAuthor = '';
  String? _currentSourceUrl;

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

  // 章节加载锁（用于翻页模式）
  bool _isLoadingChapter = false;

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
    _settings = _settingsService.readingSettings;
    _autoPager.setSpeed(_settings.autoReadSpeed);
    _autoPager.setMode(_settings.pageTurnMode == PageTurnMode.scroll
        ? AutoPagerMode.scroll
        : AutoPagerMode.page);

    _currentChapterIndex = widget.initialChapter;
    _initReader();

    // 应用亮度设置（首帧后，避免部分机型窗口未就绪）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNativeBrightnessForSettings(
        const ReadingSettings(),
        _settings,
        force: true,
      );
    });

    // 初始化自动翻页器
    _autoPager.setScrollController(_scrollController);
    _autoPager.setOnNextPage(() {
      if (_currentChapterIndex < _chapters.length - 1) {
        _loadChapter(_currentChapterIndex + 1);
      }
    });

    // 全屏沉浸
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initReader() async {
    final book = _bookRepo.getBookById(widget.bookId);
    _currentSourceUrl = book?.sourceUrl ?? book?.sourceId;

    _chapters = _chapterRepo.getChaptersForBook(widget.bookId);
    if (_chapters.isNotEmpty) {
      if (_currentChapterIndex >= _chapters.length) {
        _currentChapterIndex = 0;
      }

      // 初始化 PageFactory：设置章节数据
      final chapterDataList = _chapters
          .map((c) => ChapterData(
                title: c.title,
                content: _postProcessContent(c.content ?? '', c.title),
              ))
          .toList();
      _pageFactory.setChapters(chapterDataList, _currentChapterIndex);

      // 监听章节变化
      _pageFactory.onContentChanged = () {
        if (mounted) {
          setState(() {
            _currentChapterIndex = _pageFactory.currentChapterIndex;
            _currentTitle = _pageFactory.currentChapterTitle;
          });
          _saveProgress();
        }
      };

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
    _saveProgress();
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    _autoPager.dispose();
    // 离开阅读器时恢复系统亮度（iOS 还原原始亮度；Android 还原窗口亮度为跟随系统）
    unawaited(_brightnessService.resetToSystem());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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
    unawaited(_brightnessService.setBrightness(newSettings.brightness));
  }

  /// 保存进度：章节 + 滚动偏移
  Future<void> _saveProgress() async {
    if (_chapters.isEmpty) return;

    final progress = (_currentChapterIndex + 1) / _chapters.length;

    // 保存到书籍库
    await _bookRepo.updateReadProgress(
      widget.bookId,
      currentChapter: _currentChapterIndex,
      readProgress: progress,
    );

    // 保存滚动偏移量
    if (_scrollController.hasClients) {
      await _settingsService.saveScrollOffset(
          widget.bookId, _scrollController.offset);
    }
  }

  Future<void> _loadChapter(int index,
      {bool restoreOffset = false, bool goToLastPage = false}) async {
    if (index < 0 || index >= _chapters.length) return;

    final book = _bookRepo.getBookById(widget.bookId);
    final chapter = _chapters[index];
    String content = chapter.content ?? '';

    if (content.isEmpty &&
        book != null &&
        !book.isLocal &&
        (chapter.url?.isNotEmpty ?? false)) {
      content = await _fetchChapterContent(book, chapter, index);
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
    });

    _syncPageFactoryChapters();

    // 如果是非滚动模式，需要在build后进行分页
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_settings.pageTurnMode != PageTurnMode.scroll) {
        _paginateContent();

        // 使用PageFactory跳转章节（自动处理goToLastPage）
        _pageFactory.jumpToChapter(index, goToLastPage: goToLastPage);
      }

      if (_scrollController.hasClients) {
        if (restoreOffset && _settings.pageTurnMode == PageTurnMode.scroll) {
          final offset = _settingsService.getScrollOffset(widget.bookId);
          if (offset > 0) {
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

    await _saveProgress();
  }

  void _syncPageFactoryChapters({bool keepPosition = false}) {
    final chapterDataList = _chapters
        .map((chapter) {
          final cached = _replaceStageCache[chapter.id];
          final title = cached?.title ?? chapter.title;
          final content = cached?.content ?? (chapter.content ?? '');
          return ChapterData(
            title: title,
            content: _postProcessContent(content, title),
          );
        })
        .toList();
    if (keepPosition) {
      _pageFactory.replaceChaptersKeepingPosition(chapterDataList);
    } else {
      _pageFactory.setChapters(chapterDataList, _currentChapterIndex);
    }
  }

  Future<String> _fetchChapterContent(
    Book book,
    Chapter chapter,
    int index,
  ) async {
    final sourceUrl = book.sourceUrl;
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return chapter.content ?? '';
    }
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) return chapter.content ?? '';

    if (mounted) {
      setState(() => _isLoadingChapter = true);
    }

    String content = chapter.content ?? '';
    try {
      content = await _ruleEngine.getContent(source, chapter.url ?? '');
      if (content.isNotEmpty) {
        await _chapterRepo.cacheChapterContent(chapter.id, content);
        _chapters[index] =
            chapter.copyWith(content: content, isDownloaded: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }

    return content;
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
    final contentWidth = screenWidth - _settings.paddingLeft - _settings.paddingRight;

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
        if (_scrollController.hasClients) {
          final max = _scrollController.position.maxScrollExtent;
          desiredChapterProgress =
              max <= 0 ? 0.0 : (_scrollController.offset / max).clamp(0.0, 1.0);
        } else {
          desiredChapterProgress = 0.0;
        }
      } else {
        final total = _pageFactory.totalPages;
        if (total <= 1) {
          desiredChapterProgress = 0.0;
        } else {
          desiredChapterProgress =
              (_pageFactory.currentPageIndex / (total - 1)).clamp(0.0, 1.0);
        }
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
              oldSettings.themeIndex != newSettings.themeIndex || // 主题变化可能影响字体? 暂时不用
              contentTransformChanged
          ) {
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
    unawaited(_settingsService.saveReadingSettings(newSettings));

    if (modeChanged) {
      final progress = desiredChapterProgress ?? 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (newMode == PageTurnMode.scroll) {
          if (!_scrollController.hasClients) return;
          final max = _scrollController.position.maxScrollExtent;
          if (max <= 0) return;
          final target = (progress * max).clamp(0.0, max).toDouble();
          _scrollController.jumpTo(target);
          return;
        }

        final total = _pageFactory.totalPages;
        if (total <= 1) return;
        final target = (progress * (total - 1)).round().clamp(0, total - 1);
        _pageFactory.jumpToPage(target);
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
    if (_showMenu) {
      setState(() => _showMenu = false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }
    final action = _resolveClickAction(details.globalPosition);
    _handleClickAction(action);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_settings.volumeKeyPage) return;
    if (_showMenu || _showAutoReadPanel) return;
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
    if (_showMenu || _showAutoReadPanel) return;
    if (_settings.pageTurnMode == PageTurnMode.scroll) return;
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 0) {
        _handlePageStep(next: true);
      } else if (event.scrollDelta.dy < 0) {
        _handlePageStep(next: false);
      }
    }
  }

  void _handlePageStep({required bool next}) {
    if (_settings.pageTurnMode == PageTurnMode.scroll) {
      _scrollPage(up: !next);
      return;
    }
    final moved =
        next ? _pageFactory.moveToNext() : _pageFactory.moveToPrev();
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
        setState(() => _showMenu = true);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
        setState(() => _showMenu = true);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  void _scrollPage({required bool up}) {
    if (!_scrollController.hasClients) return;

    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;
    final targetOffset = up
        ? currentOffset - viewportHeight + 40
        : currentOffset + viewportHeight - 40;

    // 如果到底了尝试下一章
    if (!up && targetOffset >= _scrollController.position.maxScrollExtent) {
      if (_currentChapterIndex < _chapters.length - 1) {
        _loadChapter(_currentChapterIndex + 1);
        return;
      }
    }

    // 如果到顶了尝试前一章
    if (up && currentOffset <= 0) {
      if (_currentChapterIndex > 0) {
        _loadChapter(_currentChapterIndex - 1);
        return;
      }
    }

    final clampedOffset = targetOffset
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
    if (!_scrollController.hasClients) return 0;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return 1.0;
    return (_scrollController.offset / max).clamp(0.0, 1.0);
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
      canPop: _showMenu,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_showMenu) {
          // 如果阻止了 pop 且菜单未显示，则显示菜单
          setState(() {
            _showMenu = true;
          });
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

                // 底部状态栏 - 只在滚动模式显示（翻页模式由PagedReaderWidget内部处理）
                if (_settings.showStatusBar &&
                    !_showMenu &&
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
                    onShowChapterList: _showChapterList,
                  ),

                // 底部菜单 (新版 Tab 导航)
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
                      // 跳转到指定页码
                      setState(() {
                        // PageFactory 内部管理页码
                        while (_pageFactory.currentPageIndex < pageIndex) {
                          if (!_pageFactory.moveToNext()) break;
                        }
                        while (_pageFactory.currentPageIndex > pageIndex) {
                          if (!_pageFactory.moveToPrev()) break;
                        }
                      });
                    },
                    onSettingsChanged: (settings) => _updateSettings(settings),
                    onShowChapterList: _showChapterList,
                    onShowTypography: () => _showQuickSettingsSheet(
                      initialTab: ReaderQuickSettingsTab.typography,
                    ),
                    onShowTheme: () => _showQuickSettingsSheet(
                      initialTab: ReaderQuickSettingsTab.theme,
                    ),
                    onShowPage: () => _showQuickSettingsSheet(
                      initialTab: ReaderQuickSettingsTab.page,
                    ),
                    onShowMore: _showMoreMenu,
                  ),

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
    final opacity = (1.0 - _settings.brightness).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: opacity),
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
      enableGestures: !_showMenu, // 菜单显示时禁止翻页手势
      onTap: () {
        setState(() {
          _showMenu = !_showMenu;
        });
        SystemChrome.setEnabledSystemUIMode(
          _showMenu ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
        );
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

  /// 滚动模式内容（按当前章节滚动）
  Widget _buildScrollContent() {
    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // 滚动结束时保存进度
          if (notification is ScrollEndNotification) {
            _saveProgress();
            setState(() {}); // 更新进度显示
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: _buildScrollChapterBody(),
        ),
      ),
    );
  }

  Widget _buildScrollChapterBody() {
    final paragraphs = _currentContent.split(RegExp(r'\n\s*\n|\n'));
    final paragraphStyle = TextStyle(
      fontSize: _settings.fontSize,
      height: _settings.lineHeight,
      color: _currentTheme.text,
      letterSpacing: _settings.letterSpacing,
      fontFamily: _currentFontFamily,
      fontWeight: _currentFontWeight,
      decoration: _currentTextDecoration,
    );
    final indent = _settings.paragraphIndent;
    final indentWidth =
        indent.isEmpty ? 0.0 : _measureTextWidth(indent, paragraphStyle);

    return Padding(
      padding: EdgeInsets.only(
        left: _settings.paddingLeft,
        right: _settings.paddingRight,
        top: _settings.paddingTop,
        bottom: _settings.showStatusBar ? 30 : _settings.paddingBottom,
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
              _currentTitle,
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
            if (paragraphText.trim().isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: EdgeInsets.only(bottom: _settings.paragraphSpacing),
              child: _buildParagraphWithFirstLineIndent(
                paragraphText,
                style: paragraphStyle,
                textAlign: _bodyTextAlign,
                indentWidth: indentWidth,
              ),
            );
          }),
          const SizedBox(height: 60),
          _buildChapterNav(_currentTheme.text),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// 根据滚动位置更新当前章节索引
  void _updateCurrentChapterFromScroll() {
    if (!_scrollController.hasClients || _chapters.isEmpty) return;

    // 使用 _lastBuiltChapterIndex 作为当前章节的估算
    // 因为 ListView.builder 优先构建首个可见 item
    if (_lastBuiltChapterIndex >= 0 &&
        _lastBuiltChapterIndex != _currentChapterIndex) {
      _currentChapterIndex = _lastBuiltChapterIndex;
      final chapter = _chapters[_currentChapterIndex];
      final cached = _replaceStageCache[chapter.id];
      final title = cached?.title ?? chapter.title;
      final content = cached?.content ?? (chapter.content ?? '');
      _currentTitle = title;
      _currentContent = _postProcessContent(content, title);
    }
  }

  // 追踪最后构建的章节索引（用于估算可见章节）
  int _lastBuiltChapterIndex = 0;

  /// 构建单个章节的内容 Widget
  Widget _buildChapterItem(int chapterIndex) {
    // 追踪当前构建的章节（ListView 优先构建首个可见 item）
    _lastBuiltChapterIndex = chapterIndex;

    final chapter = _chapters[chapterIndex];
    final cached = _replaceStageCache[chapter.id];
    final title = cached?.title ?? chapter.title;
    final content = _postProcessContent(
      cached?.content ?? (chapter.content ?? ''),
      title,
    );
    final paragraphs = content.split(RegExp(r'\n\s*\n|\n'));
    final paragraphStyle = TextStyle(
      fontSize: _settings.fontSize,
      height: _settings.lineHeight,
      color: _currentTheme.text,
      letterSpacing: _settings.letterSpacing,
      fontFamily: _currentFontFamily,
      fontWeight: _currentFontWeight,
      decoration: _currentTextDecoration,
    );
    final indent = _settings.paragraphIndent;
    final indentWidth = indent.isEmpty
        ? 0.0
        : _measureTextWidth(
            indent,
            paragraphStyle,
          );

    return Container(
      // 对每个章节使用 Key 以便追踪
      key: ValueKey('chapter_$chapterIndex'),
      padding: EdgeInsets.only(
        left: _settings.paddingLeft,
        right: _settings.paddingRight,
        top: chapterIndex == 0 ? _settings.paddingTop : 0,
        bottom: _settings.showStatusBar ? 30 : _settings.paddingBottom,
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
            // 章节标题
            Text(
              chapter.title,
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
          // 正文内容（参考 legado paragraphIndent 处理）
          ...paragraphs.map((paragraph) {
            final paragraphText = paragraph.trimRight();
            if (paragraphText.trim().isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: EdgeInsets.only(bottom: _settings.paragraphSpacing),
              child: _buildParagraphWithFirstLineIndent(
                paragraphText,
                style: paragraphStyle,
                textAlign: _bodyTextAlign,
                indentWidth: indentWidth,
              ),
            );
          }),
          // 章节分隔（不是最后一章）
          if (chapterIndex < _chapters.length - 1) ...[
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 100,
                height: 1,
                color: _currentTheme.text.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 40),
          ] else ...[
            // 最后一章显示导航
            const SizedBox(height: 60),
            _buildChapterNav(_currentTheme.text),
            const SizedBox(height: 100),
          ],
        ],
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

  double _measureTextWidth(String text, TextStyle style) {
    if (text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );
    painter.layout();
    return painter.width;
  }

  /// 段落渲染（首行缩进，对标 legado 的 `paragraphIndent` 体验）
  ///
  /// 说明：
  /// - 不依赖段首前导空格，避免在 `TextAlign.justify` 下出现“看起来不缩进”
  /// - 通过 `WidgetSpan(SizedBox(width))` 做首行缩进，后续换行仍顶格
  Widget _buildParagraphWithFirstLineIndent(
    String paragraph, {
    required TextStyle style,
    required TextAlign textAlign,
    required double indentWidth,
  }) {
    if (indentWidth <= 0) {
      return Text(
        paragraph,
        textAlign: textAlign,
        style: style,
      );
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: style,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SizedBox(width: indentWidth),
          ),
          TextSpan(text: paragraph),
        ],
      ),
    );
  }

  Widget _buildChapterNav(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentChapterIndex > 0)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _loadChapter(_currentChapterIndex - 1),
            child: Text('← 上一章',
                style: TextStyle(color: textColor.withValues(alpha: 0.6))),
          )
        else
          const SizedBox(),
        if (_currentChapterIndex < _chapters.length - 1)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _loadChapter(_currentChapterIndex + 1),
            child: Text('下一章 →',
                style: TextStyle(color: textColor.withValues(alpha: 0.6))),
          )
        else
          const SizedBox(),
      ],
    );
  }

  /// 更多菜单弹窗
  void _showMoreMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('更多选项',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              // 第一排
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMoreMenuItem(CupertinoIcons.square_grid_3x2, '点击', () {
                    Navigator.pop(context);
                    _showClickActionConfig();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.play_circle, '自动', () {
                    Navigator.pop(context);
                    _toggleAutoReadPanel();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.arrow_clockwise, '刷新', () {
                    Navigator.pop(context);
                    _refreshChapter();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.bookmark_solid, '书签列表', () {
                    Navigator.pop(context);
                    _showBookmarkDialog();
                  }),
                  _buildMoreMenuItem(
                      _hasBookmarkAtCurrent
                          ? CupertinoIcons.bookmark_fill
                          : CupertinoIcons.bookmark,
                      _hasBookmarkAtCurrent ? '删书签' : '加书签', () {
                    Navigator.pop(context);
                    _toggleBookmark();
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // 第二排 (设置)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMoreMenuItem(CupertinoIcons.settings, '更多设置', () {
                    Navigator.pop(context);
                    _showMoreSettingsSheet();
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // 取消按钮
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemGrey5,
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('取消', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: CupertinoColors.activeBlue.withValues(alpha: 0.3),
        child: Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: CupertinoColors.white, size: 26),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  /// 刷新当前章节
  void _refreshChapter() {
    _loadChapter(_currentChapterIndex);
    setState(() => _showMenu = false);
  }

  /// 显示综合界面设置面板
  void _showInterfaceSettingsSheet() {
    _showReadingSettingsSheet(initialTab: 0);
  }

  void _showQuickSettingsSheet({
    required ReaderQuickSettingsTab initialTab,
  }) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => ReaderQuickSettingsSheet(
        settings: _settings,
        themes: AppColors.readingThemes,
        initialTab: initialTab,
        onSettingsChanged: _updateSettings,
        onOpenFullSettings: () => _showReadingSettingsSheet(initialTab: 0),
      ),
    );
  }

  void _showReadingSettingsSheet({int initialTab = 0}) {
    int selectedTab = initialTab;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
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
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '阅读设置',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: CupertinoColors.systemGrey,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSettingsTabs(
                    selectedTab,
                    (value) {
                      setPopupState(() => selectedTab = value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
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


  Widget _buildSettingsTabs(int selectedTab, ValueChanged<int> onChanged) {
    Widget buildTab(String label, bool isSelected) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return CupertinoSlidingSegmentedControl<int>(
      groupValue: selectedTab,
      backgroundColor: Colors.white12,
      thumbColor: CupertinoColors.activeBlue,
      children: {
        0: buildTab('Aa', selectedTab == 0),
        1: buildTab('主题', selectedTab == 1),
        2: buildTab('翻页', selectedTab == 2),
        3: buildTab('更多', selectedTab == 3),
      },
      onValueChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
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
      case 10:
        return _buildQuickSettingsTab(setPopupState);
      case 11:
        return _buildFontSettingsTab(setPopupState);
      case 12:
        return _buildLayoutSettingsTab(setPopupState);
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
                          final hasIndent = _settings.paragraphIndent.isNotEmpty;
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('字体: ${_currentFontFamily ?? "系统默认"}',
                            style: const TextStyle(color: Colors.white)),
                        const Icon(CupertinoIcons.chevron_right,
                            color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: _settings.textBold,
                  backgroundColor: Colors.white12,
                  thumbColor: CupertinoColors.activeBlue,
                  children: const {
                    2: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text('细体',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    0: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text('正常',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text('粗体',
                          style: TextStyle(
                              color: Colors.white70,
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
                        label: '字距',
                        isActive: _settings.letterSpacing.abs() >= 0.1,
                        onTap: () => _showLetterSpacingPicker(setPopupState),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('高级排版与边距',
                            style: TextStyle(color: Colors.white)),
                        Icon(CupertinoIcons.chevron_right,
                            color: Colors.white54, size: 16),
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

  Future<void> _showLetterSpacingPicker(StateSetter setPopupState) async {
    final controller =
        TextEditingController(text: _settings.letterSpacing.toStringAsFixed(1));
    final result = await showCupertinoDialog<double>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('字距'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '-2.0 ~ 5.0',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('确定'),
            onPressed: () {
              final raw = double.tryParse(controller.text.trim());
              Navigator.pop(context, raw);
            },
          ),
        ],
      ),
    );
    if (result == null) return;
    _updateSettingsFromSheet(
      setPopupState,
      _settings.copyWith(letterSpacing: result.clamp(-2.0, 5.0)),
    );
  }

  /// 常用设置：把高频项放在一个页面里，避免“到处点来点去”。
  ///
  /// 设计目标：
  /// - 1 次打开就能调：字号 / 行距 / 段距 / 缩进 / 两端对齐 / 亮度 / 翻页模式
  Widget _buildQuickSettingsTab(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('quick'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            title: '排版（常用）',
            child: Column(
              children: [
                _buildSliderSetting(
                  '字号',
                  _settings.fontSize,
                  10,
                  40,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(fontSize: val),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '行距',
                  _settings.lineHeight,
                  1.0,
                  3.0,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(lineHeight: val),
                    );
                  },
                  displayFormat: (v) => v.toStringAsFixed(1),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '段距',
                  _settings.paragraphSpacing,
                  0,
                  50,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(paragraphSpacing: val),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleBtn(
                        label: '两端对齐',
                        isActive: _settings.textFullJustify,
                        onTap: () {
                          _updateSettingsFromSheet(
                            setPopupState,
                            _settings.copyWith(
                              textFullJustify: !_settings.textFullJustify,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggleBtn(
                        label: '段首缩进',
                        isActive: _settings.paragraphIndent.isNotEmpty,
                        onTap: () {
                          final hasIndent = _settings.paragraphIndent.isNotEmpty;
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
              ],
            ),
          ),
          _buildSettingsCard(
            title: '亮度与主题（常用）',
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.sun_min,
                        color: Colors.white54, size: 20),
                    Expanded(
                      child: CupertinoSlider(
                        value: _settings.brightness,
                        min: 0.0,
                        max: 1.0,
                        activeColor: CupertinoColors.activeBlue,
                        onChanged: (value) {
                          _updateSettingsFromSheet(
                            setPopupState,
                            _settings.copyWith(brightness: value),
                          );
                        },
                      ),
                    ),
                    const Icon(CupertinoIcons.sun_max,
                        color: Colors.white54, size: 20),
                  ],
                ),
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
                const SizedBox(height: 12),
                // 快捷主题：日间/夜间/护眼/纯黑
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppColors.dayTheme,
                    AppColors.nightTheme,
                    AppColors.sepiaTheme,
                    AppColors.amoledTheme,
                  ].map((theme) {
                    final index = AppColors.readingThemes.indexOf(theme);
                    final isSelected = _settings.themeIndex == index;
                    return ChoiceChip(
                      label: Text(theme.name),
                      selected: isSelected,
                      selectedColor: CupertinoColors.activeBlue,
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 13,
                      ),
                      onSelected: (selected) {
                        if (!selected) return;
                        if (index < 0) return;
                        _updateSettingsFromSheet(
                          setPopupState,
                          _settings.copyWith(themeIndex: index),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '翻页（常用）',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PageTurnMode.scroll,
                PageTurnMode.slide,
                PageTurnMode.simulation2,
                PageTurnMode.cover,
              ].map((mode) {
                final isSelected = _settings.pageTurnMode == mode;
                return ChoiceChip(
                  label: Text(mode.name),
                  selected: isSelected,
                  selectedColor: CupertinoColors.activeBlue,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                  ),
                  onSelected: (selected) {
                    if (!selected) return;
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(pageTurnMode: mode),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
                          color: isSelected
                              ? CupertinoColors.activeBlue
                              : Colors.white12,
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
                                color: CupertinoColors.activeBlue,
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
            title: '亮度',
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.sun_min,
                        color: Colors.white54, size: 20),
                    Expanded(
                      child: CupertinoSlider(
                        value: _settings.brightness,
                        min: 0.0,
                        max: 1.0,
                        activeColor: CupertinoColors.activeBlue,
                        onChanged: (value) {
                          _updateSettingsFromSheet(
                            setPopupState,
                            _settings.copyWith(brightness: value),
                          );
                        },
                      ),
                    ),
                    const Icon(CupertinoIcons.sun_max,
                        color: Colors.white54, size: 20),
                  ],
                ),
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
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFontSettingsTab(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('font'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            title: '字体',
            child: GestureDetector(
              onTap: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (ctx) => _buildFontSelectDialog(setPopupState),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('字体: ${_currentFontFamily ?? "系统默认"}',
                        style: const TextStyle(color: Colors.white)),
                    const Icon(CupertinoIcons.chevron_right,
                        color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ),
          ),
          _buildSettingsCard(
            title: '字号',
            child: Row(
              children: [
                _buildCircleBtn(Icons.remove, () {
                  if (_settings.fontSize > 10) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(fontSize: _settings.fontSize - 1),
                    );
                  }
                }),
                Expanded(
                  child: CupertinoSlider(
                    value: _settings.fontSize,
                    min: 10,
                    max: 40,
                    divisions: 30,
                    activeColor: CupertinoColors.activeBlue,
                    onChanged: (val) {
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(fontSize: val),
                      );
                    },
                  ),
                ),
                _buildCircleBtn(Icons.add, () {
                  if (_settings.fontSize < 40) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(fontSize: _settings.fontSize + 1),
                    );
                  }
                }),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${_settings.fontSize.toInt()}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '字距',
            child: _buildSliderSetting(
              '间距',
              _settings.letterSpacing,
              -2,
              5,
              (val) {
                _updateSettingsFromSheet(
                  setPopupState,
                  _settings.copyWith(letterSpacing: val),
                );
              },
              displayFormat: (v) => v.toStringAsFixed(1),
            ),
          ),
          _buildSettingsCard(
            title: '字形',
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _settings.textBold,
              backgroundColor: Colors.white12,
              thumbColor: CupertinoColors.activeBlue,
              children: const {
                2: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('细体',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('正常',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('粗体',
                      style: TextStyle(
                          color: Colors.white70,
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
          _buildSettingsCard(
            title: '装饰',
            child: _buildToggleBtn(
              label: '下划线',
              isActive: _settings.underline,
              onTap: () {
                _updateSettingsFromSheet(
                  setPopupState,
                  _settings.copyWith(underline: !_settings.underline),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLayoutSettingsTab(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('layout'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            title: '排版间距',
            child: Column(
              children: [
                _buildSliderSetting(
                  '行距',
                  _settings.lineHeight,
                  1.0,
                  3.0,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(lineHeight: val),
                    );
                  },
                  displayFormat: (v) => v.toStringAsFixed(1),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '段距',
                  _settings.paragraphSpacing,
                  0,
                  50,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(paragraphSpacing: val),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '对齐与缩进',
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleBtn(
                    label: '两端对齐',
                    isActive: _settings.textFullJustify,
                    onTap: () {
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(
                            textFullJustify: !_settings.textFullJustify),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleBtn(
                    label: '段首缩进',
                    isActive: _settings.paragraphIndent.isNotEmpty,
                    onTap: () {
                      final hasIndent = _settings.paragraphIndent.isNotEmpty;
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(
                            paragraphIndent: hasIndent ? '' : '　　'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '内容边距',
            child: Column(
              children: [
                _buildSliderSetting(
                  '左右',
                  _settings.paddingLeft,
                  0,
                  80,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(
                        paddingLeft: val,
                        paddingRight: val,
                        marginHorizontal: val,
                      ),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '上下',
                  _settings.paddingTop,
                  0,
                  80,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(
                        paddingTop: val,
                        paddingBottom: val,
                        marginVertical: val,
                      ),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
              ],
            ),
          ),
          _buildSettingsCard(
            title: '标题',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleBtn(
                        label: '居左',
                        isActive: _settings.titleMode == 0,
                        onTap: () {
                          _updateSettingsFromSheet(
                            setPopupState,
                            _settings.copyWith(titleMode: 0),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildToggleBtn(
                        label: '居中',
                        isActive: _settings.titleMode == 1,
                        onTap: () {
                          _updateSettingsFromSheet(
                            setPopupState,
                            _settings.copyWith(titleMode: 1),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildToggleBtn(
                        label: '隐藏',
                        isActive: _settings.titleMode == 2,
                        onTap: () {
                          _updateSettingsFromSheet(
                            setPopupState,
                            _settings.copyWith(titleMode: 2),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSliderSetting(
                  '字号',
                  (_settings.fontSize + _settings.titleSize)
                      .clamp(10, 50)
                      .toDouble(),
                  10,
                  50,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(
                        titleSize: (val - _settings.fontSize).toInt(),
                      ),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '上距',
                  _settings.titleTopSpacing,
                  0,
                  60,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(titleTopSpacing: val),
                    );
                  },
                  displayFormat: (v) => v.toInt().toString(),
                ),
                const SizedBox(height: 8),
                _buildSliderSetting(
                  '下距',
                  _settings.titleBottomSpacing,
                  0,
                  60,
                  (val) {
                    _updateSettingsFromSheet(
                      setPopupState,
                      _settings.copyWith(titleBottomSpacing: val),
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

  Widget _buildPageSettingsTab(StateSetter setPopupState) {
    return SingleChildScrollView(
      key: const ValueKey('page'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            title: '翻页模式',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PageTurnModeUi.values(current: _settings.pageTurnMode).map((mode) {
                final isSelected = _settings.pageTurnMode == mode;
                return ChoiceChip(
                  label: Text(
                    PageTurnModeUi.isHidden(mode) ? '${mode.name}（隐藏）' : mode.name,
                  ),
                  selected: isSelected,
                  selectedColor: CupertinoColors.activeBlue,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                  ),
                  onSelected: PageTurnModeUi.isHidden(mode)
                      ? null
                      : (selected) {
                    if (selected) {
                      _updateSettingsFromSheet(
                        setPopupState,
                        _settings.copyWith(pageTurnMode: mode),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
          _buildSettingsCard(
            title: '翻页手感',
            child: Column(
              children: [
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
                const SizedBox(height: 8),
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
          _buildSettingsCard(
            title: '按键',
            child: Column(
              children: [
                _buildSwitchRow('音量键翻页', _settings.volumeKeyPage, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(volumeKeyPage: value),
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
                _buildSwitchRow(
                    '显示章节进度', _settings.showChapterProgress, (value) {
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
              ],
            ),
          ),
          _buildSettingsCard(
            title: '页眉',
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
                  '左侧',
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
                  '中间',
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
                  '右侧',
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
              ],
            ),
          ),
          _buildSettingsCard(
            title: '页脚',
            child: Column(
              children: [
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
                  '左侧',
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
                  '中间',
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
                  '右侧',
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
            title: '其他',
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
                _buildSwitchRow('净化章节标题', _settings.cleanChapterTitle, (value) {
                  _updateSettingsFromSheet(
                    setPopupState,
                    _settings.copyWith(cleanChapterTitle: value),
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
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
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
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            Row(
              children: [
                Text(value,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.chevron_right,
                    color: Colors.white38, size: 14),
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
                      const Icon(CupertinoIcons.check_mark,
                          color: CupertinoColors.activeBlue),
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
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 13,
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white12,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildSliderSetting(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {String Function(double)? displayFormat}) {
    return Row(
      children: [
        SizedBox(
            width: 40,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Expanded(
          child: CupertinoSlider(
            value: value,
            min: min,
            max: max,
            activeColor: CupertinoColors.activeBlue,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
            width: 30,
            child: Text(
              displayFormat?.call(value) ?? value.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 13),
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
          color: isActive
              ? CupertinoColors.activeBlue.withValues(alpha: 0.2)
              : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive ? CupertinoColors.activeBlue : Colors.white10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: isActive ? CupertinoColors.activeBlue : Colors.white70,
                fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSelectDialog(StateSetter parentSetState) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text('选择字体',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: ReadingFontFamily.presets.length,
              itemBuilder: (ctx, index) {
                final font = ReadingFontFamily.presets[index];
                final isSelected = _settings.fontFamilyIndex == index;
                return ListTile(
                  title: Text(font.name,
                      style: TextStyle(
                          color: isSelected
                              ? CupertinoColors.activeBlue
                              : Colors.white)),
                  trailing: isSelected
                      ? const Icon(CupertinoIcons.checkmark,
                          color: CupertinoColors.activeBlue)
                      : null,
                  onTap: () {
                    _updateSettings(_settings.copyWith(fontFamilyIndex: index));
                    parentSetState(() {}); // Ensure sheet updates
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 显示更多设置
  void _showMoreSettingsSheet() {
    _showReadingSettingsSheet(initialTab: 3);
  }

  Widget _buildSwitchRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: CupertinoColors.activeBlue,
          ),
        ],
      ),
    );
  }

  /// 显示书签列表
  void _showBookmarkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookmarkDialog(
        bookId: widget.bookId,
        bookName: widget.bookTitle,
        bookAuthor: _bookAuthor,
        currentChapter: _currentChapterIndex,
        currentChapterTitle: _currentTitle,
        repository: _bookmarkRepo,
        onJumpTo: (chapterIndex, chapterPos) {
          _loadChapter(chapterIndex);
        },
      ),
    );
  }

  /// 切换当前位置的书签
  Future<void> _toggleBookmark() async {
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
  }

  /// 更新书签状态
  void _updateBookmarkStatus() {
    setState(() {
      _hasBookmarkAtCurrent =
          _bookmarkRepo.hasBookmark(widget.bookId, _currentChapterIndex);
    });
  }

  /// 显示自动阅读面板
  void _toggleAutoReadPanel() {
    setState(() {
      _showAutoReadPanel = !_showAutoReadPanel;
      _showMenu = false;
      if (_showAutoReadPanel) {
        _autoPager.start();
      } else {
        _autoPager.stop();
      }
    });
  }

  /// 显示点击区域配置
  void _showClickActionConfig() {
    showClickActionConfigDialog(
      context,
      currentConfig: _settings.clickActions,
      onSave: (newConfig) {
        _updateSettings(_settings.copyWith(clickActions: newConfig));
      },
    );
  }

  void _showChapterList() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _ChapterListSheet(
        bookTitle: widget.bookTitle,
        bookAuthor: _bookAuthor,
        chapters: _chapters,
        currentChapterIndex: _currentChapterIndex,
        onChapterTap: (index) {
          Navigator.pop(context);
          _loadChapter(index);
        },
      ),
    );
  }
}

/// 目录面板 - 参考 Legado 设计
class _ChapterListSheet extends StatefulWidget {
  final String bookTitle;
  final String bookAuthor;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onChapterTap;

  const _ChapterListSheet({
    required this.bookTitle,
    required this.bookAuthor,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterTap,
  });

  @override
  State<_ChapterListSheet> createState() => _ChapterListSheetState();
}

class _ChapterListSheetState extends State<_ChapterListSheet> {
  int _selectedTab = 0; // 0=目录, 1=书签, 2=笔记
  bool _isReversed = false; // 倒序排列
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // 初始滚动到当前章节位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentChapter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentChapter() {
    final index = _isReversed
        ? widget.chapters.length - 1 - widget.currentChapterIndex
        : widget.currentChapterIndex;
    if (index > 0 && index < widget.chapters.length) {
      _scrollController.animateTo(
        index * 56.0, // 估算每个 item 高度
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<Chapter> get _filteredChapters {
    var chapters = widget.chapters;
    if (_searchQuery.isNotEmpty) {
      chapters = chapters
          .where(
              (c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_isReversed) {
      chapters = chapters.reversed.toList();
    }
    return chapters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F5), // Legado 风格的暖色背景
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖动指示器
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 顶部书籍信息
          _buildHeader(),

          // Tab 栏
          _buildTabBar(),

          // 搜索和排序
          _buildSearchAndSort(),

          // 内容区
          Expanded(
            child: _selectedTab == 0
                ? _buildChapterList()
                : _buildEmptyTab(_selectedTab == 1 ? '暂无书签' : '暂无笔记'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 书封（占位）
          Container(
            width: 50,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E4DF),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black12),
            ),
            child: const Center(
              child: Icon(CupertinoIcons.book, color: Colors.black38, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          // 书名和作者
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bookTitle,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.bookAuthor.isNotEmpty ? widget.bookAuthor : '未知作者',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共${widget.chapters.length}章',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Row(
        children: [
          _buildTab(0, '目录'),
          _buildTab(1, '书签'),
          _buildTab(2, '笔记'),
          const Spacer(),
          // 删除缓存、检查更新按钮
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: () {},
            child: const Icon(CupertinoIcons.trash,
                size: 20, color: Color(0xFF666666)),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: () {},
            child: const Icon(CupertinoIcons.arrow_clockwise,
                size: 20, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? const Color(0xFF4CAF50) : const Color(0xFF666666),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 搜索框
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CupertinoTextField(
                controller: _searchController,
                placeholder: '输入关键字搜索目录',
                placeholderStyle:
                    const TextStyle(color: Color(0xFF999999), fontSize: 13),
                style: const TextStyle(color: Color(0xFF333333), fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: null,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(CupertinoIcons.search,
                      size: 16, color: Color(0xFF999999)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          // 排序按钮
          CupertinoButton(
            padding: const EdgeInsets.only(left: 12),
            onPressed: () {
              setState(() => _isReversed = !_isReversed);
            },
            child: Icon(
              _isReversed ? CupertinoIcons.sort_up : CupertinoIcons.sort_down,
              size: 22,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    final chapters = _filteredChapters;
    if (chapters.isEmpty) {
      return _buildEmptyTab('无匹配章节');
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final originalIndex = _isReversed
            ? widget.chapters.length - 1 - widget.chapters.indexOf(chapter)
            : widget.chapters.indexOf(chapter);
        final isCurrent = originalIndex == widget.currentChapterIndex;

        return GestureDetector(
          onTap: () => widget.onChapterTap(widget.chapters.indexOf(chapter)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    chapter.title,
                    style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF333333),
                      fontSize: 14,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrent)
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: Color(0xFF4CAF50),
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyTab(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.doc_text,
              size: 48, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
          ),
        ],
      ),
    );
  }
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
