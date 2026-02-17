import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/widgets/scroll_text_layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScrollTextLayoutEngine', () {
    final engine = ScrollTextLayoutEngine.instance;

    setUp(() {
      engine.clearForTest();
    });

    test('compose returns non-empty lines for normal paragraph', () {
      const style = TextStyle(
        fontSize: 20,
        height: 1.6,
        letterSpacing: 0.2,
      );
      const content = '这是第一段正文内容，用于测试排版。\n这是第二行。';
      const key = ScrollTextLayoutKey(
        chapterId: 'c1',
        contentHash: 100,
        widthPx: 320,
        fontSizeX100: 2000,
        lineHeightX100: 160,
        letterSpacingX100: 20,
        fontFamily: null,
        fontWeight: null,
        fontStyle: null,
        justify: true,
        paragraphIndent: '　　',
        paragraphSpacingX100: 1200,
      );

      final layout = engine.compose(
        key: key,
        content: content,
        style: style,
        maxWidth: 320,
        justify: true,
        paragraphIndent: '　　',
        paragraphSpacing: 12,
      );

      expect(layout.lines, isNotEmpty);
      expect(layout.bodyHeight, greaterThan(0));
      expect(layout.lines.first.runs, isNotEmpty);
    });

    test('same key should hit cache and return same layout instance', () {
      const style = TextStyle(fontSize: 18, height: 1.5);
      const content = '缓存命中测试文本';
      const key = ScrollTextLayoutKey(
        chapterId: 'cache-key',
        contentHash: 1,
        widthPx: 280,
        fontSizeX100: 1800,
        lineHeightX100: 150,
        letterSpacingX100: 0,
        fontFamily: null,
        fontWeight: null,
        fontStyle: null,
        justify: false,
        paragraphIndent: '　　',
        paragraphSpacingX100: 1000,
      );

      final a = engine.compose(
        key: key,
        content: content,
        style: style,
        maxWidth: 280,
        justify: false,
        paragraphIndent: '　　',
        paragraphSpacing: 10,
      );
      final b = engine.compose(
        key: key,
        content: content,
        style: style,
        maxWidth: 280,
        justify: false,
        paragraphIndent: '　　',
        paragraphSpacing: 10,
      );

      expect(identical(a, b), isTrue);
      expect(engine.cacheSizeForDebug, 1);
    });

    test('different width key should produce a different cached layout', () {
      const style = TextStyle(fontSize: 18, height: 1.5);
      const content = '宽度变化应触发不同布局';
      const keyA = ScrollTextLayoutKey(
        chapterId: 'diff-width',
        contentHash: 2,
        widthPx: 240,
        fontSizeX100: 1800,
        lineHeightX100: 150,
        letterSpacingX100: 0,
        fontFamily: null,
        fontWeight: null,
        fontStyle: null,
        justify: true,
        paragraphIndent: '　　',
        paragraphSpacingX100: 1000,
      );
      const keyB = ScrollTextLayoutKey(
        chapterId: 'diff-width',
        contentHash: 2,
        widthPx: 360,
        fontSizeX100: 1800,
        lineHeightX100: 150,
        letterSpacingX100: 0,
        fontFamily: null,
        fontWeight: null,
        fontStyle: null,
        justify: true,
        paragraphIndent: '　　',
        paragraphSpacingX100: 1000,
      );

      final narrow = engine.compose(
        key: keyA,
        content: content,
        style: style,
        maxWidth: 240,
        justify: true,
        paragraphIndent: '　　',
        paragraphSpacing: 10,
      );
      final wide = engine.compose(
        key: keyB,
        content: content,
        style: style,
        maxWidth: 360,
        justify: true,
        paragraphIndent: '　　',
        paragraphSpacing: 10,
      );

      expect(identical(narrow, wide), isFalse);
      expect(engine.cacheSizeForDebug, 2);
    });
  });
}
