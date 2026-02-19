import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/search/services/search_scope_picker_helper.dart';
import 'package:soupreader/features/source/models/book_source.dart';

BookSource _source({
  required String name,
  required String url,
  String? group,
  String? comment,
}) {
  return BookSource(
    bookSourceName: name,
    bookSourceUrl: url,
    bookSourceGroup: group,
    bookSourceComment: comment,
  );
}

void main() {
  test('filterSourcesByQuery 覆盖 name/url/group/comment 字段', () {
    final sources = <BookSource>[
      _source(name: '源A', url: 'https://a.com', group: '甲组', comment: '热门'),
      _source(name: '源B', url: 'https://b.com', group: '乙组', comment: '冷门'),
    ];

    expect(
      SearchScopePickerHelper.filterSourcesByQuery(sources, '源A')
          .map((e) => e.bookSourceName)
          .toList(),
      <String>['源A'],
    );
    expect(
      SearchScopePickerHelper.filterSourcesByQuery(sources, 'b.com')
          .map((e) => e.bookSourceName)
          .toList(),
      <String>['源B'],
    );
    expect(
      SearchScopePickerHelper.filterSourcesByQuery(sources, '乙组')
          .map((e) => e.bookSourceName)
          .toList(),
      <String>['源B'],
    );
    expect(
      SearchScopePickerHelper.filterSourcesByQuery(sources, '热门')
          .map((e) => e.bookSourceName)
          .toList(),
      <String>['源A'],
    );
  });

  test('toggleGroupSelection 按选择顺序维护分组列表', () {
    final selected = <String>[];
    SearchScopePickerHelper.toggleGroupSelection(selected, '乙');
    SearchScopePickerHelper.toggleGroupSelection(selected, '甲');
    expect(selected, <String>['乙', '甲']);

    SearchScopePickerHelper.toggleGroupSelection(selected, '乙');
    expect(selected, <String>['甲']);

    SearchScopePickerHelper.toggleGroupSelection(selected, '乙');
    expect(selected, <String>['甲', '乙']);
  });

  test('orderedSelectedGroups 过滤不存在分组并保留用户顺序', () {
    final selected = <String>['乙', '不存在', '甲'];
    final allGroups = <String>['甲', '乙', '丙'];
    final ordered = SearchScopePickerHelper.orderedSelectedGroups(
      selected,
      allGroups,
    );
    expect(ordered, <String>['乙', '甲']);
  });
}
