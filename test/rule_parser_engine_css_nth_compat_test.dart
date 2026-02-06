import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  group('RuleParserEngine CSS nth compat', () {
    test('nth-child works for basic list', () {
      final doc = html_parser.parse(
        '<ul><li>1</li><li>2</li><li>3</li></ul>',
      );
      final engine = RuleParserEngine();

      final els = engine.debugQueryAllElements(doc, 'li:nth-child(2)');
      expect(els.map((e) => e.text).toList(), ['2']);
    });

    test('nth-last-child works', () {
      final doc = html_parser.parse(
        '<ul><li>1</li><li>2</li><li>3</li></ul>',
      );
      final engine = RuleParserEngine();

      final els = engine.debugQueryAllElements(doc, 'li:nth-last-child(1)');
      expect(els.map((e) => e.text).toList(), ['3']);
    });

    test('nth-of-type works with mixed siblings', () {
      final doc = html_parser.parse(
        '<div><span>a</span><i>b</i><span>c</span><span>d</span></div>',
      );
      final engine = RuleParserEngine();

      final els = engine.debugQueryAllElements(doc, 'div > span:nth-of-type(2)');
      expect(els.map((e) => e.text).toList(), ['c']);
    });

    test('selector groups with comma are supported', () {
      final doc = html_parser.parse(
        '<ul><li>1</li><li>2</li><li>3</li></ul>',
      );
      final engine = RuleParserEngine();

      final els = engine.debugQueryAllElements(
        doc,
        'li:nth-child(1), li:nth-child(3)',
      );
      expect(els.map((e) => e.text).toSet(), {'1', '3'});
    });

    test('adjacent sibling combinator + works with nth-child filter', () {
      final doc = html_parser.parse(
        '<div><p class="a">A</p><p class="b">B</p><p class="b">C</p></div>',
      );
      final engine = RuleParserEngine();

      final els = engine.debugQueryAllElements(doc, 'p.a + p.b:nth-child(2)');
      expect(els.map((e) => e.text).toList(), ['B']);
    });
  });
}

