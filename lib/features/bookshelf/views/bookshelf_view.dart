import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../widgets/book_cover_card.dart';
import '../../../app/theme/colors.dart';

/// 书架页面
class BookshelfView extends StatefulWidget {
  const BookshelfView({super.key});

  @override
  State<BookshelfView> createState() => _BookshelfViewState();
}

class _BookshelfViewState extends State<BookshelfView> {
  // 视图模式: grid 或 list
  bool _isGridView = true;

  // 示例书籍数据（后续接入数据库）
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

  Future<void> _onRefresh() async {
    // 模拟刷新延迟
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      HapticFeedback.lightImpact(); // iOS 风格刷新反馈
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()), // 强制 iOS 弹性回弹
        slivers: [
          SliverAppBar.large(
            title: const Text('书架'),
            centerTitle: Platform.isIOS ? false : true, // iOS 大标题默认居左
            actions: [
              IconButton(icon: const Icon(Icons.search), onPressed: _onSearch),
              IconButton(
                icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                  if (Platform.isIOS) HapticFeedback.selectionClick();
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: _onMenuSelected,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.file_open, size: 20),
                        SizedBox(width: 12),
                        Text('导入本地书籍'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manage',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('批量管理'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // iOS 原生下拉刷新
          if (Platform.isIOS)
            CupertinoSliverRefreshControl(
              onRefresh: _onRefresh,
            ),

          // 内容区域
          _books.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : _buildSliverContent(),

          // 底部留白，避免被 FAB 或 Navbar 遮挡
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddBook,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '书架空空如也',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角添加书籍',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverContent() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: _isGridView ? _buildSliverGrid() : _buildSliverList(),
    );
  }

  Widget _buildSliverGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final book = _books[index];
          return BookCoverCard(
            book: book,
            onTap: () => _onBookTap(book),
            onLongPress: () => _onBookLongPress(book),
          );
        },
        childCount: _books.length,
      ),
    );
  }

  Widget _buildSliverList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final book = _books[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildListItem(book),
          );
        },
        childCount: _books.length,
      ),
    );
  }

  Widget _buildListItem(Book book) {
    return GestureDetector(
      onTap: () => _onBookTap(book),
      onLongPress: () => _onBookLongPress(book),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          // 减少阴影浓度，更扁平化
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 60,
                height: 84,
                color: AppColors.primary.withOpacity(0.8),
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 进度
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: book.readProgress,
                            backgroundColor: AppColors.dividerDark,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.accent,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        book.progressText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
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

  void _onSearch() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('搜索功能开发中...')));
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'import':
        _onImportLocal();
        break;
      case 'manage':
        // TODO: 批量管理
        break;
    }
  }

  void _onAddBook() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('添加书籍功能开发中...')));
  }

  void _onImportLocal() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('导入本地书籍功能开发中...')));
  }

  void _onBookTap(Book book) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('打开《${book.title}》')));
  }

  void _onBookLongPress(Book book) {
    if (Platform.isIOS) HapticFeedback.mediumImpact();
    // 显示操作菜单
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildBookActionSheet(book),
    );
  }

  Widget _buildBookActionSheet(Book book) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              book.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('书籍详情'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('缓存全本'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('移除书籍'),
            onTap: () {
              Navigator.pop(context);
              _removeBook(book);
            },
          ),
        ],
      ),
    );
  }

  void _removeBook(Book book) {
    setState(() {
      _books.removeWhere((b) => b.id == book.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已移除《${book.title}》'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            setState(() {
              _books.add(book);
            });
          },
        ),
      ),
    );
  }
}
