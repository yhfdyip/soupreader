import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/search/services/search_book_toc_filter_helper.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  const toc = <TocItem>[
    TocItem(index: 0, name: '第一章 开始', url: 'chapter-1'),
    TocItem(index: 1, name: '第二章 终章', url: 'chapter-2'),
    TocItem(index: 2, name: 'Special Episode', url: 'chapter-3'),
  ];

  test('目录检索：空关键字返回全量目录并保持原顺序', () {
    final entries = SearchBookTocFilterHelper.filterEntries(
      toc: toc,
      rawQuery: '   ',
      reversed: false,
    );

    expect(
        entries.map((entry) => entry.key).toList(growable: false), [0, 1, 2]);
  });

  test('目录检索：按章节原始标题字段过滤', () {
    final entries = SearchBookTocFilterHelper.filterEntries(
      toc: toc,
      rawQuery: '终章',
      reversed: false,
    );

    expect(entries.length, 1);
    expect(entries.first.key, 1);
    expect(entries.first.value.name, '第二章 终章');
  });

  test('目录检索：大小写不敏感', () {
    final entries = SearchBookTocFilterHelper.filterEntries(
      toc: toc,
      rawQuery: 'special',
      reversed: false,
    );

    expect(entries.length, 1);
    expect(entries.first.key, 2);
  });

  test('目录检索：倒序在过滤后执行', () {
    final entries = SearchBookTocFilterHelper.filterEntries(
      toc: toc,
      rawQuery: '章',
      reversed: true,
    );

    expect(entries.map((entry) => entry.key).toList(growable: false), [1, 0]);
  });

  test('目录检索：不使用展示标题参与命中', () {
    final entries = SearchBookTocFilterHelper.filterEntries(
      toc: toc,
      rawQuery: '壹',
      reversed: false,
    );

    expect(entries, isEmpty);
  });
}
