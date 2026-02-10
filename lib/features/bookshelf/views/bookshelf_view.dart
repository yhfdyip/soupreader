import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../app/theme/design_tokens.dart';
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
      debugPrint('[bookshelf] init done, books=\${_books.length}');
    } catch (e, st) {
      _initError = '书架初始化异常: $e';
      debugPrint('[bookshelf] init failed: $e');
      debugPrintStack(stackTrace: st);
    }
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
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书架'),
        backgroundColor: theme.barBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
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
              onPressed: _openReadingHistory,
              child: const Icon(CupertinoIcons.clock),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showMoreMenu,
              child: const Icon(CupertinoIcons.ellipsis),
            ),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark
                  ? AppDesignTokens.surfaceDark.withValues(alpha: 0.78)
                  : AppDesignTokens.surfaceLight.withValues(alpha: 0.96),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: _initError != null
              ? _buildInitError()
              : (_books.isEmpty ? _buildEmptyState() : _buildBookList()),
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
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: _importLocalBook,
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
              child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildCoverImage(book),
                    )
                  : Center(
                      child: Text(
                        book.title.isNotEmpty
                            ? book.title.substring(0, 1)
                            : '?',
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

  Widget _buildCoverImage(Book book) {
    final coverUrl = book.coverUrl ?? '';
    if (coverUrl.isEmpty) {
      return _buildCoverFallback(book);
    }

    if (_isRemoteCover(coverUrl)) {
      return Image.network(
        coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildCoverFallback(book),
      );
    }

    if (kIsWeb) {
      return _buildCoverFallback(book);
    }

    return Image.file(
      File(coverUrl),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildCoverFallback(book),
    );
  }

  Widget _buildCoverFallback(Book book) {
    return Center(
      child: Text(
        book.title.isNotEmpty ? book.title.substring(0, 1) : '?',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isRemoteCover(String value) {
    final uri = Uri.tryParse(value);
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
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
            child: Center(
              child: Text(
                book.title.isNotEmpty ? book.title.substring(0, 1) : '?',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          title: Text(book.title),
          subtitle: Text('${book.author} · ${book.totalChapters}章'),
          trailing: const CupertinoListTileChevron(),
          onTap: () => _openReader(book),
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
