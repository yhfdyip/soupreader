import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  late List<BookmarkEntity> _bookmarks;
  bool _isLoading = true;

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
        const SnackBar(
          content: Text('书签已添加'),
          duration: Duration(seconds: 1),
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
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF333333)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '书签',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // 添加书签按钮
                    TextButton.icon(
                      onPressed: _addBookmark,
                      icon: const Icon(Icons.add, color: Colors.amber),
                      label: const Text(
                        '添加',
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 书签列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bookmarks.isEmpty
                    ? _buildEmptyState()
                    : _buildBookmarkList(),
          ),
        ],
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
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无书签',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方"添加"按钮添加当前位置',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        onTap: () => _jumpToBookmark(bookmark),
        leading: const Icon(Icons.bookmark, color: Colors.amber),
        title: Text(
          bookmark.chapterTitle,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatTime(bookmark.createdTime),
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        trailing: IconButton(
          icon:
              Icon(Icons.delete_outline, color: Colors.white.withOpacity(0.5)),
          onPressed: () => _deleteBookmark(bookmark),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          hasBookmark ? Icons.bookmark : Icons.bookmark_border,
          color: hasBookmark ? Colors.amber : Colors.white70,
          size: 24,
        ),
      ),
    );
  }
}
