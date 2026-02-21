import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../import/import_service.dart';
import '../../reader/views/simple_reader_view.dart';
import '../../search/views/search_book_info_view.dart';
import '../../search/views/search_view.dart';
import '../../settings/views/exception_logs_view.dart';
import '../services/bookshelf_booklist_import_service.dart';
import '../services/bookshelf_catalog_update_service.dart';
import '../services/bookshelf_import_export_service.dart';
import '../models/book.dart';

/// 书架页面 - 纯 iOS 原生风格
class BookshelfView extends StatefulWidget {
  final ValueListenable<int>? reselectSignal;

  const BookshelfView({
    super.key,
    this.reselectSignal,
  });

  @override
  State<BookshelfView> createState() => _BookshelfViewState();
}

class _BookshelfViewState extends State<BookshelfView> {
  bool _isGridView = true;
  // 与 legado 一致：图墙/列表都可展示“更新中”状态。
  final Set<String> _updatingBookIds = <String>{};
  final ScrollController _scrollController = ScrollController();
  late final BookRepository _bookRepo;
  late final ImportService _importService;
  late final SettingsService _settingsService;
  late final BookshelfImportExportService _bookshelfIo;
  late final BookshelfBooklistImportService _booklistImporter;
  late final BookshelfCatalogUpdateService _catalogUpdater;
  StreamSubscription<List<Book>>? _booksSubscription;
  List<Book> _books = [];
  bool _isImporting = false;
  bool _isUpdatingCatalog = false;
  String? _initError;
  int? _lastExternalReselectVersion;

  @override
  void initState() {
    super.initState();
    try {
      debugPrint('[bookshelf] init start');
      final db = DatabaseService();
      _bookRepo = BookRepository(db);
      _importService = ImportService();
      _settingsService = SettingsService();
      _bookshelfIo = BookshelfImportExportService();
      _booklistImporter = BookshelfBooklistImportService();
      _catalogUpdater = BookshelfCatalogUpdateService(
        database: db,
        bookRepo: _bookRepo,
      );
      _isGridView = _settingsService.appSettings.bookshelfViewMode ==
          BookshelfViewMode.grid;
      _lastExternalReselectVersion = widget.reselectSignal?.value;
      widget.reselectSignal?.addListener(_onExternalReselectSignal);
      _loadBooks();
      _booksSubscription = _bookRepo.watchAllBooks().listen((books) {
        if (!mounted) return;
        setState(() {
          _books = List<Book>.from(books);
          _sortBooks(_settingsService.appSettings.bookshelfSortMode);
        });
      });
      debugPrint('[bookshelf] init done, books=\${_books.length}');
    } catch (e, st) {
      _initError = '书架初始化异常: $e';
      debugPrint('[bookshelf] init failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  void didUpdateWidget(covariant BookshelfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal == widget.reselectSignal) return;
    oldWidget.reselectSignal?.removeListener(_onExternalReselectSignal);
    _lastExternalReselectVersion = widget.reselectSignal?.value;
    widget.reselectSignal?.addListener(_onExternalReselectSignal);
  }

  @override
  void dispose() {
    _booksSubscription?.cancel();
    widget.reselectSignal?.removeListener(_onExternalReselectSignal);
    _scrollController.dispose();
    super.dispose();
  }

  void _onExternalReselectSignal() {
    final version = widget.reselectSignal?.value;
    if (version == null) return;
    if (_lastExternalReselectVersion == version) return;
    _lastExternalReselectVersion = version;
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _loadBooks() {
    setState(() {
      _books = List<Book>.from(_bookRepo.getAllBooks());
      _sortBooks(_settingsService.appSettings.bookshelfSortMode);
    });
  }

  void _sortBooks(BookshelfSortMode mode) {
    int compareDateTimeDesc(DateTime? a, DateTime? b) {
      final aTime = a ?? DateTime(2000);
      final bTime = b ?? DateTime(2000);
      return bTime.compareTo(aTime);
    }

    _books.sort((a, b) {
      switch (mode) {
        case BookshelfSortMode.recentRead:
          return compareDateTimeDesc(
            a.lastReadTime ?? a.addedTime,
            b.lastReadTime ?? b.addedTime,
          );
        case BookshelfSortMode.recentAdded:
          return compareDateTimeDesc(a.addedTime, b.addedTime);
        case BookshelfSortMode.title:
          return a.title.compareTo(b.title);
        case BookshelfSortMode.author:
          return a.author.compareTo(b.author);
      }
    });
  }

  Future<void> _importLocalBook() async {
    if (_isImporting) return;

    setState(() => _isImporting = true);

    try {
      final result = await _importService.importLocalBook();

      if (result.success && result.book != null) {
        _loadBooks();
        if (mounted) {
          _showMessage(
              '导入成功：${result.book!.title}\n共 ${result.chapterCount} 章');
        }
      } else if (!result.cancelled && result.errorMessage != null) {
        if (mounted) {
          _showMessage('导入失败：${result.errorMessage}');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _openGlobalSearch() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SearchView(),
      ),
    );
    if (!mounted) return;
    _loadBooks();
  }

  Future<void> _exportBookshelf() async {
    final result = await _bookshelfIo.exportToFile(_books);
    if (!result.success) {
      if (result.cancelled) return;
      _showMessage(result.errorMessage ?? '导出失败');
      return;
    }
    final hint = result.outputPathOrHint;
    _showMessage(hint == null ? '导出成功' : '导出成功：$hint');
  }

  Future<void> _importBookshelf() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    final parseResult = await _bookshelfIo.importFromFile();
    if (!parseResult.success) {
      if (mounted) setState(() => _isImporting = false);
      if (parseResult.cancelled) return;
      _showMessage(parseResult.errorMessage ?? '导入失败');
      return;
    }

    final progress = ValueNotifier<BooklistImportProgress>(
      BooklistImportProgress(
        done: 0,
        total: parseResult.items.length,
        currentName: '',
        currentSource: '',
      ),
    );

    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('正在导入书单'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ValueListenableBuilder<BooklistImportProgress>(
            valueListenable: progress,
            builder: (context, p, _) {
              final name = p.currentName.isEmpty ? '—' : p.currentName;
              final src = p.currentSource.isEmpty ? '—' : p.currentSource;
              return Column(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(height: 10),
                  Text('进度：${p.done}/${p.total}'),
                  const SizedBox(height: 6),
                  Text('当前：$name'),
                  const SizedBox(height: 6),
                  Text('书源：$src'),
                ],
              );
            },
          ),
        ),
      ),
    );

    final summary = await _booklistImporter.importBySearching(
      parseResult.items,
      onProgress: (p) => progress.value = p,
    );

    if (!mounted) return;
    Navigator.pop(context);
    setState(() => _isImporting = false);
    _loadBooks();

    final details = summary.errors.isEmpty
        ? ''
        : '\n\n失败详情（最多 5 条）：\n${summary.errors.take(5).join('\n')}';
    _showMessage('${summary.summaryText}$details');
  }

  String _sortLabel(BookshelfSortMode mode) {
    switch (mode) {
      case BookshelfSortMode.recentRead:
        return '最近阅读';
      case BookshelfSortMode.recentAdded:
        return '最近加入';
      case BookshelfSortMode.title:
        return '书名';
      case BookshelfSortMode.author:
        return '作者';
    }
  }

  Future<void> _applySortMode(BookshelfSortMode next) async {
    final current = _settingsService.appSettings.bookshelfSortMode;
    if (next == current) return;
    await _settingsService.saveAppSettings(
      _settingsService.appSettings.copyWith(bookshelfSortMode: next),
    );
    _loadBooks();
  }

  Future<void> _applyLayoutMode(BookshelfViewMode next) async {
    final current = _settingsService.appSettings.bookshelfViewMode;
    if (next == current) return;
    setState(() {
      _isGridView = next == BookshelfViewMode.grid;
    });
    await _settingsService.saveAppSettings(
      _settingsService.appSettings.copyWith(bookshelfViewMode: next),
    );
  }

  Future<void> _showLayoutMenu() async {
    final currentLayout = _settingsService.appSettings.bookshelfViewMode;
    final currentSort = _settingsService.appSettings.bookshelfSortMode;
    BookshelfViewMode? nextLayout;
    BookshelfSortMode? nextSort;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('书架布局'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: currentLayout == BookshelfViewMode.grid,
            child: const Text('图墙模式'),
            onPressed: () {
              nextLayout = BookshelfViewMode.grid;
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            isDefaultAction: currentLayout == BookshelfViewMode.list,
            child: const Text('列表模式'),
            onPressed: () {
              nextLayout = BookshelfViewMode.list;
              Navigator.pop(context);
            },
          ),
          for (final mode in BookshelfSortMode.values)
            CupertinoActionSheetAction(
              isDefaultAction: mode == currentSort,
              child: Text('排序：${_sortLabel(mode)}'),
              onPressed: () {
                nextSort = mode;
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

    if (nextLayout != null) {
      await _applyLayoutMode(nextLayout!);
    }
    if (nextSort != null) {
      await _applySortMode(nextSort!);
    }
  }

  void _showPendingAction(String actionName) {
    _showMessage('$actionName 暂未实现，已保留与 legado 同层入口。');
  }

  Future<void> _openExceptionLogs() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ExceptionLogsView(),
      ),
    );
  }

  String _updateCatalogMenuText() {
    if (_isUpdatingCatalog) {
      return '更新目录（进行中）';
    }
    return '更新目录';
  }

  void _showMoreMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('书架'),
        actions: [
          CupertinoActionSheetAction(
            child: Text(_updateCatalogMenuText()),
            onPressed: () {
              Navigator.pop(context);
              _updateBookshelfCatalog();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('本机导入'),
            onPressed: () {
              Navigator.pop(context);
              _importLocalBook();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('远程导入'),
            onPressed: () {
              Navigator.pop(context);
              _showPendingAction('远程导入');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('URL 导入'),
            onPressed: () {
              Navigator.pop(context);
              _showPendingAction('URL 导入');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('书架管理'),
            onPressed: () {
              Navigator.pop(context);
              _showPendingAction('书架管理');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('缓存导出'),
            onPressed: () {
              Navigator.pop(context);
              _showPendingAction('缓存导出');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('分组管理'),
            onPressed: () {
              Navigator.pop(context);
              _showPendingAction('分组管理');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('书架布局'),
            onPressed: () {
              Navigator.pop(context);
              _showLayoutMenu();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出书架'),
            onPressed: () {
              Navigator.pop(context);
              _exportBookshelf();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导入书架'),
            onPressed: () {
              Navigator.pop(context);
              _importBookshelf();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('日志'),
            onPressed: () {
              Navigator.pop(context);
              _openExceptionLogs();
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

  String _buildCatalogUpdateSummaryMessage(
      BookshelfCatalogUpdateSummary summary) {
    final lines = <String>[];
    if (summary.updateCandidateCount <= 0) {
      return '当前书架没有可更新的网络书籍';
    }

    lines.add(
      '目录更新完成：成功 ${summary.successCount} 本，失败 ${summary.failedCount} 本'
      '${summary.skippedCount > 0 ? '，跳过 ${summary.skippedCount} 本' : ''}',
    );
    if (summary.failedDetails.isNotEmpty) {
      lines.add('');
      lines.add('失败详情（最多 5 条）：');
      lines.addAll(summary.failedDetails.take(5));
    }
    return lines.join('\n');
  }

  Future<void> _updateBookshelfCatalog() async {
    if (_isImporting || _isUpdatingCatalog) return;

    final snapshot = _books.toList(growable: false);
    final remoteCandidates =
        snapshot.where((book) => !book.isLocal).toList(growable: false);
    if (remoteCandidates.isEmpty) {
      _showMessage('当前书架没有可更新的网络书籍');
      return;
    }
    final candidates = remoteCandidates
        .where((book) => _settingsService.getBookCanUpdate(book.id))
        .toList(growable: false);
    if (candidates.isEmpty) {
      _showMessage('当前书架没有可更新的网络书籍（可能已关闭“允许更新”）');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isUpdatingCatalog = true;
      _updatingBookIds.clear();
    });

    try {
      final summary = await _catalogUpdater.updateBooks(
        candidates,
        onBookUpdatingChanged: (bookId, updating) {
          if (!mounted) return;
          setState(() {
            if (updating) {
              _updatingBookIds.add(bookId);
            } else {
              _updatingBookIds.remove(bookId);
            }
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isUpdatingCatalog = false;
        _updatingBookIds.clear();
      });
      _loadBooks();
      _showMessage(_buildCatalogUpdateSummaryMessage(summary));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingCatalog = false;
        _updatingBookIds.clear();
      });
      _showMessage('更新目录失败：$e');
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '书架',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _openGlobalSearch,
            child: const Icon(CupertinoIcons.search),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: _initError != null
          ? _buildInitError()
          : (_books.isEmpty ? _buildEmptyState() : _buildBookList()),
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
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.bookOpen,
            size: 52,
            color: scheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            '书架空空如也',
            style: theme.textTheme.h4,
          ),
          const SizedBox(height: 24),
          ShadButton(
            onPressed: _importLocalBook,
            leading: const Icon(LucideIcons.fileUp),
            child: const Text('导入本地书籍'),
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
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: GridView.builder(
        controller: _scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.56,
          crossAxisSpacing: 2,
          mainAxisSpacing: 6,
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
    final unreadCount = _unreadCountLikeLegado(book);
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
                        color: CupertinoColors.systemGrey5.resolveFrom(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppCoverImage(
                        urlOrPath: book.coverUrl,
                        title: book.title,
                        author: book.author,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 8,
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
            Text(
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
          ],
        ),
      ),
    );
  }

  Widget _buildGridLoadingBadge() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const CupertinoActivityIndicator(radius: 6),
    );
  }

  Widget _buildGridUnreadBadge(int unreadCount) {
    if (unreadCount <= 0) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        _formatUnreadCount(unreadCount),
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }

  String _formatUnreadCount(int unreadCount) {
    if (unreadCount > 99) return '99+';
    return '$unreadCount';
  }

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

  Widget _buildListView() {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = _books[index];
        final readAgo = _formatReadAgo(book.lastReadTime);
        final isUpdating = _isUpdating(book);
        return GestureDetector(
          onTap: () => _openReader(book),
          onLongPress: () => _onBookLongPress(book),
          child: ShadCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCoverImage(
                  urlOrPath: book.coverUrl,
                  title: book.title,
                  author: book.author,
                  width: 66,
                  height: 90,
                  borderRadius: 8,
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
                              style: theme.textTheme.p.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.foreground,
                              ),
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
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                book.progressText,
                                style: theme.textTheme.small.copyWith(
                                  color: scheme.primary,
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
                            color: scheme.mutedForeground,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              book.author.trim().isEmpty ? '未知作者' : book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                color: scheme.mutedForeground,
                              ),
                            ),
                          ),
                          if (readAgo != null)
                            Text(
                              readAgo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                color: scheme.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 13,
                            color: scheme.mutedForeground,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _buildReadLine(book),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                color: scheme.mutedForeground,
                              ),
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
                            color: scheme.mutedForeground,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _buildLatestLine(book),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                color: scheme.mutedForeground,
                              ),
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
                          LucideIcons.chevronRight,
                          size: 16,
                          color: scheme.mutedForeground,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    return '阅读：$current/$total 章';
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
    showCupertinoModalPopup(
      context: context,
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
