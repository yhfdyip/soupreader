import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../bookshelf/models/book.dart';

/// 阅读器目录/书签/笔记面板（对标同类阅读器的“目录抽屉”交互）
///
/// - 暖色背景（类似 Legado）
/// - 顶部展示书籍信息
/// - Tab：目录 / 书签 / 笔记
/// - 工具按钮：清缓存、刷新（检查更新/重新拉取目录由外部注入）
class ReaderCatalogSheet extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final List<BookmarkEntity> bookmarks;

  /// 清理本书已缓存章节内容（不删除目录条目）
  final Future<ChapterCacheInfo> Function() onClearBookCache;

  /// 刷新目录（可实现为“检查更新/重新拉取目录”），返回刷新后的章节列表
  final Future<List<Chapter>> Function() onRefreshCatalog;

  final ValueChanged<int> onChapterSelected;
  final ValueChanged<BookmarkEntity> onBookmarkSelected;
  final Future<void> Function(BookmarkEntity bookmark) onDeleteBookmark;

  const ReaderCatalogSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.chapters,
    required this.currentChapterIndex,
    required this.bookmarks,
    required this.onClearBookCache,
    required this.onRefreshCatalog,
    required this.onChapterSelected,
    required this.onBookmarkSelected,
    required this.onDeleteBookmark,
  });

  @override
  State<ReaderCatalogSheet> createState() => _ReaderCatalogSheetState();
}

class _ReaderCatalogSheetState extends State<ReaderCatalogSheet> {
  int _selectedTab = 0; // 0=目录, 1=书签, 2=笔记
  bool _isReversed = false;
  bool _busy = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late List<Chapter> _chapters;
  late List<BookmarkEntity> _bookmarks;

  @override
  void initState() {
    super.initState();
    _chapters = List<Chapter>.from(widget.chapters);
    _bookmarks = List<BookmarkEntity>.from(widget.bookmarks);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentChapter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentChapter() {
    if (_selectedTab != 0) return;
    if (!_scrollController.hasClients) return;

    final index = _isReversed
        ? _chapters.length - 1 - widget.currentChapterIndex
        : widget.currentChapterIndex;
    if (index <= 0 || index >= _chapters.length) return;

    // 估算每个 item 高度，避免首次打开时找不到当前章节
    final estimatedItemHeight = 56.0;
    final target = (index * estimatedItemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    _scrollController.jumpTo(target);
  }

  List<Chapter> get _filteredChapters {
    var list = _chapters;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((c) => c.title.toLowerCase().contains(q))
          .toList(growable: false);
    }
    if (_isReversed) {
      list = list.reversed.toList(growable: false);
    }
    return list;
  }

  List<BookmarkEntity> get _filteredBookmarks {
    var list = _bookmarks;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((b) =>
              b.chapterTitle.toLowerCase().contains(q) ||
              b.content.toLowerCase().contains(q))
          .toList(growable: false);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F5), // 暖色背景（对标 Legado）
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildGrabber(),
            _buildHeader(),
            _buildTabBar(),
            _buildSearchAndSort(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _BookCover(
            title: widget.bookTitle,
            coverUrl: widget.coverUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bookTitle,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.bookAuthor.trim().isNotEmpty
                      ? widget.bookAuthor.trim()
                      : '未知作者',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共${_chapters.length}章',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final chapterCount = _chapters.length;
    final bookmarkCount = _bookmarks.length;

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Row(
        children: [
          _buildTab(0, '目录', count: chapterCount),
          _buildTab(1, '书签', count: bookmarkCount),
          _buildTab(2, '笔记'),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _busy ? null : _confirmClearCache,
            child: Icon(
              CupertinoIcons.trash,
              size: 20,
              color: _busy ? const Color(0xFFBBBBBB) : const Color(0xFF666666),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _busy ? null : _refreshCatalog,
            child: Icon(
              CupertinoIcons.arrow_clockwise,
              size: 20,
              color: _busy ? const Color(0xFFBBBBBB) : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, {int? count}) {
    final isSelected = _selectedTab == index;
    final title = count == null ? label : '$label ($count)';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedTab = index;
          _searchQuery = '';
          _searchController.text = '';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentChapter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color:
                isSelected ? const Color(0xFF4CAF50) : const Color(0xFF666666),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndSort() {
    final showSort = _selectedTab == 0;
    final placeholder = switch (_selectedTab) {
      0 => '输入关键字搜索目录',
      1 => '搜索书签',
      _ => '搜索',
    };

    // 笔记暂未实现，避免显示“可搜索但无内容”的假入口
    if (_selectedTab == 2) {
      return const SizedBox(height: 8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CupertinoTextField(
                controller: _searchController,
                placeholder: placeholder,
                placeholderStyle:
                    const TextStyle(color: Color(0xFF999999), fontSize: 13),
                style: const TextStyle(color: Color(0xFF333333), fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: null,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    CupertinoIcons.search,
                    size: 16,
                    color: Color(0xFF999999),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          if (showSort) ...[
            CupertinoButton(
              padding: const EdgeInsets.only(left: 12),
              onPressed: () {
                setState(() => _isReversed = !_isReversed);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToCurrentChapter();
                });
              },
              child: Icon(
                _isReversed ? CupertinoIcons.sort_up : CupertinoIcons.sort_down,
                size: 22,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_selectedTab) {
      0 => _buildChapterList(),
      1 => _buildBookmarkList(),
      _ => _buildEmptyTab('暂无笔记'),
    };
  }

  Widget _buildChapterList() {
    final chapters = _filteredChapters;
    if (chapters.isEmpty) {
      return _buildEmptyTab(_searchQuery.trim().isNotEmpty ? '无匹配章节' : '暂无章节');
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final originalIndex = chapter.index;
        final isCurrent = originalIndex == widget.currentChapterIndex;
        final hasCache = chapter.isDownloaded && (chapter.content?.isNotEmpty ?? false);

        return GestureDetector(
          onTap: () => widget.onChapterSelected(originalIndex),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    chapter.title,
                    style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF333333),
                      fontSize: 14,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasCache)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      CupertinoIcons.cloud_download_fill,
                      color: Color(0xFFAAAAAA),
                      size: 16,
                    ),
                  ),
                if (isCurrent)
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: Color(0xFF4CAF50),
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookmarkList() {
    final bookmarks = _filteredBookmarks;
    if (bookmarks.isEmpty) {
      final message = _searchQuery.trim().isNotEmpty ? '无匹配书签' : '暂无书签';
      return _buildEmptyTab(message);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => Container(
        height: 1,
        color: const Color(0xFFEEEEEE),
      ),
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return Dismissible(
          key: ValueKey(bookmark.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            color: const Color(0xFFFFEAEA),
            child: const Icon(
              CupertinoIcons.delete,
              color: CupertinoColors.destructiveRed,
              size: 20,
            ),
          ),
          confirmDismiss: (_) async {
            return await _confirmDeleteBookmark(bookmark);
          },
          onDismissed: (_) async {
            await widget.onDeleteBookmark(bookmark);
            if (!mounted) return;
            setState(() {
              _bookmarks.removeWhere((b) => b.id == bookmark.id);
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onBookmarkSelected(bookmark),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookmark.chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bookmark.content.trim().isNotEmpty
                              ? bookmark.content.trim()
                              : '（无预览内容）',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.chevron_forward,
                    color: Color(0xFFBBBBBB),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyTab(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.doc_text,
            size: 48,
            color: Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteBookmark(BookmarkEntity bookmark) async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('删除书签'),
            content: Text('\n确定删除该书签吗？\n\n${bookmark.chapterTitle}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showToast(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  int _estimateCachedChapters() {
    var count = 0;
    for (final chapter in _chapters) {
      if (chapter.isDownloaded && (chapter.content?.isNotEmpty ?? false)) {
        count++;
      }
    }
    return count;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0B';
    const k = 1024.0;
    final kb = bytes / k;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)}MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)}GB';
  }

  Future<void> _confirmClearCache() async {
    final cachedCount = _estimateCachedChapters();
    if (cachedCount <= 0) {
      _showToast('暂无可清理的章节缓存');
      return;
    }

    final ok = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('清理缓存'),
            content: Text('\n将清理本书已缓存的 $cachedCount 章内容（不删除目录）。'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('清理'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final info = await widget.onClearBookCache();
      if (!mounted) return;
      setState(() {
        _chapters = _chapters
            .map((c) => c.isDownloaded
                ? c.copyWith(isDownloaded: false, content: null)
                : c)
            .toList(growable: false);
      });
      _showToast('已清理：${info.chapters}章 / ${_formatBytes(info.bytes)}');
    } catch (e) {
      if (!mounted) return;
      _showToast('清理失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshCatalog() async {
    setState(() => _busy = true);
    final oldCount = _chapters.length;
    try {
      final updated = await widget.onRefreshCatalog();
      if (!mounted) return;
      setState(() {
        _chapters = List<Chapter>.from(updated);
      });

      final diff = _chapters.length - oldCount;
      if (diff > 0) {
        _showToast('发现更新：新增 $diff 章');
      } else {
        _showToast('暂无更新');
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('刷新失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _BookCover extends StatelessWidget {
  final String title;
  final String? coverUrl;

  const _BookCover({
    required this.title,
    required this.coverUrl,
  });

  bool _isRemote(String value) {
    final uri = Uri.tryParse(value);
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  @override
  Widget build(BuildContext context) {
    final url = (coverUrl ?? '').trim();
    if (url.isNotEmpty && _isRemote(url)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          url,
          width: 50,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final first = title.trim().isNotEmpty ? title.trim().substring(0, 1) : '?';
    return Container(
      width: 50,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E4DF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black12),
      ),
      alignment: Alignment.center,
      child: Text(
        first,
        style: const TextStyle(
          color: Colors.black38,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
