import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/discovery/services/discovery_filter_helper.dart';
import 'package:soupreader/features/source/models/book_source.dart';

BookSource _source({
  required String name,
  required String url,
  String? group,
}) {
  return BookSource(
    bookSourceName: name,
    bookSourceUrl: url,
    bookSourceGroup: group,
  );
}

void main() {
  test('applyQueryFilter 普通关键字仅匹配书源名和分组', () {
    final sources = <BookSource>[
      _source(name: '玄幻主站', url: 'https://alpha.example.com', group: '玄幻'),
      _source(name: '科幻分站', url: 'https://beta.example.com', group: '科幻'),
    ];

    expect(
      DiscoveryFilterHelper.applyQueryFilter(sources, '玄幻')
          .map((item) => item.bookSourceName)
          .toList(growable: false),
      <String>['玄幻主站'],
    );
    expect(
      DiscoveryFilterHelper.applyQueryFilter(sources, 'beta.example.com'),
      isEmpty,
    );
  });

  test('applyQueryFilter 仅小写 group: 触发分组分支且按分组项精确匹配', () {
    final sources = <BookSource>[
      _source(name: '源A', url: 'https://a.example.com', group: '男频,都市'),
      _source(name: '源B', url: 'https://b.example.com', group: '女频'),
    ];

    expect(
      DiscoveryFilterHelper.applyQueryFilter(sources, 'group:男频')
          .map((item) => item.bookSourceName)
          .toList(growable: false),
      <String>['源A'],
    );
    expect(
      DiscoveryFilterHelper.applyQueryFilter(sources, 'group:男'),
      isEmpty,
    );
    expect(
      DiscoveryFilterHelper.applyQueryFilter(sources, 'Group:女频'),
      isEmpty,
    );
  });

  test('extractGroups 支持中英文分隔符并去重', () {
    expect(
      DiscoveryFilterHelper.extractGroups('甲组, 乙组；甲组; 丙组，'),
      <String>['甲组', '乙组', '丙组'],
    );
    expect(DiscoveryFilterHelper.extractGroups('  '), isEmpty);
  });

  test('shouldShowEmptyMessage 仅在查询为空且无结果时返回 true', () {
    expect(
      DiscoveryFilterHelper.shouldShowEmptyMessage(
        visibleCount: 0,
        query: '',
      ),
      isTrue,
    );
    expect(
      DiscoveryFilterHelper.shouldShowEmptyMessage(
        visibleCount: 0,
        query: 'group:玄幻',
      ),
      isFalse,
    );
    expect(
      DiscoveryFilterHelper.shouldShowEmptyMessage(
        visibleCount: 2,
        query: '',
      ),
      isFalse,
    );
  });
}
