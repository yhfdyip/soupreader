import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_image_request_parser.dart';

void main() {
  group('ReaderImageRequestParser', () {
    test('解析 legacy url option headers', () {
      const raw =
          'https://example.com/img.jpg,{"headers":{"Referer":"https://a.com","X-Test":"1"}}';
      final parsed = ReaderImageRequestParser.parse(raw);
      expect(parsed.raw, raw);
      expect(parsed.url, 'https://example.com/img.jpg');
      expect(parsed.headers['Referer'], 'https://a.com');
      expect(parsed.headers['X-Test'], '1');
    });

    test('解析 header 文本（JSON 与逐行）', () {
      final jsonHeaders = ReaderImageRequestParser.parseHeaderText(
        '{"User-Agent":"UA","Cookie":"a=1"}',
      );
      expect(jsonHeaders['User-Agent'], 'UA');
      expect(jsonHeaders['Cookie'], 'a=1');

      final lineHeaders = ReaderImageRequestParser.parseHeaderText(
        'Referer: https://r.example\nX-Token: abc',
      );
      expect(lineHeaders['Referer'], 'https://r.example');
      expect(lineHeaders['X-Token'], 'abc');
    });

    test('data url 不拆分 option', () {
      const dataUrl = 'data:image/png;base64,AA==';
      final parsed = ReaderImageRequestParser.parse(dataUrl);
      expect(parsed.url, dataUrl);
      expect(parsed.headers, isEmpty);
    });
  });
}
