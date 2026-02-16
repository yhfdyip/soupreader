import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

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
            error: 'missing mock for \\${options.uri}',
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

  const detailHtml = '''
    <html><body>
      <h1>详情书名</h1>
      <span class="author">作者甲</span>
      <img class="cover" src="/cover.jpg" />
      <div class="intro">这是简介</div>
      <span class="kind">玄幻</span>
      <a class="last">第10章</a>
      <span class="time">2026-02-15</span>
      <span class="words">12万</span>
    </body></html>
  ''';

  group('RuleParserEngine book list parity', () {
    test('search uses bookUrlPattern and parses as detail page', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        bookUrlPattern: r'https://example.com/book/\d+',
        searchUrl: 'https://example.com/book/1',
        ruleSearch: const SearchRule(
          bookList: 'li',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
        ruleBookInfo: const BookInfoRule(
          name: 'h1@text',
          author: '.author@text',
          coverUrl: '.cover@src',
          intro: '.intro@text',
          kind: '.kind@text',
          lastChapter: '.last@text',
          updateTime: '.time@text',
          wordCount: '.words@text',
        ),
      );

      final results = await withMockResponses(
        {'https://example.com/book/1': detailHtml},
        () => engine.search(source, 'k'),
      );

      expect(results.length, 1);
      expect(results.first.name, '详情书名');
      expect(results.first.author, '作者甲');
      expect(results.first.coverUrl, 'https://example.com/cover.jpg');
      expect(results.first.bookUrl, 'https://example.com/book/1');
    });

    test('bookUrlPattern follows full-string match semantics', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        // 对标 Kotlin String.matches：该模式只能匹配完整字符串，不应匹配 URL 子串。
        bookUrlPattern: r'book/\d+',
        searchUrl: 'https://example.com/book/1',
        ruleSearch: const SearchRule(
          bookList: 'li',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
      );

      const html = '''
        <html><body><ul>
          <li><a href="/x">列表书</a></li>
        </ul></body></html>
      ''';

      final results = await withMockResponses(
        {'https://example.com/book/1': html},
        () => engine.search(source, 'k'),
      );

      expect(results.length, 1);
      expect(results.first.name, '列表书');
      expect(results.first.bookUrl, 'https://example.com/x');
    });

    test('search falls back to detail parse when list empty and no pattern',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li.item',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
        ruleBookInfo: const BookInfoRule(
          name: 'h1@text',
          author: '.author@text',
        ),
      );

      final results = await withMockResponses(
        {'https://example.com/search': detailHtml},
        () => engine.search(source, 'k'),
      );

      expect(results.length, 1);
      expect(results.first.name, '详情书名');
      expect(results.first.author, '作者甲');
      expect(results.first.bookUrl, 'https://example.com/search');
    });

    test('search list item with empty bookUrl falls back to baseUrl', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
      );

      const html = '<html><body><ul><li><a>第一本</a></li></ul></body></html>';
      final results = await withMockResponses(
        {'https://example.com/search': html},
        () => engine.search(source, 'k'),
      );

      expect(results.length, 1);
      expect(results.first.name, '第一本');
      expect(results.first.bookUrl, 'https://example.com/search');
    });

    test('explore falls back to search rule when explore bookList is blank',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        exploreUrl: 'https://example.com/explore',
        ruleExplore: const ExploreRule(bookList: ''),
        ruleSearch: const SearchRule(
          bookList: 'li',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
      );

      const html =
          '<html><body><ul><li><a href="/book/1">发现一本</a></li></ul></body></html>';
      final results = await withMockResponses(
        {'https://example.com/explore': html},
        () => engine.explore(source),
      );

      expect(results.length, 1);
      expect(results.first.name, '发现一本');
      expect(results.first.bookUrl, 'https://example.com/book/1');
    });

    test('book list supports legacy reverse prefix', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: '-li',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
      );

      const html = '''
        <html><body><ul>
          <li><a href="/a">A</a></li>
          <li><a href="/b">B</a></li>
        </ul></body></html>
      ''';

      final results = await withMockResponses(
        {'https://example.com/search': html},
        () => engine.search(source, 'k'),
      );

      expect(results.map((e) => e.name).toList(), ['B', 'A']);
      expect(
        results.map((e) => e.bookUrl).toList(),
        ['https://example.com/b', 'https://example.com/a'],
      );
    });

    test('book list dedups by bookUrl like legado SearchBook equals', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li',
          name: 'a@text',
          author: '.author@text',
          bookUrl: 'a@href',
        ),
      );

      const html = '''
        <html><body><ul>
          <li><a href="/same">A</a><span class="author">甲</span></li>
          <li><a href="/same">B</a><span class="author">乙</span></li>
          <li><a href="/other">C</a><span class="author">丙</span></li>
        </ul></body></html>
      ''';

      final results = await withMockResponses(
        {'https://example.com/search': html},
        () => engine.search(source, 'k'),
      );

      expect(results.length, 2);
      expect(results.map((e) => e.name).toList(), ['A', 'C']);
      expect(
        results.map((e) => e.bookUrl).toList(),
        ['https://example.com/same', 'https://example.com/other'],
      );
    });

    test('search filter applies before collecting list items', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li',
          name: 'a@text',
          author: '.author@text',
          bookUrl: 'a@href',
        ),
      );

      const html = '''
        <html><body><ul>
          <li><a href="/a">A</a><span class="author">甲</span></li>
          <li><a href="/b">B</a><span class="author">乙</span></li>
          <li><a href="/c">C</a><span class="author">丙</span></li>
        </ul></body></html>
      ''';

      final results = await withMockResponses(
        {'https://example.com/search': html},
        () => engine.search(
          source,
          'k',
          filter: (name, author) => name == 'B' && author == '乙',
        ),
      );

      expect(results.length, 1);
      expect(results.first.name, 'B');
      expect(results.first.author, '乙');
      expect(results.first.bookUrl, 'https://example.com/b');
    });

    test('search shouldBreak stops list parsing early', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
      );

      const html = '''
        <html><body><ul>
          <li><a href="/1">一</a></li>
          <li><a href="/2">二</a></li>
          <li><a href="/3">三</a></li>
        </ul></body></html>
      ''';

      final results = await withMockResponses(
        {'https://example.com/search': html},
        () => engine.search(
          source,
          'k',
          shouldBreak: (size) => size >= 1,
        ),
      );

      expect(results.length, 1);
      expect(results.first.name, '一');
      expect(results.first.bookUrl, 'https://example.com/1');
    });

    test('detail fallback respects search filter', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li.item',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
        ruleBookInfo: const BookInfoRule(
          name: 'h1@text',
          author: '.author@text',
        ),
      );

      final blocked = await withMockResponses(
        {'https://example.com/search': detailHtml},
        () => engine.search(
          source,
          'k',
          filter: (_, __) => false,
        ),
      );
      expect(blocked, isEmpty);

      final allowed = await withMockResponses(
        {'https://example.com/search': detailHtml},
        () => engine.search(
          source,
          'k',
          filter: (name, author) => name == '详情书名' && author == '作者甲',
        ),
      );
      expect(allowed.length, 1);
      expect(allowed.first.name, '详情书名');
      expect(allowed.first.author, '作者甲');
    });

    test('searchDebug follows same detail fallback semantics', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li.item',
          name: 'a@text',
          bookUrl: 'a@href',
        ),
        ruleBookInfo: const BookInfoRule(
          name: 'h1@text',
          author: '.author@text',
        ),
      );

      final result = await withMockResponses(
        {'https://example.com/search': detailHtml},
        () => engine.searchDebug(source, 'k'),
      );

      expect(result.error, isNull);
      expect(result.listCount, 0);
      expect(result.results.length, 1);
      expect(result.results.first.name, '详情书名');
    });

    test('search list fields apply legacy format semantics', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        searchUrl: 'https://example.com/search',
        ruleSearch: const SearchRule(
          bookList: 'li.item',
          name: 'a@text',
          author: '.author@text',
          intro: '.intro@html',
          kind: '.kind@text',
          wordCount: '.words@text',
          bookUrl: 'a@href',
        ),
      );

      const html = '''
        <html><body><ul>
          <li class="item">
            <a href="/book/1">书名A 作者王五</a>
            <span class="author">作者：王五 著</span>
            <div class="intro"><p>第一段</p><p>第二段</p></div>
            <span class="kind">玄幻</span>
            <span class="kind">连载</span>
            <span class="words">12001</span>
          </li>
        </ul></body></html>
      ''';

      final results = await withMockResponses(
        {'https://example.com/search': html},
        () => engine.search(source, 'k'),
      );

      expect(results.length, 1);
      expect(results.first.name, '书名A');
      expect(results.first.author, '王五');
      expect(results.first.kind, '玄幻,连载');
      expect(results.first.wordCount, '1.2万字');
      expect(results.first.intro, '第一段\n第二段');
    });

    test('bookInfo fields apply legacy format semantics', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleBookInfo: const BookInfoRule(
          name: 'h1@text',
          author: '.author@text',
          intro: '.intro@html',
          kind: '.kind@text',
          wordCount: '.words@text',
          tocUrl: 'a.toc@href',
        ),
      );

      const html = '''
        <html><body>
          <h1>书名B 作者赵六</h1>
          <span class="author">作者: 赵六 著</span>
          <div class="intro"><p>简介甲</p><p>简介乙</p></div>
          <span class="kind">仙侠</span>
          <span class="kind">完结</span>
          <span class="words">9999</span>
          <a class="toc" href="/toc/1">目录</a>
        </body></html>
      ''';

      final detail = await withMockResponses(
        {'https://example.com/book/1': html},
        () => engine.getBookInfo(source, '/book/1'),
      );

      expect(detail, isNotNull);
      expect(detail!.name, '书名B');
      expect(detail.author, '赵六');
      expect(detail.kind, '仙侠,完结');
      expect(detail.wordCount, '9999字');
      expect(detail.intro, '简介甲\n简介乙');
      expect(detail.tocUrl, 'https://example.com/toc/1');
    });

    test('bookInfo empty tocUrl falls back to request url on redirect',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleBookInfo: const BookInfoRule(
          name: 'h1@text',
          tocUrl: 'a.toc@href',
        ),
      );

      const html = '<html><body><h1>详情名</h1></body></html>';
      final dio = RuleParserEngine.debugDioForTest();
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.toString() == 'https://example.com/book/1') {
            handler.resolve(
              Response<List<int>>(
                requestOptions: options,
                data: utf8.encode(html),
                statusCode: 200,
                isRedirect: true,
                redirects: <RedirectRecord>[
                  RedirectRecord(
                    302,
                    'GET',
                    Uri.parse('https://example.com/final/landing'),
                  ),
                ],
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
        final detail = await engine.getBookInfo(source, '/book/1');
        expect(detail, isNotNull);
        expect(detail!.tocUrl, 'https://example.com/book/1');

        final debug = await engine.getBookInfoDebug(source, '/book/1');
        expect(debug.error, isNull);
        expect(debug.detail, isNotNull);
        expect(debug.detail!.tocUrl, 'https://example.com/book/1');
      } finally {
        dio.interceptors.remove(interceptor);
      }
    });
  });
}
