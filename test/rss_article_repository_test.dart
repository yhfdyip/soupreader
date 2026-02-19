import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/rss_article_repository.dart';
import 'package:soupreader/features/rss/models/rss_article.dart';
import 'package:soupreader/features/rss/models/rss_read_record.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_rss_article_repo_',
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

  test('flowByOriginSort 对齐 legado：按 order 倒序并左连接 read 标记', () async {
    final articleRepo = RssArticleRepository(DatabaseService());
    final readRepo = RssReadRecordRepository(DatabaseService());

    await articleRepo.insert(const <RssArticle>[
      RssArticle(
        origin: 'https://rss.example.com',
        sort: '头条',
        title: '文章-1',
        link: 'https://rss.example.com/a1',
        order: 100,
      ),
      RssArticle(
        origin: 'https://rss.example.com',
        sort: '头条',
        title: '文章-2',
        link: 'https://rss.example.com/a2',
        order: 200,
      ),
    ]);

    await readRepo.insertRecord(const <RssReadRecord>[
      RssReadRecord(
        record: 'https://rss.example.com/a1',
        title: '文章-1',
        readTime: 123456,
        read: true,
      ),
    ]);

    final list = await articleRepo
        .flowByOriginSort(
          'https://rss.example.com',
          '头条',
        )
        .first;

    expect(list.map((e) => e.link), <String>[
      'https://rss.example.com/a2',
      'https://rss.example.com/a1',
    ]);
    expect(list[0].read, isFalse);
    expect(list[1].read, isTrue);
  });

  test('append 语义对齐 OnConflict.IGNORE，clearOld 可清理旧文章', () async {
    final articleRepo = RssArticleRepository(DatabaseService());

    await articleRepo.insert(const <RssArticle>[
      RssArticle(
        origin: 'https://rss.example.com',
        sort: '头条',
        title: '文章-1',
        link: 'https://rss.example.com/a1',
        order: 100,
      ),
    ]);

    await articleRepo.append(const <RssArticle>[
      // 重复主键：应被忽略
      RssArticle(
        origin: 'https://rss.example.com',
        sort: '头条',
        title: '文章-1-dup',
        link: 'https://rss.example.com/a1',
        order: 99,
      ),
      // 新文章：应追加
      RssArticle(
        origin: 'https://rss.example.com',
        sort: '头条',
        title: '文章-2',
        link: 'https://rss.example.com/a2',
        order: 98,
      ),
    ]);

    await articleRepo.clearOld('https://rss.example.com', '头条', 100);

    final list = await articleRepo
        .flowByOriginSort(
          'https://rss.example.com',
          '头条',
        )
        .first;
    expect(list.length, 1);
    expect(list.single.link, 'https://rss.example.com/a1');
    expect(list.single.title, '文章-1');
  });

  test('阅读记录 DAO 语义：count/getRecords/deleteAll', () async {
    final readRepo = RssReadRecordRepository(DatabaseService());

    await readRepo.insertRecord(const <RssReadRecord>[
      RssReadRecord(record: 'l1', title: 't1', readTime: 10),
      RssReadRecord(record: 'l2', title: 't2', readTime: 20),
    ]);

    expect(await readRepo.countRecords(), 2);
    final records = await readRepo.getRecords();
    expect(records.map((e) => e.record), <String>['l2', 'l1']);

    await readRepo.deleteAllRecord();
    expect(await readRepo.countRecords(), 0);
  });
}
