import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const bookRowHtml = '''
    <html><body>
      <table>
        <tr id="nr">
          <td class="odd"><a href="/42/42506/">明克街13号</a></td>
          <td class="even"><a href="/42/42506/32968665.html" target="_blank">新书《捞尸人》，已发布！</a></td>
          <td class="odd">纯洁滴小龙</td>
          <td class="even">9190K</td>
          <td class="odd" align="center">24-09-01</td>
          <td class="even" align="center">连载</td>
        </tr>
      </table>
    </body></html>
  ''';

  Future<T> withMockResponses<T>(
    Map<String, String> responses,
    Future<T> Function() run,
  ) async {
    final dio = RuleParserEngine.debugDioForTest();
    final interceptor = InterceptorsWrapper(
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
    );
    dio.interceptors.add(interceptor);
    try {
      return await run();
    } finally {
      dio.interceptors.remove(interceptor);
    }
  }

  group('RuleParserEngine legado [] index compat', () {
    test('supports td[2]@text for author extraction', () {
      final doc = html_parser.parse(bookRowHtml);
      final engine = RuleParserEngine();

      final author = engine.debugParseRule(
        doc,
        'tr#nr@td[2]@text',
        'https://www.blxs.info',
      );

      expect(author, '纯洁滴小龙');
    });

    test('keeps legacy dot index alias td.2@text', () {
      final doc = html_parser.parse(bookRowHtml);
      final engine = RuleParserEngine();

      final author = engine.debugParseRule(
        doc,
        'tr#nr@td.2@text',
        'https://www.blxs.info',
      );

      expect(author, '纯洁滴小龙');
    });

    test('supports negative index td[-1]@text', () {
      final doc = html_parser.parse(bookRowHtml);
      final engine = RuleParserEngine();

      final status = engine.debugParseRule(
        doc,
        'tr#nr@td[-1]@text',
        'https://www.blxs.info',
      );

      expect(status, '连载');
    });

    test('supports range index td[0:2]@text', () {
      final doc = html_parser.parse(bookRowHtml);
      final engine = RuleParserEngine();

      final values = engine.debugParseStringListFromHtml(
        doc,
        'tr#nr@td[0:2]@text',
        'https://www.blxs.info',
        false,
      );

      expect(values, ['明克街13号', '新书《捞尸人》', '已发布！', '纯洁滴小龙']);
    });

    test('supports exclude mode td[!0,2]@text', () {
      final doc = html_parser.parse(bookRowHtml);
      final engine = RuleParserEngine();

      final values = engine.debugParseStringListFromHtml(
        doc,
        'tr#nr@td[!0,2]@text',
        'https://www.blxs.info',
        false,
      );

      expect(values, ['新书《捞尸人》', '已发布！', '9190K', '24-09-01', '连载']);
    });

    test('single-value text rule merges multi-index results with newline', () {
      final doc = html_parser.parse(bookRowHtml);
      final engine = RuleParserEngine();

      final merged = engine.debugParseRule(
        doc,
        'tr#nr@td[5,4,3]@text',
        'https://www.blxs.info',
      );

      expect(merged, '连载\n24-09-01\n9190K');
    });

    test('supports css attr selector with trailing index', () {
      final doc = html_parser.parse(bookRowHtml);
      final engine = RuleParserEngine();

      final value = engine.debugParseRule(
        doc,
        'tr#nr@td[class=odd][0]@text',
        'https://www.blxs.info',
      );

      expect(value, '明克街13号');
    });

    test('supports index-only step [0] as children selector', () {
      final doc = html_parser.parse(
        '<html><body><div id="box"><span>A</span><span>B</span></div></body></html>',
      );
      final engine = RuleParserEngine();

      final value = engine.debugParseRule(
        doc,
        'div#box@[0]@text',
        'https://example.com',
      );

      expect(value, 'A');
    });
  });

  group('RuleParserEngine legado [] index across stages', () {
    test('search stage supports td[2] author rule', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'tr#nr',
          name: 'td[0]@text',
          author: 'td[2]@text',
          bookUrl: 'td[0]@a@href',
        ),
      );

      final result = await withMockResponses(
        {'https://example.com/search': bookRowHtml},
        () => engine.search(source, '明克街'),
      );

      expect(result.length, 1);
      expect(result.first.author, '纯洁滴小龙');
      expect(result.first.bookUrl, 'https://example.com/42/42506/');
    });

    test('search stage url keeps first candidate for td[1,0]@a@href', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'tr#nr',
          name: 'td[0]@text',
          author: 'td[2]@text',
          bookUrl: 'td[1,0]@a@href',
        ),
      );

      final result = await withMockResponses(
        {'https://example.com/search': bookRowHtml},
        () => engine.search(source, '明克街'),
      );

      expect(result.length, 1);
      expect(
          result.first.bookUrl, 'https://example.com/42/42506/32968665.html');
    });

    test('explore stage supports td[2] author rule', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        exploreUrl: 'https://example.com/explore',
        ruleExplore: const ExploreRule(
          bookList: 'tr#nr',
          name: 'td[0]@text',
          author: 'td[2]@text',
          bookUrl: 'td[0]@a@href',
        ),
      );

      final result = await withMockResponses(
        {'https://example.com/explore': bookRowHtml},
        () => engine.explore(source),
      );

      expect(result.length, 1);
      expect(result.first.author, '纯洁滴小龙');
      expect(result.first.bookUrl, 'https://example.com/42/42506/');
    });

    test('bookInfo stage supports td[2] author rule', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleBookInfo: const BookInfoRule(
          init: 'tr#nr',
          name: 'td[0]@text',
          author: 'td[2]@text',
          tocUrl: 'td[0]@a@href',
        ),
      );

      final detail = await withMockResponses(
        {'https://example.com/book/1': bookRowHtml},
        () => engine.getBookInfo(source, '/book/1'),
      );

      expect(detail, isNotNull);
      expect(detail!.author, '纯洁滴小龙');
      expect(detail.tocUrl, 'https://example.com/42/42506/');
    });

    test('bookInfo stage tocUrl keeps first candidate for td[1,0]@a@href',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleBookInfo: const BookInfoRule(
          init: 'tr#nr',
          name: 'td[0]@text',
          author: 'td[2]@text',
          tocUrl: 'td[1,0]@a@href',
        ),
      );

      final detail = await withMockResponses(
        {'https://example.com/book/1': bookRowHtml},
        () => engine.getBookInfo(source, '/book/1'),
      );

      expect(detail, isNotNull);
      expect(detail!.tocUrl, 'https://example.com/42/42506/32968665.html');
    });

    test('toc stage supports a[0] rules', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: 'ul#toc li',
          chapterName: 'a[0]@text',
          chapterUrl: 'a[0]@href',
        ),
      );
      const tocHtml = '''
        <html><body>
          <ul id="toc">
            <li><a href="/c1">第一章</a><a href="/ignore-1">忽略</a></li>
            <li><a href="/c2">第二章</a><a href="/ignore-2">忽略</a></li>
          </ul>
        </body></html>
      ''';

      final toc = await withMockResponses(
        {'https://example.com/toc': tocHtml},
        () => engine.getToc(source, '/toc'),
      );

      expect(toc.map((e) => e.name).toList(), ['第一章', '第二章']);
      expect(
        toc.map((e) => e.url).toList(),
        ['https://example.com/c1', 'https://example.com/c2'],
      );
    });

    test('toc stage chapterUrl keeps first non-empty candidate', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: 'ul#toc li',
          chapterName: 'a[1]@text',
          chapterUrl: 'a[0,1]@href',
        ),
      );
      const tocHtml = '''
        <html><body>
          <ul id="toc">
            <li><a href="">忽略</a><a href="/c1">第一章</a></li>
            <li><a>空链接</a><a href="/c2">第二章</a></li>
          </ul>
        </body></html>
      ''';

      final toc = await withMockResponses(
        {'https://example.com/toc': tocHtml},
        () => engine.getToc(source, '/toc'),
      );

      expect(toc.map((e) => e.name).toList(), ['第一章', '第二章']);
      expect(
        toc.map((e) => e.url).toList(),
        ['https://example.com/c1', 'https://example.com/c2'],
      );
    });

    test('content stage supports p[0] rule', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          content: 'div#content@p[0]@text',
        ),
      );
      const contentHtml = '''
        <html><body>
          <div id="content">
            <p>正文A</p>
            <p>附注</p>
          </div>
        </body></html>
      ''';

      final content = await withMockResponses(
        {'https://example.com/chapter/1': contentHtml},
        () => engine.getContent(source, '/chapter/1'),
      );

      expect(content, '正文A');
    });
  });
}
