import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  group('RuleParserEngine bookInfo tocUrl legado compat', () {
    final engine = RuleParserEngine();

    test('falls back to detail url when tocUrl is empty', () {
      final tocUrl = engine.debugResolveTocUrlLikeLegadoForTest(
        rawTocUrl: '',
        detailUrl: 'https://www.bqgu.cc/book/263/',
      );

      expect(tocUrl, 'https://www.bqgu.cc/book/263/');
    });

    test('falls back to detail url when tocUrl is only whitespace', () {
      final tocUrl = engine.debugResolveTocUrlLikeLegadoForTest(
        rawTocUrl: '   ',
        detailUrl: 'https://www.bqgu.cc/book/263/',
      );

      expect(tocUrl, 'https://www.bqgu.cc/book/263/');
    });

    test('resolves relative tocUrl against detail url', () {
      final tocUrl = engine.debugResolveTocUrlLikeLegadoForTest(
        rawTocUrl: '/book/263/list.html',
        detailUrl: 'https://www.bqgu.cc/book/263/',
      );

      expect(tocUrl, 'https://www.bqgu.cc/book/263/list.html');
    });

    test('keeps absolute tocUrl unchanged', () {
      final tocUrl = engine.debugResolveTocUrlLikeLegadoForTest(
        rawTocUrl: 'https://www.bqgu.cc/book/263/index.html',
        detailUrl: 'https://www.bqgu.cc/book/263/',
      );

      expect(tocUrl, 'https://www.bqgu.cc/book/263/index.html');
    });
  });
}
