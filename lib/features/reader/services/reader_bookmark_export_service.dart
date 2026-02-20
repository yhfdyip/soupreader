import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/database/entities/bookmark_entity.dart';

typedef ReaderBookmarkSaveFile = Future<String?> Function({
  required String dialogTitle,
  required String fileName,
  required List<String> allowedExtensions,
});

typedef ReaderBookmarkWriteFile = Future<void> Function({
  required String path,
  required String content,
});

typedef ReaderBookmarkCopyText = Future<void> Function(String text);

enum ReaderBookmarkExportFormat {
  json,
  markdown,
}

class ReaderBookmarkExportResult {
  final bool success;
  final bool cancelled;
  final String? outputPath;
  final String? message;

  const ReaderBookmarkExportResult({
    this.success = false,
    this.cancelled = false,
    this.outputPath,
    this.message,
  });
}

class ReaderBookmarkExportService {
  ReaderBookmarkExportService({
    ReaderBookmarkSaveFile? saveFile,
    ReaderBookmarkWriteFile? writeFile,
    ReaderBookmarkCopyText? copyText,
  })  : _saveFile = saveFile ?? _defaultSaveFile,
        _writeFile = writeFile ?? _defaultWriteFile,
        _copyText = copyText ?? _defaultCopyText;

  final ReaderBookmarkSaveFile _saveFile;
  final ReaderBookmarkWriteFile _writeFile;
  final ReaderBookmarkCopyText _copyText;

  Future<ReaderBookmarkExportResult> exportJson({
    required String bookTitle,
    required String bookAuthor,
    required List<BookmarkEntity> bookmarks,
  }) {
    return _export(
      format: ReaderBookmarkExportFormat.json,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      bookmarks: bookmarks,
    );
  }

  Future<ReaderBookmarkExportResult> exportMarkdown({
    required String bookTitle,
    required String bookAuthor,
    required List<BookmarkEntity> bookmarks,
  }) {
    return _export(
      format: ReaderBookmarkExportFormat.markdown,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      bookmarks: bookmarks,
    );
  }

  Future<ReaderBookmarkExportResult> _export({
    required ReaderBookmarkExportFormat format,
    required String bookTitle,
    required String bookAuthor,
    required List<BookmarkEntity> bookmarks,
  }) async {
    if (bookmarks.isEmpty) {
      return const ReaderBookmarkExportResult(
        message: '暂无书签可导出',
      );
    }
    final sorted = List<BookmarkEntity>.from(bookmarks)
      ..sort((a, b) {
        final chapter = a.chapterIndex.compareTo(b.chapterIndex);
        if (chapter != 0) return chapter;
        final pos = a.chapterPos.compareTo(b.chapterPos);
        if (pos != 0) return pos;
        return a.createdTime.compareTo(b.createdTime);
      });
    final content = switch (format) {
      ReaderBookmarkExportFormat.json => _buildJsonContent(sorted),
      ReaderBookmarkExportFormat.markdown => _buildMarkdownContent(
          sorted,
          bookTitle: bookTitle,
          bookAuthor: bookAuthor,
        ),
    };
    final extension = switch (format) {
      ReaderBookmarkExportFormat.json => 'json',
      ReaderBookmarkExportFormat.markdown => 'md',
    };
    final dialogTitle = switch (format) {
      ReaderBookmarkExportFormat.json => '导出书签',
      ReaderBookmarkExportFormat.markdown => '导出 Markdown',
    };
    final outputFileName = _buildOutputFileName(
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      extension: extension,
    );

    try {
      if (kIsWeb) {
        await _copyText(content);
        return const ReaderBookmarkExportResult(
          success: true,
          message: '已复制导出内容到剪贴板',
        );
      }
      final outputPath = await _saveFile(
        dialogTitle: dialogTitle,
        fileName: outputFileName,
        allowedExtensions: <String>[extension],
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return const ReaderBookmarkExportResult(cancelled: true);
      }
      final normalizedPath = outputPath.trim();
      await _writeFile(path: normalizedPath, content: content);
      return ReaderBookmarkExportResult(
        success: true,
        outputPath: normalizedPath,
      );
    } catch (e) {
      return ReaderBookmarkExportResult(
        message: '导出失败：$e',
      );
    }
  }

  String _buildJsonContent(List<BookmarkEntity> bookmarks) {
    final payload = bookmarks
        .map((bookmark) => <String, dynamic>{
              'id': bookmark.id,
              'bookName': bookmark.bookName,
              'bookAuthor': bookmark.bookAuthor,
              'chapterIndex': bookmark.chapterIndex,
              'chapterTitle': bookmark.chapterTitle,
              'chapterPos': bookmark.chapterPos,
              'content': bookmark.content,
              'createdTime': bookmark.createdTime.millisecondsSinceEpoch,
            })
        .toList(growable: false);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _buildMarkdownContent(
    List<BookmarkEntity> bookmarks, {
    required String bookTitle,
    required String bookAuthor,
  }) {
    final safeTitle = bookTitle.trim().isEmpty ? '未知书籍' : bookTitle.trim();
    final safeAuthor = bookAuthor.trim().isEmpty ? '未知作者' : bookAuthor.trim();
    final buffer = StringBuffer()
      ..writeln('## $safeTitle $safeAuthor')
      ..writeln();
    for (final bookmark in bookmarks) {
      final chapterTitle = bookmark.chapterTitle.trim().isEmpty
          ? '第 ${bookmark.chapterIndex + 1} 章'
          : bookmark.chapterTitle.trim();
      final excerpt =
          bookmark.content.trim().isEmpty ? '（无）' : bookmark.content.trim();
      buffer
        ..writeln('#### $chapterTitle')
        ..writeln()
        ..writeln('###### 原文')
        ..writeln(' $excerpt')
        ..writeln()
        ..writeln('###### 摘要')
        ..writeln(' $excerpt')
        ..writeln();
    }
    return buffer.toString();
  }

  String _buildOutputFileName({
    required String bookTitle,
    required String bookAuthor,
    required String extension,
  }) {
    final safeTitle = _sanitizeFileNameSegment(bookTitle, fallback: 'book');
    final safeAuthor = _sanitizeFileNameSegment(bookAuthor, fallback: 'author');
    return 'bookmark-$safeTitle $safeAuthor.$extension';
  }

  String _sanitizeFileNameSegment(String value, {required String fallback}) {
    final normalized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return fallback;
    return normalized;
  }

  static Future<String?> _defaultSaveFile({
    required String dialogTitle,
    required String fileName,
    required List<String> allowedExtensions,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      allowedExtensions: allowedExtensions,
      type: FileType.custom,
    );
  }

  static Future<void> _defaultWriteFile({
    required String path,
    required String content,
  }) {
    return File(path).writeAsString(content);
  }

  static Future<void> _defaultCopyText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
