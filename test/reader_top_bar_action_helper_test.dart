import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_top_bar_action_helper.dart';

void main() {
  group('ReaderTopBarActionHelper', () {
    test('normalizeChapterUrl trims legacy suffix', () {
      expect(
        ReaderTopBarActionHelper.normalizeChapterUrl(
          'https://a.example/ch/1,{extra:true}',
        ),
        'https://a.example/ch/1',
      );
    });

    test('resolveChapterUrl keeps absolute url', () {
      expect(
        ReaderTopBarActionHelper.resolveChapterUrl(
          chapterUrl: 'https://a.example/ch/2',
          bookUrl: 'https://book.example/info',
          sourceUrl: 'https://source.example',
        ),
        'https://a.example/ch/2',
      );
    });

    test('resolveChapterUrl resolves relative url by bookUrl first', () {
      expect(
        ReaderTopBarActionHelper.resolveChapterUrl(
          chapterUrl: '/chapter/3',
          bookUrl: 'https://book.example/novel/1',
          sourceUrl: 'https://source.example/root',
        ),
        'https://book.example/chapter/3',
      );
    });

    test('resolveChapterUrl falls back to sourceUrl when bookUrl missing', () {
      expect(
        ReaderTopBarActionHelper.resolveChapterUrl(
          chapterUrl: 'chapter/4',
          bookUrl: '',
          sourceUrl: 'https://source.example/entry/index.html',
        ),
        'https://source.example/entry/chapter/4',
      );
    });

    test('isHttpUrl accepts http/https only', () {
      expect(
        ReaderTopBarActionHelper.isHttpUrl('https://a.example'),
        isTrue,
      );
      expect(
        ReaderTopBarActionHelper.isHttpUrl('http://a.example'),
        isTrue,
      );
      expect(
        ReaderTopBarActionHelper.isHttpUrl('ftp://a.example'),
        isFalse,
      );
      expect(
        ReaderTopBarActionHelper.isHttpUrl('javascript:alert(1)'),
        isFalse,
      );
    });
  });
}
