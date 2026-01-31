import 'dart:io';
import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:uuid/uuid.dart';
import '../bookshelf/models/book.dart';
import '../import/txt_parser.dart';

/// EPUB 文件解析器
class EpubParser {
  static const _uuid = Uuid();

  /// 从文件路径导入 EPUB
  static Future<EpubImportResult> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final bytes = await file.readAsBytes();
    final fileName = file.path.split(Platform.pathSeparator).last;

    return importFromBytes(bytes, fileName, filePath);
  }

  /// 从字节数据导入（iOS 使用）
  static Future<EpubImportResult> importFromBytes(
    Uint8List bytes,
    String fileName,
    String? filePath,
  ) async {
    try {
      // 解析 EPUB
      final epubBook = await EpubReader.readBook(bytes);

      // 提取书籍信息
      final bookId = _uuid.v4();
      final title = epubBook.Title ??
          fileName.replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');
      final author = epubBook.Author ?? '未知作者';

      // 获取封面
      String? coverUrl;
      if (epubBook.CoverImage != null) {
        // TODO: 保存封面图片到本地并返回路径
      }

      // 解析章节
      final chapters = _parseChapters(epubBook, bookId);

      // 创建书籍
      final book = Book(
        id: bookId,
        title: title,
        author: author,
        coverUrl: coverUrl,
        totalChapters: chapters.length,
        isLocal: true,
        localPath: filePath,
        addedTime: DateTime.now(),
      );

      return EpubImportResult(book: book, chapters: chapters);
    } catch (e) {
      throw Exception('EPUB解析失败: $e');
    }
  }

  /// 解析章节
  static List<Chapter> _parseChapters(EpubBook epubBook, String bookId) {
    final chapters = <Chapter>[];

    // 获取阅读顺序
    final spine = epubBook.Schema?.Package?.Spine?.Items;
    if (spine == null || spine.isEmpty) {
      return chapters;
    }

    // 获取内容文件映射
    final manifest = epubBook.Schema?.Package?.Manifest?.Items;
    if (manifest == null) {
      return chapters;
    }

    // 获取内容
    final content = epubBook.Content;
    if (content == null) {
      return chapters;
    }

    int chapterIndex = 0;

    for (final spineItem in spine) {
      final idRef = spineItem.IdRef;
      if (idRef == null) continue;

      // 查找对应的 manifest item
      final manifestItem = manifest.values.firstWhere(
        (item) => item.Id == idRef,
        orElse: () => manifest.values.first,
      );

      // 获取HTML内容
      final href = manifestItem.Href;
      if (href == null) continue;

      final htmlContent = content.Html?[href];
      if (htmlContent?.Content == null) continue;

      // 提取文本内容
      final textContent = _extractTextFromHtml(htmlContent!.Content!);
      if (textContent.trim().isEmpty) continue;

      // 尝试从导航获取标题
      String chapterTitle = '第${chapterIndex + 1}章';

      // 从 TOC 获取标题
      final tocItems = epubBook.Schema?.Navigation?.NavMap?.Points;
      if (tocItems != null) {
        for (final tocItem in tocItems) {
          if (tocItem.Content?.Source?.contains(href) == true) {
            chapterTitle = tocItem.NavLabels?.first?.Text ?? chapterTitle;
            break;
          }
        }
      }

      chapters.add(Chapter(
        id: '${bookId}_$chapterIndex',
        bookId: bookId,
        title: chapterTitle,
        index: chapterIndex,
        isDownloaded: true,
        content: textContent,
      ));

      chapterIndex++;
    }

    // 如果没有解析到章节，尝试使用所有HTML内容
    if (chapters.isEmpty && content.Html != null) {
      for (final entry in content.Html!.entries) {
        final textContent = _extractTextFromHtml(entry.value.Content ?? '');
        if (textContent.trim().isEmpty) continue;

        chapters.add(Chapter(
          id: '${bookId}_$chapterIndex',
          bookId: bookId,
          title: '第${chapterIndex + 1}章',
          index: chapterIndex,
          isDownloaded: true,
          content: textContent,
        ));

        chapterIndex++;
      }
    }

    return chapters;
  }

  /// 从 HTML 提取文本
  static String _extractTextFromHtml(String html) {
    // 移除 script 和 style 标签及内容
    html = html.replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    html = html.replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');

    // 转换换行标签
    html = html.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    html = html.replaceAll(RegExp(r'<p[^>]*>'), '\n\n');
    html = html.replaceAll(RegExp(r'</p>'), '');
    html = html.replaceAll(RegExp(r'<div[^>]*>'), '\n');
    html = html.replaceAll(RegExp(r'</div>'), '');

    // 移除所有 HTML 标签
    html = html.replaceAll(RegExp(r'<[^>]+>'), '');

    // 解码 HTML 实体
    html = html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");

    // 清理多余空白
    html = html.replaceAll(RegExp(r'\n\s*\n+'), '\n\n');
    html = html.replaceAll(RegExp(r' +'), ' ');

    return html.trim();
  }
}

/// EPUB 导入结果
class EpubImportResult {
  final Book book;
  final List<Chapter> chapters;

  EpubImportResult({required this.book, required this.chapters});
}
