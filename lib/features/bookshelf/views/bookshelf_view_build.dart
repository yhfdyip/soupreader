// ignore_for_file: invalid_use_of_protected_member
part of 'bookshelf_view.dart';

extension _BookshelfBuildX on _BookshelfViewState {
  Widget _buildInitErrorPage() {
    return AppCupertinoPageScaffold(
      title: '书架',
      useSliverNavigationBar: true,
      sliverScrollController: _scrollController,
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => SliverSafeArea(
        top: true,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: _buildInitError(),
        ),
      ),
    );
  }

  Widget _buildBodySliver() {
    if (_initError != null) {
      return SliverSafeArea(
        top: true,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: _buildInitError(),
        ),
      );
    }
    final displayItems = _displayItems();
    final contentSliver = displayItems.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        : _buildBookList(displayItems);
    if (_isStyle2Enabled) {
      return SliverSafeArea(
        top: true,
        bottom: true,
        sliver: contentSliver,
      );
    }
    return SliverSafeArea(
      top: true,
      bottom: true,
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: _buildStyle1GroupBar(),
          ),
          contentSliver,
        ],
      ),
    );
  }

  Widget _buildStyle1GroupBar() {
    final groups = _visibleGroupsForStyle1();
    if (groups.isEmpty) return const SizedBox.shrink();
    final selectedIndex = _resolveStyle1SelectedTabIndex(groups);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final activeColor = CupertinoTheme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: separatorColor,
            width: AppDesignTokens.hairlineBorderWidth,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            return _buildStyle1GroupChip(
              group: group,
              index: index,
              selected: index == selectedIndex,
              activeColor: activeColor,
              separatorColor: separatorColor,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStyle1GroupChip({
    required BookshelfBookGroup group,
    required int index,
    required bool selected,
    required Color activeColor,
    required Color separatorColor,
  }) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final bgColor = selected
        ? activeColor.withValues(alpha: 0.14)
        : CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onStyle1GroupTap(index, group),
      onLongPress: () => _onStyle1GroupLongPress(group),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.45)
                : separatorColor.withValues(alpha: 0.8),
            width: AppDesignTokens.hairlineBorderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          group.groupName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.2,
            color: selected ? activeColor : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildInitError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, size: 40),
            const SizedBox(height: 12),
            Text(
              _initError ?? '初始化失败',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 90),
      title: '书架空空如也',
      message: '先导入一本本地书，或从搜索添加网络书籍',
      action: CupertinoButton.filled(
        onPressed: _importLocalBook,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc,
              size: 17,
              color: CupertinoColors.white,
            ),
            SizedBox(width: 6),
            Text(
              '导入本地书籍',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList(List<Object> displayItems) {
    if (_isGridView) {
      return _buildGridSliver(displayItems);
    } else {
      return _buildListSliver(displayItems);
    }
  }

  Widget _wrapWithFastScroller(Widget child) {
    if (_initError != null || _displayItems().isEmpty) return child;
    if (!_settingsService.appSettings.bookshelfShowFastScroller) {
      return child;
    }
    return CupertinoScrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: child,
    );
  }

  Widget _buildGridSliver(List<Object> displayItems) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridCrossAxisCount,
          childAspectRatio: 0.56,
          crossAxisSpacing: 2,
          mainAxisSpacing: 6,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = displayItems[index];
            if (item is BookshelfBookGroup) {
              return _buildGroupGridCard(item);
            }
            if (item is Book) {
              return _buildBookCard(item);
            }
            return const SizedBox.shrink();
          },
          childCount: displayItems.length,
        ),
      ),
    );
  }

  Widget _buildGroupGridCard(BookshelfBookGroup group) {
    return GestureDetector(
      onTap: () => _onGroupTap(group),
      onLongPress: () => _onGroupLongPress(group),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppUiTokens.resolve(context).colors.card,
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
                ),
                child: AppCoverImage(
                  urlOrPath: group.cover,
                  title: group.groupName,
                  author: '',
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: AppDesignTokens.radiusControl,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 12 * 1.25 * 2,
              child: Text(
                group.groupName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    final unreadCount = _settingsService.appSettings.bookshelfShowUnread
        ? _unreadCountLikeLegado(book)
        : 0;
    final isUpdating = _isUpdating(book);

    return GestureDetector(
      onTap: () => _openReader(book),
      onLongPress: () => _onBookLongPress(book),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppUiTokens.resolve(context).colors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppCoverImage(
                        urlOrPath: book.coverUrl,
                        title: book.title,
                        author: book.author,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: AppDesignTokens.radiusControl,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: isUpdating
                        ? _buildGridLoadingBadge()
                        : _buildGridUnreadBadge(unreadCount),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 12 * 1.25 * 2,
              child: Text(
                book.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLoadingBadge() => const _BookshelfGridLoadingBadge();

  Widget _buildGridUnreadBadge(int unreadCount) =>
      _BookshelfGridUnreadBadge(unreadCount: unreadCount);

  int _unreadCountLikeLegado(Book book) {
    final total = book.totalChapters;
    if (total <= 0) return 0;
    final current = book.currentChapter.clamp(0, total - 1);
    return math.max(total - current - 1, 0);
  }

  bool _isUpdating(Book book) {
    if (book.isLocal) return false;
    return _updatingBookIds.contains(book.id);
  }

  BoxDecoration _buildListCardDecoration(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    return BoxDecoration(
      color: uiTokens.colors.card,
      borderRadius: BorderRadius.circular(uiTokens.radii.card),
    );
  }

  TextStyle _buildListTitleStyle() {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoColors.label.resolveFrom(context),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
  }

  TextStyle _buildListMetaStyle() {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          fontSize: 12,
        );
  }

  Widget _buildListSliver(List<Object> displayItems) {
    final theme = CupertinoTheme.of(context);
    final metaTextStyle = _buildListMetaStyle();
    final titleTextStyle = _buildListTitleStyle();
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    final showLastUpdateTime =
        _settingsService.appSettings.bookshelfShowLastUpdateTime;
    final sliverItemCount =
        displayItems.isEmpty ? 0 : displayItems.length * 2 - 1;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index.isOdd) return const SizedBox(height: 8);
            final item = displayItems[index ~/ 2];
            if (item is BookshelfBookGroup) {
              return _buildGroupListTile(item);
            }
            if (item is! Book) return const SizedBox.shrink();
            final book = item;
            final readAgo = _formatReadAgo(book.lastReadTime);
            final isUpdating = _isUpdating(book);
            return GestureDetector(
              onTap: () => _openReader(book),
              onLongPress: () => _onBookLongPress(book),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: _buildListCardDecoration(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCoverImage(
                      urlOrPath: book.coverUrl,
                      title: book.title,
                      author: book.author,
                      width: 66,
                      height: 90,
                      borderRadius: AppDesignTokens.radiusControl,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleTextStyle,
                                ),
                              ),
                              if (book.isReading)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    book.progressText,
                                    style: metaTextStyle.copyWith(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.person,
                                size: 13,
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  book.author.trim().isEmpty
                                      ? '未知作者'
                                      : book.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                              ),
                              if (showLastUpdateTime && readAgo != null)
                                Text(
                                  readAgo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock,
                                size: 13,
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _buildReadLine(book),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.book,
                                size: 13,
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _buildLatestLine(book),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: isUpdating
                          ? const CupertinoActivityIndicator(radius: 8)
                          : Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: secondaryLabel,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: sliverItemCount,
        ),
      ),
    );
  }

  Widget _buildGroupListTile(BookshelfBookGroup group) {
    final metaTextStyle = _buildListMetaStyle();
    final titleTextStyle = _buildListTitleStyle();
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      onTap: () => _onGroupTap(group),
      onLongPress: () => _onGroupLongPress(group),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: _buildListCardDecoration(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCoverImage(
              urlOrPath: group.cover,
              title: group.groupName,
              author: '',
              width: 66,
              height: 90,
              borderRadius: AppDesignTokens.radiusControl,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleTextStyle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '分组',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: metaTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onGroupTap(BookshelfBookGroup group) {
    if (!_isStyle2Enabled) return;
    if (_selectedGroupId == group.groupId) return;
    debugPrint(
      '[bookshelf] style2 enter group id=${group.groupId}, name=${group.groupName}',
    );
    setState(() => _selectedGroupId = group.groupId);
    _scrollToTop();
  }

  void _onGroupLongPress(BookshelfBookGroup _) {
    if (!_isStyle2Enabled) return;
    // 当前迁移阶段以“分组管理”作为分组编辑统一入口。
    _openBookshelfGroupManageDialog();
  }

  void _onStyle1GroupTap(int index, BookshelfBookGroup group) {
    final groups = _visibleGroupsForStyle1();
    final currentIndex = _resolveStyle1SelectedTabIndex(groups);
    if (index == currentIndex) {
      final count = _filterBooksByGroup(_books, group.groupId).length;
      debugPrint(
        '[bookshelf] style1 reselect group=${group.groupName} count=$count',
      );
      _showBottomHint('${group.groupName}($count)');
      return;
    }
    debugPrint(
      '[bookshelf] style1 select tab index=$index group=${group.groupName}',
    );
    setState(() => _style1SelectedTabIndex = index);
    _scrollToTop();
    unawaited(_persistStyle1SelectedTabIndex(index));
  }

  void _onStyle1GroupLongPress(BookshelfBookGroup group) {
    debugPrint(
      '[bookshelf] style1 long press group id=${group.groupId} name=${group.groupName}',
    );
    // 当前迁移阶段以“分组管理”作为分组编辑统一入口。
    _openBookshelfGroupManageDialog();
  }

  String _buildReadLine(Book book) {
    final total = book.totalChapters;
    if (total <= 0) {
      return book.isReading ? '阅读进度 ${book.progressText}' : '未开始阅读';
    }
    final current = (book.currentChapter + 1).clamp(1, total);
    if (!book.isReading) {
      return '未开始阅读 · 共 $total 章';
    }
    final unreadCount = _settingsService.appSettings.bookshelfShowUnread
        ? _unreadCountLikeLegado(book)
        : 0;
    if (unreadCount <= 0) {
      return '阅读：$current/$total 章';
    }
    return '阅读：$current/$total 章 · 未读 $unreadCount';
  }

  String _buildLatestLine(Book book) {
    final latest = (book.latestChapter ?? '').trim();
    if (latest.isNotEmpty) {
      return '最新：$latest';
    }
    if (book.isLocal) {
      return '本地书籍';
    }
    return '暂无最新章节';
  }

  String? _formatReadAgo(DateTime? value) {
    if (value == null) return null;
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';

    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  void _openReader(Book book) {
    Navigator.of(context, rootNavigator: true)
        .push(
          CupertinoPageRoute(
            builder: (context) => SimpleReaderView(
              bookId: book.id,
              bookTitle: book.title,
              initialChapter: book.currentChapter,
            ),
          ),
        )
        .then((_) => _loadBooks()); // 返回时刷新列表
  }

  void _onBookLongPress(Book book) {
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoActionSheet(
        title: Text(book.title),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('书籍详情'),
            onPressed: () {
              Navigator.pop(context);
              _showBookInfo(book);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('移除书籍'),
            onPressed: () async {
              Navigator.pop(context);
              await _bookRepo.deleteBook(book.id);
              _loadBooks();
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

  Future<void> _showBookInfo(Book book) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    if (!mounted) return;
    _loadBooks();
  }
}

class _BookshelfGridLoadingBadge extends StatelessWidget {
  const _BookshelfGridLoadingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: CupertinoColors.label.resolveFrom(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const CupertinoActivityIndicator(radius: 6),
    );
  }
}

class _BookshelfGridUnreadBadge extends StatelessWidget {
  final int unreadCount;

  const _BookshelfGridUnreadBadge({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) return const SizedBox.shrink();
    final label = unreadCount > 99 ? '99+' : '$unreadCount';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
