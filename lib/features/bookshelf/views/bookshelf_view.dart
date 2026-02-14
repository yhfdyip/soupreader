import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../import/import_service.dart';
import '../../reader/views/simple_reader_view.dart';
import '../services/bookshelf_booklist_import_service.dart';
import '../services/bookshelf_import_export_service.dart';
import '../views/reading_history_view.dart';
import '../models/book.dart';

/// 书架页面 - 纯 iOS 原生风格
class BookshelfView extends StatefulWidget {
  const BookshelfView({super.key});

  @override
  State<BookshelfView> createState() => _BookshelfViewState();
}

class _BookshelfViewState extends State<BookshelfView> {
  bool _isGridView = true;
  late final BookRepository _bookRepo;
  late final ImportService _importService;
  late final SettingsService _settingsService;
  late final BookshelfImportExportService _bookshelfIo;
  late final BookshelfBooklistImportService _booklistImporter;
  StreamSubscription<List<Book>>? _booksSubscription;
  List<Book> _books = [];
  bool _isImporting = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    try {
      debugPrint('[bookshelf] init start');
      _bookRepo = BookRepository(DatabaseService());
      _importService = ImportService();
      _settingsService = SettingsService();
      _bookshelfIo = BookshelfImportExportService();
      _booklistImporter = BookshelfBooklistImportService();
      _isGridView = _settingsService.appSettings.bookshelfViewMode ==
          BookshelfViewMode.grid;
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
  void dispose() {
    _booksSubscription?.cancel();
    super.dispose();
  }

  void _loadBooks() {
    setState(() {
      _books = _bookRepo.getAllBooks();
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

  Future<void> _openReadingHistory() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingHistoryView(),
      ),
    );
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

  Future<void> _showSortMenu() async {
    final current = _settingsService.appSettings.bookshelfSortMode;
    BookshelfSortMode? selected;

    String label(BookshelfSortMode m) {
      switch (m) {
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

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('排序方式'),
        actions: [
          for (final mode in BookshelfSortMode.values)
            CupertinoActionSheetAction(
              isDefaultAction: mode == current,
              child: Text(label(mode)),
              onPressed: () {
                selected = mode;
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

    final next = selected;
    if (next == null || next == current) return;

    await _settingsService.saveAppSettings(
      _settingsService.appSettings.copyWith(bookshelfSortMode: next),
    );
    _loadBooks();
  }

  Future<void> _showLayoutMenu() async {
    final current = _settingsService.appSettings.bookshelfViewMode;
    BookshelfViewMode? selected;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('书架布局'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: current == BookshelfViewMode.grid,
            child: const Text('图墙模式'),
            onPressed: () {
              selected = BookshelfViewMode.grid;
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            isDefaultAction: current == BookshelfViewMode.list,
            child: const Text('列表模式'),
            onPressed: () {
              selected = BookshelfViewMode.list;
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

    final next = selected;
    if (next == null || next == current) return;

    setState(() {
      _isGridView = next == BookshelfViewMode.grid;
    });
    await _settingsService.saveAppSettings(
      _settingsService.appSettings.copyWith(bookshelfViewMode: next),
    );
  }

  void _showMoreMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('书架'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('本机导入（TXT/EPUB）'),
            onPressed: () {
              Navigator.pop(context);
              _importLocalBook();
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
            child: const Text('排序方式'),
            onPressed: () {
              Navigator.pop(context);
              _showSortMenu();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出书单（JSON）'),
            onPressed: () {
              Navigator.pop(context);
              _exportBookshelf();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导入书单（JSON）'),
            onPressed: () {
              Navigator.pop(context);
              _importBookshelf();
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
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(30, 30),
        onPressed: _isImporting ? null : _importLocalBook,
        child: _isImporting
            ? const CupertinoActivityIndicator()
            : const Icon(CupertinoIcons.add),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _openReadingHistory,
            child: const Icon(CupertinoIcons.clock),
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
      onTap: () => _openReader(book),
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
          const SizedBox(height: 8),
          // 标题
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          // 作者
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final radius = theme.radius;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = _books[index];
        return GestureDetector(
          onTap: () => _openReader(book),
          onLongPress: () => _onBookLongPress(book),
          child: ShadCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            leading: Container(
              width: 44,
              height: 62,
              decoration: BoxDecoration(
                color: scheme.muted,
                borderRadius: radius,
              ),
              child: AppCoverImage(
                urlOrPath: book.coverUrl,
                title: book.title,
                author: book.author,
                width: 44,
                height: 62,
                borderRadius: 8,
              ),
            ),
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: scheme.mutedForeground,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${book.author} · ${book.totalChapters}章',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
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

  void _showBookInfo(Book book) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(book.title),
        content: Text(
            '\n作者：${book.author}\n章节：${book.totalChapters}章\n${book.isLocal ? '来源：本地导入' : ''}'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
