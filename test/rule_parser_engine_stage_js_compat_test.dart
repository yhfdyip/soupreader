import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('RuleParserEngine stage js compat', () {
    test('ruleToc.preUpdateJs 仅前置执行，不改写目录响应体', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          preUpdateJs:
              'result = JSON.stringify({list:[{name:"X",url:"/x"}]}); result',
          chapterList: 'ul#toc li',
          chapterName: 'a@text',
          chapterUrl: 'a@href',
        ),
      );

      final responses = <String, String>{
        'https://example.com/toc':
            '<html><body><ul id="toc"><li><a href="/c1">C1</a></li></ul></body></html>',
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
        expect(toc.map((e) => e.name).toList(), ['C1']);
        expect(toc.map((e) => e.url).toList(), ['https://example.com/c1']);
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('loginCheckJs 在搜索阶段生效', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        loginCheckJs:
            'result = "<html><body><ul><li><a href=\\"/book/1\\">新书名</a></li></ul></body></html>"; result',
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
      );

      final responses = <String, String>{
        'https://example.com/search':
            '<html><body><ul><li><a href="/book/1">旧书名</a></li></ul></body></html>',
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
        final list = await engine.search(source, 'k');
        expect(list, isNotEmpty);
        expect(list.first.name, '新书名');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('loginCheckJs 在发现/详情/目录阶段生效', () async {
      final engine = RuleParserEngine();
      final exploreSource = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        loginCheckJs:
            'result = "<html><body><ul><li><a href=\\"/book/1\\">新发现</a></li></ul></body></html>"; result',
        exploreUrl: 'https://example.com/explore',
        ruleExplore: const ExploreRule(
          bookList: 'li',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
      );
      final infoSource = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        loginCheckJs:
            'result = "<html><body><h1>新详情</h1><a class=\\"toc\\" href=\\"/toc\\">toc</a></body></html>"; result',
        ruleBookInfo: const BookInfoRule(
          name: 'h1@text',
          tocUrl: 'a.toc@href',
        ),
      );
      final tocSource = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        loginCheckJs:
            'result = "<html><body><ul><li><a href=\\"/c1\\">新章节</a></li></ul></body></html>"; result',
        ruleToc: const TocRule(
          chapterList: 'li',
          chapterName: 'a@text',
          chapterUrl: 'a@href',
        ),
      );

      final responses = <String, String>{
        'https://example.com/explore':
            '<html><body><ul><li><a href="/book/1">旧发现</a></li></ul></body></html>',
        'https://example.com/book/1':
            '<html><body><h1>旧详情</h1><a class="toc" href="/toc">toc</a></body></html>',
        'https://example.com/toc':
            '<html><body><ul><li><a href="/c1">旧章节</a></li></ul></body></html>',
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
        final explore = await engine.explore(exploreSource);
        expect(explore, isNotEmpty);
        expect(explore.first.name, '新发现');

        final detail = await engine.getBookInfo(infoSource, '/book/1');
        expect(detail, isNotNull);
        expect(detail!.name, '新详情');

        final toc = await engine.getToc(tocSource, '/toc');
        expect(toc, isNotEmpty);
        expect(toc.first.name, '新章节');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('loginCheckJs 在正文阶段生效（含调试接口）', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        loginCheckJs:
            'result = "<html><body><div id=\\"content\\">新正文</div></body></html>"; result',
        ruleContent: const ContentRule(
          content: 'div#content@text',
        ),
      );

      final responses = <String, String>{
        'https://example.com/chapter/1':
            '<html><body><div id="content">旧正文</div></body></html>',
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
        expect(content, '新正文');

        final debug = await engine.getContentDebug(source, '/chapter/1');
        expect(debug.error, isNull);
        expect(debug.content, '新正文');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('正文清洗保留图片标签并绝对化 src（对齐 legado formatKeepImg）', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          content: 'div#content@html',
        ),
      );

      final responses = <String, String>{
        'https://example.com/chapter/1':
            '<html><body><div id="content"><p>前<img src="/a.jpg"/></p></div></body></html>',
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
        expect(content, contains('前'));
        expect(content, contains('<img src="https://example.com/a.jpg">'));
        expect(content, isNot(contains('<p>')));
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('正文规则为空时返回章节链接', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(content: ''),
      );

      final content = await engine.getContent(source, '/chapter/1');
      expect(content, '/chapter/1');

      final debug = await engine.getContentDebug(source, '/chapter/1');
      expect(debug.error, isNull);
      expect(debug.content, '/chapter/1');
    });

    test('ruleContent.webJs rewrites response before content extraction',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          webJs: 'result = JSON.stringify({content:"正文A"}); result',
          content: r'@Json:$.content',
        ),
      );

      final responses = <String, String>{
        'https://example.com/chapter/1':
            '<html><body><div id="content">old</div></body></html>',
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
        expect(content, '正文A');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('ruleContent.replaceRegex keeps later rules when one is invalid',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          content: 'div#content@text',
          // 第二条正则非法；第三条应继续生效。
          replaceRegex: r'第##D##(坏正则##X##章##Z',
        ),
      );

      final responses = <String, String>{
        'https://example.com/chapter/1':
            '<html><body><div id="content">第1章</div></body></html>',
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
        expect(content, 'D1Z');
      } finally {
        dio.interceptors.removeLast();
      }
    });
  });
}
