import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    hide Slider; // 隐藏 Slider 以避免与 Cupertino 冲突
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
import '../widgets/reader_menus.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_status_bar.dart';

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

  // 章节加载锁（用于翻页模式）
  // ignore: unused_field
  final bool _isLoadingChapter = false;

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

    // 全屏沉浸
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
    const topOffset = 37.0;
    const bottomOffset = 37.0;

    final contentHeight = screenHeight -
        safeArea.top -
        topOffset -
        safeArea.bottom -
        bottomOffset -
        8.0;
    final contentWidth =
        screenWidth - _settings.marginHorizontal - _settings.marginHorizontal;

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
    );
    _pageFactory.paginateAll();
  }

  /// 更新设置
  void _updateSettings(ReadingSettings newSettings) {
    // 检查是否需要重新分页
    // 1. 从滚动模式切换到翻页模式
    // 2. 也是翻页模式且排版参数变更
    bool needRepaginate = false;

    if (_settings.pageTurnMode == PageTurnMode.scroll &&
        newSettings.pageTurnMode != PageTurnMode.scroll) {
      needRepaginate = true;
    } else if (newSettings.pageTurnMode != PageTurnMode.scroll) {
      if (_settings.fontSize != newSettings.fontSize ||
              _settings.lineHeight != newSettings.lineHeight ||
              _settings.letterSpacing != newSettings.letterSpacing ||
              _settings.paragraphSpacing !=
                  newSettings.paragraphSpacing || // 监听段间距变化
              _settings.marginHorizontal != newSettings.marginHorizontal ||
              // fontFamily 变化通常意味着需要全量刷新，但也需要重排
              _settings.themeIndex != newSettings.themeIndex // 主题变化可能影响字体? 暂时不用
          ) {
        needRepaginate = true;
      }
    }

    setState(() {
      _settings = newSettings;
      if (needRepaginate) {
        _paginateContentLogicOnly();
      }
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
                  ReaderStatusBar(
                    settings: _settings,
                    currentTheme: _currentTheme,
                    currentTime: _getCurrentTime(),
                    title: _currentTitle,
                    progress: _getChapterProgress(),
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
                    onShowInterfaceSettings: _showInterfaceSettingsSheet,
                    onShowMoreMenu: _showMoreMenu,
                  ),

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
      enableGestures: !_showMenu, // 菜单显示时禁止翻页手势
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
    );
  }

  /// 滚动模式内容 - 使用 ListView.builder 实现章节丝滑连接
  Widget _buildScrollContent() {
    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // 滚动时实时更新当前章节索引
          if (notification is ScrollUpdateNotification) {
            _updateCurrentChapterFromScroll();
          }
          // 滚动结束时保存进度
          if (notification is ScrollEndNotification) {
            _saveProgress();
            setState(() {}); // 更新进度显示
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          // 预加载前后 2 个章节的内容
          cacheExtent: MediaQuery.of(context).size.height * 3,
          itemCount: _chapters.length,
          itemBuilder: (context, index) {
            return _buildChapterItem(index);
          },
        ),
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
      _currentTitle = _chapters[_currentChapterIndex].title;
      _currentContent = _chapters[_currentChapterIndex].content ?? '';
    }
  }

  // 追踪最后构建的章节索引（用于估算可见章节）
  int _lastBuiltChapterIndex = 0;

  /// 构建单个章节的内容 Widget
  Widget _buildChapterItem(int chapterIndex) {
    // 追踪当前构建的章节（ListView 优先构建首个可见 item）
    _lastBuiltChapterIndex = chapterIndex;

    final chapter = _chapters[chapterIndex];
    final content = chapter.content ?? '';
    final paragraphs = content.split(RegExp(r'\n\s*\n|\n'));

    return Container(
      // 对每个章节使用 Key 以便追踪
      key: ValueKey('chapter_$chapterIndex'),
      padding: EdgeInsets.only(
        left: _settings.marginHorizontal,
        right: _settings.marginHorizontal,
        top: chapterIndex == 0 ? _settings.marginVertical : 0,
        bottom: _settings.showStatusBar ? 30 : _settings.marginVertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // 章节标题
          Text(
            chapter.title,
            style: TextStyle(
              fontSize: _settings.fontSize + 6,
              fontWeight: FontWeight.bold,
              color: _currentTheme.text,
              fontFamily: _currentFontFamily,
            ),
          ),
          SizedBox(height: _settings.paragraphSpacing * 1.5),
          // 正文内容
          ...paragraphs.map((paragraph) {
            final trimmed = paragraph.trim();
            if (trimmed.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(bottom: _settings.paragraphSpacing),
              child: Text(
                '　　$trimmed',
                style: TextStyle(
                  fontSize: _settings.fontSize,
                  height: _settings.lineHeight,
                  color: _currentTheme.text,
                  letterSpacing: _settings.letterSpacing,
                  fontFamily: _currentFontFamily,
                ),
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
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Container(
          height: MediaQuery.of(context).size.height * 0.75, // 更高的面板
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 顶部指示条
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 标题
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '界面设置',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 阅读主题
                      _buildSectionTitle('阅读主题'),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(
                              AppColors.readingThemes.length, (index) {
                            final theme = AppColors.readingThemes[index];
                            final isSelected = _settings.themeIndex == index;
                            return GestureDetector(
                              onTap: () {
                                _updateSettings(
                                    _settings.copyWith(themeIndex: index));
                                setPopupState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 70,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: theme.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: CupertinoColors.activeBlue,
                                          width: 3)
                                      : Border.all(color: Colors.white12),
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
                          }),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. 翻页动画
                      _buildSectionTitle('翻页动画'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PageTurnMode.values.map((mode) {
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
                              if (selected) {
                                _updateSettings(
                                    _settings.copyWith(pageTurnMode: mode));
                                setPopupState(() {});
                              }
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // 3. 字体设置
                      _buildSectionTitle('字体与大小'),
                      const SizedBox(height: 12),
                      // 字体选择
                      GestureDetector(
                        onTap: () {
                          // 简单的字体切换浮层，不再深入嵌套
                          showCupertinoModalPopup(
                              context: context,
                              builder: (ctx) =>
                                  _buildFontSelectDialog(setPopupState));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
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
                      Row(
                        children: [
                          _buildCircleBtn(Icons.remove, () {
                            if (_settings.fontSize > 10) {
                              _updateSettings(_settings.copyWith(
                                  fontSize: _settings.fontSize - 1));
                              setPopupState(() {});
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
                                _updateSettings(
                                    _settings.copyWith(fontSize: val));
                                setPopupState(() {});
                              },
                            ),
                          ),
                          _buildCircleBtn(Icons.add, () {
                            if (_settings.fontSize < 40) {
                              _updateSettings(_settings.copyWith(
                                  fontSize: _settings.fontSize + 1));
                              setPopupState(() {});
                            }
                          }),
                          SizedBox(
                              width: 40,
                              child: Text(
                                '${_settings.fontSize.toInt()}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 4. 排版
                      _buildSectionTitle('排版间距'),
                      const SizedBox(height: 12),
                      _buildSliderSetting('行距', _settings.lineHeight, 1.0, 3.0,
                          (val) {
                        _updateSettings(_settings.copyWith(lineHeight: val));
                        setPopupState(() {});
                      }, displayFormat: (v) => v.toStringAsFixed(1)),
                      const SizedBox(height: 8),
                      _buildSliderSetting(
                          '段距', _settings.paragraphSpacing, 0, 50, (val) {
                        _updateSettings(
                            _settings.copyWith(paragraphSpacing: val));
                        setPopupState(() {});
                      }, displayFormat: (v) => v.toInt().toString()),

                      const SizedBox(height: 24),
                      // 5. 对齐与缩进
                      _buildSectionTitle('对齐与缩进'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildToggleBtn(
                              label: '两端对齐',
                              isActive: _settings.textFullJustify,
                              onTap: () {
                                _updateSettings(_settings.copyWith(
                                    textFullJustify:
                                        !_settings.textFullJustify));
                                setPopupState(() {});
                              },
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
                                _updateSettings(_settings.copyWith(
                                    paragraphIndent: hasIndent ? '' : '　　'));
                                setPopupState(() {});
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      // 6. 边距
                      _buildSectionTitle('内容边距'),
                      const SizedBox(height: 12),
                      _buildSliderSetting(
                          '左右', _settings.marginHorizontal, 0, 80, (val) {
                        _updateSettings(
                            _settings.copyWith(marginHorizontal: val));
                        setPopupState(() {});
                      }, displayFormat: (v) => v.toInt().toString()),
                      const SizedBox(height: 8),
                      _buildSliderSetting('上下', _settings.marginVertical, 0, 80,
                          (val) {
                        _updateSettings(
                            _settings.copyWith(marginVertical: val));
                        setPopupState(() {});
                      }, displayFormat: (v) => v.toInt().toString()),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
