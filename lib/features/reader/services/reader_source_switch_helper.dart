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

  static String normalizeForCompare(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
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
    var text = normalizeForCompare(value);
    text = text.replaceFirst(
      RegExp(r'^第?[0-9零一二三四五六七八九十百千万两]+[章节回卷部篇集]'),
      '',
    );
    text = text.replaceFirst(RegExp(r'^(chapter|chap|ch)[0-9]+'), '');
    text = text.replaceAll(
      RegExp(r'[\-—_:：\[\]【】\(\)（）《》<>·\.、,，;；!！?？]'),
      '',
    );
    return text;
  }

  static int resolveTargetChapterIndex({
    required List<Chapter> newChapters,
    required String currentChapterTitle,
    required int currentChapterIndex,
  }) {
    if (newChapters.isEmpty) return 0;

    final titleKey = normalizeChapterTitle(currentChapterTitle);
    if (titleKey.isNotEmpty) {
      final exactIndex = newChapters.indexWhere(
        (chapter) => normalizeChapterTitle(chapter.title) == titleKey,
      );
      if (exactIndex >= 0) return exactIndex;

      final fuzzyIndexes = <int>[];
      for (var i = 0; i < newChapters.length; i++) {
        final key = normalizeChapterTitle(newChapters[i].title);
        if (key.isEmpty) continue;
        if (key.length >= 4 && titleKey.contains(key)) {
          fuzzyIndexes.add(i);
          continue;
        }
        if (titleKey.length >= 4 && key.contains(titleKey)) {
          fuzzyIndexes.add(i);
        }
      }
      if (fuzzyIndexes.isNotEmpty) {
        fuzzyIndexes.sort(
          (a, b) =>
              (a - currentChapterIndex).abs() - (b - currentChapterIndex).abs(),
        );
        return fuzzyIndexes.first;
      }
    }

    return currentChapterIndex.clamp(0, newChapters.length - 1);
  }
}
