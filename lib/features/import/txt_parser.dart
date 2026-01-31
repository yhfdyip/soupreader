import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../bookshelf/models/book.dart';

/// TXT 文件解析器
class TxtParser {
  static const _uuid = Uuid();

  /// 常见章节标题正则 - 按优先级排序
  static final List<RegExp> _chapterPatterns = [
    // 第1章xxx 格式（阿拉伯数字，章后直接跟标题）
    RegExp(r'^\s*第\d+章\S.*$', multiLine: true),
    // 第X章、第X节、第X回、第X卷 (中文数字或阿拉伯数字)
    RegExp(r'^\s*第[零一二三四五六七八九十百千万\d]+[章节回卷].*$', multiLine: true),
    // 【第X章】格式
    RegExp(r'^\s*【第[零一二三四五六七八九十百千万\d]+[章节回卷]】.*$', multiLine: true),
    // 第 X 章 (带空格)
    RegExp(r'^\s*第\s*\d+\s*章.*$', multiLine: true),
    // Chapter X / CHAPTER X
    RegExp(r'^\s*[Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s+\d+.*$', multiLine: true),
    // 卷X 章X
    RegExp(r'^\s*[卷第]\s*[零一二三四五六七八九十百千万\d]+\s*[章节卷].*$', multiLine: true),
    // 纯数字章节：001、0001、1、01 等开头
    RegExp(r'^\s*\d{1,4}[\.\、\s].*$', multiLine: true),
    // 正文 第X章
    RegExp(r'^\s*正文\s+第[零一二三四五六七八九十百千万\d]+[章节回卷].*$', multiLine: true),
    // 序章、楔子、引子、终章、番外
    RegExp(r'^\s*[序终]章.*$', multiLine: true),
    RegExp(r'^\s*[楔引]子.*$', multiLine: true),
    RegExp(r'^\s*番外.*$', multiLine: true),
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
    // 检测 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      // UTF-8 with BOM
      return utf8.decode(bytes.sublist(3));
    }

    // 尝试 UTF-8
    try {
      final utf8Result = utf8.decode(bytes, allowMalformed: false);
      // 检查是否有大量替换字符
      final badChars = utf8Result.split('\uFFFD').length - 1;
      if (badChars < 10) {
        return utf8Result;
      }
    } catch (_) {}

    // 尝试 GBK (使用 latin1 作为备选)
    try {
      return latin1.decode(bytes);
    } catch (_) {}

    // 最后使用 UTF-8 允许错误
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 解析内容
  static TxtImportResult _parseContent(
      String content, String bookName, String? filePath) {
    // 清理内容 - 统一换行符
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
    // 尝试所有模式，找出匹配最多的
    RegExp? bestPattern;
    int maxMatches = 0;
    List<RegExpMatch> bestMatches = [];

    for (final pattern in _chapterPatterns) {
      final matches = pattern.allMatches(content).toList();
      // 过滤掉太短的匹配（可能是误匹配）
      final validMatches = matches.where((m) {
        final text = m.group(0) ?? '';
        // 章节标题通常不会太长，也不会太短
        return text.trim().length >= 2 && text.trim().length <= 50;
      }).toList();

      if (validMatches.length > maxMatches) {
        maxMatches = validMatches.length;
        bestPattern = pattern;
        bestMatches = validMatches;
      }
    }

    // 如果没有找到足够的章节（至少2章），按固定字数分章
    if (bestPattern == null || maxMatches < 2) {
      return _splitByLength(content);
    }

    // 按章节分割
    final chapters = <_ChapterInfo>[];

    // 处理第一章前的内容（序言/简介）
    if (bestMatches.isNotEmpty && bestMatches.first.start > 200) {
      final preface = content.substring(0, bestMatches.first.start).trim();
      if (preface.isNotEmpty && preface.length > 50) {
        chapters.add(_ChapterInfo(title: '序言', content: preface));
      }
    }

    for (int i = 0; i < bestMatches.length; i++) {
      final match = bestMatches[i];
      final title = match.group(0)?.trim() ?? '第${i + 1}章';

      final startIndex = match.end;
      final endIndex = (i + 1 < bestMatches.length)
          ? bestMatches[i + 1].start
          : content.length;

      final chapterContent = content.substring(startIndex, endIndex).trim();

      // 只添加有内容的章节
      if (chapterContent.isNotEmpty && chapterContent.length > 10) {
        chapters.add(_ChapterInfo(title: title, content: chapterContent));
      }
    }

    return chapters.isEmpty ? _splitByLength(content) : chapters;
  }

  /// 按固定长度分章（备选方案）
  static List<_ChapterInfo> _splitByLength(String content) {
    const charsPerChapter = 5000; // 每章约5000字
    final chapters = <_ChapterInfo>[];

    content = content.trim();
    if (content.isEmpty) {
      return [_ChapterInfo(title: '正文', content: '')];
    }

    if (content.length <= charsPerChapter) {
      return [_ChapterInfo(title: '正文', content: content)];
    }

    int chapterIndex = 1;
    int start = 0;

    while (start < content.length) {
      int end = start + charsPerChapter;
      if (end >= content.length) {
        end = content.length;
      } else {
        // 尝试在段落边界处分割
        final searchEnd = (end + 500).clamp(0, content.length);
        final newlinePos = content.indexOf('\n\n', end);
        if (newlinePos > 0 && newlinePos < searchEnd) {
          end = newlinePos;
        } else {
          final singleNewline = content.indexOf('\n', end);
          if (singleNewline > 0 && singleNewline < searchEnd) {
            end = singleNewline;
          }
        }
      }

      final chapterContent = content.substring(start, end).trim();
      if (chapterContent.isNotEmpty) {
        chapters.add(_ChapterInfo(
          title: '第${chapterIndex}章',
          content: chapterContent,
        ));
        chapterIndex++;
      }
      start = end;
    }

    return chapters.isEmpty
        ? [_ChapterInfo(title: '正文', content: content)]
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
