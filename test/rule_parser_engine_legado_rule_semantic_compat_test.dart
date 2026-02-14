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

  const rowHtml = '''
    <html><body>
      <table>
        <tr id="nr">
          <td><a href="/book/1">书名A</a></td>
          <td>简介A</td>
          <td>作者A</td>
          <td>1000字</td>
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

  group('RuleParserEngine legado semantic compat', () {
    test('supports @CSS: and @@ prefixes', () {
      final doc = html_parser.parse(rowHtml);
      final engine = RuleParserEngine();

      final cssName = engine.debugParseRule(
        doc,
        '@CSS:tr#nr@td.0@text',
        'https://example.com',
      );
      final atName = engine.debugParseRule(
        doc,
        '@@tr#nr@td.0@text',
        'https://example.com',
      );

      expect(cssName, '书名A');
      expect(atName, '书名A');
    });

    test('supports legacy dot syntax with colon list and exclude mode', () {
      final doc = html_parser.parse(
        '<html><body><ul><li>0</li><li>1</li><li>2</li><li>3</li></ul></body></html>',
      );
      final engine = RuleParserEngine();

      final picked = engine.debugParseStringListFromHtml(
        doc,
        'li.-1:1@text',
        'https://example.com',
        false,
      );
      final excluded = engine.debugParseStringListFromHtml(
        doc,
        'li!0:2@text',
        'https://example.com',
        false,
      );

      expect(picked, ['3', '1']);
      expect(excluded, ['1', '3']);
    });

    test('textNodes and ownText follow legacy semantics', () {
      final doc = html_parser.parse(
        '<html><body><div id="c">甲<span>中</span>乙</div></body></html>',
      );
      final engine = RuleParserEngine();

      final textNodes = engine.debugParseRule(
        doc,
        'div#c@textNodes',
        'https://example.com',
      );
      final ownText = engine.debugParseRule(
        doc,
        'div#c@ownText',
        'https://example.com',
      );

      expect(textNodes, '甲\n乙');
      expect(ownText, '甲乙');
    });

    test(
        'html extractor removes script/style and all extractor returns outerHtml',
        () {
      final doc = html_parser.parse(
        '<html><body><div id="c"><script>1</script><style>.a{}</style><p>正文</p></div></body></html>',
      );
      final engine = RuleParserEngine();

      final htmlValue = engine.debugParseRule(
        doc,
        'div#c@html',
        'https://example.com',
      );
      final allValue = engine.debugParseRule(
        doc,
        'div#c@all',
        'https://example.com',
      );

      expect(htmlValue, contains('<p>正文</p>'));
      expect(htmlValue.contains('<script'), isFalse);
      expect(htmlValue.contains('<style'), isFalse);
      expect(allValue.startsWith('<div'), isTrue);
    });

    test('replaceFirst marker keeps legacy first-match behavior', () {
      final doc = html_parser.parse(
        '<html><body><div id="c">ababa</div></body></html>',
      );
      final engine = RuleParserEngine();

      final value = engine.debugParseRule(
        doc,
        'div#c@text##a.##X###',
        'https://example.com',
      );

      expect(value, 'X');
    });

    test('supports legacy children selector prefix', () {
      final doc = html_parser.parse(
        '<html><body><div id="box"><span>A</span><span>B</span><span>C</span></div></body></html>',
      );
      final engine = RuleParserEngine();

      final value = engine.debugParseRule(
        doc,
        'div#box@children.1@text',
        'https://example.com',
      );

      expect(value, 'B');
    });

    test('supports legacy text.xxx selector prefix', () {
      final doc = html_parser.parse(
        '<html><body><div id="box"><p>作者甲</p><p><span>作者乙</span></p><p>其它</p></div></body></html>',
      );
      final engine = RuleParserEngine();

      final values = engine.debugParseStringListFromHtml(
        doc,
        'div#box@text.作者@text',
        'https://example.com',
        false,
      );

      expect(values, ['作者甲', '作者乙']);
    });

    test('single token text/href are treated as current element extractors',
        () {
      final doc = html_parser.parse(
        '<html><body><a id="c" href="/chapter/1">第一章</a></body></html>',
      );
      final element = doc.querySelector('a#c');
      expect(element, isNotNull);
      final engine = RuleParserEngine();

      final textValue = engine.debugParseRule(
        element!,
        'text',
        'https://example.com',
      );
      final hrefValue = engine.debugParseRule(
        element,
        'href',
        'https://example.com',
      );

      expect(textValue, '第一章');
      expect(hrefValue, 'https://example.com/chapter/1');
    });
  });

  group('RuleParserEngine legado semantic compat across stages', () {
    test('search uses @CSS / @@ and legacy dot exclude', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: '@CSS:tr#nr',
          name: '@@td.0@text',
          author: 'td!0:1@text',
          bookUrl: '@CSS:td.0@a@href',
        ),
      );

      final list = await withMockResponses(
        {'https://example.com/search': rowHtml},
        () => engine.search(source, '书名A'),
      );

      expect(list.length, 1);
      expect(list.first.name, '书名A');
      expect(list.first.author, '作者A\n1000字');
    });

    test('search supports legacy text.xxx selector prefix', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'tr#nr',
          name: 'td.0@text',
          author: 'text.作者@text',
          bookUrl: 'td.0@a@href',
        ),
      );

      final list = await withMockResponses(
        {'https://example.com/search': rowHtml},
        () => engine.search(source, '书名A'),
      );

      expect(list.length, 1);
      expect(list.first.author, '作者A');
    });

    test('explore uses @CSS / @@ and legacy dot exclude', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        exploreUrl: 'https://example.com/explore',
        ruleExplore: const ExploreRule(
          bookList: '@CSS:tr#nr',
          name: '@@td.0@text',
          author: 'td!0:1@text',
          bookUrl: '@CSS:td.0@a@href',
        ),
      );

      final list = await withMockResponses(
        {'https://example.com/explore': rowHtml},
        () => engine.explore(source),
      );

      expect(list.length, 1);
      expect(list.first.author, '作者A\n1000字');
    });

    test('bookInfo uses @CSS / @@ prefixes', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleBookInfo: const BookInfoRule(
          init: '@CSS:tr#nr',
          name: '@@td.0@text',
          author: 'td!0:1@text',
          tocUrl: '@CSS:td.0@a@href',
        ),
      );

      final detail = await withMockResponses(
        {'https://example.com/book/1': rowHtml},
        () => engine.getBookInfo(source, '/book/1'),
      );

      expect(detail, isNotNull);
      expect(detail!.name, '书名A');
      expect(detail.author, '作者A\n1000字');
    });

    test('toc stage supports @CSS / @@ and dot index', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: '@CSS:ul#toc li',
          chapterName: '@@a.0@text',
          chapterUrl: '@CSS:a.0@href',
        ),
      );
      const tocHtml = '''
        <html><body>
          <ul id="toc">
            <li><a href="/c1">第一章</a><a href="/ignore-1">x</a></li>
            <li><a href="/c2">第二章</a><a href="/ignore-2">x</a></li>
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

    test('toc stage supports chapterName=text and chapterUrl=href', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: '#list a',
          chapterName: 'text',
          chapterUrl: 'href',
        ),
      );
      const tocHtml = '''
        <html><body>
          <div id="list">
            <a href="/c1">第一章</a>
            <a href="/c2">第二章</a>
          </div>
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

    test('toc stage dedups duplicated chapter urls like legado', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: '#list a',
          chapterName: 'text',
          chapterUrl: 'href',
        ),
      );
      const tocHtml = '''
        <html><body>
          <div id="list">
            <dt>《测试书》最新章节</dt>
            <dd><a href="/c3">第三章</a></dd>
            <dd><a href="/c2">第二章</a></dd>
            <dt>《测试书》正文</dt>
            <dd><a href="/c1">第一章</a></dd>
            <dd><a href="/c2">第二章（正文）</a></dd>
            <dd><a href="/c3">第三章（正文）</a></dd>
          </div>
        </body></html>
      ''';

      final toc = await withMockResponses(
        {'https://example.com/toc': tocHtml},
        () => engine.getToc(source, '/toc'),
      );

      expect(
        toc.map((e) => e.name).toList(),
        ['第一章', '第二章（正文）', '第三章（正文）'],
      );
      expect(
        toc.map((e) => e.url).toList(),
        [
          'https://example.com/c1',
          'https://example.com/c2',
          'https://example.com/c3',
        ],
      );
      expect(toc.map((e) => e.index).toList(), [0, 1, 2]);
    });

    test('toc stage with -chapterList keeps legado reverse/dedup order',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: '-#list a',
          chapterName: 'text',
          chapterUrl: 'href',
        ),
      );
      const tocHtml = '''
        <html><body>
          <div id="list">
            <dt>《测试书》最新章节</dt>
            <dd><a href="/c3">第三章</a></dd>
            <dd><a href="/c2">第二章</a></dd>
            <dt>《测试书》正文</dt>
            <dd><a href="/c1">第一章</a></dd>
            <dd><a href="/c2">第二章（正文）</a></dd>
            <dd><a href="/c3">第三章（正文）</a></dd>
          </div>
        </body></html>
      ''';

      final toc = await withMockResponses(
        {'https://example.com/toc': tocHtml},
        () => engine.getToc(source, '/toc'),
      );

      expect(toc.map((e) => e.name).toList(), ['第一章', '第二章', '第三章']);
      expect(
        toc.map((e) => e.url).toList(),
        [
          'https://example.com/c1',
          'https://example.com/c2',
          'https://example.com/c3',
        ],
      );
      expect(toc.map((e) => e.index).toList(), [0, 1, 2]);
    });

    test('toc debug output keeps same dedup result as toc stage', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          chapterList: '#list a',
          chapterName: 'text',
          chapterUrl: 'href',
        ),
      );
      const tocHtml = '''
        <html><body>
          <div id="list">
            <a href="/c3">第三章</a>
            <a href="/c2">第二章</a>
            <a href="/c1">第一章</a>
            <a href="/c2">第二章（重复）</a>
            <a href="/c3">第三章（重复）</a>
          </div>
        </body></html>
      ''';

      final debug = await withMockResponses(
        {'https://example.com/toc': tocHtml},
        () => engine.getTocDebug(source, '/toc'),
      );

      expect(debug.error, isNull);
      expect(debug.listCount, 5);
      expect(
        debug.toc.map((e) => e.url).toList(),
        [
          'https://example.com/c1',
          'https://example.com/c2',
          'https://example.com/c3',
        ],
      );
      expect(debug.toc.map((e) => e.index).toList(), [0, 1, 2]);
    });

    test('content stage supports textNodes and replaceFirst marker', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          content: '@@div#content@textNodes',
          replaceRegex: '甲.##X##flag',
        ),
      );
      const contentHtml = '''
        <html><body>
          <div id="content">甲一<span>中</span>乙</div>
        </body></html>
      ''';

      final content = await withMockResponses(
        {'https://example.com/chapter/1': contentHtml},
        () => engine.getContent(source, '/chapter/1'),
      );

      expect(content, 'X');
    });
  });
}
