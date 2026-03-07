import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/models/book.dart';
import '../services/reader_bookmark_export_service.dart';
import 'simple_reader_view.dart';

/// 所有书签（对齐 legado `AllBookmarkActivity`）
class AllBookmarkView extends StatefulWidget {
  const AllBookmarkView({super.key});

  @override
  State<AllBookmarkView> createState() => _AllBookmarkViewState();
}

enum _AllBookmarkTopAction {
  exportJson,
  exportMarkdown,
}

class _AllBookmarkViewState extends State<AllBookmarkView> {
  final GlobalKey _moreMenuKey = GlobalKey();
  final BookmarkRepository _bookmarkRepo = BookmarkRepository();
  final ReaderBookmarkExportService _bookmarkExportService =
      ReaderBookmarkExportService();
  final SettingsService _settingsService = SettingsService();
  late final BookRepository _bookRepo;

  List<BookmarkEntity> _bookmarks = <BookmarkEntity>[];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _bookRepo = BookRepository(DatabaseService());
    unawaited(_loadBookmarks());
  }

  Future<void> _loadBookmarks() async {
    try {
      await _bookmarkRepo.init();
      final list = _bookmarkRepo.getAllBookmarksByLegacyOrder();
      if (!mounted) return;
      setState(() {
        _bookmarks = list;
        _loading = false;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'all_bookmark.init',
        message: '所有书签初始化失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _showToast('加载书签失败：$error');
    }
  }

  Future<void> _runExport({required bool markdown}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bookmarks = _bookmarkRepo.getAllBookmarksByLegacyOrder();
      final node =
          markdown ? 'all_bookmark.menu_export_md' : 'all_bookmark.menu_export';
      final result = markdown
          ? await _bookmarkExportService.exportAllMarkdown(
              bookmarks: bookmarks,
            )
          : await _bookmarkExportService.exportAllJson(
              bookmarks: bookmarks,
            );
      if (!mounted) return;
      if (result.cancelled) {
        return;
      }
      if (result.success) {
        ExceptionLogService().record(
          node: node,
          message: '导出成功',
          context: <String, dynamic>{
            'bookmarkCount': bookmarks.length,
            'format': markdown ? 'md' : 'json',
            if (result.outputPath != null) 'outputPath': result.outputPath,
          },
        );
      } else {
        ExceptionLogService().record(
          node: node,
          message: result.message ?? '导出失败',
          context: <String, dynamic>{
            'bookmarkCount': bookmarks.length,
            'format': markdown ? 'md' : 'json',
          },
        );
      }
      final message = result.success
          ? (result.message?.trim().isNotEmpty == true
              ? result.message!
              : '导出成功')
          : (result.message?.trim().isNotEmpty == true
              ? result.message!
              : '导出失败');
      _showToast(message);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: markdown
            ? 'all_bookmark.menu_export_md'
            : 'all_bookmark.menu_export',
        message: '导出失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'format': markdown ? 'md' : 'json',
        },
      );
      if (!mounted) return;
      _showToast('导出失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _exporting = false);
    }
  }

  Future<void> _showTopActions() async {
    if (!mounted) return;
    final action = await showAppPopoverMenu<_AllBookmarkTopAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: [
        AppPopoverMenuItem(
          value: _AllBookmarkTopAction.exportJson,
          icon: CupertinoIcons.square_arrow_up,
          label: _exporting ? '导出中...' : '导出',
        ),
        AppPopoverMenuItem(
          value: _AllBookmarkTopAction.exportMarkdown,
          icon: CupertinoIcons.doc_text,
          label: _exporting ? '导出中...' : '导出(MD)',
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AllBookmarkTopAction.exportJson:
        unawaited(_runExport(markdown: false));
        break;
      case _AllBookmarkTopAction.exportMarkdown:
        unawaited(_runExport(markdown: true));
        break;
    }
  }

  Future<Book?> _resolveBookForBookmark(BookmarkEntity bookmark) async {
    await _bookRepo.watchAllBooks().first;
    final bookId = bookmark.bookId.trim();
    if (bookId.isNotEmpty) {
      final byId = _bookRepo.getBookById(bookId);
      if (byId != null) {
        return byId;
      }
    }
    final allBooks = _bookRepo.getAllBooks();
    for (final book in allBooks) {
      if (book.title == bookmark.bookName &&
          book.author == bookmark.bookAuthor) {
        return book;
      }
    }
    return null;
  }

  double _decodeBookmarkChapterProgress(int chapterPos) {
    return (chapterPos / 10000.0).clamp(0.0, 1.0).toDouble();
  }

  Future<void> _openBookmarkInReader(BookmarkEntity bookmark) async {
    try {
      final book = await _resolveBookForBookmark(bookmark);
      if (book == null) {
        _showToast('书籍不存在，无法定位阅读');
        return;
      }
      final chapterIndex =
          bookmark.chapterIndex < 0 ? 0 : bookmark.chapterIndex;
      final progress = _decodeBookmarkChapterProgress(bookmark.chapterPos);
      await _settingsService.saveChapterPageProgress(
        book.id,
        chapterIndex: chapterIndex,
        progress: progress,
      );
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(
          builder: (_) => SimpleReaderView(
            bookId: book.id,
            bookTitle: book.title,
            initialChapter: chapterIndex,
          ),
        ),
      );
      if (!mounted) return;
      await _loadBookmarks();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'all_bookmark.item_open_reader',
        message: '定位阅读失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookmarkId': bookmark.id,
          'bookId': bookmark.bookId,
          'chapterIndex': bookmark.chapterIndex,
          'chapterPos': bookmark.chapterPos,
        },
      );
      if (!mounted) return;
      _showToast('定位阅读失败：$error');
    }
  }

  Future<void> _openBookmarkDetail(BookmarkEntity bookmark) async {
    final chapter = bookmark.chapterTitle.trim().isEmpty
        ? '第 ${bookmark.chapterIndex + 1} 章'
        : bookmark.chapterTitle.trim();
    final excerpt =
        bookmark.content.trim().isEmpty ? '（无）' : bookmark.content.trim();
    final progressPercent =
        (_decodeBookmarkChapterProgress(bookmark.chapterPos) * 100)
            .toStringAsFixed(1);
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(chapter),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Text(
              '${bookmark.bookName} · ${bookmark.bookAuthor}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '章节进度 $progressPercent%',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              excerpt,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_openBookmarkInReader(bookmark));
            },
            child: const Text('定位阅读'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '所有书签',
      trailing: AppNavBarButton(
        key: _moreMenuKey,
        onPressed: _showTopActions,
        child: _exporting
            ? const CupertinoActivityIndicator(radius: 10)
            : const Icon(CupertinoIcons.ellipsis_circle, size: 22),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 13),
      );
    }
    if (_bookmarks.isEmpty) {
      return const AppEmptyState(
        illustration: AppEmptyPlanetIllustration(size: 88),
        title: '暂无书签',
        message: '添加书签后会显示在这里',
      );
    }
    return ListView.builder(
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        final chapter = bookmark.chapterTitle.trim().isEmpty
            ? '第 ${bookmark.chapterIndex + 1} 章'
            : bookmark.chapterTitle.trim();
        final excerpt =
            bookmark.content.trim().isEmpty ? '（无）' : bookmark.content.trim();
        return CupertinoListTile.notched(
          title: Text(chapter),
          subtitle: Text(
            '${bookmark.bookName} · ${bookmark.bookAuthor}\n$excerpt',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          additionalInfo: Text(_formatTime(bookmark.createdTime)),
          trailing: const CupertinoListTileChevron(),
          onTap: () => unawaited(_openBookmarkDetail(bookmark)),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
