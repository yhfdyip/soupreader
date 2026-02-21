import 'dart:io';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/import/txt_parser.dart';

void main() {
  Uint8List utf16leBytes(String text) {
    final units = text.codeUnits;
    final out = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      out[i * 2] = units[i] & 0xFF;
      out[i * 2 + 1] = (units[i] >> 8) & 0xFF;
    }
    return out;
  }

  group('TxtParser charset override', () {
    test('forced GBK keeps Chinese text readable', () {
      final raw = '第1章 开始\n你好，世界';
      final bytes = Uint8List.fromList(gbk.encode(raw));

      final result = TxtParser.importFromBytes(
        bytes,
        'gbk.txt',
        forcedCharset: 'GBK',
      );

      expect(result.charset, 'GBK');
      expect(result.chapters, isNotEmpty);
      expect(result.chapters.first.content, contains('你好，世界'));
    });

    test('forced UTF-16LE decodes content correctly', () {
      final raw = '第1章 开始\n这是 UTF16LE 内容';
      final bytes = utf16leBytes(raw);

      final result = TxtParser.importFromBytes(
        bytes,
        'utf16le.txt',
        forcedCharset: 'UTF-16LE',
      );

      expect(result.charset, 'UTF-16LE');
      expect(result.chapters, isNotEmpty);
      expect(result.chapters.first.content, contains('这是 UTF16LE 内容'));
    });

    test('reparseFromFile keeps existing book id', () async {
      final dir = await Directory.systemTemp.createTemp('txt_reparse_');
      final file = File('${dir.path}${Platform.pathSeparator}demo.txt');
      await file.writeAsBytes(gbk.encode('第1章 开始\n重解析正文').toList());

      try {
        final result = await TxtParser.reparseFromFile(
          filePath: file.path,
          bookId: 'book-fixed-id',
          bookName: '固定ID书籍',
          forcedCharset: 'GB18030',
        );

        expect(result.book.id, 'book-fixed-id');
        expect(result.charset, 'GB18030');
        expect(
          result.chapters.every((chapter) => chapter.bookId == 'book-fixed-id'),
          isTrue,
        );
      } finally {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('reparseFromFile 按 splitLongChapter 控制长正文拆分', () async {
      final dir = await Directory.systemTemp.createTemp('txt_reparse_split_');
      final file = File('${dir.path}${Platform.pathSeparator}split.txt');
      final longContent = List<String>.filled(6200, '甲').join();
      await file.writeAsString(longContent, flush: true);

      try {
        final disabled = await TxtParser.reparseFromFile(
          filePath: file.path,
          bookId: 'book-split-off',
          bookName: '关闭拆分',
          splitLongChapter: false,
        );
        final enabled = await TxtParser.reparseFromFile(
          filePath: file.path,
          bookId: 'book-split-on',
          bookName: '开启拆分',
          splitLongChapter: true,
        );

        expect(disabled.chapters.length, 1);
        expect(disabled.chapters.first.title, '正文');
        expect(enabled.chapters.length, greaterThan(1));
      } finally {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    });
  });
}
