import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/utils/html_text_formatter.dart';

void main() {
  group('HtmlTextFormatter.formatToPlainText', () {
    test('converts common block tags to newlines', () {
      final input = '<div>第一段</div><div>第二段</div>';
      expect(HtmlTextFormatter.formatToPlainText(input), '第一段\n第二段');
    });

    test('handles br/p and normalizes whitespace around newlines', () {
      final input = '<p> A </p><p>&nbsp;B&nbsp;</p><br/>  C';
      expect(HtmlTextFormatter.formatToPlainText(input), 'A\nB\nC');
    });

    test('removes HTML comments', () {
      final input = 'Hello<!-- should be removed -->World';
      expect(HtmlTextFormatter.formatToPlainText(input), 'HelloWorld');
    });

    test('removes common invisible characters and entities', () {
      final input = 'A&thinsp;B\u200C\u200D';
      expect(HtmlTextFormatter.formatToPlainText(input), 'AB');
    });

    test('strips remaining tags but keeps text', () {
      final input = '<span>Text</span><b>Bold</b>';
      expect(HtmlTextFormatter.formatToPlainText(input), 'TextBold');
    });
  });

  group('HtmlTextFormatter.formatKeepImageTags', () {
    test('keeps img tags and resolves src to absolute url', () {
      final input = '<div>图前<img data-src="/img/a.jpg"/>图后</div>';
      final output = HtmlTextFormatter.formatKeepImageTags(
        input,
        baseUrl: 'https://example.com/book/1',
      );
      expect(output, '　　图前<img src="https://example.com/img/a.jpg">图后');
    });

    test('keeps legado style image option suffix', () {
      final input = '<p><img src="/i.jpg{Referer@https://example.com}"/></p>';
      final output = HtmlTextFormatter.formatKeepImageTags(
        input,
        baseUrl: 'https://example.com/chapter/1',
      );
      expect(
        output,
        '　　<img src="https://example.com/i.jpg{Referer@https://example.com}">',
      );
    });
  });
}
