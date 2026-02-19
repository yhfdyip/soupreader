import '../../bookshelf/models/book.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';

class ReaderSourceSwitchCandidate {
  final BookSource source;
  final SearchResult book;

  const ReaderSourceSwitchCandidate({
    required this.source,
    required this.book,
  });
}

class ReaderSourceSwitchHelper {
  const ReaderSourceSwitchHelper._();

  static const String _chapterNumChars = r'\d零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟';

  static final RegExp _chapterNamePattern1 = RegExp(
    '.*?第([$_chapterNumChars]+)[章节篇回集话]',
  );

  static final RegExp _chapterNamePattern2 = RegExp(
    '^(?:[$_chapterNumChars]+[,:、])*([$_chapterNumChars]+)(?:[,:、]|\\.[^\\d])',
  );

  static final RegExp _chapterPrefixRegex = RegExp(
    '^.*?第(?:[$_chapterNumChars]+)[章节篇回集话](?!\$)|^(?:[$_chapterNumChars]+[,:、])*(?:[$_chapterNumChars]+)(?:[,:、](?!\$)|\\.(?=[^\\d]))',
  );

  static final RegExp _chapterOtherRegex = RegExp(
    r'[^\w\u3400-\u4DBF\u4E00-\u9FFF〇]',
  );

  static const Map<String, int> _chineseNumMap = {
    '零': 0,
    '〇': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
    '壹': 1,
    '贰': 2,
    '叁': 3,
    '肆': 4,
    '伍': 5,
    '陆': 6,
    '柒': 7,
    '捌': 8,
    '玖': 9,
    '拾': 10,
    '百': 100,
    '佰': 100,
    '千': 1000,
    '仟': 1000,
    '万': 10000,
    '亿': 100000000,
  };

  static String normalizeForCompare(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  static List<ReaderSourceSwitchCandidate> buildCandidates({
    required Book currentBook,
    required List<BookSource> enabledSources,
    required List<SearchResult> searchResults,
  }) {
    final currentSource = normalizeForCompare(currentBook.sourceUrl ?? '');
    final title = normalizeForCompare(currentBook.title);
    final author = normalizeForCompare(currentBook.author);
    final sourceMap = {
      for (final source in enabledSources)
        normalizeForCompare(source.bookSourceUrl): source,
    };

    final exact = <ReaderSourceSwitchCandidate>[];
    final fallback = <ReaderSourceSwitchCandidate>[];
    final seenCandidateKeys = <String>{};

    for (final item in searchResults) {
      final sourceKey = normalizeForCompare(item.sourceUrl);
      if (sourceKey.isEmpty || sourceKey == currentSource) continue;
      final source = sourceMap[sourceKey];
      if (source == null) continue;

      final itemTitle = normalizeForCompare(item.name);
      if (itemTitle != title) continue;

      final bookUrl = item.bookUrl.trim();
      final dedupeKey = '$sourceKey|$bookUrl';
      if (bookUrl.isEmpty || !seenCandidateKeys.add(dedupeKey)) continue;

      final candidate = ReaderSourceSwitchCandidate(source: source, book: item);
      final itemAuthor = normalizeForCompare(item.author);
      final authorMatched =
          author.isNotEmpty && itemAuthor.isNotEmpty && author == itemAuthor;

      if (authorMatched) {
        exact.add(candidate);
      } else {
        fallback.add(candidate);
      }
    }

    return <ReaderSourceSwitchCandidate>[...exact, ...fallback];
  }

  static String normalizeChapterTitle(String value) {
    return _pureChapterName(value);
  }

  static int resolveTargetChapterIndex({
    required List<Chapter> newChapters,
    required String currentChapterTitle,
    required int currentChapterIndex,
    int oldChapterCount = 0,
  }) {
    // 对齐 legado BookHelp.getDurChapter：
    // 章节 0 固定回退到 0；空目录时保留旧索引。
    if (currentChapterIndex <= 0) return 0;
    if (newChapters.isEmpty) return currentChapterIndex;

    final oldChapterNum = _chapterNum(currentChapterTitle);
    final oldName = _pureChapterName(currentChapterTitle);
    final newChapterSize = newChapters.length;

    final estimatedIndex = oldChapterCount == 0
        ? currentChapterIndex
        : currentChapterIndex * oldChapterCount ~/ newChapterSize;
    final minIndex = (currentChapterIndex < estimatedIndex
            ? currentChapterIndex
            : estimatedIndex) -
        10;
    final maxIndex = (currentChapterIndex > estimatedIndex
            ? currentChapterIndex
            : estimatedIndex) +
        10;
    final searchStart = minIndex.clamp(0, newChapterSize - 1);
    final searchEnd = maxIndex.clamp(0, newChapterSize - 1);

    var bestSimilarity = 0.0;
    var bestIndex = 0;
    var bestChapterNum = 0;

    if (oldName.isNotEmpty) {
      for (var i = searchStart; i <= searchEnd; i++) {
        final newName = _pureChapterName(newChapters[i].title);
        final similarity = _jaccardByRune(oldName, newName);
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestIndex = i;
        }
      }
    }

    if (bestSimilarity < 0.96 && oldChapterNum > 0) {
      for (var i = searchStart; i <= searchEnd; i++) {
        final chapterNum = _chapterNum(newChapters[i].title);
        if (chapterNum == oldChapterNum) {
          bestChapterNum = chapterNum;
          bestIndex = i;
          break;
        }
        if ((chapterNum - oldChapterNum).abs() <
            (bestChapterNum - oldChapterNum).abs()) {
          bestChapterNum = chapterNum;
          bestIndex = i;
        }
      }
    }

    if (bestSimilarity > 0.96 || (bestChapterNum - oldChapterNum).abs() < 1) {
      return bestIndex;
    }
    return currentChapterIndex.clamp(0, newChapterSize - 1);
  }

  static int _chapterNum(String? chapterName) {
    if (chapterName == null) return -1;
    final normalized = _toHalfWidth(chapterName).replaceAll(RegExp(r'\s+'), '');
    final m1 = _chapterNamePattern1.firstMatch(normalized);
    if (m1 != null) {
      return _stringToInt(m1.group(1));
    }
    final m2 = _chapterNamePattern2.firstMatch(normalized);
    if (m2 != null) {
      return _stringToInt(m2.group(1));
    }
    return -1;
  }

  static String _pureChapterName(String? chapterName) {
    if (chapterName == null) return '';
    final normalized = _toHalfWidth(chapterName).replaceAll(RegExp(r'\s+'), '');
    return normalized
        .replaceFirst(_chapterPrefixRegex, '')
        .replaceAll(_chapterOtherRegex, '')
        .toLowerCase();
  }

  static String _toHalfWidth(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 12288) {
        buffer.writeCharCode(32);
        continue;
      }
      if (rune >= 65281 && rune <= 65374) {
        buffer.writeCharCode(rune - 65248);
        continue;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  static int _stringToInt(String? text) {
    if (text == null || text.trim().isEmpty) return -1;
    final normalized = _toHalfWidth(text).replaceAll(RegExp(r'\s+'), '');
    final direct = int.tryParse(normalized);
    if (direct != null) return direct;
    return _chineseNumToInt(normalized);
  }

  static int _chineseNumToInt(String value) {
    final chars = value.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    if (chars.isEmpty) return -1;

    if (chars.length > 1 &&
        RegExp(r'^[〇零一二三四五六七八九壹贰叁肆伍陆柒捌玖]+$').hasMatch(value)) {
      final digits = StringBuffer();
      for (final ch in chars) {
        final mapped = _chineseNumMap[ch];
        if (mapped == null || mapped > 9) return -1;
        digits.write(mapped);
      }
      return int.tryParse(digits.toString()) ?? -1;
    }

    var result = 0;
    var tmp = 0;
    var billion = 0;
    for (var i = 0; i < chars.length; i++) {
      final mapped = _chineseNumMap[chars[i]];
      if (mapped == null) return -1;
      if (mapped == 100000000) {
        result += tmp;
        result *= mapped;
        billion = billion * mapped + result;
        result = 0;
        tmp = 0;
        continue;
      }
      if (mapped == 10000) {
        result += tmp;
        result *= mapped;
        tmp = 0;
        continue;
      }
      if (mapped >= 10) {
        if (tmp == 0) tmp = 1;
        result += mapped * tmp;
        tmp = 0;
        continue;
      }

      if (i >= 2 && i == chars.length - 1) {
        final prev = _chineseNumMap[chars[i - 1]] ?? 0;
        if (prev > 10) {
          tmp = mapped * prev ~/ 10;
          continue;
        }
      }
      tmp = tmp * 10 + mapped;
    }

    return result + tmp + billion;
  }

  static double _jaccardByRune(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0.0;
    final leftSet = left.runes.toSet();
    final rightSet = right.runes.toSet();
    final intersection = leftSet.intersection(rightSet).length;
    if (intersection == 0) return 0.0;
    final union = leftSet.length + rightSet.length - intersection;
    if (union <= 0) return 0.0;
    return intersection / union;
  }
}
