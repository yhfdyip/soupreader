import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../bookshelf/models/book.dart';
import '../services/reader_legacy_menu_helper.dart';

/// 阅读器目录/书签面板（对标 legado 目录抽屉交互）
///
/// - 暖色背景（类似 Legado）
/// - 顶部展示书籍信息
/// - Tab：目录 / 书签
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
  final Map<int, String> initialDisplayTitlesByIndex;
  final Future<String> Function(Chapter chapter)? resolveDisplayTitle;
  final bool isLocalTxtBook;
  final bool initialUseReplace;
  final bool initialLoadWordCount;
  final bool initialSplitLongChapter;
  final ValueChanged<bool>? onUseReplaceChanged;
  final ValueChanged<bool>? onLoadWordCountChanged;
  final ValueChanged<bool>? onSplitLongChapterChanged;
  final Future<void> Function(bool splitLongChapter)? onApplySplitLongChapter;
  final Future<void> Function()? onOpenLogs;
  final Future<void> Function()? onExportBookmark;
  final Future<void> Function()? onExportBookmarkMarkdown;
  final VoidCallback? onEditTocRule;

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
    this.initialDisplayTitlesByIndex = const <int, String>{},
    this.resolveDisplayTitle,
    this.isLocalTxtBook = false,
    this.initialUseReplace = false,
    this.initialLoadWordCount = false,
    this.initialSplitLongChapter = false,
    this.onUseReplaceChanged,
    this.onLoadWordCountChanged,
    this.onSplitLongChapterChanged,
    this.onApplySplitLongChapter,
    this.onOpenLogs,
    this.onExportBookmark,
    this.onExportBookmarkMarkdown,
    this.onEditTocRule,
  });

  @override
  State<ReaderCatalogSheet> createState() => _ReaderCatalogSheetState();
}

class _ReaderCatalogSheetState extends State<ReaderCatalogSheet> {
  static const double _chapterListItemExtent = 60;
  static const double _currentChapterAlignment = 0.08;

  int _selectedTab = 0; // 0=目录, 1=书签
  bool _isReversed = false;
  bool _busy = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _chapterItemKeys = <int, GlobalKey>{};
  final Map<int, String> _displayTitlesByChapterIndex = <int, String>{};

  late List<Chapter> _chapters;
  late List<BookmarkEntity> _bookmarks;
  int? _lastAutoScrollTargetChapterIndex;
  bool _pendingPreciseScroll = false;
  int _displayTitleResolverToken = 0;
  bool _useReplace = false;
  bool _loadWordCount = false;
  bool _splitLongChapter = false;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _panelBg =>
      _isDark ? AppDesignTokens.surfaceDark : const Color(0xFFFAF8F5);

  Color get _textStrong =>
      _isDark ? AppDesignTokens.textInverse : const Color(0xFF333333);

  Color get _textNormal =>
      _isDark ? AppDesignTokens.textMuted : const Color(0xFF666666);

  Color get _textSubtle =>
      _isDark ? AppDesignTokens.textMuted : const Color(0xFF888888);

  Color get _lineColor =>
      _isDark ? AppDesignTokens.borderDark : const Color(0xFFEEEEEE);

  Color get _cardMutedBg =>
      _isDark ? AppDesignTokens.pageBgDark : const Color(0xFFF0EDE8);

  @override
  void initState() {
    super.initState();
    _chapters = List<Chapter>.from(widget.chapters);
    _bookmarks = List<BookmarkEntity>.from(widget.bookmarks);
    _useReplace = widget.initialUseReplace;
    _loadWordCount = widget.initialLoadWordCount;
    _splitLongChapter = widget.initialSplitLongChapter;
    _primeDisplayTitles(reset: true);

    _scheduleScrollToCurrentChapter();
  }

  @override
  void dispose() {
    _displayTitleResolverToken++;
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderCatalogSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    final chapterListChanged = !identical(oldWidget.chapters, widget.chapters);
    final currentChapterChanged =
        oldWidget.currentChapterIndex != widget.currentChapterIndex;
    if (chapterListChanged || currentChapterChanged) {
      _chapters = List<Chapter>.from(widget.chapters);
      _resetAutoScrollState();
      _scheduleScrollToCurrentChapter();
    }
    if (!identical(oldWidget.bookmarks, widget.bookmarks)) {
      _bookmarks = List<BookmarkEntity>.from(widget.bookmarks);
    }
    if (oldWidget.initialUseReplace != widget.initialUseReplace) {
      _useReplace = widget.initialUseReplace;
    }
    if (oldWidget.initialLoadWordCount != widget.initialLoadWordCount) {
      _loadWordCount = widget.initialLoadWordCount;
    }
    if (oldWidget.initialSplitLongChapter != widget.initialSplitLongChapter) {
      _splitLongChapter = widget.initialSplitLongChapter;
    }

    final resolverChanged =
        oldWidget.resolveDisplayTitle != widget.resolveDisplayTitle;
    final initialTitlesChanged = !identical(
      oldWidget.initialDisplayTitlesByIndex,
      widget.initialDisplayTitlesByIndex,
    );
    if (chapterListChanged || resolverChanged || initialTitlesChanged) {
      _primeDisplayTitles(reset: true);
    } else if (currentChapterChanged) {
      _resolveDisplayTitlesAroundCurrent();
    }
  }

  Map<int, String> _sanitizeInitialDisplayTitles() {
    if (widget.initialDisplayTitlesByIndex.isEmpty || _chapters.isEmpty) {
      return const <int, String>{};
    }
    final validIndexes = _chapters.map((chapter) => chapter.index).toSet();
    final sanitized = <int, String>{};
    for (final entry in widget.initialDisplayTitlesByIndex.entries) {
      if (!validIndexes.contains(entry.key)) continue;
      if (entry.value.trim().isEmpty) continue;
      sanitized[entry.key] = entry.value;
    }
    return sanitized;
  }

  void _primeDisplayTitles({required bool reset}) {
    final seeded = _sanitizeInitialDisplayTitles();
    if (reset) {
      _displayTitlesByChapterIndex
        ..clear()
        ..addAll(seeded);
    } else {
      _displayTitlesByChapterIndex.addAll(seeded);
    }
    _resolveDisplayTitlesAroundCurrent();
  }

  int _resolveCurrentChapterListPosition() {
    for (var i = 0; i < _chapters.length; i++) {
      if (_chapters[i].index == widget.currentChapterIndex) {
        return i;
      }
    }
    return 0;
  }

  void _resolveDisplayTitlesAroundCurrent() {
    final resolver = widget.resolveDisplayTitle;
    if (resolver == null || _chapters.isEmpty) {
      _displayTitleResolverToken++;
      return;
    }
    final token = ++_displayTitleResolverToken;
    final start = _resolveCurrentChapterListPosition();
    unawaited(
      _resolveDisplayTitlesInDirection(
        resolver: resolver,
        token: token,
        start: start,
        step: 1,
      ),
    );
    unawaited(
      _resolveDisplayTitlesInDirection(
        resolver: resolver,
        token: token,
        start: start - 1,
        step: -1,
      ),
    );
  }

  void _refreshDisplayTitlesAfterReplaceToggle() {
    _displayTitleResolverToken++;
    setState(() {
      _displayTitlesByChapterIndex.clear();
    });
    _resolveDisplayTitlesAroundCurrent();
  }

  Future<void> _resolveDisplayTitlesInDirection({
    required Future<String> Function(Chapter chapter) resolver,
    required int token,
    required int start,
    required int step,
  }) async {
    if (step == 0) return;
    for (var i = start; i >= 0 && i < _chapters.length; i += step) {
      if (!mounted || token != _displayTitleResolverToken) return;
      final chapter = _chapters[i];
      if (_displayTitlesByChapterIndex.containsKey(chapter.index)) continue;
      var resolved = chapter.title;
      try {
        final title = await resolver(chapter);
        if (title.trim().isNotEmpty) {
          resolved = title;
        }
      } catch (_) {
        // 保持目录可用：单条解析失败时回退原始标题。
      }
      if (!mounted || token != _displayTitleResolverToken) return;
      if (_displayTitlesByChapterIndex[chapter.index] == resolved) continue;
      setState(() {
        _displayTitlesByChapterIndex[chapter.index] = resolved;
      });
    }
  }

  String _displayTitleForChapter(Chapter chapter) {
    return _displayTitlesByChapterIndex[chapter.index] ?? chapter.title;
  }

  GlobalKey _chapterKeyFor(int chapterIndex) {
    return _chapterItemKeys.putIfAbsent(
      chapterIndex,
      () => GlobalKey(debugLabel: 'catalog_chapter_$chapterIndex'),
    );
  }

  int? _findCurrentVisibleListIndex() {
    final chapters = _filteredChapters;
    for (var i = 0; i < chapters.length; i++) {
      if (chapters[i].index == widget.currentChapterIndex) {
        return i;
      }
    }
    return null;
  }

  void _resetAutoScrollState() {
    _lastAutoScrollTargetChapterIndex = null;
    _pendingPreciseScroll = false;
  }

  double _clampTargetOffset(double rawOffset) {
    final position = _scrollController.position;
    return rawOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  void _scheduleScrollToCurrentChapter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToCurrentChapter();
    });
  }

  void _scrollToCurrentChapter() {
    if (_selectedTab != 0) return;
    if (!_scrollController.hasClients) return;

    final chapters = _filteredChapters;
    if (chapters.isEmpty) return;

    final currentVisibleIndex = _findCurrentVisibleListIndex();
    if (currentVisibleIndex == null) return;

    // 对齐 legado：将当前章前一项滚动到可视区顶部，避免当前章贴边显示。
    final targetVisibleIndex =
        currentVisibleIndex > 0 ? currentVisibleIndex - 1 : 0;
    if (targetVisibleIndex < 0 || targetVisibleIndex >= chapters.length) return;

    final targetChapterIndex = chapters[targetVisibleIndex].index;
    if (_lastAutoScrollTargetChapterIndex != targetChapterIndex) {
      final estimatedOffset = targetVisibleIndex * _chapterListItemExtent;
      _scrollController.jumpTo(_clampTargetOffset(estimatedOffset));
      _lastAutoScrollTargetChapterIndex = targetChapterIndex;
    }
    if (_pendingPreciseScroll) return;

    _pendingPreciseScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingPreciseScroll = false;
      if (!mounted || _selectedTab != 0 || !_scrollController.hasClients) {
        return;
      }
      final targetContext = _chapterKeyFor(targetChapterIndex).currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        alignment: _currentChapterAlignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  List<Chapter> get _filteredChapters {
    var list = _chapters;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      // 对齐 legado：目录检索仍基于章节原始标题字段（BookChapter.title）。
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
      decoration: BoxDecoration(
        color: _panelBg,
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
    final color = _isDark
        ? AppDesignTokens.textMuted.withValues(alpha: 0.45)
        : const Color(0x1F000000);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color,
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
                  style: TextStyle(
                    color: _textStrong,
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
                  style: TextStyle(
                    color: _textSubtle,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共${_chapters.length}章',
                  style: TextStyle(
                    color: _textSubtle,
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _lineColor),
        ),
      ),
      child: Row(
        children: [
          _buildTab(0, '目录', count: chapterCount),
          _buildTab(1, '书签', count: bookmarkCount),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _busy ? null : _showTocActionsMenu,
            child: Icon(
              CupertinoIcons.ellipsis_circle,
              size: 20,
              color: _busy
                  ? AppDesignTokens.textMuted.withValues(alpha: 0.55)
                  : _textNormal,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _busy ? null : _confirmClearCache,
            child: Icon(
              CupertinoIcons.trash,
              size: 20,
              color: _busy
                  ? AppDesignTokens.textMuted.withValues(alpha: 0.55)
                  : _textNormal,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _busy ? null : _refreshCatalog,
            child: Icon(
              CupertinoIcons.arrow_clockwise,
              size: 20,
              color: _busy
                  ? AppDesignTokens.textMuted.withValues(alpha: 0.55)
                  : _textNormal,
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
          _resetAutoScrollState();
        });
        _scheduleScrollToCurrentChapter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? _accent : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? _accent : _textNormal,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndSort() {
    final showSort = _selectedTab == 0;
    final placeholder = _selectedTab == 0 ? '输入关键字搜索目录' : '搜索书签';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: _cardMutedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoTextField(
                    controller: _searchController,
                    placeholder: placeholder,
                    placeholderStyle:
                        TextStyle(color: _textSubtle, fontSize: 13),
                    style: TextStyle(color: _textStrong, fontSize: 13),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: null,
                    prefix: Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        CupertinoIcons.search,
                        size: 16,
                        color: _textSubtle,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _resetAutoScrollState();
                      });
                      _scheduleScrollToCurrentChapter();
                    },
                  ),
                ),
              ),
              if (showSort) ...[
                CupertinoButton(
                  padding: const EdgeInsets.only(left: 12),
                  onPressed: () {
                    setState(() {
                      _isReversed = !_isReversed;
                      _resetAutoScrollState();
                    });
                    _scheduleScrollToCurrentChapter();
                  },
                  child: Icon(
                    _isReversed
                        ? CupertinoIcons.sort_up
                        : CupertinoIcons.sort_down,
                    size: 22,
                    color: _textNormal,
                  ),
                ),
              ],
            ],
          ),
          if (_selectedTab == 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _searchQuery.trim().isEmpty
                      ? '共 ${_chapters.length} 章'
                      : '匹配 ${_filteredChapters.length} 章',
                  style: TextStyle(
                    color: _textSubtle,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedTab == 0) return _buildChapterList();
    return _buildBookmarkList();
  }

  void _showTocActionsMenu() {
    final actions = ReaderLegacyMenuHelper.buildTocMenuActions(
      bookmarkTab: _selectedTab == 1,
      isLocalTxt: widget.isLocalTxtBook,
    );
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('目录操作'),
        actions: actions
            .map(
              (action) => CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _runTocAction(action);
                },
                child: Text(_tocActionLabel(action)),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  String _tocActionLabel(ReaderLegacyTocMenuAction action) {
    final raw = ReaderLegacyMenuHelper.tocMenuLabel(action);
    final checked = switch (action) {
      ReaderLegacyTocMenuAction.reverseToc => _isReversed,
      ReaderLegacyTocMenuAction.useReplace => _useReplace,
      ReaderLegacyTocMenuAction.loadWordCount => _loadWordCount,
      ReaderLegacyTocMenuAction.splitLongChapter => _splitLongChapter,
      _ => false,
    };
    return checked ? '✓ $raw' : raw;
  }

  Future<void> _runTocAction(ReaderLegacyTocMenuAction action) async {
    switch (action) {
      case ReaderLegacyTocMenuAction.reverseToc:
        setState(() {
          _isReversed = !_isReversed;
          _resetAutoScrollState();
        });
        _scheduleScrollToCurrentChapter();
        return;
      case ReaderLegacyTocMenuAction.useReplace:
        setState(() => _useReplace = !_useReplace);
        widget.onUseReplaceChanged?.call(_useReplace);
        _refreshDisplayTitlesAfterReplaceToggle();
        _showToast(_useReplace ? '已开启目录替换规则' : '已关闭目录替换规则');
        return;
      case ReaderLegacyTocMenuAction.loadWordCount:
        setState(() => _loadWordCount = !_loadWordCount);
        widget.onLoadWordCountChanged?.call(_loadWordCount);
        _showToast(_loadWordCount ? '已开启目录字数显示' : '已关闭目录字数显示');
        return;
      case ReaderLegacyTocMenuAction.tocRule:
        if (widget.onEditTocRule != null) {
          widget.onEditTocRule!.call();
        } else {
          _showToast('当前书籍未接入 TXT 目录规则配置');
        }
        return;
      case ReaderLegacyTocMenuAction.splitLongChapter:
        final next = !_splitLongChapter;
        setState(() => _busy = true);
        try {
          if (widget.onApplySplitLongChapter != null) {
            await widget.onApplySplitLongChapter!.call(next);
          }
          widget.onSplitLongChapterChanged?.call(next);
          if (!mounted) return;
          setState(() => _splitLongChapter = next);
          if (next) {
            _showToast('已开启“分割长章节”');
          } else {
            _showToast('已关闭“分割长章节”，重新加载正文可能需要更长时间');
          }
        } catch (error) {
          if (mounted) {
            _showToast('切换分割长章节失败：$error');
          }
        } finally {
          if (mounted) {
            setState(() => _busy = false);
          }
        }
        return;
      case ReaderLegacyTocMenuAction.exportBookmark:
        if (widget.onExportBookmark != null) {
          await widget.onExportBookmark!.call();
        } else {
          _showToast('当前书籍不支持导出书签');
        }
        return;
      case ReaderLegacyTocMenuAction.exportMarkdown:
        if (widget.onExportBookmarkMarkdown != null) {
          await widget.onExportBookmarkMarkdown!.call();
        } else {
          _showToast('当前书籍不支持导出 Markdown');
        }
        return;
      case ReaderLegacyTocMenuAction.log:
        if (widget.onOpenLogs != null) {
          await widget.onOpenLogs!.call();
        } else {
          _showToast('日志入口不可用');
        }
        return;
    }
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
        final hasCache =
            chapter.isDownloaded && (chapter.content?.isNotEmpty ?? false);

        return GestureDetector(
          key: _chapterKeyFor(originalIndex),
          onTap: () => widget.onChapterSelected(originalIndex),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: _chapterListItemExtent),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isCurrent
                  ? _accent.withValues(alpha: _isDark ? 0.12 : 0.1)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrent
                    ? _accent.withValues(alpha: _isDark ? 0.35 : 0.24)
                    : const Color(0x00000000),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${originalIndex + 1}',
                    style: TextStyle(
                      color: isCurrent ? _accent : _textSubtle,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _displayTitleForChapter(chapter),
                    style: TextStyle(
                      color: isCurrent ? _accent : _textStrong,
                      fontSize: 14,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasCache)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _cardMutedBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '已缓存',
                        style: TextStyle(
                          color: _textSubtle,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                if (isCurrent)
                  Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: _accent,
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
        color: _lineColor,
      ),
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return Dismissible(
          key: ValueKey(bookmark.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            color: _isDark
                ? CupertinoColors.destructiveRed.withValues(alpha: 0.18)
                : const Color(0xFFFFEAEA),
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
                      color: _accent,
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
                          style: TextStyle(
                            color: _textStrong,
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
                          style: TextStyle(
                            color: _textSubtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    color: _textSubtle,
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
          Icon(
            CupertinoIcons.doc_text,
            size: 48,
            color: _textSubtle.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: _textSubtle, fontSize: 14),
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
        _resetAutoScrollState();
      });
      _primeDisplayTitles(reset: true);
      _scheduleScrollToCurrentChapter();

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

  @override
  Widget build(BuildContext context) {
    return AppCoverImage(
      urlOrPath: coverUrl,
      title: title,
      width: 50,
      height: 70,
      borderRadius: 4,
      showTextOnPlaceholder: false,
    );
  }
}
