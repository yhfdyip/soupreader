import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  group('RuleParserEngine variable rule compat', () {
    test('@put stores variable and @get reads it', () {
      final doc = html_parser.parse(
        '<div><span class="name">张三</span><h1>标题</h1></div>',
      );
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final result = engine.debugParseRule(
        doc,
        '@put:{"who":"span.name@text"}h1@text&&@get:{who}',
        'https://example.com/book',
      );

      expect(result, '标题\n张三');
      expect(engine.debugGetRuntimeVariable('who'), '张三');
    });

    test('{{js}} can read @get variable through vars binding', () {
      final doc = html_parser.parse(
        '<div><span class="name">李四</span></div>',
      );
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final result = engine.debugParseRule(
        doc,
        '@put:{"who":"span.name@text"}{{vars["who"] + "-ok"}}',
        'https://example.com/book',
      );

      expect(result, '李四-ok');
    });

    test('@put works on json nodes and can be reused', () {
      final json = {
        'book': {
          'name': '测试书',
          'author': '作者A',
        },
      };
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();

      final result = engine.debugParseStringListFromJson(
        json,
        '@put:{"authorName":"@Json:\$.book.author"}@Json:\$.book.name&&@get:{authorName}',
        'https://example.com/book',
        false,
      );

      expect(result, ['测试书', '作者A']);
      expect(engine.debugGetRuntimeVariable('authorName'), '作者A');
    });

    test('@get can be used in URL template placeholders', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();
      engine.debugPutRuntimeVariable('k', '中文 空格');

      final url = engine.debugBuildUrlForTest(
        'https://example.com',
        '/search?key={{k}}',
        const {},
      );

      expect(url,
          'https://example.com/search?key=%E4%B8%AD%E6%96%87%20%E7%A9%BA%E6%A0%BC');
    });

    test('runtime variable snapshot supports desensitized export', () {
      final engine = RuleParserEngine();
      engine.debugClearRuntimeVariables();
      engine.debugPutRuntimeVariable('token', 'abcdef123456');
      engine.debugPutRuntimeVariable('kw', '玄幻');

      final masked = engine.debugRuntimeVariablesSnapshot();
      final raw = engine.debugRuntimeVariablesSnapshot(desensitize: false);

      expect(raw['token'], 'abcdef123456');
      expect(raw['kw'], '玄幻');
      expect(masked['token'], isNot('abcdef123456'));
      expect(masked['token']!.endsWith('56'), isTrue);
      expect(masked['kw'], isNot('玄幻'));
      expect(masked['kw'], '**');
    });
  });
}
