import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/rss/models/rss_source.dart';
import 'package:soupreader/features/rss/services/rss_source_manage_helper.dart';

RssSource _source({
  required String url,
  required String name,
  String? group,
  bool enabled = true,
  String? loginUrl,
  int customOrder = 0,
}) {
  return RssSource(
    sourceUrl: url,
    sourceName: name,
    sourceGroup: group,
    enabled: enabled,
    loginUrl: loginUrl,
    customOrder: customOrder,
  );
}

void main() {
  test('parseQueryIntent 对齐 legado 查询模式', () {
    expect(
      RssSourceManageHelper.parseQueryIntent('').mode,
      RssSourceQueryMode.all,
    );
    expect(
      RssSourceManageHelper.parseQueryIntent('启用').mode,
      RssSourceQueryMode.enabled,
    );
    expect(
      RssSourceManageHelper.parseQueryIntent('禁用').mode,
      RssSourceQueryMode.disabled,
    );
    expect(
      RssSourceManageHelper.parseQueryIntent('需登录').mode,
      RssSourceQueryMode.login,
    );
    expect(
      RssSourceManageHelper.parseQueryIntent('未分组').mode,
      RssSourceQueryMode.noGroup,
    );
    final group = RssSourceManageHelper.parseQueryIntent('group:资讯');
    expect(group.mode, RssSourceQueryMode.group);
    expect(group.keyword, '资讯');
  });

  test('addGroupToNoGroupSources 只更新未分组源', () {
    final all = <RssSource>[
      _source(url: 'u1', name: 'a', group: ''),
      _source(url: 'u2', name: 'b', group: null),
      _source(url: 'u3', name: 'c', group: '科技'),
    ];
    final updates = RssSourceManageHelper.addGroupToNoGroupSources(
      allSources: all,
      group: '新增组',
    );
    expect(updates.map((e) => e.sourceUrl), <String>['u1', 'u2']);
    expect(updates.map((e) => e.sourceGroup), everyElement('新增组'));
  });

  test('renameGroup 与 removeGroup 保持分组项级别更新', () {
    final all = <RssSource>[
      _source(url: 'u1', name: 'a', group: '科幻,资讯'),
      _source(url: 'u2', name: 'b', group: '资讯'),
      _source(url: 'u3', name: 'c', group: '其他'),
    ];
    final renamed = RssSourceManageHelper.renameGroup(
      allSources: all,
      oldGroup: '资讯',
      newGroup: '新闻',
    );
    expect(renamed.map((e) => e.sourceUrl), <String>['u1', 'u2']);
    expect(renamed.first.sourceGroup, '科幻,新闻');
    expect(renamed.last.sourceGroup, '新闻');

    final removed = RssSourceManageHelper.removeGroup(
      allSources: all,
      group: '资讯',
    );
    expect(removed.map((e) => e.sourceUrl), <String>['u1', 'u2']);
    expect(removed.first.sourceGroup, '科幻');
    expect(removed.last.sourceGroup, '');
  });

  test('moveToTop/moveToBottom 使用 min/max order 推进排序', () {
    final source = _source(url: 'u1', name: 'a', customOrder: 5);
    final top = RssSourceManageHelper.moveToTop(
      source: source,
      minOrder: 3,
    );
    final bottom = RssSourceManageHelper.moveToBottom(
      source: source,
      maxOrder: 10,
    );
    expect(top.customOrder, 2);
    expect(bottom.customOrder, 11);
  });
}
