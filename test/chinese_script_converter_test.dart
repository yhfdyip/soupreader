import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/utils/chinese_script_converter.dart';

void main() {
  group('ChineseScriptConverter', () {
    final converter = ChineseScriptConverter.instance;

    test('converts simplified chinese to traditional', () {
      const input = '简体转化为繁体，阅读器目录更新后继续阅读。';
      final output = converter.simplifiedToTraditional(input);
      expect(output, '簡體轉化爲繁體，閱讀器目錄更新後繼續閱讀。');
    });

    test('keeps ascii and emoji unchanged', () {
      const input = 'Chapter 12 ✅: abcXYZ123';
      final output = converter.simplifiedToTraditional(input);
      expect(output, input);
    });

    test('returns stable result on repeated calls', () {
      const input = '愿你阅读愉快';
      final first = converter.simplifiedToTraditional(input);
      final second = converter.simplifiedToTraditional(input);
      expect(first, '願你閱讀愉快');
      expect(second, first);
    });

    test('applies phrase overrides before char conversion', () {
      const input = '理发店开门一分钟后再理发。';
      final output = converter.simplifiedToTraditional(input);
      expect(output, '理髮店開門一分鐘後再理髮。');
    });

    test('uses longest phrase match at current position', () {
      const input = '一出戏结束后再来一出戏。';
      final output = converter.simplifiedToTraditional(input);
      expect(output, '一齣戲結束後再來一齣戲。');
    });

    test('converts traditional chinese to simplified', () {
      const input = '理髮店開門一分鐘後再理髮。';
      final output = converter.traditionalToSimplified(input);
      expect(output, '理发店开门一分钟后再理发。');
    });

    test('converts title-style text in traditional to simplified', () {
      const input = '願你閱讀愉快';
      final output = converter.traditionalToSimplified(input);
      expect(output, '愿你阅读愉快');
    });
  });
}
