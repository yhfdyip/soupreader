import 'dart:io';
import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../bookshelf/models/book.dart';
import '../../core/utils/html_text_formatter.dart';

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
      final coverUrl = await _saveCoverImage(epubBook, bookId);

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

  static Future<String?> _saveCoverImage(
      EpubBook epubBook, String bookId) async {
    final coverData = _extractCoverImageData(epubBook);
    if (coverData == null) return null;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final coverDir = Directory('${docsDir.path}/.book_covers');
      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }

      final extension = _inferCoverExtension(coverData.bytes, coverData.href);
      final coverFile = File('${coverDir.path}/$bookId.$extension');
      await coverFile.writeAsBytes(coverData.bytes, flush: true);
      return coverFile.path;
    } catch (_) {
      return null;
    }
  }

  static _CoverImageData? _extractCoverImageData(EpubBook epubBook) {
    final package = epubBook.Schema?.Package;
    final metaItems = package?.Metadata?.MetaItems;
    final manifestItems = package?.Manifest?.Items;
    final images = epubBook.Content?.Images;

    if (metaItems == null ||
        metaItems.isEmpty ||
        manifestItems == null ||
        manifestItems.isEmpty ||
        images == null ||
        images.isEmpty) {
      return null;
    }

    String? coverItemId;
    for (final metaItem in metaItems) {
      final name = metaItem.Name?.trim().toLowerCase();
      final content = metaItem.Content?.trim();
      if (name == 'cover' && content != null && content.isNotEmpty) {
        coverItemId = content;
        break;
      }
    }
    if (coverItemId == null) return null;

    String? coverHref;
    for (final manifestItem in manifestItems) {
      final manifestId = manifestItem.Id;
      if (manifestId != null &&
          manifestId.toLowerCase() == coverItemId.toLowerCase()) {
        coverHref = manifestItem.Href;
        break;
      }
    }
    if (coverHref == null || coverHref.isEmpty) return null;

    final coverImage = _findCoverImageFile(images, coverHref);
    final coverBytes = coverImage?.Content;
    if (coverBytes == null || coverBytes.isEmpty) return null;

    return _CoverImageData(bytes: coverBytes, href: coverHref);
  }

  static EpubByteContentFile? _findCoverImageFile(
    Map<String, EpubByteContentFile> images,
    String href,
  ) {
    final exactMatch = images[href];
    if (exactMatch != null) return exactMatch;

    final normalizedHref = _normalizeResourcePath(href);
    for (final entry in images.entries) {
      final normalizedKey = _normalizeResourcePath(entry.key);
      if (normalizedKey == normalizedHref ||
          normalizedKey.endsWith('/$normalizedHref') ||
          normalizedHref.endsWith('/$normalizedKey')) {
        return entry.value;
      }
    }

    return null;
  }

  static String _normalizeResourcePath(String value) {
    final withoutQuery = value.split('?').first.split('#').first;
    return withoutQuery.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
  }

  static String _inferCoverExtension(List<int> bytes, String href) {
    final extensionFromHref = _extractImageExtension(href);
    if (extensionFromHref != null) {
      return extensionFromHref;
    }

    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    return 'jpg';
  }

  static String? _extractImageExtension(String href) {
    final normalized = _normalizeResourcePath(href).toLowerCase();
    final match = RegExp(r'\.([a-z0-9]+)$').firstMatch(normalized);
    final extension = match?.group(1);
    if (extension == null || extension.isEmpty) return null;

    switch (extension) {
      case 'jpeg':
        return 'jpg';
      case 'jpg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return extension;
      default:
        return null;
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
      final manifestItem = manifest.firstWhere(
        (item) => item.Id == idRef,
        orElse: () => manifest.first,
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
            chapterTitle = tocItem.NavigationLabels?.first.Text ?? chapterTitle;
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
    // EPUB 内容通常为 HTML/XHTML：统一走“对标 legado”的 HTML -> 文本清理。
    // 说明：段首缩进/段距等阅读排版策略不在此处做，留给阅读器层统一处理。
    return HtmlTextFormatter.formatToPlainText(html);
  }
}

/// EPUB 导入结果
class EpubImportResult {
  final Book book;
  final List<Chapter> chapters;

  EpubImportResult({required this.book, required this.chapters});
}

class _CoverImageData {
  final List<int> bytes;
  final String href;

  const _CoverImageData({required this.bytes, required this.href});
}
