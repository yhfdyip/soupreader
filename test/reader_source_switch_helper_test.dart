import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/reader/services/reader_source_switch_helper.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

BookSource _source({
  required String url,
  required String name,
  bool enabled = true,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    enabled: enabled,
  );
}

Chapter _chapter({required int index, required String title}) {
  return Chapter(
    id: 'c$index',
    bookId: 'b',
    title: title,
    index: index,
  );
}

SearchResult _search({
  required String name,
  required String author,
  required String bookUrl,
  required String sourceUrl,
  required String sourceName,
}) {
  return SearchResult(
    name: name,
    author: author,
    coverUrl: '',
    intro: '',
    lastChapter: '',
    bookUrl: bookUrl,
    sourceUrl: sourceUrl,
    sourceName: sourceName,
  );
}

void main() {
  test('normalizeForCompare trims lowercases and removes spaces', () {
    expect(
      ReaderSourceSwitchHelper.normalizeForCompare('  诡秘  之主  '),
      '诡秘之主',
    );
    expect(
      ReaderSourceSwitchHelper.normalizeForCompare('  ABC  d '),
      'abcd',
    );
  });

  test('buildCandidates excludes current source and mismatched title', () {
    final book = Book(
      id: 'b1',
      title: '诡秘之主',
      author: '爱潜水的乌贼',
      sourceUrl: 'https://source-a',
    );

    final enabledSources = <BookSource>[
      _source(url: 'https://source-a', name: 'A'),
      _source(url: 'https://source-b', name: 'B'),
    ];

    final results = <SearchResult>[
      _search(
        name: '诡秘之主',
        author: '爱潜水的乌贼',
        bookUrl: 'https://book-a',
        sourceUrl: 'https://source-a',
        sourceName: 'A',
      ),
      _search(
        name: '不是这本',
        author: '作者',
        bookUrl: 'https://book-b',
        sourceUrl: 'https://source-b',
        sourceName: 'B',
      ),
      _search(
        name: '诡秘之主',
        author: '爱潜水的乌贼',
        bookUrl: 'https://book-c',
        sourceUrl: 'https://source-b',
        sourceName: 'B',
      ),
    ];

    final candidates = ReaderSourceSwitchHelper.buildCandidates(
      currentBook: book,
      enabledSources: enabledSources,
      searchResults: results,
    );

    expect(candidates.length, 1);
    expect(candidates.first.source.bookSourceName, 'B');
    expect(candidates.first.book.bookUrl, 'https://book-c');
  });

  test('buildCandidates orders exact author match before fallback', () {
    final book = Book(
      id: 'b2',
      title: '凡人修仙传',
      author: '忘语',
      sourceUrl: 'https://source-a',
    );

    final enabledSources = <BookSource>[
      _source(url: 'https://source-b', name: 'B'),
      _source(url: 'https://source-c', name: 'C'),
    ];

    final results = <SearchResult>[
      _search(
        name: '凡人修仙传',
        author: '其他作者',
        bookUrl: 'https://book-fallback',
        sourceUrl: 'https://source-b',
        sourceName: 'B',
      ),
      _search(
        name: '凡人修仙传',
        author: '忘语',
        bookUrl: 'https://book-exact',
        sourceUrl: 'https://source-c',
        sourceName: 'C',
      ),
    ];

    final candidates = ReaderSourceSwitchHelper.buildCandidates(
      currentBook: book,
      enabledSources: enabledSources,
      searchResults: results,
    );

    expect(candidates.length, 2);
    expect(candidates.first.book.bookUrl, 'https://book-exact');
    expect(candidates.last.book.bookUrl, 'https://book-fallback');
  });

  test('buildCandidates dedupes same source and bookUrl', () {
    final book = Book(
      id: 'b3',
      title: '雪中悍刀行',
      author: '烽火戏诸侯',
      sourceUrl: 'https://source-a',
    );
    final enabledSources = <BookSource>[
      _source(url: 'https://source-b', name: 'B'),
    ];
    final results = <SearchResult>[
      _search(
        name: '雪中悍刀行',
        author: '烽火戏诸侯',
        bookUrl: 'https://book-1',
        sourceUrl: 'https://source-b',
        sourceName: 'B',
      ),
      _search(
        name: '雪中悍刀行',
        author: '烽火戏诸侯',
        bookUrl: 'https://book-1',
        sourceUrl: 'https://source-b',
        sourceName: 'B',
      ),
    ];

    final candidates = ReaderSourceSwitchHelper.buildCandidates(
      currentBook: book,
      enabledSources: enabledSources,
      searchResults: results,
    );
    expect(candidates.length, 1);
  });

  test('resolveTargetChapterIndex uses normalized title match', () {
    final chapters = <Chapter>[
      _chapter(index: 0, title: '第1章 山雨欲来'),
      _chapter(index: 1, title: '第二章 风起云涌'),
      _chapter(index: 2, title: '第三章 大幕拉开'),
    ];

    final index = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: chapters,
      currentChapterTitle: '第2章-风起云涌',
      currentChapterIndex: 0,
    );
    expect(index, 1);
  });

  test('resolveTargetChapterIndex falls back to nearest index', () {
    final chapters = <Chapter>[
      _chapter(index: 0, title: '序章'),
      _chapter(index: 1, title: '第一章'),
    ];

    final index = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: chapters,
      currentChapterTitle: '完全不匹配标题',
      currentChapterIndex: 8,
    );
    expect(index, 1);
  });
}
