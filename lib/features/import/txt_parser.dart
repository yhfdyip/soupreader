import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fast_gbk/fast_gbk.dart';
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
  static Future<TxtImportResult> importFromFile(
    String filePath, {
    String? forcedCharset,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final bytes = await file.readAsBytes();
    final decoded = _decodeContent(bytes, forcedCharset: forcedCharset);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final bookName =
        fileName.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');

    return _parseContent(
      decoded.content,
      bookName,
      filePath,
      charset: decoded.charset,
    );
  }

  /// 从字节数据导入（iOS 使用）
  static TxtImportResult importFromBytes(
    Uint8List bytes,
    String fileName, {
    String? forcedCharset,
  }) {
    final decoded = _decodeContent(bytes, forcedCharset: forcedCharset);
    final bookName =
        fileName.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
    return _parseContent(
      decoded.content,
      bookName,
      null,
      charset: decoded.charset,
    );
  }

  /// 以既有书籍 ID 重解析 TXT（用于阅读器设置编码后的重载）。
  static Future<TxtImportResult> reparseFromFile({
    required String filePath,
    required String bookId,
    required String bookName,
    String? forcedCharset,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }
    final bytes = await file.readAsBytes();
    final decoded = _decodeContent(bytes, forcedCharset: forcedCharset);
    return _parseContent(
      decoded.content,
      bookName,
      filePath,
      charset: decoded.charset,
      forcedBookId: bookId,
    );
  }

  /// 自动检测编码并解码
  static _DecodedTxtContent _decodeContent(
    Uint8List bytes, {
    String? forcedCharset,
  }) {
    if (bytes.isEmpty) {
      return const _DecodedTxtContent(
        content: '',
        charset: 'UTF-8',
      );
    }

    final normalizedForced = _normalizeForcedCharset(forcedCharset);
    if (normalizedForced != null) {
      return _decodeContentByCharset(bytes, normalizedForced);
    }

    // 检测 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      // UTF-8 with BOM
      return _DecodedTxtContent(
        content: utf8.decode(bytes.sublist(3), allowMalformed: true),
        charset: 'UTF-8',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // UTF-16 LE BOM
      return _DecodedTxtContent(
        content: _decodeUtf16(bytes.sublist(2), littleEndian: true),
        charset: 'UTF-16LE',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // UTF-16 BE BOM
      return _DecodedTxtContent(
        content: _decodeUtf16(bytes.sublist(2), littleEndian: false),
        charset: 'UTF-16',
      );
    }

    // 优先 UTF-8（对标 legado：优先使用探测结果中的 Unicode 编码）
    try {
      return _DecodedTxtContent(
        content: utf8.decode(bytes, allowMalformed: false),
        charset: 'UTF-8',
      );
    } catch (_) {}

    // 非 UTF-8 时，优先按 GBK 解码（中文 TXT 常见；对齐 legado 的编码探测目标）
    try {
      return _DecodedTxtContent(
        content: gbk.decode(bytes, allowMalformed: true),
        charset: 'GBK',
      );
    } catch (_) {}

    // 最后回退：UTF-8 容错，尽量不崩溃
    return _DecodedTxtContent(
      content: utf8.decode(bytes, allowMalformed: true),
      charset: 'UTF-8',
    );
  }

  static String? _normalizeForcedCharset(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final upper = value.toUpperCase().replaceAll('_', '-');
    switch (upper) {
      case 'UTF8':
      case 'UTF-8':
        return 'UTF-8';
      case 'GB2312':
        return 'GB2312';
      case 'GB18030':
        return 'GB18030';
      case 'GBK':
        return 'GBK';
      case 'UNICODE':
        return 'Unicode';
      case 'UTF16':
      case 'UTF-16':
        return 'UTF-16';
      case 'UTF16LE':
      case 'UTF-16LE':
        return 'UTF-16LE';
      case 'ASCII':
        return 'ASCII';
      default:
        return value;
    }
  }

  static _DecodedTxtContent _decodeContentByCharset(
    Uint8List bytes,
    String charset,
  ) {
    try {
      final upper = charset.toUpperCase();
      switch (upper) {
        case 'UTF-8':
          final noBom = _trimUtf8Bom(bytes);
          return _DecodedTxtContent(
            content: utf8.decode(noBom, allowMalformed: true),
            charset: 'UTF-8',
          );
        case 'GB2312':
        case 'GB18030':
        case 'GBK':
          return _DecodedTxtContent(
            content: gbk.decode(bytes, allowMalformed: true),
            charset: upper,
          );
        case 'UNICODE':
        case 'UTF-16':
          if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
            return _DecodedTxtContent(
              content: _decodeUtf16(bytes.sublist(2), littleEndian: true),
              charset: 'UTF-16LE',
            );
          }
          if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
            return _DecodedTxtContent(
              content: _decodeUtf16(bytes.sublist(2), littleEndian: false),
              charset: 'UTF-16',
            );
          }
          return _DecodedTxtContent(
            content: _decodeUtf16(bytes, littleEndian: true),
            charset: 'UTF-16',
          );
        case 'UTF-16LE':
          if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
            return _DecodedTxtContent(
              content: _decodeUtf16(bytes.sublist(2), littleEndian: true),
              charset: 'UTF-16LE',
            );
          }
          return _DecodedTxtContent(
            content: _decodeUtf16(bytes, littleEndian: true),
            charset: 'UTF-16LE',
          );
        case 'ASCII':
          return _DecodedTxtContent(
            content: ascii.decode(bytes, allowInvalid: true),
            charset: 'ASCII',
          );
        default:
          return _DecodedTxtContent(
            content: utf8.decode(bytes, allowMalformed: true),
            charset: charset,
          );
      }
    } catch (_) {
      return _DecodedTxtContent(
        content: utf8.decode(bytes, allowMalformed: true),
        charset: charset,
      );
    }
  }

  static Uint8List _trimUtf8Bom(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  static String _decodeUtf16(
    Uint8List bytes, {
    required bool littleEndian,
  }) {
    final length = bytes.length;
    if (length < 2) return '';
    final evenLength = length - (length % 2);
    final data = ByteData.sublistView(bytes, 0, evenLength);
    final codeUnits = Uint16List(evenLength ~/ 2);
    final endian = littleEndian ? Endian.little : Endian.big;
    for (var i = 0; i < codeUnits.length; i++) {
      codeUnits[i] = data.getUint16(i * 2, endian);
    }
    return String.fromCharCodes(codeUnits);
  }

  /// 解析内容
  static TxtImportResult _parseContent(
    String content,
    String bookName,
    String? filePath, {
    required String charset,
    String? forcedBookId,
  }) {
    // 清理内容 - 统一换行符
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 识别章节
    final chapters = _splitChapters(content);

    // 创建书籍
    final bookId = forcedBookId ?? _uuid.v4();
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
        // TXT 的排版问题主要来自“硬换行”（每行固定宽度换行但段落不空行）。
        // 阅读器侧会把 `\n` 当成段落分隔，因此这里先对正文做一次段落归一化。
        content: _normalizeTxtTypography(entry.value.content),
      );
    }).toList();

    return TxtImportResult(
      book: book,
      chapters: chapterList,
      charset: charset,
    );
  }

  /// TXT 段落归一化（对标 Legado 的“按段落阅读”的体验，而非逐行阅读）。
  ///
  /// 处理目标：
  /// - 保留真正的段落分隔（空行）
  /// - 对“硬换行”文本：合并连续非空行，避免每一行都被当成一个段落
  ///
  /// 注意：
  /// - 这是启发式算法；如果文本本来就是诗歌/台词逐行排版，会尽量避免触发合并。
  static String _normalizeTxtTypography(String content) {
    var text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.trim();
    if (text.isEmpty) return text;

    final lines = text.split('\n');
    final trimmedLines = _trimTrailingSpacesPerLine(lines);
    if (!_looksLikeHardWrappedText(trimmedLines)) {
      return trimmedLines.join('\n').trim();
    }

    // 对标 legado：当内容“疑似硬换行”时，进行一次重新分段。
    // legado 完整实现：`io.legado.app.help.book.ContentHelp.reSegment`
    return reSegmentLikeLegado(
      trimmedLines.join('\n'),
      chapterTitle: '',
    );
  }

  static List<String> _trimTrailingSpacesPerLine(List<String> lines) {
    return lines.map((l) => l.trimRight()).toList(growable: false);
  }

  static bool _looksLikeHardWrappedText(List<String> lines) {
    int nonEmpty = 0;
    int blank = 0;
    int indentLike = 0;
    int lengthInRange = 0;
    int totalLen = 0;

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) {
        blank++;
        continue;
      }
      nonEmpty++;
      totalLen += t.length;

      // 段首缩进/空格缩进：一般代表“作者原始段落”，不应当合并为硬换行
      if (line.startsWith('　　') ||
          line.startsWith('　') ||
          RegExp(r'^\s{2,}').hasMatch(line)) {
        indentLike++;
      }

      // 硬换行的典型特征：大量长度相近的中等长度行（并且空行极少）
      if (t.length >= 16 && t.length <= 120) {
        lengthInRange++;
      }
    }

    // 过短的内容不做启发式合并，避免诗歌/对白逐行排版被破坏。
    if (nonEmpty < 12) return false;

    final blankRatio = blank / (nonEmpty + blank);
    final indentRatio = indentLike / nonEmpty;
    final inRangeRatio = lengthInRange / nonEmpty;
    final avgLen = totalLen / nonEmpty;

    // 触发条件（相对保守）：
    // - 空行占比很低（几乎没有自然段落分隔）
    // - 大部分行长度处于“可能是自动换行”的区间
    // - 平均长度不至于太短（避免诗歌/对话逐行）
    // - 缩进段落占比不高（避免本来就按段落写的文本）
    return totalLen >= 400 &&
        blankRatio <= 0.06 &&
        inRangeRatio >= 0.7 &&
        avgLen >= 18 &&
        indentRatio <= 0.25;
  }

  static bool _isAsciiLetterOrDigit(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) || // 0-9
        (codeUnit >= 65 && codeUnit <= 90) || // A-Z
        (codeUnit >= 97 && codeUnit <= 122); // a-z
  }

  /// 是否句末标点（对标 legado `ContentHelp.MARK_SENTENCES_END`）
  static bool _isSentenceEndChar(String ch) {
    return ch == '？' ||
        ch == '。' ||
        ch == '！' ||
        ch == '?' ||
        ch == '!' ||
        ch == '~';
  }

  static bool _isRightQuote(String ch) => ch == '”' || ch == '"';

  static bool _isPredominantlyCjk(String text) {
    // 只扫描前一段内容，避免大文本遍历成本
    final maxScan = text.length.clamp(0, 2000);
    int cjk = 0;
    int asciiWord = 0;
    for (int i = 0; i < maxScan; i++) {
      final code = text.codeUnitAt(i);
      if ((code >= 0x4E00 && code <= 0x9FFF) ||
          (code >= 0x3400 && code <= 0x4DBF) ||
          (code >= 0xF900 && code <= 0xFAFF)) {
        cjk++;
      } else if (_isAsciiLetterOrDigit(code)) {
        asciiWord++;
      }
    }
    if (cjk < 50) return false;
    return cjk >= asciiWord * 2;
  }

  static String _smartJoin(String left, String right) {
    final l = left.trimRight();
    final r = right.trimLeft();
    if (l.isEmpty) return r;
    if (r.isEmpty) return l;

    final last = l.codeUnitAt(l.length - 1);
    final first = r.codeUnitAt(0);
    if (_isAsciiLetterOrDigit(last) && _isAsciiLetterOrDigit(first)) {
      return '$l $r';
    }
    return '$l$r';
  }

  /// 对标 legado 的“重新分段”入口（简化版，可用于阅读器菜单）。
  static String reSegmentLikeLegado(
    String content, {
    required String chapterTitle,
  }) {
    var text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (text.isEmpty) return '';
    final lines = _trimTrailingSpacesPerLine(text.split('\n'));
    if (lines.isEmpty) return '';
    text = _reSegmentLikeLegado(lines).trim();

    final safeChapterTitle = chapterTitle.trim();
    if (safeChapterTitle.isEmpty) {
      return text;
    }
    final paragraphs = text.split('\n');
    if (paragraphs.isNotEmpty &&
        paragraphs.first.trim() == safeChapterTitle &&
        paragraphs.length > 1) {
      paragraphs.removeAt(0);
      return paragraphs.join('\n').trim();
    }
    return text;
  }

  /// 对标 legado 的“重新分段”思路（简化版）。
  ///
  /// legado 完整实现：`io.legado.app.help.book.ContentHelp.reSegment`
  /// 这里保留最关键、最能解决 TXT 硬换行的部分：
  /// - 合并错误的换行（硬换行）
  /// - 保留真实空行作为段落分隔
  /// - 在段落过长时，按句末标点插入换行，避免超长段落
  static String _reSegmentLikeLegado(List<String> lines) {
    final buffer = StringBuffer();
    var paragraph = '';

    // 是否主要为中文内容：中文小说里“去掉段落内空白”更接近 legado；
    // 英文内容则保留空格，避免单词黏连。
    final cjkPreferred = _isPredominantlyCjk(lines.take(80).join('\n'));
    final innerSpaceRegex =
        RegExp(r'[\u3000\s]+', multiLine: true); // 对齐 legado

    void flushParagraph() {
      final p = paragraph.trim();
      if (p.isEmpty) {
        paragraph = '';
        return;
      }
      final segmented = _insertSoftNewlinesBySentenceEnd(p);
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(segmented);
      paragraph = '';
    }

    for (final raw in lines) {
      final trimmed = raw.trimRight();
      if (trimmed.trim().isEmpty) {
        // 空行：段落分隔
        flushParagraph();
        continue;
      }

      final line = cjkPreferred
          ? trimmed.replaceAll(innerSpaceRegex, '')
          : trimmed.trim();

      if (paragraph.isEmpty) {
        paragraph = line;
        continue;
      }

      // 对齐 legado 的“句末换行”逻辑：
      // 上一段的末尾是句末标点，或是右引号且其前一位是句末标点，则开始新段。
      final last = paragraph.substring(paragraph.length - 1);
      final prev = paragraph.length >= 2
          ? paragraph.substring(paragraph.length - 2, paragraph.length - 1)
          : '';
      final shouldNewParagraph = _isSentenceEndChar(last) ||
          (_isRightQuote(last) && _isSentenceEndChar(prev));
      if (shouldNewParagraph) {
        flushParagraph();
        paragraph = line;
        continue;
      }

      // 继续黏合：中文直接拼接；英文/数字用 smart join 避免单词黏连
      paragraph =
          cjkPreferred ? '$paragraph$line' : _smartJoin(paragraph, line);
    }

    flushParagraph();
    return buffer.toString();
  }

  /// 段落内部“软换行”：避免硬换行修复后出现一整段超长文本。
  ///
  /// 规则（偏保守）：
  /// - 段落较短则不处理
  /// - 当距离上次换行超过一定阈值后，遇到句末标点才插入换行
  static String _insertSoftNewlinesBySentenceEnd(String paragraph) {
    if (paragraph.length <= 220) return paragraph;

    const minCharsBetweenBreaks = 60;
    final sb = StringBuffer();
    int sinceBreak = 0;
    for (int i = 0; i < paragraph.length; i++) {
      final ch = paragraph[i];
      sb.write(ch);
      sinceBreak++;

      if (sinceBreak < minCharsBetweenBreaks) continue;

      if (_isSentenceEndChar(ch)) {
        if (i + 1 < paragraph.length && paragraph[i + 1] != '\n') {
          sb.write('\n');
          sinceBreak = 0;
        }
        continue;
      }

      // 处理 “。”后紧跟右引号 的常见情况：。” / ?” / !”
      if (_isRightQuote(ch) && i >= 1 && _isSentenceEndChar(paragraph[i - 1])) {
        if (i + 1 < paragraph.length && paragraph[i + 1] != '\n') {
          sb.write('\n');
          sinceBreak = 0;
        }
      }
    }

    return sb.toString().replaceAll(RegExp(r'\n{2,}'), '\n').trim();
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
          title: '第$chapterIndex章',
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
  final String charset;

  TxtImportResult({
    required this.book,
    required this.chapters,
    required this.charset,
  });
}

class _DecodedTxtContent {
  final String content;
  final String charset;

  const _DecodedTxtContent({
    required this.content,
    required this.charset,
  });
}
