import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Curves;
import 'package:flutter/services.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/models/book.dart';
import '../models/reading_settings.dart';

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

  @override
  void initState() {
    super.initState();
    _chapterRepo = ChapterRepository(DatabaseService());
    _bookRepo = BookRepository(DatabaseService());
    _settingsService = SettingsService();
    _settings = _settingsService.readingSettings;

    _currentChapterIndex = widget.initialChapter;
    _initReader();

    // 全屏沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initReader() async {
    _chapters = _chapterRepo.getChaptersForBook(widget.bookId);
    if (_chapters.isNotEmpty) {
      if (_currentChapterIndex >= _chapters.length) {
        _currentChapterIndex = 0;
      }
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

  Future<void> _loadChapter(int index, {bool restoreOffset = false}) async {
    if (index < 0 || index >= _chapters.length) return;

    setState(() {
      _currentChapterIndex = index;
      _currentTitle = _chapters[index].title;
      _currentContent = _chapters[index].content ?? '';
    });

    // 等待一帧让内容渲染后再设置偏移
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (restoreOffset) {
          final offset = _settingsService.getScrollOffset(widget.bookId);
          if (offset > 0) {
            _scrollController.jumpTo(offset);
            return;
          }
        }
        _scrollController.jumpTo(0);
      }
    });

    await _saveProgress();
  }

  /// 切换主题
  void _updateSettings(ReadingSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    _settingsService.saveReadingSettings(newSettings);
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final theme = ReaderTheme.values[_settings.themeIndex];

    return CupertinoPageScaffold(
      backgroundColor: theme.backgroundColor,
      child: GestureDetector(
        onTapUp: _handleTap,
        child: Stack(
          children: [
            // 阅读内容
            SafeArea(
              bottom: false,
              child: Padding(
                padding: _settings.padding,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        _currentTitle,
                        style: TextStyle(
                          fontSize: _settings.fontSize + 6,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        _currentContent,
                        style: TextStyle(
                          fontSize: _settings.fontSize,
                          height: _settings.lineHeight,
                          color: theme.textColor,
                          letterSpacing: _settings.letterSpacing,
                        ),
                      ),
                      const SizedBox(height: 100),
                      _buildChapterNav(theme.textColor),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),

            // 顶部菜单
            if (_showMenu) _buildTopMenu(),

            // 底部菜单
            if (_showMenu) _buildBottomMenu(),
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
            child: Text('← 上一章',
                style: TextStyle(color: textColor.withOpacity(0.6))),
            onPressed: () => _loadChapter(_currentChapterIndex - 1),
          )
        else
          const SizedBox(),
        if (_currentChapterIndex < _chapters.length - 1)
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Text('下一章 →',
                style: TextStyle(color: textColor.withOpacity(0.6))),
            onPressed: () => _loadChapter(_currentChapterIndex + 1),
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
          color: CupertinoColors.black.withOpacity(0.85),
        ),
        child: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.transparent,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child:
                const Icon(CupertinoIcons.back, color: CupertinoColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          middle: Text(
            widget.bookTitle,
            style: const TextStyle(color: CupertinoColors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.list_bullet,
                color: CupertinoColors.white),
            onPressed: _showChapterList,
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
          bottom: MediaQuery.of(context).padding.bottom + 10,
          top: 20,
        ),
        decoration: BoxDecoration(
          color: CupertinoColors.black.withOpacity(0.85),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度滑条 (模拟进度)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.chevron_left,
                        color: CupertinoColors.white, size: 20),
                    onPressed: _currentChapterIndex > 0
                        ? () => _loadChapter(_currentChapterIndex - 1)
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${_currentChapterIndex + 1} / ${_chapters.length}',
                          style: const TextStyle(
                              color: CupertinoColors.systemGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.chevron_right,
                        color: CupertinoColors.white, size: 20),
                    onPressed: _currentChapterIndex < _chapters.length - 1
                        ? () => _loadChapter(_currentChapterIndex + 1)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 设置按钮组
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMenuBtn(
                    CupertinoIcons.textformat_size, '样式', _showStyleSheet),
                _buildMenuBtn(
                    CupertinoIcons.brightness, '亮度', _showBrightnessSheet),
                _buildMenuBtn(CupertinoIcons.square_grid_2x2, '更多', () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: CupertinoColors.white, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(color: CupertinoColors.white, fontSize: 12)),
        ],
      ),
    );
  }

  void _showStyleSheet() {
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
                const Text('字体大小',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                _buildSizeAdjuster((val) {
                  _updateSettings(
                      _settings.copyWith(fontSize: _settings.fontSize + val));
                  setPopupState(() {});
                }, _settings.fontSize.toInt()),
                const SizedBox(height: 20),
                const Text('行高间距',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                _buildLineHeightAdjuster((val) {
                  _updateSettings(_settings.copyWith(
                      lineHeight:
                          (_settings.lineHeight + val).clamp(1.2, 3.0)));
                  setPopupState(() {});
                }, _settings.lineHeight),
                const SizedBox(height: 20),
                const Text('阅读背景',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ReaderTheme.values
                      .map((t) => GestureDetector(
                            onTap: () {
                              _updateSettings(
                                  _settings.copyWith(themeIndex: t.index));
                              setPopupState(() {});
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: t.backgroundColor,
                                shape: BoxShape.circle,
                                border: _settings.themeIndex == t.index
                                    ? Border.all(
                                        color: CupertinoColors.activeBlue,
                                        width: 3)
                                    : Border.all(color: Colors.white24),
                              ),
                              child: t.index == 3
                                  ? const Icon(CupertinoIcons.moon_fill,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSizeAdjuster(Function(double) onChange, int current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CupertinoButton(
            child: const Text('A-', style: TextStyle(color: Colors.white)),
            onPressed: () => onChange(-2)),
        Text('$current',
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        CupertinoButton(
            child: const Text('A+', style: TextStyle(color: Colors.white)),
            onPressed: () => onChange(2)),
      ],
    );
  }

  Widget _buildLineHeightAdjuster(Function(double) onChange, double current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CupertinoButton(
            child: const Icon(CupertinoIcons.minus, color: Colors.white),
            onPressed: () => onChange(-0.2)),
        Text(current.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        CupertinoButton(
            child: const Icon(CupertinoIcons.plus, color: Colors.white),
            onPressed: () => onChange(0.2)),
      ],
    );
  }

  void _showBrightnessSheet() {
    // 暂未实现完整系统亮度调节，仅展示占位
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 150,
        color: const Color(0xFF1C1C1E),
        child: const Center(
            child: Text('亮度调节功能开发中...', style: TextStyle(color: Colors.white))),
      ),
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

/// 阅读器主题定义
enum ReaderTheme {
  dark,
  beige,
  green,
  black,
  contrast;

  Color get backgroundColor {
    switch (this) {
      case ReaderTheme.dark:
        return const Color(0xFF1C1C1E);
      case ReaderTheme.beige:
        return const Color(0xFFF5F5DC);
      case ReaderTheme.green:
        return const Color(0xFFE3EDCD);
      case ReaderTheme.black:
        return const Color(0xFF000000);
      case ReaderTheme.contrast:
        return const Color(0xFFFFFFFF);
    }
  }

  Color get textColor {
    switch (this) {
      case ReaderTheme.dark:
        return const Color(0xFFE5E5E7);
      case ReaderTheme.beige:
        return const Color(0xFF2C2C2E);
      case ReaderTheme.green:
        return const Color(0xFF2C2C2E);
      case ReaderTheme.black:
        return const Color(0xFF999999);
      case ReaderTheme.contrast:
        return const Color(0xFF111111);
    }
  }
}
