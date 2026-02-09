import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  group('RuleParserEngine URL option compat', () {
    test('supports url option split with whitespace after comma', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search?q={{key}}, {"method":"POST","body":"a=1"}',
        const {'key': '测试'},
      );

      expect(
        resolved.url,
        'https://example.com/search?q=%E6%B5%8B%E8%AF%95',
      );
      expect(resolved.method, 'POST');
      expect(resolved.body, 'a=1');
      expect(resolved.methodDecision, '使用 urlOption.method=POST');
    });

    test('supports @get in URL option body and headers', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();
      engine.debugPutRuntimeVariable('kw', '玄幻');
      engine.debugPutRuntimeVariable('token', 'abc123');

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search, {"method":"POST","body":"k=@get:{kw}","headers":{"X-Token":"@get:{token}"}}',
        const {},
      );

      expect(resolved.method, 'POST');
      expect(resolved.body, 'k=%E7%8E%84%E5%B9%BB');
      expect(resolved.headers['X-Token'], 'abc123');
    });

    test('supports {{vars[...]}} in URL option body and headers', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();
      engine.debugPutRuntimeVariable('kw', '仙侠');
      engine.debugPutRuntimeVariable('token', 'Bearer X');

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search, {"method":"POST","body":"k={{vars["kw"]}}","headers":{"Authorization":"{{vars["token"]}}"}}',
        const {},
      );

      expect(resolved.method, 'POST');
      expect(resolved.body, 'k=%E4%BB%99%E4%BE%A0');
      expect(resolved.headers['Authorization'], 'Bearer X');
    });

    test('url option js can patch url and header', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search, {"js":"java.url = java.url + \'&p=2\'; java.headerMap.put(\'X-From\', \'js\');"}',
        const {},
      );

      expect(resolved.url, 'https://example.com/search&p=2');
      expect(resolved.headers['X-From'], 'js');
    });

    test('charset=gbk encodes query params for GET url', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search?k=中文, {"charset":"gbk"}',
        const {},
      );

      expect(resolved.url, 'https://example.com/search?k=%D6%D0%CE%C4');
      expect(resolved.method, 'GET');
    });

    test('charset=gbk encodes x-www-form-urlencoded POST body', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search, {"method":"POST","charset":"gbk","body":"k=中文"}',
        const {},
      );

      expect(resolved.method, 'POST');
      expect(resolved.body, 'k=%D6%D0%CE%C4');
      expect(
        resolved.headers['Content-Type'],
        'application/x-www-form-urlencoded; charset=GBK',
      );
    });

    test('json body keeps raw text without forced form encoding', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search, {"method":"POST","charset":"gbk","body":{"k":"中文"}}',
        const {},
      );

      expect(resolved.method, 'POST');
      expect(resolved.body, '{"k":"中文"}');
      expect(resolved.bodyEncoding, 'json');
      expect(resolved.bodyDecision, contains('识别为 JSON'));
    });

    test('exposes retry from url option', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search, {"method":"POST","retry":2,"body":"k=1"}',
        const {},
      );

      expect(resolved.method, 'POST');
      expect(resolved.body, 'k=1');
      expect(resolved.retry, 2);
      expect(resolved.retryDecision, 'urlOption.retry=2');
    });

    test('negative retry is normalized to zero', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search, {"method":"POST","retry":-3,"body":"k=1"}',
        const {},
      );

      expect(resolved.retry, 0);
      expect(resolved.retryDecision, contains('非法负值'));
    });

    test('charset=escape follows legacy %u style', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search?k=中文 空格, {"charset":"escape"}',
        const {},
      );

      expect(resolved.url,
          'https://example.com/search?k=%u4e2d%u6587%20%u7a7a%u683c');
      expect(resolved.requestCharsetDecision, '请求参数按 legacy escape 编码');
    });

    test('already encoded query is kept when charset is empty', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search?k=%E4%B8%AD%E6%96%87',
        const {},
      );

      expect(resolved.url, 'https://example.com/search?k=%E4%B8%AD%E6%96%87');
    });

    test('supports <js> chain with @result', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();
      final built = engine.debugBuildUrlForTest(
        'https://example.com',
        '/search?kw=abc<js>"@result" + "&p=1"</js>',
        const {},
      );

      expect(built, 'https://example.com/search?kw=abc&p=1');
    });

    test('supports @js at end and can read params binding', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();
      final built = engine.debugBuildUrlForTest(
        'https://example.com',
        '/search?kw={{key}}@js: "@result" + "&p=" + page',
        const {'key': '玄幻', 'page': '2'},
      );

      expect(built, 'https://example.com/search?kw=%E7%8E%84%E5%B9%BB&p=2');
    });

    test('supports jsLib in @js URL segment', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();
      final built = engine.debugBuildUrlForTest(
        'https://example.com',
        '/search?kw={{key}}@js: joinUrl(result, page)',
        const {'key': '玄幻', 'page': '3'},
        jsLib: 'function joinUrl(url, page){ return url + "&p=" + page; }',
      );

      expect(built, 'https://example.com/search?kw=%E7%8E%84%E5%B9%BB&p=3');
    });

    test('supports jsLib in URL option body template js', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final resolved = engine.debugResolveRequestForTest(
        'https://example.com',
        '/search, {"method":"POST","body":"k={{makeKeyword()}}"}',
        const {},
        jsLib: 'function makeKeyword(){ return "仙侠"; }',
      );

      expect(resolved.method, 'POST');
      expect(resolved.body, 'k=%E4%BB%99%E4%BE%A0');
    });
  });
}
