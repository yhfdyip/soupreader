import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/search/models/search_scope.dart';
import 'package:soupreader/features/source/models/book_source.dart';

BookSource _source({
  required String url,
  required String name,
  String? group,
  bool enabled = true,
  int order = 0,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    bookSourceGroup: group,
    enabled: enabled,
    customOrder: order,
  );
}

void main() {
  test('all scope resolves to all enabled sources sorted by customOrder', () {
    final sources = <BookSource>[
      _source(url: 'u2', name: 'B', group: '女频', order: 2),
      _source(url: 'u1', name: 'A', group: '男频', order: 1),
    ];

    final resolved = const SearchScope('').resolve(sources);
    expect(resolved.isAll, isTrue);
    expect(resolved.sources.map((item) => item.bookSourceUrl), ['u1', 'u2']);
    expect(resolved.display(), '全部书源');
  });

  test('source scope resolves single source and keeps source mode', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: '源A', group: '男频', order: 1),
      _source(url: 'u2', name: '源B', group: '女频', order: 2),
    ];

    final resolved = const SearchScope('源B::u2').resolve(sources);
    expect(resolved.isSource, isTrue);
    expect(resolved.sources.map((item) => item.bookSourceUrl), ['u2']);
    expect(resolved.display(), '源B');
    expect(resolved.normalizedScope, '源B::u2');
  });

  test('missing source fallback to all', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: '源A', group: '男频', order: 1),
      _source(url: 'u2', name: '源B', group: '女频', order: 2),
    ];

    final resolved = const SearchScope('源X::missing').resolve(sources);
    expect(resolved.isAll, isTrue);
    expect(resolved.normalizedScope, '');
    expect(resolved.sources.map((item) => item.bookSourceUrl), ['u1', 'u2']);
  });

  test('group scope removes invalid groups and deduplicates sources', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: '源A', group: '男频,完本', order: 1),
      _source(url: 'u2', name: '源B', group: '完本', order: 3),
      _source(url: 'u3', name: '源C', group: '女频', order: 2),
    ];

    final resolved = const SearchScope('完本,不存在,男频').resolve(sources);
    expect(resolved.isAll, isFalse);
    expect(resolved.isSource, isFalse);
    expect(resolved.selectedGroups, ['完本', '男频']);
    expect(resolved.normalizedScope, '完本,男频');
    expect(resolved.sources.map((item) => item.bookSourceUrl), ['u1', 'u2']);
  });

  test('group scope fallback to all when no valid groups', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: '源A', group: '男频', order: 1),
    ];

    final resolved = const SearchScope('不存在').resolve(sources);
    expect(resolved.isAll, isTrue);
    expect(resolved.normalizedScope, '');
    expect(resolved.sources.map((item) => item.bookSourceUrl), ['u1']);
  });

  test('fromSource strips colon in source name', () {
    final source = _source(url: 'u1', name: '源:A', group: '男频', order: 1);
    expect(SearchScope.fromSource(source), '源A::u1');
  });

  test('source scope can resolve disabled source when provided', () {
    final allSources = <BookSource>[
      _source(url: 'u1', name: '源A', group: '男频', enabled: true, order: 1),
      _source(url: 'u2', name: '源B', group: '女频', enabled: false, order: 2),
    ];
    final enabledSources =
        allSources.where((item) => item.enabled).toList(growable: false);

    final resolved = const SearchScope('源B::u2').resolve(
      enabledSources,
      allSourcesForSourceMode: allSources,
    );
    expect(resolved.isSource, isTrue);
    expect(resolved.sources.length, 1);
    expect(resolved.sources.first.bookSourceUrl, 'u2');
  });
}
