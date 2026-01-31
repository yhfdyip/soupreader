import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../bookshelf/models/book.dart';

/// 简洁阅读器 - Cupertino 风格
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
  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  String _currentContent = '';
  String _currentTitle = '';

  // 阅读设置
  double _fontSize = 18.0;
  bool _isDarkMode = true;

  // UI 状态
  bool _showMenu = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chapterRepo = ChapterRepository(DatabaseService());
    _currentChapterIndex = widget.initialChapter;
    _loadChapters();

    // 全屏沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _loadChapters() {
    _chapters = _chapterRepo.getChaptersForBook(widget.bookId);
    if (_chapters.isNotEmpty) {
      _loadChapter(_currentChapterIndex);
    }
  }

  void _loadChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;

    setState(() {
      _currentChapterIndex = index;
      _currentTitle = _chapters[index].title;
      _currentContent = _chapters[index].content ?? '';
    });

    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5DC); // 米色
    final textColor =
        _isDarkMode ? const Color(0xFFE5E5E7) : const Color(0xFF2C2C2E);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: GestureDetector(
        onTap: () => setState(() => _showMenu = !_showMenu),
        child: Stack(
          children: [
            // 阅读内容
            SafeArea(
              child: _chapters.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                fontSize: _fontSize + 4,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 正文
                            Text(
                              _currentContent,
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.8,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 60),
                            // 章节导航
                            _buildChapterNav(textColor),
                            const SizedBox(height: 40),
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
            child: Text(
              '← 上一章',
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
            onPressed: () => _loadChapter(_currentChapterIndex - 1),
          )
        else
          const SizedBox(),
        if (_currentChapterIndex < _chapters.length - 1)
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Text(
              '下一章 →',
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
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
          color: CupertinoColors.systemBackground.darkColor.withOpacity(0.95),
        ),
        child: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.transparent,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          middle: Text(
            widget.bookTitle,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.list_bullet),
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
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.darkColor.withOpacity(0.95),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度显示
            Text(
              '${_currentChapterIndex + 1} / ${_chapters.length}',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            // 设置按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSettingButton(
                  CupertinoIcons.textformat_size,
                  '字号',
                  _showFontSizeSheet,
                ),
                _buildSettingButton(
                  _isDarkMode ? CupertinoIcons.sun_max : CupertinoIcons.moon,
                  _isDarkMode ? '日间' : '夜间',
                  () => setState(() => _isDarkMode = !_isDarkMode),
                ),
                _buildSettingButton(
                  CupertinoIcons.arrow_left,
                  '上一章',
                  _currentChapterIndex > 0
                      ? () => _loadChapter(_currentChapterIndex - 1)
                      : null,
                ),
                _buildSettingButton(
                  CupertinoIcons.arrow_right,
                  '下一章',
                  _currentChapterIndex < _chapters.length - 1
                      ? () => _loadChapter(_currentChapterIndex + 1)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingButton(IconData icon, String label, VoidCallback? onTap) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.3 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showChapterList() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            // 拖动指示器
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3.resolveFrom(context),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '目录 (${_chapters.length}章)',
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == _currentChapterIndex;
                  return CupertinoListTile(
                    title: Text(
                      _chapters[index].title,
                      style: TextStyle(
                        color: isCurrent
                            ? CupertinoTheme.of(context).primaryColor
                            : null,
                        fontWeight: isCurrent ? FontWeight.bold : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(
                            CupertinoIcons.play_fill,
                            color: CupertinoTheme.of(context).primaryColor,
                            size: 14,
                          )
                        : null,
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

  void _showFontSizeSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('字体大小'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoButton(
                    child: const Text('A-', style: TextStyle(fontSize: 20)),
                    onPressed: () {
                      if (_fontSize > 12) {
                        setState(() => _fontSize -= 2);
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '${_fontSize.toInt()}',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  CupertinoButton(
                    child: const Text('A+', style: TextStyle(fontSize: 20)),
                    onPressed: () {
                      if (_fontSize < 30) {
                        setState(() => _fontSize += 2);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
