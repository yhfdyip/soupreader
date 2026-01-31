import 'package:flutter/cupertino.dart';
import '../models/book.dart';

/// 书架页面 - 纯 iOS 原生风格
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
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书架'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                _isGridView
                    ? CupertinoIcons.list_bullet
                    : CupertinoIcons.square_grid_2x2,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.ellipsis_vertical),
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
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            '书架空空如也',
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '前往发现页添加书籍',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
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
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return _buildBookCard(book);
        },
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    return GestureDetector(
      onTap: () => _onBookTap(book),
      onLongPress: () => _onBookLongPress(book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: book.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(book.coverUrl!, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Text(
                        book.title.substring(0, 1),
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // 标题
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          // 进度
          Text(
            book.progressText,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leadingSize: 50,
          leading: Container(
            width: 50,
            height: 70,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              borderRadius: BorderRadius.circular(6),
            ),
            child: book.coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(book.coverUrl!, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      book.title.substring(0, 1),
                      style: TextStyle(
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
          title: Text(book.title),
          subtitle: Text(book.author),
          additionalInfo: Text(book.progressText),
          trailing: const CupertinoListTileChevron(),
          onTap: () => _onBookTap(book),
        );
      },
    );
  }

  void _showMoreOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('导入本地书籍'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('批量管理'),
            onPressed: () => Navigator.pop(context),
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
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('缓存全本'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('移除书籍'),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _books.removeWhere((b) => b.id == book.id);
              });
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
}
