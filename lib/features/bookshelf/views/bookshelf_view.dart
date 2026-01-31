import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show LinearProgressIndicator, AlwaysStoppedAnimation;
import '../models/book.dart';
import '../widgets/book_cover_card.dart';
import '../../../app/theme/colors.dart';

/// 书架页面 - iOS 原生风格
class BookshelfView extends StatefulWidget {
  const BookshelfView({super.key});

  @override
  State<BookshelfView> createState() => _BookshelfViewState();
}

class _BookshelfViewState extends State<BookshelfView> {
  bool _isGridView = true;

  final List<Book> _books = [
    Book(
      id: '1',
      title: '斗破苍穹',
      author: '天蚕土豆',
      currentChapter: 100,
      totalChapters: 1500,
      readProgress: 0.35,
      addedTime: DateTime.now().subtract(const Duration(days: 7)),
      lastReadTime: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Book(
      id: '2',
      title: '完美世界',
      author: '辰东',
      currentChapter: 50,
      totalChapters: 2000,
      readProgress: 0.12,
      addedTime: DateTime.now().subtract(const Duration(days: 3)),
      lastReadTime: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Book(
      id: '3',
      title: '遮天',
      author: '辰东',
      currentChapter: 0,
      totalChapters: 1800,
      readProgress: 0.0,
      addedTime: DateTime.now(),
    ),
    Book(
      id: '4',
      title: '凡人修仙传',
      author: '忘语',
      currentChapter: 800,
      totalChapters: 2446,
      readProgress: 0.65,
      addedTime: DateTime.now().subtract(const Duration(days: 30)),
      lastReadTime: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书架'),
        backgroundColor: const Color(0xE6121212),
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                _isGridView
                    ? CupertinoIcons.list_bullet
                    : CupertinoIcons.square_grid_2x2,
                color: CupertinoColors.white,
              ),
              onPressed: () {
                setState(() => _isGridView = !_isGridView);
              },
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.ellipsis_vertical,
                  color: CupertinoColors.white),
              onPressed: _showMoreOptions,
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _books.isEmpty ? _buildEmptyState() : _buildBookList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.book,
            size: 64,
            color: CupertinoColors.systemGrey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '书架空空如也',
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '前往发现页添加书籍',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList() {
    if (_isGridView) {
      return _buildGridView();
    } else {
      return _buildListView();
    }
  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return BookCoverCard(
            book: book,
            onTap: () => _onBookTap(book),
            onLongPress: () => _onBookLongPress(book),
          );
        },
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final book = _books[index];
        return _buildListItem(book);
      },
    );
  }

  Widget _buildListItem(Book book) {
    return GestureDetector(
      onTap: () => _onBookTap(book),
      onLongPress: () => _onBookLongPress(book),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 60,
                height: 84,
                color: AppColors.accent.withOpacity(0.2),
                child: book.coverUrl != null
                    ? Image.network(book.coverUrl!, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          book.title.substring(0, 1),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 书籍信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: book.readProgress,
                            backgroundColor:
                                CupertinoColors.systemGrey.withOpacity(0.3),
                            valueColor:
                                const AlwaysStoppedAnimation(AppColors.accent),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        book.progressText,
                        style: TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('导入本地书籍'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('批量管理'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _onBookTap(Book book) {
    // TODO: 跳转到阅读页面
  }

  void _onBookLongPress(Book book) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(book.title),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('书籍详情'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('缓存全本'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('移除书籍'),
            onPressed: () {
              Navigator.pop(context);
              _removeBook(book);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _removeBook(Book book) {
    setState(() {
      _books.removeWhere((b) => b.id == book.id);
    });
  }
}
