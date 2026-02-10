import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/bookmark_repository.dart';

/// 书签列表对话框
class BookmarkDialog extends StatefulWidget {
  final String bookId;
  final String bookName;
  final String bookAuthor;
  final int currentChapter;
  final String currentChapterTitle;
  final BookmarkRepository repository;
  final Function(int chapterIndex, int chapterPos)? onJumpTo;

  const BookmarkDialog({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.bookAuthor,
    required this.currentChapter,
    required this.currentChapterTitle,
    required this.repository,
    this.onJumpTo,
  });

  @override
  State<BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<BookmarkDialog> {
  List<BookmarkEntity> _bookmarks = <BookmarkEntity>[];
  bool _isLoading = true;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

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

  Color get _lineColor =>
      _isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;

  Color get _cardBg => _isDark
      ? CupertinoColors.systemGrey.withValues(alpha: 0.1)
      : AppDesignTokens.surfaceLight.withValues(alpha: 0.96);

  Color get _dangerBg => _isDark
      ? AppDesignTokens.error.withValues(alpha: 0.24)
      : AppDesignTokens.error.withValues(alpha: 0.18);

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    setState(() {
      _bookmarks = widget.repository.getBookmarksForBook(widget.bookId);
      _isLoading = false;
    });
  }

  Future<void> _addBookmark() async {
    // 获取内容预览（这里简化处理，实际应传入当前阅读位置的文本）
    await widget.repository.addBookmark(
      bookId: widget.bookId,
      bookName: widget.bookName,
      bookAuthor: widget.bookAuthor,
      chapterIndex: widget.currentChapter,
      chapterTitle: widget.currentChapterTitle,
      chapterPos: 0, // 可以传入实际的字符位置
      content: '', // 可以传入预览文本
    );

    _loadBookmarks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _isDark ? const Color(0xFF2C2C2E) : _panelBg,
          content: Text(
            '书签已添加',
            style: TextStyle(color: _textStrong),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _deleteBookmark(BookmarkEntity bookmark) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除书签'),
        content: const Text('确定要删除这个书签吗？'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.removeBookmark(bookmark.id);
      _loadBookmarks();
    }
  }

  void _jumpToBookmark(BookmarkEntity bookmark) {
    Navigator.pop(context);
    widget.onJumpTo?.call(bookmark.chapterIndex, bookmark.chapterPos);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildGrabber(),

            // 标题栏
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _lineColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '书签（${_bookmarks.length}）',
                      style: TextStyle(
                        color: _textStrong,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(30, 30),
                    onPressed: _addBookmark,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.add, color: _accent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '添加',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(30, 30),
                    onPressed: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.xmark,
                      color: _textSubtle,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

            // 书签列表
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CupertinoActivityIndicator(
                        radius: 12,
                        color: _accent,
                      ),
                    )
                  : _bookmarks.isEmpty
                      ? _buildEmptyState()
                      : _buildBookmarkList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    final color = _isDark
        ? Colors.white24
        : AppDesignTokens.textMuted.withValues(alpha: 0.35);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 64,
            color: _textSubtle.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无书签',
            style: TextStyle(
              color: _textNormal,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方“添加”按钮添加当前位置',
            style: TextStyle(
              color: _textSubtle,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        return _buildBookmarkItem(bookmark);
      },
    );
  }

  Widget _buildBookmarkItem(BookmarkEntity bookmark) {
    return Dismissible(
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteBookmark(bookmark),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _dangerBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppDesignTokens.error.withValues(alpha: 0.5),
          ),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _lineColor.withValues(alpha: 0.85)),
        ),
        child: ListTile(
          onTap: () => _jumpToBookmark(bookmark),
          leading: Icon(
            Icons.bookmark,
            color: _accent,
          ),
          title: Text(
            bookmark.chapterTitle,
            style: TextStyle(color: _textStrong),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatTime(bookmark.createdTime),
            style: TextStyle(color: _textSubtle, fontSize: 12),
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: _textSubtle,
            ),
            onPressed: () => _deleteBookmark(bookmark),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} 分钟前';
      }
      return '${diff.inHours} 小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}

/// 快速添加书签指示器
class BookmarkIndicator extends StatelessWidget {
  final bool hasBookmark;
  final VoidCallback? onTap;

  const BookmarkIndicator({
    super.key,
    required this.hasBookmark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final activeColor =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
    final inactiveColor =
        isDark ? CupertinoColors.systemGrey : AppDesignTokens.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          hasBookmark ? Icons.bookmark : Icons.bookmark_border,
          color: hasBookmark ? activeColor : inactiveColor,
          size: 24,
        ),
      ),
    );
  }
}
