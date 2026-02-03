import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, Slider, showModalBottomSheet, Material, InkWell;
import 'package:flutter/services.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../bookshelf/models/book.dart';
import '../models/reading_settings.dart';
import '../widgets/auto_pager.dart';
import '../widgets/bookmark_dialog.dart';
import '../widgets/click_action_config_dialog.dart';
import '../widgets/paged_reader_widget.dart';
import '../widgets/page_factory.dart';

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
  late final SettingsService _settingsService;

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

  // 书签系统
  late final BookmarkRepository _bookmarkRepo;
  bool _hasBookmarkAtCurrent = false;

  // 自动阅读
  final AutoPager _autoPager = AutoPager();
  bool _showAutoReadPanel = false;

  // 当前书籍信息
  final String _bookAuthor = '';

  // 翻页模式相关（对标 Legado PageFactory）
  final PageFactory _pageFactory = PageFactory();

  @override
  void initState() {
    super.initState();
    _chapterRepo = ChapterRepository(DatabaseService());
    _bookRepo = BookRepository(DatabaseService());
    _bookmarkRepo = BookmarkRepository();
    _settingsService = SettingsService();
    _settings = _settingsService.readingSettings;

    _currentChapterIndex = widget.initialChapter;
    _initReader();

    // 初始化自动翻页器
    _autoPager.setScrollController(_scrollController);
    _autoPager.setOnNextPage(() {
      if (_currentChapterIndex < _chapters.length - 1) {
        _loadChapter(_currentChapterIndex + 1);
      }
    });

    // 全屏沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initReader() async {
    _chapters = _chapterRepo.getChaptersForBook(widget.bookId);
    if (_chapters.isNotEmpty) {
      if (_currentChapterIndex >= _chapters.length) {
        _currentChapterIndex = 0;
      }

      // 初始化 PageFactory：设置章节数据
      final chapterDataList = _chapters
          .map((c) => ChapterData(
                title: c.title,
                content: c.content ?? '',
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
    _autoPager.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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

    setState(() {
      _currentChapterIndex = index;
      _currentTitle = _chapters[index].title;
      _currentContent = _chapters[index].content ?? '';
    });

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

  /// 将内容分页（使用 PageFactory 对标 Legado）
  void _paginateContent() {
    if (!mounted) return;

    // 获取屏幕可用尺寸（对标 flutter_reader fetchArticle）
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeArea = MediaQuery.of(context).padding;

    // 对标 flutter_reader 的布局计算
    const topOffset = 37.0;
    const bottomOffset = 37.0;

    final contentHeight = screenHeight -
        safeArea.top -
        topOffset -
        safeArea.bottom -
        bottomOffset -
        8.0; // Small buffer for descents/snapping
    final contentWidth =
        screenWidth - _settings.marginHorizontal - _settings.marginHorizontal;

    // 使用 PageFactory 进行三章节分页（对标 Legado）
    _pageFactory.setLayoutParams(
      contentHeight: contentHeight,
      contentWidth: contentWidth,
      fontSize: _settings.fontSize,
      lineHeight: _settings.lineHeight,
      letterSpacing: _settings.letterSpacing,
      fontFamily: _currentFontFamily,
    );
    _pageFactory.paginateAll();

    // 保留兼容滚动模式
    setState(() {
    });
  }

  /// 更新设置
  void _updateSettings(ReadingSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    _settingsService.saveReadingSettings(newSettings);
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

  /// 左右点击翻页处理
  void _handleTap(TapUpDetails details) {
    if (_showMenu) {
      setState(() => _showMenu = false);
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth / 3) {
      // 点击左侧：向上翻页
      _scrollPage(up: true);
    } else if (tapX > screenWidth * 2 / 3) {
      // 点击右侧：向下翻页
      _scrollPage(up: false);
    } else {
      // 点击中间：显示菜单
      setState(() => _showMenu = true);
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

    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// 获取当前时间字符串
  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// 计算章节内进度
  double _getChapterProgress() {
    if (!_scrollController.hasClients) return 0;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return 1.0;
    return (_scrollController.offset / max).clamp(0.0, 1.0);
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
                  _buildStatusBar(),

                // 顶部菜单
                if (_showMenu) _buildTopMenu(),

                // 底部菜单
                if (_showMenu) _buildBottomMenu(),

                // 自动阅读控制面板
                if (_showAutoReadPanel)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AutoReadPanel(
                      autoPager: _autoPager,
                      onClose: () {
                        setState(() {
                          _showAutoReadPanel = false;
                        });
                      },
                    ),
                  ),
              ],
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
      ),
      backgroundColor: _currentTheme.background,
      padding: EdgeInsets.symmetric(horizontal: _settings.marginHorizontal),
      onTap: () {
        setState(() {
          _showMenu = !_showMenu;
        });
      },
      showStatusBar: _settings.showStatusBar,
      // 翻页动画增强参数
      animDuration: _settings.pageAnimDuration,
      pageDirection: _settings.pageDirection,
      pageTouchSlop: _settings.pageTouchSlop,
      simulationClickBias: _settings.simulationClickBias,
    );
  }

  /// 滚动模式内容
  Widget _buildScrollContent() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: _settings.marginHorizontal,
          right: _settings.marginHorizontal,
          top: _settings.marginVertical,
          bottom: _settings.showStatusBar ? 30 : _settings.marginVertical,
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              setState(() {}); // 更新进度显示
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // 章节标题
                Text(
                  _currentTitle,
                  style: TextStyle(
                    fontSize: _settings.fontSize + 6,
                    fontWeight: FontWeight.bold,
                    color: _currentTheme.text,
                    fontFamily: _currentFontFamily,
                  ),
                ),
                SizedBox(height: _settings.paragraphSpacing * 1.5),
                // 正文内容
                _buildFormattedContent(),
                const SizedBox(height: 60),
                _buildChapterNav(_currentTheme.text),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建格式化的正文内容（支持段落间距）
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

  /// 底部状态栏
  Widget _buildStatusBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 4,
          top: 4,
          left: _settings.marginHorizontal,
          right: _settings.marginHorizontal,
        ),
        color: _currentTheme.background,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 时间
            if (_settings.showTime)
              Text(
                _getCurrentTime(),
                style: TextStyle(
                  color: _currentTheme.text.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            // 章节标题（缩略）
            Expanded(
              child: Text(
                _currentTitle,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _currentTheme.text.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ),
            // 进度
            if (_settings.showProgress)
              Text(
                '${(_getChapterProgress() * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _currentTheme.text.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
          ],
        ),
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

  Widget _buildTopMenu() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.85),
        ),
        child: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.transparent,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child:
                const Icon(CupertinoIcons.back, color: CupertinoColors.white),
          ),
          middle: Text(
            widget.bookTitle,
            style: const TextStyle(color: CupertinoColors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showChapterList,
            child: const Icon(CupertinoIcons.list_bullet,
                color: CupertinoColors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomMenu() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 12,
          left: 8,
          right: 8,
        ),
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildNavBtn(
                      CupertinoIcons.chevron_left,
                      _currentChapterIndex > 0
                          ? () => _loadChapter(_currentChapterIndex - 1)
                          : null),
                  Expanded(
                    child: Text(
                      '${_currentChapterIndex + 1} / ${_chapters.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: CupertinoColors.systemGrey, fontSize: 13),
                    ),
                  ),
                  _buildNavBtn(
                      CupertinoIcons.chevron_right,
                      _currentChapterIndex < _chapters.length - 1
                          ? () => _loadChapter(_currentChapterIndex + 1)
                          : null),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 主要按钮 - 单排5个
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMenuBtn(
                    CupertinoIcons.list_bullet, '目录', _showChapterList),
                _buildMenuBtn(
                    _hasBookmarkAtCurrent
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    '书签',
                    _toggleBookmark),
                _buildMenuBtn(
                    CupertinoIcons.textformat_size, '字体', _showFontSheet),
                _buildMenuBtn(CupertinoIcons.moon, '主题', _showThemeSheet),
                _buildMenuBtn(
                    CupertinoIcons.ellipsis_circle, '更多', _showMoreMenu),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 导航按钮（上一章/下一章）
  Widget _buildNavBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: onTap != null
                ? CupertinoColors.white
                : CupertinoColors.systemGrey,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: CupertinoColors.activeBlue.withValues(alpha: 0.3),
        highlightColor: CupertinoColors.activeBlue.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: CupertinoColors.white, size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: CupertinoColors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
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
                  _buildMoreMenuItem(CupertinoIcons.brightness, '亮度', () {
                    Navigator.pop(context);
                    _showBrightnessSheet();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.book, '翻页', () {
                    Navigator.pop(context);
                    _showPageTurnModeSheet();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.slider_horizontal_3, '排版',
                      () {
                    Navigator.pop(context);
                    _showLayoutSheet();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.settings, '设置', () {
                    Navigator.pop(context);
                    _showMoreSettingsSheet();
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // 第二排
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMoreMenuItem(CupertinoIcons.play_circle, '自动', () {
                    Navigator.pop(context);
                    _toggleAutoReadPanel();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.square_grid_3x2, '点击', () {
                    Navigator.pop(context);
                    _showClickActionConfig();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.arrow_clockwise, '刷新', () {
                    Navigator.pop(context);
                    _refreshChapter();
                  }),
                  _buildMoreMenuItem(CupertinoIcons.bookmark_solid, '书签列表', () {
                    Navigator.pop(context);
                    _showBookmarkDialog();
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

  /// 显示亮度调节
  void _showBrightnessSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('亮度调节',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(CupertinoIcons.sun_min,
                        color: Colors.white54, size: 20),
                    Expanded(
                      child: Slider(
                        value: _settings.brightness,
                        min: 0.1,
                        max: 1.0,
                        activeColor: CupertinoColors.activeBlue,
                        inactiveColor: Colors.white24,
                        onChanged: (value) {
                          _updateSettings(
                              _settings.copyWith(brightness: value));
                          setPopupState(() {});
                        },
                      ),
                    ),
                    const Icon(CupertinoIcons.sun_max_fill,
                        color: Colors.white, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('跟随系统',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    CupertinoSwitch(
                      value: _settings.useSystemBrightness,
                      activeTrackColor: CupertinoColors.activeBlue,
                      onChanged: (value) {
                        _updateSettings(
                            _settings.copyWith(useSystemBrightness: value));
                        setPopupState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '注：亮度调节功能需要原生插件支持',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示字体设置
  void _showFontSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('字体设置',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                // 字体大小
                const Text('字体大小',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onPressed: () {
                        if (_settings.fontSize > 12) {
                          _updateSettings(_settings.copyWith(
                              fontSize: _settings.fontSize - 2));
                          setPopupState(() {});
                        }
                      },
                      child: const Text('A-',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                    Expanded(
                      child: Slider(
                        value: _settings.fontSize,
                        min: 12,
                        max: 32,
                        divisions: 10,
                        activeColor: CupertinoColors.activeBlue,
                        inactiveColor: Colors.white24,
                        onChanged: (value) {
                          _updateSettings(_settings.copyWith(fontSize: value));
                          setPopupState(() {});
                        },
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onPressed: () {
                        if (_settings.fontSize < 32) {
                          _updateSettings(_settings.copyWith(
                              fontSize: _settings.fontSize + 2));
                          setPopupState(() {});
                        }
                      },
                      child: const Text('A+',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 字体选择
                const Text('字体',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      List.generate(ReadingFontFamily.presets.length, (index) {
                    final font = ReadingFontFamily.presets[index];
                    final isSelected = _settings.fontFamilyIndex == index;
                    return GestureDetector(
                      onTap: () {
                        _updateSettings(
                            _settings.copyWith(fontFamilyIndex: index));
                        setPopupState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CupertinoColors.activeBlue
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          font.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示主题选择
  void _showThemeSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('阅读主题',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      List.generate(AppColors.readingThemes.length, (index) {
                    final theme = AppColors.readingThemes[index];
                    final isSelected = _settings.themeIndex == index;
                    return GestureDetector(
                      onTap: () {
                        _updateSettings(_settings.copyWith(themeIndex: index));
                        setPopupState(() {});
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: CupertinoColors.activeBlue, width: 3)
                              : Border.all(color: Colors.white24),
                        ),
                        child: Center(
                          child: Text(
                            theme.name,
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示翻页方式选择
  void _showPageTurnModeSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('翻页设置',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // 翻页模式
                  const Text('翻页模式',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: PageTurnMode.values.map((mode) {
                      final isSelected = _settings.pageTurnMode == mode;
                      return GestureDetector(
                        onTap: () {
                          _updateSettings(_settings.copyWith(pageTurnMode: mode));
                          setPopupState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CupertinoColors.activeBlue
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(mode.icon,
                                  color:
                                      isSelected ? Colors.white : Colors.white70,
                                  size: 18),
                              const SizedBox(width: 8),
                              Text(
                                mode.name,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 翻页方向
                  const Text('翻页方向',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: PageDirection.values.map((direction) {
                      final isSelected = _settings.pageDirection == direction;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            _updateSettings(_settings.copyWith(pageDirection: direction));
                            setPopupState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? CupertinoColors.activeBlue
                                  : Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(direction.icon,
                                    color: isSelected ? Colors.white : Colors.white70,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  direction.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 动画时长
                  _buildSliderRow(
                    '动画时长',
                    _settings.pageAnimDuration.toDouble(),
                    100,
                    600,
                    (value) {
                      _updateSettings(_settings.copyWith(pageAnimDuration: value.toInt()));
                      setPopupState(() {});
                    },
                    displayValue: '${_settings.pageAnimDuration}ms',
                  ),
                  const SizedBox(height: 16),

                  // 翻页灵敏度
                  _buildSliderRow(
                    '翻页灵敏度',
                    _settings.pageTouchSlop.toDouble(),
                    10,
                    50,
                    (value) {
                      _updateSettings(_settings.copyWith(pageTouchSlop: value.toInt()));
                      setPopupState(() {});
                    },
                    displayValue: '${_settings.pageTouchSlop}%',
                  ),
                  const SizedBox(height: 16),

                  // 仿真翻页角度偏转
                  if (_settings.pageTurnMode == PageTurnMode.simulation) ...[
                    _buildSliderRow(
                      '点击翻页角度',
                      _settings.simulationClickBias,
                      0.8,
                      1.0,
                      (value) {
                        _updateSettings(
                            _settings.copyWith(simulationClickBias: value));
                        setPopupState(() {});
                      },
                      displayValue: _settings.simulationClickBias.toStringAsFixed(2),
                    ),
                    const Text('值越接近 1.0 越垂直，越小角度越大',
                        style: TextStyle(color: Colors.white30, fontSize: 10)),
                    const SizedBox(height: 16),
                  ],

                  // 滚动模式无动画
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('滚动模式无动画翻页',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      CupertinoSwitch(
                        value: _settings.noAnimScrollPage,
                        onChanged: (value) {
                          _updateSettings(_settings.copyWith(noAnimScrollPage: value));
                          setPopupState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 音量键翻页
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('音量键翻页',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      CupertinoSwitch(
                        value: _settings.volumeKeyPage,
                        onChanged: (value) {
                          _updateSettings(_settings.copyWith(volumeKeyPage: value));
                          setPopupState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 鼠标滚轮翻页
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('鼠标滚轮翻页',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      CupertinoSwitch(
                        value: _settings.mouseWheelPage,
                        onChanged: (value) {
                          _updateSettings(_settings.copyWith(mouseWheelPage: value));
                          setPopupState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示排版设置
  void _showLayoutSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('排版设置',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                // 行距
                _buildSliderRow(
                  '行距',
                  _settings.lineHeight,
                  1.2,
                  3.0,
                  (value) {
                    _updateSettings(_settings.copyWith(lineHeight: value));
                    setPopupState(() {});
                  },
                  displayValue: _settings.lineHeight.toStringAsFixed(1),
                ),
                const SizedBox(height: 16),
                // 段距
                _buildSliderRow(
                  '段落间距',
                  _settings.paragraphSpacing,
                  0,
                  48,
                  (value) {
                    _updateSettings(
                        _settings.copyWith(paragraphSpacing: value));
                    setPopupState(() {});
                  },
                  displayValue: '${_settings.paragraphSpacing.toInt()}',
                ),
                const SizedBox(height: 16),
                // 左右边距
                _buildSliderRow(
                  '左右边距',
                  _settings.marginHorizontal,
                  8,
                  48,
                  (value) {
                    _updateSettings(
                        _settings.copyWith(marginHorizontal: value));
                    setPopupState(() {});
                  },
                  displayValue: '${_settings.marginHorizontal.toInt()}',
                ),
                const SizedBox(height: 16),
                // 上下边距
                _buildSliderRow(
                  '上下边距',
                  _settings.marginVertical,
                  8,
                  48,
                  (value) {
                    _updateSettings(_settings.copyWith(marginVertical: value));
                    setPopupState(() {});
                  },
                  displayValue: '${_settings.marginVertical.toInt()}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String? displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text(displayValue ?? value.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: CupertinoColors.activeBlue,
          inactiveColor: Colors.white24,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 显示更多设置
  void _showMoreSettingsSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text('更多设置',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSwitchRow('显示状态栏', _settings.showStatusBar, (value) {
                  _updateSettings(_settings.copyWith(showStatusBar: value));
                  setPopupState(() {});
                }),
                _buildSwitchRow('显示时间', _settings.showTime, (value) {
                  _updateSettings(_settings.copyWith(showTime: value));
                  setPopupState(() {});
                }),
                _buildSwitchRow('显示进度', _settings.showProgress, (value) {
                  _updateSettings(_settings.copyWith(showProgress: value));
                  setPopupState(() {});
                }),
                _buildSwitchRow('屏幕常亮', _settings.keepScreenOn, (value) {
                  _updateSettings(_settings.copyWith(keepScreenOn: value));
                  setPopupState(() {});
                }),
              ],
            ),
          ),
        ),
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
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('目录',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == _currentChapterIndex;
                  return CupertinoListTile(
                    title: Text(_chapters[index].title,
                        style: TextStyle(
                            color: isCurrent
                                ? CupertinoColors.activeBlue
                                : Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _loadChapter(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
