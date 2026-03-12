import 'package:flutter/cupertino.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../bookshelf/models/book.dart';

/// 目录/书签弹窗 - Cupertino 风格
/// 支持倒序和 Tab 切换
class ChapterListDialog extends StatefulWidget {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final List<Bookmark> bookmarks;
  final ValueChanged<int> onChapterSelected;
  final ValueChanged<Bookmark> onBookmarkSelected;
  final ReadingThemeColors currentTheme;

  const ChapterListDialog({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.bookmarks,
    required this.onChapterSelected,
    required this.onBookmarkSelected,
    required this.currentTheme,
  });

  static void show(
    BuildContext context, {
    required List<Chapter> chapters,
    required int currentChapterIndex,
    required List<Bookmark> bookmarks,
    required ValueChanged<int> onChapterSelected,
    required ValueChanged<Bookmark> onBookmarkSelected,
    required ReadingThemeColors currentTheme,
  }) {
    showCupertinoBottomSheetDialog(
      context: context,
      builder: (context) => ChapterListDialog(
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        bookmarks: bookmarks,
        onChapterSelected: onChapterSelected,
        onBookmarkSelected: onBookmarkSelected,
        currentTheme: currentTheme,
      ),
    );
  }

  @override
  State<ChapterListDialog> createState() => _ChapterListDialogState();
}

class _ChapterListDialogState extends State<ChapterListDialog> {
  // 倒序状态
  bool _isReversed = false;
  // 当前 Tab
  int _currentTab = 0;
  final ScrollController _chapterScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _scrollToCurrentChapter();
      });
    });
  }

  @override
  void dispose() {
    _chapterScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentChapter() {
    final index = widget.currentChapterIndex;
    if (index < 0 || index >= widget.chapters.length) return;
    final displayIndex = _isReversed ? widget.chapters.length - 1 - index : index;
    const itemHeight = 52.0;
    final offset = (displayIndex * itemHeight - 80).clamp(0.0, double.infinity);
    _chapterScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  bool get _isDark => widget.currentTheme.isDark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _textStrong =>
      CupertinoColors.label.resolveFrom(context);

  Color get _textNormal =>
      CupertinoColors.secondaryLabel.resolveFrom(context);

  Color get _textSubtle =>
      CupertinoColors.tertiaryLabel.resolveFrom(context);

  Color get _cardBg =>
      CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: AppSheetPanel(
        contentPadding: EdgeInsets.zero,
        child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 拖动指示器
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.separator.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 标题和操作栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Tab 切换
                  Expanded(
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _currentTab,
                      padding: const EdgeInsets.all(3),
                      children: {
                        0: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '目录 (${widget.chapters.length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _currentTab == 0
                                  ? _textStrong
                                  : _textSubtle,
                            ),
                          ),
                        ),
                        1: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '书签 (${widget.bookmarks.length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _currentTab == 1
                                  ? _textStrong
                                  : _textSubtle,
                            ),
                          ),
                        ),
                      },
                      onValueChanged: (value) {
                        setState(() {
                          _currentTab = value ?? 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.all(12),
                    minimumSize: Size.zero,
                    onPressed: () {
                      setState(() {
                        _isReversed = !_isReversed;
                      });
                    },
                    child: Icon(
                      _isReversed
                          ? CupertinoIcons.sort_up
                          : CupertinoIcons.sort_down,
                      color: _isReversed ? _accent : _textNormal,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // 列表内容
            Expanded(
              child: PrimaryScrollController(
                controller: _chapterScrollController,
                child: _currentTab == 0 ? _buildChapterList() : _buildBookmarkList(),
              ),
            ),
            // 底部当前章节跳转栏（仅目录 Tab 显示）
            if (_currentTab == 0) _buildCurrentChapterBar(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildChapterList() {
    final chapters =
        _isReversed ? widget.chapters.reversed.toList() : widget.chapters;

    return CupertinoScrollbar(
      controller: _chapterScrollController,
      thumbVisibility: false,
      child: ListView.builder(
      controller: _chapterScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final actualIndex =
            _isReversed ? widget.chapters.length - 1 - index : index;
        final chapter = chapters[index];
        final isCurrentChapter = actualIndex == widget.currentChapterIndex;

        return CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            Navigator.pop(context);
            widget.onChapterSelected(actualIndex);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: isCurrentChapter
                  ? _accent.withValues(alpha: _isDark ? 0.16 : 0.12)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl - 2),
              border: isCurrentChapter
                  ? Border.all(
                      color: _accent.withValues(alpha: _isDark ? 0.3 : 0.35),
                    )
                  : null,
            ),
            child: Row(
              children: [
                // 章节序号
                SizedBox(
                  width: 40,
                  child: Text(
                    '${actualIndex + 1}',
                    style: TextStyle(
                      color: isCurrentChapter ? _accent : _textSubtle,
                      fontSize: 12,
                    ),
                  ),
                ),
                // 章节标题
                Expanded(
                  child: Text(
                    chapter.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentChapter ? _accent : _textStrong,
                      fontSize: 15,
                      fontWeight: isCurrentChapter
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                // 当前章节标记
                if (isCurrentChapter)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
                    ),
                    child: const Text(
                      '当前',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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

  Widget _buildCurrentChapterBar() {
    final index = widget.currentChapterIndex;
    if (index < 0 || index >= widget.chapters.length) {
      return const SizedBox.shrink();
    }
    final chapter = widget.chapters[index];
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 0.5, color: separatorColor),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: Size.zero,
          onPressed: _scrollToCurrentChapter,
          child: Row(
            children: [
              Icon(
                CupertinoIcons.location_fill,
                size: 14,
                color: _accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${index + 1} / ${widget.chapters.length}',
                style: TextStyle(
                  color: _textNormal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarkList() {
    if (widget.bookmarks.isEmpty) {
      return const AppEmptyState(
        illustration: AppEmptyPlanetIllustration(size: 82),
        title: '暂无书签',
        message: '阅读时点击书签图标可添加书签',
      );
    }

    final bookmarks =
        _isReversed ? widget.bookmarks.reversed.toList() : widget.bookmarks;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];

        return CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            Navigator.pop(context);
            widget.onBookmarkSelected(bookmark);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl - 2),
              border: Border.all(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 章节标题
                Text(
                  bookmark.chapterTitle,
                  style: TextStyle(
                    color: _textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // 书签内容
                Text(
                  bookmark.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textNormal,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                // 创建时间
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.time,
                      color: _textSubtle,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(bookmark.createdAt),
                      style: TextStyle(
                        color: _textSubtle,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 书签模型（如果未定义）
class Bookmark {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String content;
  final DateTime createdAt;
  final double? progress;

  Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.content,
    required this.createdAt,
    this.progress,
  });
}
