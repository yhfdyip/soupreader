import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
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
    showCupertinoModalPopup(
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

  bool get _isDark => widget.currentTheme.isDark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _panelBg =>
      _isDark ? const Color(0xFF1C1C1E) : AppDesignTokens.surfaceLight;

  Color get _textStrong =>
      _isDark ? CupertinoColors.white : AppDesignTokens.textStrong;

  Color get _textNormal =>
      _isDark ? CupertinoColors.systemGrey : AppDesignTokens.textNormal;

  Color get _textSubtle => _isDark
      ? CupertinoColors.systemGrey.withValues(alpha: 0.75)
      : AppDesignTokens.textMuted;

  Color get _chipBg => _isDark
      ? CupertinoColors.systemGrey.withValues(alpha: 0.2)
      : AppDesignTokens.pageBgLight;

  Color get _cardBg => _isDark
      ? CupertinoColors.systemGrey.withValues(alpha: 0.1)
      : AppDesignTokens.surfaceLight.withValues(alpha: 0.96);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  color: _isDark
                      ? Colors.white24
                      : _textSubtle.withValues(alpha: 0.35),
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
                      backgroundColor: _chipBg,
                      thumbColor: _accent,
                      children: {
                        0: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '目录 (${widget.chapters.length})',
                            style: TextStyle(
                              fontSize: 13,
                              color: _currentTab == 0
                                  ? CupertinoColors.white
                                  : _textSubtle,
                            ),
                          ),
                        ),
                        1: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '书签 (${widget.bookmarks.length})',
                            style: TextStyle(
                              fontSize: 13,
                              color: _currentTab == 1
                                  ? CupertinoColors.white
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
                  const SizedBox(width: 12),
                  // 倒序按钮
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () {
                      setState(() {
                        _isReversed = !_isReversed;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isReversed
                              ? CupertinoIcons.arrow_up
                              : CupertinoIcons.arrow_down,
                          color: _accent,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isReversed ? '倒序' : '正序',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 列表内容
            Expanded(
              child:
                  _currentTab == 0 ? _buildChapterList() : _buildBookmarkList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterList() {
    final chapters =
        _isReversed ? widget.chapters.reversed.toList() : widget.chapters;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final actualIndex =
            _isReversed ? widget.chapters.length - 1 - index : index;
        final chapter = chapters[index];
        final isCurrentChapter = actualIndex == widget.currentChapterIndex;

        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            widget.onChapterSelected(actualIndex);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: isCurrentChapter
                  ? _accent.withValues(alpha: _isDark ? 0.16 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '当前',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookmarkList() {
    if (widget.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.bookmark,
              color: _textSubtle.withValues(alpha: 0.8),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无书签',
              style: TextStyle(
                color: _textNormal,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '阅读时点击书签图标可添加书签',
              style: TextStyle(
                color: _textSubtle,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final bookmarks =
        _isReversed ? widget.bookmarks.reversed.toList() : widget.bookmarks;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];

        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            widget.onBookmarkSelected(bookmark);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isDark
                    ? AppDesignTokens.borderDark.withValues(alpha: 0.6)
                    : AppDesignTokens.borderLight,
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
                    fontWeight: FontWeight.w500,
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
                      size: 12,
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
