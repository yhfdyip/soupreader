import 'package:flutter/cupertino.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../reader/views/simple_reader_view.dart';
import '../models/book.dart';

/// 阅读记录
///
/// 当前实现：基于 `Book.lastReadTime` 的简易列表。
class ReadingHistoryView extends StatefulWidget {
  const ReadingHistoryView({super.key});

  @override
  State<ReadingHistoryView> createState() => _ReadingHistoryViewState();
}

class _ReadingHistoryViewState extends State<ReadingHistoryView> {
  late final BookRepository _bookRepo;

  @override
  void initState() {
    super.initState();
    _bookRepo = BookRepository(DatabaseService());
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '阅读记录',
      child: StreamBuilder<List<Book>>(
        stream: _bookRepo.watchAllBooks(),
        builder: (context, snapshot) {
          final books = snapshot.data ?? _bookRepo.getAllBooks();
          final history =
              books.where((b) => b.lastReadTime != null && b.isReading).toList()
                ..sort((a, b) {
                  final at = a.lastReadTime ?? DateTime(2000);
                  final bt = b.lastReadTime ?? DateTime(2000);
                  return bt.compareTo(at);
                });

          if (history.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final book = history[index];
              return GestureDetector(
                onLongPress: () => _showActions(book),
                child: CupertinoListTile.notched(
                  title: Text(book.title),
                  subtitle: Text(_subtitleForBook(book)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _openReader(book),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 64,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无阅读记录',
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleForBook(Book book) {
    final progress = (book.readProgress * 100).clamp(0, 100).toStringAsFixed(1);
    final lastRead = book.lastReadTime;
    final lastReadText = lastRead == null
        ? '—'
        : '${lastRead.year}-${_two(lastRead.month)}-${_two(lastRead.day)}';
    return '${book.author} · 进度 $progress% · $lastReadText';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  void _openReader(Book book) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => SimpleReaderView(
          bookId: book.id,
          bookTitle: book.title,
          initialChapter: book.currentChapter,
        ),
      ),
    );
  }

  void _showActions(Book book) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(book.title),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('继续阅读'),
            onPressed: () {
              Navigator.pop(context);
              _openReader(book);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('清除阅读记录'),
            onPressed: () async {
              Navigator.pop(context);
              await _bookRepo.clearReadingRecord(book.id);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('从书架移除'),
            onPressed: () async {
              Navigator.pop(context);
              await _bookRepo.deleteBook(book.id);
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
