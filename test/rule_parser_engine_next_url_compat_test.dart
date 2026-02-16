import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('RuleParserEngine next url compat', () {
    test('nextTocUrl supports || fallback on html rules', () {
      final doc = html_parser.parse('''
        <html><body>
          <a class="no-next" href="">none</a>
          <a class="next" href="/toc?page=2">next</a>
        </body></html>
      ''');
      final engine = RuleParserEngine();

      final nextList = engine.debugParseStringListFromHtml(
        doc,
        'a.no-next@href||a.next@href',
        'https://example.com/book/1',
        true,
      );

      expect(nextList, ['https://example.com/toc?page=2']);
    });

    test('nextContentUrl supports || fallback on json rules', () {
      final engine = RuleParserEngine();
      final json = {
        'next': '',
        'paging': {'next': '/chapter/1?page=2'}
      };

      final nextList = engine.debugParseStringListFromJson(
        json,
        r'@Json:$.next||@Json:$.paging.next',
        'https://example.com/chapter/1',
        true,
      );

      expect(nextList, ['https://example.com/chapter/1?page=2']);
    });

    test('pick next candidate skips current visited and hash-only diff', () {
      final engine = RuleParserEngine();

      final picked = engine.debugPickNextUrlCandidateForTest(
        const [
          '#footer',
          '/chapter/1?page=2#top',
          '/chapter/1?page=2#middle',
          '/chapter/1?page=3',
        ],
        currentUrl: 'https://example.com/chapter/1?page=1',
        visitedUrls: {
          'https://example.com/chapter/1?page=1',
          'https://example.com/chapter/1?page=2',
        },
      );

      expect(picked, 'https://example.com/chapter/1?page=3');
    });

    test('pick next candidate supports blocked nextChapterUrl key', () {
      final engine = RuleParserEngine();

      final picked = engine.debugPickNextUrlCandidateForTest(
        const [
          '/chapter/2',
          '/chapter/1?page=2',
        ],
        currentUrl: 'https://example.com/chapter/1?page=1',
        visitedUrls: {
          'https://example.com/chapter/1?page=1',
        },
        blockedUrl: 'https://example.com/chapter/2',
      );

      expect(picked, 'https://example.com/chapter/1?page=2');
    });

    test('candidate debug lines include enqueue and skip reasons', () {
      final engine = RuleParserEngine();

      final result = engine.debugCollectNextUrlCandidatesWithDebugForTest(
        const [
          '',
          '/chapter/1?page=1',
          '/chapter/1?page=2',
          '/chapter/2',
          '/chapter/1?page=2#top',
          '/chapter/1?page=3',
        ],
        currentUrl: 'https://example.com/chapter/1?page=1',
        visitedUrls: {
          'https://example.com/chapter/1?page=2',
        },
        queuedUrls: {
          'https://example.com/chapter/1?page=3',
        },
        blockedUrl: 'https://example.com/chapter/2',
      );

      expect(result.urls, isEmpty);
      expect(result.hasBlockedCandidate, isTrue);
      expect(
        result.debugLines.any((line) => line.contains('跳过：空值')),
        isTrue,
      );
      expect(
        result.debugLines.any((line) => line.contains('跳过：当前页')),
        isTrue,
      );
      expect(
        result.debugLines.any((line) => line.contains('跳过：已访问')),
        isTrue,
      );
      expect(
        result.debugLines.any((line) => line.contains('跳过：命中下一章')),
        isTrue,
      );
      expect(
        result.debugLines.any((line) => line.contains('跳过：本批重复')),
        isTrue,
      );
      expect(
        result.debugLines.any((line) => line.contains('跳过：已在队列')),
        isTrue,
      );
      expect(
        result.debugLines.last.contains('汇总：新增 0 条'),
        isTrue,
      );
    });

    test('content paging stops when next candidate equals nextChapterUrl',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          content: 'div#content@text',
          nextContentUrl: 'a.next@href',
        ),
      );

      final responses = <String, String>{
        'https://example.com/chapter/1':
            '<html><body><div id="content">第一页</div><a class="next" href="/chapter/2">next</a></body></html>',
      };

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final content = await engine.getContent(
          source,
          '/chapter/1',
          nextChapterUrl: '/chapter/2',
        );
        expect(content, '第一页');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('content paging consumes multiple next candidates in order', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          content: 'div#content@text',
          nextContentUrl: 'a.next@href',
        ),
      );

      final responses = <String, String>{
        'https://example.com/chapter/1':
            '<html><body><div id="content">P1</div><a class="next" href="/chapter/1?page=2">n2</a><a class="next" href="/chapter/1?page=3">n3</a></body></html>',
        'https://example.com/chapter/1?page=2':
            '<html><body><div id="content">P2</div></body></html>',
        'https://example.com/chapter/1?page=3':
            '<html><body><div id="content">P3</div></body></html>',
      };

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final content = await engine.getContent(source, '/chapter/1');
        expect(content, 'P1\nP2\nP3');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('toc paging consumes multiple next candidates in order', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: '.item',
          chapterName: '.name@text',
          chapterUrl: '.name@href',
          nextTocUrl: 'a.next@href',
        ),
      );

      final responses = <String, String>{
        'https://example.com/toc':
            '<html><body><div class="item"><a class="name" href="/c1">C1</a></div><a class="next" href="/toc?page=2">n2</a><a class="next" href="/toc?page=3">n3</a></body></html>',
        'https://example.com/toc?page=2':
            '<html><body><div class="item"><a class="name" href="/c2">C2</a></div></body></html>',
        'https://example.com/toc?page=3':
            '<html><body><div class="item"><a class="name" href="/c3">C3</a></div></body></html>',
      };

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final toc = await engine.getToc(source, '/toc');
        expect(toc.map((e) => e.name).toList(), ['C1', 'C2', 'C3']);
        expect(
          toc.map((e) => e.url).toList(),
          [
            'https://example.com/c1',
            'https://example.com/c2',
            'https://example.com/c3'
          ],
        );
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('toc keeps volume/vip/pay/tag and applies chapterUrl fallback',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: '.item',
          chapterName: '.name@text',
          chapterUrl: '.name@href',
          updateTime: '.tag@text',
          isVolume: '.is-volume@text',
          isVip: '.is-vip@text',
          isPay: '.is-pay@text',
        ),
      );

      final responses = <String, String>{
        'https://example.com/toc': '''
          <html><body>
            <div class="item">
              <a class="name">卷一</a>
              <span class="tag">分卷</span>
              <span class="is-volume">true</span>
              <span class="is-vip">false</span>
              <span class="is-pay">0</span>
            </div>
            <div class="item">
              <a class="name">第一章</a>
              <span class="tag">正文</span>
              <span class="is-volume">false</span>
              <span class="is-vip">1</span>
              <span class="is-pay">yes</span>
            </div>
          </body></html>
        ''',
      };

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final toc = await engine.getToc(source, '/toc');
        expect(toc.length, 2);
        expect(toc[0].name, '卷一');
        expect(toc[0].url, '卷一0');
        expect(toc[0].isVolume, isTrue);
        expect(toc[0].isVip, isFalse);
        expect(toc[0].isPay, isFalse);
        expect(toc[0].tag, '分卷');

        expect(toc[1].name, '第一章');
        expect(toc[1].url, 'https://example.com/toc');
        expect(toc[1].isVolume, isFalse);
        expect(toc[1].isVip, isTrue);
        expect(toc[1].isPay, isTrue);
        expect(toc[1].tag, '正文');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('toc paging is not limited by legacy temporary cap (12)', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: '.item',
          chapterName: '.name@text',
          chapterUrl: '.name@href',
          nextTocUrl: 'a.next@href',
        ),
      );

      final responses = <String, String>{};
      for (var i = 1; i <= 13; i++) {
        final url = i == 1
            ? 'https://example.com/toc'
            : 'https://example.com/toc?page=$i';
        final next =
            i < 13 ? '<a class="next" href="/toc?page=${i + 1}">n</a>' : '';
        responses[url] =
            '<html><body><div class="item"><a class="name" href="/c$i">C$i</a></div>$next</body></html>';
      }

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final toc = await engine.getToc(source, '/toc');
        expect(toc.length, 13);
        expect(toc.last.name, 'C13');
        expect(toc.last.url, 'https://example.com/c13');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('content paging is not limited by legacy temporary cap (8)', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          content: 'div#content@text',
          nextContentUrl: 'a.next@href',
        ),
      );

      final responses = <String, String>{};
      for (var i = 1; i <= 9; i++) {
        final url = i == 1
            ? 'https://example.com/chapter/1'
            : 'https://example.com/chapter/1?page=$i';
        final next = i < 9
            ? '<a class="next" href="/chapter/1?page=${i + 1}">n</a>'
            : '';
        responses[url] =
            '<html><body><div id="content">P$i</div>$next</body></html>';
      }

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final content = await engine.getContent(source, '/chapter/1');
        expect(content, 'P1\nP2\nP3\nP4\nP5\nP6\nP7\nP8\nP9');
      } finally {
        dio.interceptors.removeLast();
      }
    });
  });
}
