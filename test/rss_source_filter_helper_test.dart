import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/rss/models/rss_source.dart';
import 'package:soupreader/features/rss/services/rss_source_filter_helper.dart';

RssSource _source({
  required String url,
  required String name,
  String? group,
  String? comment,
  String? loginUrl,
  bool enabled = true,
  int customOrder = 0,
}) {
  return RssSource(
    sourceUrl: url,
    sourceName: name,
    sourceGroup: group,
    sourceComment: comment,
    loginUrl: loginUrl,
    enabled: enabled,
    customOrder: customOrder,
  );
}

void main() {
  test('groupSearch 按分组项精确匹配，不走 contains', () {
    final sources = <RssSource>[
      _source(
        url: 'u1',
        name: 'A',
        group: '玄幻,女频',
        customOrder: 2,
      ),
      _source(
        url: 'u2',
        name: 'B',
        group: '新玄幻派',
        customOrder: 1,
      ),
      _source(
        url: 'u3',
        name: 'C',
        group: '玄幻',
        customOrder: 0,
      ),
    ];

    final filtered = RssSourceFilterHelper.filterGroupSearch(sources, '玄幻');
    expect(filtered.map((e) => e.sourceUrl), <String>['u3', 'u1']);
  });

  test('noGroup 包含 null/空串/包含未分组文案', () {
    final sources = <RssSource>[
      _source(url: 'u1', name: 'A', group: null),
      _source(url: 'u2', name: 'B', group: ''),
      _source(url: 'u3', name: 'C', group: '都市,未分组来源'),
      _source(url: 'u4', name: 'D', group: '男频'),
    ];

    final filtered = RssSourceFilterHelper.filterNoGroup(sources);
    expect(
        filtered.map((e) => e.sourceUrl).toSet(), <String>{'u1', 'u2', 'u3'});
  });

  test('enabledSearch 与 enabledByGroup 仅作用于启用源', () {
    final sources = <RssSource>[
      _source(
        url: 'u1',
        name: '启用-有登录',
        group: '资讯',
        loginUrl: 'https://login.example',
        enabled: true,
      ),
      _source(
        url: 'u2',
        name: '禁用-有登录',
        group: '资讯',
        loginUrl: 'https://login.example',
        enabled: false,
      ),
      _source(
        url: 'u3',
        name: '启用-其他分组',
        group: '小说',
        enabled: true,
      ),
    ];

    final enabledSearch = RssSourceFilterHelper.filterEnabled(
      sources,
      searchKey: '登录',
    );
    expect(enabledSearch.map((e) => e.sourceUrl), <String>['u1']);

    final enabledByGroup = RssSourceFilterHelper.filterEnabledByGroup(
      sources,
      '资讯',
    );
    expect(enabledByGroup.map((e) => e.sourceUrl), <String>['u1']);

    final loginOnly = RssSourceFilterHelper.filterLogin(sources);
    expect(loginOnly.map((e) => e.sourceUrl).toSet(), <String>{'u1', 'u2'});
  });

  test('groups 处理会拆分去重并保留 legado 风格排序', () {
    final groups = RssSourceFilterHelper.dealGroups(
      const <String>[
        '玄幻,女频',
        '女频;科幻',
        '1区,玄幻',
      ],
    );
    expect(groups, containsAll(<String>['玄幻', '女频', '科幻', '1区']));
    expect(groups.toSet().length, groups.length);
  });
}
