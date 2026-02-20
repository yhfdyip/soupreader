import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_source_action_helper.dart';

void main() {
  group('ReaderSourceActionHelper', () {
    test('legacy action order keeps four items and fixed sequence', () {
      expect(
        ReaderSourceActionHelper.legacyActionOrder,
        <String>['登录', '章节购买', '编辑书源', '禁用书源'],
      );
    });

    test('chapter pay visibility follows legacy flags when available', () {
      final visible = ReaderSourceActionHelper.shouldShowChapterPay(
        hasLoginUrl: true,
        hasPayAction: true,
        currentChapterIsVip: true,
        currentChapterIsPay: false,
      );
      final hiddenWhenPaid = ReaderSourceActionHelper.shouldShowChapterPay(
        hasLoginUrl: true,
        hasPayAction: true,
        currentChapterIsVip: true,
        currentChapterIsPay: true,
      );
      final hiddenWhenNotVip = ReaderSourceActionHelper.shouldShowChapterPay(
        hasLoginUrl: true,
        hasPayAction: true,
        currentChapterIsVip: false,
        currentChapterIsPay: false,
      );

      expect(visible, isTrue);
      expect(hiddenWhenPaid, isFalse);
      expect(hiddenWhenNotVip, isFalse);
    });

    test('chapter pay visibility falls back when chapter flags are missing',
        () {
      final visible = ReaderSourceActionHelper.shouldShowChapterPay(
        hasLoginUrl: true,
        hasPayAction: true,
        currentChapterIsVip: null,
        currentChapterIsPay: null,
      );
      expect(visible, isTrue);
    });

    test('pay action output resolves absolute url', () {
      final result = ReaderSourceActionHelper.resolvePayActionOutput(
        'https://buy.example.com/chapter/1',
      );
      expect(result.type, ReaderSourcePayActionResultType.url);
      expect(result.url, 'https://buy.example.com/chapter/1');
    });

    test('pay action output resolves boolean success/noop', () {
      final success = ReaderSourceActionHelper.resolvePayActionOutput('true');
      final noop = ReaderSourceActionHelper.resolvePayActionOutput('false');

      expect(success.type, ReaderSourcePayActionResultType.success);
      expect(noop.type, ReaderSourcePayActionResultType.noop);
    });
  });
}
