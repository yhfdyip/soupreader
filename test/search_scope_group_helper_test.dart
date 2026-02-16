import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/search/models/search_scope_group_helper.dart';
import 'package:soupreader/features/source/models/book_source.dart';

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
  test('enabledGroupsFromSources 仅统计启用书源并按 legacy 分隔符拆分', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: 'A', group: 'C， A;B'),
      _source(url: 'u2', name: 'B', group: 'B；D'),
      _source(url: 'u3', name: 'C', group: 'E', enabled: false),
      _source(url: 'u4', name: 'D', group: '   '),
    ];

    final groups = SearchScopeGroupHelper.enabledGroupsFromSources(sources);
    expect(groups, ['A', 'B', 'C', 'D']);
  });

  test('dealGroups 会去空去重并稳定排序', () {
    final groups = SearchScopeGroupHelper.dealGroups([
      ' z ;a',
      'b, a',
      '',
      'z',
      '  ',
    ]);
    expect(groups, ['a', 'b', 'z']);
  });

  test('dealGroups 中文分组按拼音顺序输出（近似 legacy cnCompare）', () {
    final groups = SearchScopeGroupHelper.dealGroups([
      '玄幻,都市,武侠',
      '历史',
    ]);
    expect(groups, ['都市', '历史', '武侠', '玄幻']);
  });

  test('dealGroups 中英混排时优先数字与中文，再英文', () {
    final groups = SearchScopeGroupHelper.dealGroups([
      'A区,玄幻,B区,武侠,10区,2区',
    ]);
    expect(groups, ['10区', '2区', '武侠', '玄幻', 'A区', 'B区']);
  });

  test('dealGroups 多音字短语按整词拼音排序（重庆/重生/中文）', () {
    final groups = SearchScopeGroupHelper.dealGroups([
      '中文,重生,重庆,重要',
    ]);
    expect(groups, ['重庆', '重生', '中文', '重要']);
  });

  test('dealGroups 常见中文分组名按拼音序稳定排序', () {
    final groups = SearchScopeGroupHelper.dealGroups([
      '男频,女频,都市,玄幻,轻小说,科幻',
    ]);
    expect(groups, ['都市', '科幻', '男频', '女频', '轻小说', '玄幻']);
  });

  test('dealGroups 符号前缀中文分组按中文类别参与排序', () {
    final groups = SearchScopeGroupHelper.dealGroups([
      '!活动,A区,2区,玄幻,_其它,B区,历史',
    ]);
    expect(groups, ['2区', '!活动', '_其它', '历史', '玄幻', 'A区', 'B区']);
  });

  test('dealGroups 同拼音前缀分组保持细分顺序稳定', () {
    final groups = SearchScopeGroupHelper.dealGroups([
      '斗罗,斗破,斗气,东野,东京,都市',
    ]);
    expect(groups, ['东京', '东野', '斗罗', '斗破', '斗气', '都市']);
  });

  test('enabledGroupsFromSources 在全部禁用时返回空分组', () {
    final sources = <BookSource>[
      _source(url: 'u1', name: 'A', group: 'A', enabled: false),
      _source(url: 'u2', name: 'B', group: 'B', enabled: false),
    ];
    final groups = SearchScopeGroupHelper.enabledGroupsFromSources(sources);
    expect(groups, isEmpty);
  });
}
