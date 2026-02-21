import 'dart:io';

import 'package:path/path.dart' as p;

import '../../bookshelf/models/book.dart';
import '../../import/epub_parser.dart';
import '../../import/txt_parser.dart';

/// 详情页“刷新”本地书籍辅助（对齐 legado `menu_refresh` 本地刷新语义）。
class SearchBookInfoRefreshHelper {
  const SearchBookInfoRefreshHelper._();

  static Future<SearchBookInfoLocalRefreshResult> refreshLocalBook({
    required Book book,
    String? preferredTxtCharset,
    bool splitLongChapter = true,
  }) async {
    if (!book.isLocal) {
      throw StateError('当前书籍不是本地书籍');
    }

    final localPath = _resolveLocalPath(book);
    if (localPath.isEmpty) {
      throw StateError('本地文件路径缺失，无法刷新');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('本地文件不存在：$localPath');
    }

    final extension = p.extension(localPath).toLowerCase();
    switch (extension) {
      case '.txt':
        return _refreshTxtBook(
          book: book,
          localPath: localPath,
          preferredTxtCharset: preferredTxtCharset,
          splitLongChapter: splitLongChapter,
        );
      case '.epub':
        return _refreshEpubBook(
          book: book,
          localPath: localPath,
        );
      default:
        throw StateError('暂不支持刷新该本地文件格式：$extension');
    }
  }

  static Future<SearchBookInfoLocalRefreshResult> _refreshTxtBook({
    required Book book,
    required String localPath,
    String? preferredTxtCharset,
    bool splitLongChapter = true,
  }) async {
    final parsed = await TxtParser.reparseFromFile(
      filePath: localPath,
      bookId: book.id,
      bookName: book.title,
      forcedCharset: preferredTxtCharset,
      splitLongChapter: splitLongChapter,
    );

    final chapters = parsed.chapters;
    if (chapters.isEmpty) {
      throw StateError('重解析后章节为空');
    }

    final maxChapter = chapters.length - 1;
    final refreshed = book.copyWith(
      title: parsed.book.title,
      totalChapters: chapters.length,
      latestChapter: chapters.last.title,
      currentChapter: book.currentChapter.clamp(0, maxChapter).toInt(),
      localPath: localPath,
      isLocal: true,
    );

    return SearchBookInfoLocalRefreshResult(
      book: refreshed,
      chapters: chapters,
      charset: parsed.charset,
    );
  }

  static Future<SearchBookInfoLocalRefreshResult> _refreshEpubBook({
    required Book book,
    required String localPath,
  }) async {
    final parsed = await EpubParser.importFromFile(localPath);
    final parsedChapters = parsed.chapters;
    if (parsedChapters.isEmpty) {
      throw StateError('EPUB 重解析后章节为空');
    }

    final chapters = parsedChapters.asMap().entries.map((entry) {
      final chapter = entry.value;
      return chapter.copyWith(
        id: '${book.id}_${entry.key}',
        bookId: book.id,
        index: entry.key,
      );
    }).toList(growable: false);

    final maxChapter = chapters.length - 1;
    final refreshed = book.copyWith(
      title: parsed.book.title,
      author: parsed.book.author,
      coverUrl: parsed.book.coverUrl ?? book.coverUrl,
      totalChapters: chapters.length,
      latestChapter: chapters.last.title,
      currentChapter: book.currentChapter.clamp(0, maxChapter).toInt(),
      localPath: localPath,
      isLocal: true,
    );

    return SearchBookInfoLocalRefreshResult(
      book: refreshed,
      chapters: chapters,
    );
  }

  static String _resolveLocalPath(Book book) {
    final candidates = <String>[
      (book.localPath ?? '').trim(),
      (book.bookUrl ?? '').trim(),
    ];

    for (final raw in candidates) {
      if (raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.hasScheme) {
        if (uri.scheme == 'file') {
          final filePath = uri.toFilePath();
          if (filePath.trim().isNotEmpty) {
            return filePath;
          }
        }
        continue;
      }
      return raw;
    }
    return '';
  }
}

class SearchBookInfoLocalRefreshResult {
  final Book book;
  final List<Chapter> chapters;
  final String? charset;

  const SearchBookInfoLocalRefreshResult({
    required this.book,
    required this.chapters,
    this.charset,
  });
}
