import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/import/txt_parser.dart';

void main() {
  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

  group('TxtParser typography normalization', () {
    test('merges hard-wrapped lines into paragraphs', () {
      // 构造“硬换行”正文：段落不空行（仅用一个空行分隔两段），每行长度相近。
      // 关键点：硬换行多数发生在“句子中间”，行尾通常不是句末标点。
      // 用“，”模拟行尾被截断；最后一行用“。”模拟自然收尾。
      final firstParaLines = List<String>.generate(12, (i) {
        final end = (i == 11) ? '。' : '，';
        return '这是第${i + 1}行接着上一行继续继续继续继续继续继续继续继续继续$end';
      });
      final secondParaLines = List<String>.generate(
        5,
        (i) {
          final end = (i == 4) ? '。' : '，';
          return '第二段第${i + 1}行继续继续继续继续继续继续继续$end';
        },
      );
      final input = [
        '第1章 开始',
        ...firstParaLines,
        '',
        ...secondParaLines,
      ].join('\n');

      final result = TxtParser.importFromBytes(bytes(input), 'demo.txt');
      expect(result.chapters.length, 1);

      final c = result.chapters.first.content ?? '';
      // 合并后应当明显少于原始行数（原始非空行=17）
      final outputLines = c.split('\n');
      expect(outputLines.length, lessThan(17));
      expect(outputLines.length, greaterThanOrEqualTo(2));
      expect(c.contains('这是第1行'), isTrue);
      expect(c.contains('这是第12行'), isTrue);
      expect(c.contains('第二段第5行'), isTrue);
    });

    test('does not merge already paragraph-indented text', () {
      final input = [
        '正文',
        '　　第一段有缩进，所以它本来就是按段落写的。',
        '　　第二段也有缩进。',
      ].join('\n');

      final result = TxtParser.importFromBytes(bytes(input), 'demo.txt');
      final c = result.chapters.first.content ?? '';
      expect(
        c,
        '正文\n'
        '　　第一段有缩进，所以它本来就是按段落写的。\n'
        '　　第二段也有缩进。',
      );
    });

    test('does not merge poetry-like short lines', () {
      final input = [
        '正文',
        '山有木兮木有枝',
        '心悦君兮君不知',
        '长相思兮长相忆',
      ].join('\n');

      final result = TxtParser.importFromBytes(bytes(input), 'demo.txt');
      final c = result.chapters.first.content ?? '';

      // 诗歌短句不应被合并成一段
      expect(c.split('\n').length, 4);
    });
  });
}
