import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../bookshelf/models/book.dart';

/// TXT 文件解析器
class TxtParser {
  static const _uuid = Uuid();

  /// 常见章节标题正则
  static final List<RegExp> _chapterPatterns = [
    // 第X章、第X节、第X回、第X卷
    RegExp(r'^第[零一二三四五六七八九十百千万0-9]+[章节回卷][^\n]*', multiLine: true),
    // Chapter X
    RegExp(r'^Chapter\s+\d+[^\n]*', caseSensitive: false, multiLine: true),
    // 数字. 标题
    RegExp(r'^\d+[\.\、][^\n]{2,30}$', multiLine: true),
    // 【第X章】
    RegExp(r'^【第[零一二三四五六七八九十百千万0-9]+章】[^\n]*', multiLine: true),
  ];

  /// 从文件路径导入 TXT
  static Future<TxtImportResult> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final bytes = await file.readAsBytes();
    final content = _decodeContent(bytes);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final bookName =
        fileName.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');

    return _parseContent(content, bookName, filePath);
  }

  /// 从字节数据导入（iOS 使用）
  static TxtImportResult importFromBytes(Uint8List bytes, String fileName) {
    final content = _decodeContent(bytes);
    final bookName =
        fileName.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
    return _parseContent(content, bookName, null);
  }

  /// 自动检测编码并解码
  static String _decodeContent(Uint8List bytes) {
    // 尝试 UTF-8
    try {
      final utf8Result = utf8.decode(bytes, allowMalformed: false);
      if (!utf8Result.contains('\uFFFD')) {
        return utf8Result;
      }
    } catch (_) {}

    // 尝试 GBK (使用 latin1 作为备选，实际应使用 gbk 包)
    try {
      // 简单处理：如果 UTF-8 失败，尝试 latin1
      return latin1.decode(bytes);
    } catch (_) {}

    // 最后使用 UTF-8 允许错误
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 解析内容
  static TxtImportResult _parseContent(
      String content, String bookName, String? filePath) {
    // 清理内容
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 识别章节
    final chapters = _splitChapters(content);

    // 创建书籍
    final bookId = _uuid.v4();
    final book = Book(
      id: bookId,
      title: bookName,
      author: '未知作者',
      totalChapters: chapters.length,
      isLocal: true,
      localPath: filePath,
      addedTime: DateTime.now(),
    );

    // 创建章节列表
    final chapterList = chapters.asMap().entries.map((entry) {
      return Chapter(
        id: '${bookId}_${entry.key}',
        bookId: bookId,
        title: entry.value.title,
        index: entry.key,
        isDownloaded: true,
        content: entry.value.content,
      );
    }).toList();

    return TxtImportResult(book: book, chapters: chapterList);
  }

  /// 分割章节
  static List<_ChapterInfo> _splitChapters(String content) {
    // 检测使用哪种章节模式
    RegExp? bestPattern;
    int maxMatches = 0;

    for (final pattern in _chapterPatterns) {
      final matches = pattern.allMatches(content).length;
      if (matches > maxMatches) {
        maxMatches = matches;
        bestPattern = pattern;
      }
    }

    // 如果没有找到章节模式，将整本书作为一章
    if (bestPattern == null || maxMatches < 2) {
      return [_ChapterInfo(title: '正文', content: content.trim())];
    }

    // 按章节分割
    final matches = bestPattern.allMatches(content).toList();
    final chapters = <_ChapterInfo>[];

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final title = match.group(0)?.trim() ?? '第${i + 1}章';

      final startIndex = match.end;
      final endIndex =
          (i + 1 < matches.length) ? matches[i + 1].start : content.length;

      final chapterContent = content.substring(startIndex, endIndex).trim();

      if (chapterContent.isNotEmpty) {
        chapters.add(_ChapterInfo(title: title, content: chapterContent));
      }
    }

    // 处理第一章前的内容（序言/简介）
    if (matches.isNotEmpty && matches.first.start > 100) {
      final preface = content.substring(0, matches.first.start).trim();
      if (preface.isNotEmpty) {
        chapters.insert(0, _ChapterInfo(title: '序言', content: preface));
      }
    }

    return chapters.isEmpty
        ? [_ChapterInfo(title: '正文', content: content.trim())]
        : chapters;
  }
}

/// 章节信息（内部使用）
class _ChapterInfo {
  final String title;
  final String content;

  _ChapterInfo({required this.title, required this.content});
}

/// TXT 导入结果
class TxtImportResult {
  final Book book;
  final List<Chapter> chapters;

  TxtImportResult({required this.book, required this.chapters});
}
