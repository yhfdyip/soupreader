import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  group('RuleParserEngine top-level split compat', () {
    test('does not split || inside regex expression', () {
      final doc = html_parser.parse(
        '<div>AB||CD</div>',
      );
      final engine = RuleParserEngine();

      final result = engine.debugParseRule(
        doc,
        r':AB\|\|CD',
        'https://example.com/book',
      );

      expect(result, 'AB||CD');
    });

    test('supports fallback || with selector extractors', () {
      final doc = html_parser.parse(
        '<div><p class="title">章节一</p></div>',
      );
      final engine = RuleParserEngine();

      final result = engine.debugParseRule(
        doc,
        'h1@text||p.title@text',
        'https://example.com/book',
      );

      expect(result, '章节一');
    });

    test('supports && merge for text rules', () {
      final doc = html_parser.parse(
        '<div><h1>标题</h1><p class="author">作者</p></div>',
      );
      final engine = RuleParserEngine();

      final result = engine.debugParseRule(
        doc,
        'h1@text&&p.author@text',
        'https://example.com/book',
      );

      expect(result, '标题\n作者');
    });

    test('supports %% interleave for list extraction', () {
      final doc = html_parser.parse(
        '<div><a href="/1">A1</a><a href="/2">A2</a></div>',
      );
      final engine = RuleParserEngine();

      final result = engine.debugParseStringListFromHtml(
        doc,
        'a@text%%a@href',
        'https://example.com/book',
        false,
      );

      expect(result, [
        'A1',
        'https://example.com/1',
        'A2',
        'https://example.com/2',
      ]);
    });

    test('does not split || inside jsonpath filter expression', () {
      final engine = RuleParserEngine();
      final json = {
        'items': [
          {'name': 'A', 'kind': 'x'},
          {'name': 'B', 'kind': 'y'},
        ],
      };

      final result = engine.debugParseStringListFromJson(
        json,
        r'@Json:$.items[?(@.kind=="x"||@.kind=="y")].name',
        'https://example.com/book',
        false,
      );

      expect(result, ['A', 'B']);
    });
  });
}
