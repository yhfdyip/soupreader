import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reading_settings.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';

/// 阅读器页面
class ReaderView extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int? initialChapter;

  const ReaderView({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.initialChapter,
  });

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  // 阅读设置
  ReadingSettings _settings = const ReadingSettings();

  // 当前阅读主题
  ReadingThemeColors get _currentTheme {
    final index = _settings.themeIndex;
    if (index >= 0 && index < AppColors.readingThemes.length) {
      return AppColors.readingThemes[index];
    }
    return AppColors.readingThemes[0];
  }

  // 是否显示菜单
  bool _showMenu = false;

  // 当前章节
  int _currentChapter = 0;
  String _chapterTitle = '第一章 序章';

  // 模拟章节内容
  final String _content = '''
    天才少年萧炎在三年休息被未婚妻纳兰嫣然退婚，整个人陷入了谷底。声誉扫地的他突然发现在其戒指中有一个老头的灵魂。

    这个老头名叫药尘，是大陆上有名的炼药师，只是一场陷阱让他死去，一缕灵魂却穿越进入了萧炎佩戴的古老戒指中。

    萧炎和药尘的相遇，改变了萧炎的命运。在药尘的帮助下，萧炎开始了他的修炼之路，一步步从废物成长为一代强者。

    "三十年河东，三十年河西，莫欺少年穷！"这句话成为了萧炎的座右铭，激励着他在这片大陆上不断前进。

    斗气大陆，一个以斗气为尊的世界。在这里，强者为尊，弱者只能被欺凌。萧炎从一个家族的废物少爷，一步步成长为能够与整个大陆为敌的强者。

    这是一个关于成长、复仇、爱情与友情的故事。萧炎用自己的努力和天赋，书写了一段传奇。
  ''';

  // 页面控制器
  late PageController _pageController;
  List<String> _pages = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter ?? 0;
    _pageController = PageController();

    // 设置全屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 初始化分页（简化版本，实际需要根据屏幕大小计算）
    _pages = _splitContent(_content);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  List<String> _splitContent(String content) {
    // 简化的分页逻辑，实际应根据屏幕大小和字体计算
    final lines = content.trim().split('\n');
    final int linesPerPage = 10;
    final List<String> pages = [];

    for (int i = 0; i < lines.length; i += linesPerPage) {
      final end =
          (i + linesPerPage > lines.length) ? lines.length : i + linesPerPage;
      pages.add(lines.sublist(i, end).join('\n'));
    }

    return pages.isEmpty ? [content] : pages;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: _currentTheme.background.computeLuminance() > 0.5
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _currentTheme.background,
        body: GestureDetector(
          onTap: _onTapScreen,
          child: Stack(
            children: [
              // 阅读内容
              _buildReadingContent(),

              // 顶部菜单
              if (_showMenu) _buildTopMenu(),

              // 底部菜单
              if (_showMenu) _buildBottomMenu(),

              // 设置面板
              if (_showMenu) _buildSettingsPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingContent() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: _settings.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 章节标题（仅首页显示）
              if (index == 0) ...[
                Text(
                  _chapterTitle,
                  style: AppTypography.chapterTitle(color: _currentTheme.text),
                ),
                SizedBox(height: _settings.paragraphSpacing),
              ],

              // 正文内容
              Expanded(
                child: Text(
                  _pages[index],
                  style: AppTypography.readingStyle(
                    fontSize: _settings.fontSize,
                    lineHeight: _settings.lineHeight,
                    letterSpacing: _settings.letterSpacing,
                    color: _currentTheme.text,
                  ),
                ),
              ),

              // 页码和进度
              _buildPageInfo(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageInfo() {
    final progress = (_currentPage + 1) / _pages.length;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_settings.showTime)
            Text(
              _getCurrentTime(),
              style: TextStyle(
                color: _currentTheme.text.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          Text(
            '${_currentPage + 1}/${_pages.length}',
            style: TextStyle(
              color: _currentTheme.text.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          if (_settings.showProgress)
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: _currentTheme.text.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTopMenu() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.bookTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.list, color: Colors.white),
              onPressed: _showChapterList,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showMoreOptions,
            ),
          ],
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
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Row(
              children: [
                Text(
                  '${_currentChapter + 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _currentPage.toDouble(),
                    min: 0,
                    max: (_pages.length - 1).toDouble(),
                    activeColor: AppColors.accent,
                    inactiveColor: Colors.white30,
                    onChanged: (value) {
                      _pageController.jumpToPage(value.toInt());
                    },
                  ),
                ),
                Text(
                  '${_pages.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 功能按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMenuButton(Icons.skip_previous, '上一章', _previousChapter),
                _buildMenuButton(
                  Icons.brightness_6,
                  '亮度',
                  _showBrightnessSlider,
                ),
                _buildMenuButton(Icons.text_fields, '设置', _showReadingSettings),
                _buildMenuButton(Icons.skip_next, '下一章', _nextChapter),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return const SizedBox.shrink(); // 设置面板单独弹出
  }

  void _onTapScreen() {
    setState(() {
      _showMenu = !_showMenu;
    });

    if (_showMenu) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildChapterListSheet(),
    );
  }

  Widget _buildChapterListSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 拖动指示条
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '目录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '共 100 章',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // 章节列表
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 100,
                  itemBuilder: (context, index) {
                    final isCurrentChapter = index == _currentChapter;
                    return ListTile(
                      title: Text(
                        '第${index + 1}章 章节标题',
                        style: TextStyle(
                          color: isCurrentChapter ? AppColors.accent : null,
                          fontWeight: isCurrentChapter ? FontWeight.bold : null,
                        ),
                      ),
                      trailing: isCurrentChapter
                          ? const Icon(
                              Icons.play_arrow,
                              color: AppColors.accent,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _jumpToChapter(index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptions() {
    // TODO: 更多选项
  }

  void _showBrightnessSlider() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('亮度调节'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.brightness_low),
                Expanded(
                  child: Slider(
                    value: _settings.brightness,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(brightness: value);
                      });
                    },
                  ),
                ),
                const Icon(Icons.brightness_high),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReadingSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildReadingSettingsSheet(),
    );
  }

  Widget _buildReadingSettingsSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 字体大小
              const Text('字体大小'),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.text_decrease),
                    onPressed: () {
                      if (_settings.fontSize > 12) {
                        setSheetState(() {
                          setState(() {
                            _settings = _settings.copyWith(
                              fontSize: _settings.fontSize - 2,
                            );
                          });
                        });
                      }
                    },
                  ),
                  Expanded(
                    child: Slider(
                      value: _settings.fontSize,
                      min: 12,
                      max: 30,
                      divisions: 9,
                      label: '${_settings.fontSize.toInt()}',
                      onChanged: (value) {
                        setSheetState(() {
                          setState(() {
                            _settings = _settings.copyWith(fontSize: value);
                          });
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_increase),
                    onPressed: () {
                      if (_settings.fontSize < 30) {
                        setSheetState(() {
                          setState(() {
                            _settings = _settings.copyWith(
                              fontSize: _settings.fontSize + 2,
                            );
                          });
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 阅读主题
              const Text('阅读主题'),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppColors.readingThemes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final theme = AppColors.readingThemes[index];
                    final isSelected = _settings.themeIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          setState(() {
                            _settings = _settings.copyWith(themeIndex: index);
                          });
                        });
                      },
                      child: Container(
                        width: 60,
                        decoration: BoxDecoration(
                          color: theme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : Colors.grey.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            theme.name,
                            style: TextStyle(color: theme.text, fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 翻页模式
              const Text('翻页模式'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: PageTurnModeUi.values(current: _settings.pageTurnMode)
                    .map((mode) {
                  final isSelected = _settings.pageTurnMode == mode;
                  return ChoiceChip(
                    label: Text(PageTurnModeUi.isHidden(mode)
                        ? '${mode.name}（隐藏）'
                        : mode.name),
                    selected: isSelected,
                    onSelected: PageTurnModeUi.isHidden(mode)
                        ? null
                        : (selected) {
                            if (selected) {
                              setSheetState(() {
                                setState(() {
                                  _settings =
                                      _settings.copyWith(pageTurnMode: mode);
                                });
                              });
                            }
                          },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _previousChapter() {
    if (_currentChapter > 0) {
      _jumpToChapter(_currentChapter - 1);
    }
  }

  void _nextChapter() {
    _jumpToChapter(_currentChapter + 1);
  }

  void _jumpToChapter(int chapter) {
    setState(() {
      _currentChapter = chapter;
      _currentPage = 0;
      _chapterTitle = '第${chapter + 1}章 章节标题';
      // TODO: 加载章节内容
    });
    _pageController.jumpToPage(0);
  }
}
