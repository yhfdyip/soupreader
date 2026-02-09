import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_filter_helper.dart';

BookSource _source({
  required String url,
  required String name,
  String? group,
  bool enabled = true,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    bookSourceGroup: group,
    enabled: enabled,
  );
}

void main() {
  test('buildGroups collects and sorts group names', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: 'A', group: '玄幻,男频'),
      _source(url: 'u2', name: 'B', group: '女频；完本'),
      _source(url: 'u3', name: 'C', group: '男频'),
    ];

    final groups = SourceFilterHelper.buildGroups(sources);
    expect(groups.first, '全部');
    expect(groups.last, '失效');
    expect(groups, containsAll(<String>['玄幻', '男频', '女频', '完本']));
  });

  test('filterByGroup supports all and disabled virtual groups', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: 'A', group: '玄幻', enabled: true),
      _source(url: 'u2', name: 'B', group: '女频', enabled: false),
      _source(url: 'u3', name: 'C', group: '玄幻,女频', enabled: false),
    ];

    expect(SourceFilterHelper.filterByGroup(sources, '全部').length, 3);
    expect(SourceFilterHelper.filterByGroup(sources, '失效').length, 2);
    expect(SourceFilterHelper.filterByGroup(sources, '玄幻').length, 2);
    expect(SourceFilterHelper.filterByGroup(sources, '女频').length, 2);
  });

  test('filterByEnabled filters by enabled flag', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: 'A', enabled: true),
      _source(url: 'u2', name: 'B', enabled: false),
      _source(url: 'u3', name: 'C', enabled: true),
    ];

    expect(
      SourceFilterHelper.filterByEnabled(sources, SourceEnabledFilter.all)
          .length,
      3,
    );
    expect(
      SourceFilterHelper.filterByEnabled(sources, SourceEnabledFilter.enabled)
          .length,
      2,
    );
    expect(
      SourceFilterHelper.filterByEnabled(sources, SourceEnabledFilter.disabled)
          .length,
      1,
    );
  });
}
