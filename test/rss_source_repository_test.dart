import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/rss_source_repository.dart';
import 'package:soupreader/features/rss/models/rss_source.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_rss_repo_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
  });

  tearDownAll(() async {
    try {
      await DatabaseService().close();
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseService().clearAll();
  });

  test('RSS 仓储写后立即读一致，且 flow 语义与 legado 对齐', () async {
    final repo = RssSourceRepository(DatabaseService());
    await repo.addSources(<RssSource>[
      const RssSource(
        sourceUrl: 'https://rss-a.example',
        sourceName: '源A',
        sourceGroup: '资讯,推荐',
        sourceComment: '可用源',
        enabled: true,
        loginUrl: 'https://rss-a.example/login',
        customOrder: 2,
      ),
      const RssSource(
        sourceUrl: 'https://rss-b.example',
        sourceName: '源B',
        sourceGroup: '资讯',
        sourceComment: '禁用',
        enabled: false,
        customOrder: 1,
      ),
      const RssSource(
        sourceUrl: 'https://rss-c.example',
        sourceName: '源C',
        sourceGroup: '',
        sourceComment: '空分组',
        enabled: true,
        customOrder: 3,
      ),
    ]);

    expect(repo.size, 3);
    expect(repo.getByKey('https://rss-a.example')?.sourceName, '源A');

    final enabled = await repo.flowEnabled().first;
    expect(enabled.map((e) => e.sourceUrl), <String>[
      'https://rss-a.example',
      'https://rss-c.example',
    ]);

    final disabled = await repo.flowDisabled().first;
    expect(disabled.map((e) => e.sourceUrl), <String>['https://rss-b.example']);

    final login = await repo.flowLogin().first;
    expect(login.map((e) => e.sourceUrl), <String>['https://rss-a.example']);

    final noGroup = await repo.flowNoGroup().first;
    expect(noGroup.map((e) => e.sourceUrl), <String>['https://rss-c.example']);

    final group = await repo.flowGroupSearch('资讯').first;
    expect(group.map((e) => e.sourceUrl), <String>[
      'https://rss-b.example',
      'https://rss-a.example',
    ]);

    final search = await repo.flowSearch('可用').first;
    expect(search.map((e) => e.sourceUrl), <String>['https://rss-a.example']);
  });

  test('upsertSourceRawJson 支持 URL 改名并保持 rawJson 回写', () async {
    final repo = RssSourceRepository(DatabaseService());
    await repo.addSource(
      const RssSource(
        sourceUrl: 'https://rss-old.example',
        sourceName: '旧源',
      ),
    );

    await repo.upsertSourceRawJson(
      originalUrl: 'https://rss-old.example',
      rawJson:
          '{"sourceUrl":"https://rss-new.example","sourceName":"新源","sourceGroup":"科技","enabled":true}',
    );

    expect(repo.getByKey('https://rss-old.example'), isNull);
    final updated = repo.getByKey('https://rss-new.example');
    expect(updated?.sourceName, '新源');
    expect(updated?.sourceGroup, '科技');
    expect(repo.getRawJsonByUrl('https://rss-new.example'), contains('新源'));
  });

  test('flowGroups / flowEnabledGroups 与 legado 分组语义一致', () async {
    final repo = RssSourceRepository(DatabaseService());
    await repo.addSources(const <RssSource>[
      RssSource(
        sourceUrl: 'https://rss-1.example',
        sourceName: '源1',
        sourceGroup: '女频,科幻',
        enabled: true,
      ),
      RssSource(
        sourceUrl: 'https://rss-2.example',
        sourceName: '源2',
        sourceGroup: '男频',
        enabled: false,
      ),
      RssSource(
        sourceUrl: 'https://rss-3.example',
        sourceName: '源3',
        sourceGroup: '科幻',
        enabled: true,
      ),
    ]);

    final allGroups = await repo.flowGroups().first;
    expect(allGroups, containsAll(<String>['女频', '科幻', '男频']));

    final enabledGroups = await repo.flowEnabledGroups().first;
    expect(enabledGroups, containsAll(<String>['女频', '科幻']));
    expect(enabledGroups, isNot(contains('男频')));
  });
}
