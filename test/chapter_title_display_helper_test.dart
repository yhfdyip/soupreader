import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/services/chapter_title_display_helper.dart';

void main() {
  group('ChapterTitleDisplayHelper', () {
    final helper = ChapterTitleDisplayHelper();

    test('关闭转换时仅清理标题换行', () {
      final output = helper.normalizeAndConvertTitle(
        '第1章\r\n理发',
        chineseConverterType: ChineseConverterType.off,
      );
      expect(output, '第1章理发');
    });

    test('简转繁模式会执行字形转换', () {
      final output = helper.normalizeAndConvertTitle(
        '理发店',
        chineseConverterType: ChineseConverterType.simplifiedToTraditional,
      );
      expect(output, '理髮店');
    });

    test('繁转简模式会执行字形转换', () {
      final output = helper.normalizeAndConvertTitle(
        '願你閱讀愉快',
        chineseConverterType: ChineseConverterType.traditionalToSimplified,
      );
      expect(output, '愿你阅读愉快');
    });

    test('buildDisplayTitle 先转换再应用替换回调', () async {
      String? seenTitle;
      final result = await helper.buildDisplayTitle(
        rawTitle: '理发\n',
        bookName: '示例书',
        sourceUrl: 'https://example.com/source',
        chineseConverterType: ChineseConverterType.simplifiedToTraditional,
        applyTitleOverride: (title) async {
          seenTitle = title;
          return '[$title]';
        },
      );
      expect(seenTitle, '理髮');
      expect(result, '[理髮]');
    });

    test('buildDisplayTitles 按输入顺序返回处理结果', () async {
      final result = await helper.buildDisplayTitles(
        rawTitles: const ['第一章\r\n理发', '願你閱讀愉快'],
        bookName: '示例书',
        sourceUrl: null,
        chineseConverterType: ChineseConverterType.traditionalToSimplified,
        applyTitleOverride: (title) async => '<$title>',
      );
      expect(
        result,
        const <String>['<第一章理发>', '<愿你阅读愉快>'],
      );
    });
  });
}
